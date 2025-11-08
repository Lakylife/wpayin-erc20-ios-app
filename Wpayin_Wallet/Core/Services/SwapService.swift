//
//  SwapService.swift
//  Wpayin_Wallet
//
//  Service for token swapping via DEX protocols
//

import Foundation
import BigInt
import WalletCore

// Helper for pow with Decimal (same as in TransactionService)
func swapPow(_ base: Decimal, _ exponent: Int) -> Decimal {
    return NSDecimalNumber(decimal: base).raising(toPower: exponent).decimalValue
}

extension Decimal {
    func swapRounded(_ scale: Int = 0) -> Decimal {
        var result = Decimal()
        var localCopy = self
        NSDecimalRound(&result, &localCopy, scale, .plain)
        return result
    }
}

enum SwapError: LocalizedError {
    case unsupportedBlockchain
    case invalidTokenPair
    case insufficientLiquidity
    case slippageTooHigh
    case failedToGetQuote
    case failedToExecuteSwap
    case noRouterAddress

    var errorDescription: String? {
        switch self {
        case .unsupportedBlockchain:
            return "Blockchain not supported for swapping"
        case .invalidTokenPair:
            return "Invalid token pair for swap"
        case .insufficientLiquidity:
            return "Insufficient liquidity for this swap"
        case .slippageTooHigh:
            return "Price impact too high"
        case .failedToGetQuote:
            return "Failed to get swap quote"
        case .failedToExecuteSwap:
            return "Failed to execute swap"
        case .noRouterAddress:
            return "No DEX router address available"
        }
    }
}

struct DEXSwapQuote {
    let amountIn: Decimal
    let amountOut: Decimal
    let amountOutMin: Decimal // With slippage
    let path: [String] // Token addresses in swap path
    let priceImpact: Decimal
    let gasEstimate: Int
}

struct SwapResult {
    let transactionHash: String
    let amountIn: Decimal
    let amountOut: Decimal
}

class SwapService {
    static let shared = SwapService()

    private let transactionService = TransactionService.shared

    // Uniswap V2 Router addresses for different chains
    private let routerAddresses: [BlockchainType: String] = [
        .ethereum: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D", // Uniswap V2 Router
        .bsc: "0x10ED43C718714eb63d5aA57B78B54704E256024E", // PancakeSwap Router
        .polygon: "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff", // QuickSwap Router
        .arbitrum: "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506", // SushiSwap on Arbitrum
        .optimism: "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506", // SushiSwap on Optimism
        .base: "0x4752ba5dbc23f44d87826276bf6fd6b1c372ad24" // BaseSwap Router
    ]

    // Wrapped native token addresses
    private let wrappedNativeAddresses: [BlockchainType: String] = [
        .ethereum: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", // WETH
        .bsc: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c", // WBNB
        .polygon: "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270", // WMATIC
        .arbitrum: "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1", // WETH
        .optimism: "0x4200000000000000000000000000000000000006", // WETH
        .base: "0x4200000000000000000000000000000000000006" // WETH
    ]

    private init() {}

    // MARK: - Public Methods

    /// Get a swap quote
    func getQuote(
        fromToken: Token,
        toToken: Token,
        amountIn: Decimal,
        slippage: Double = 0.5
    ) async throws -> DEXSwapQuote {
        // Validate same blockchain
        guard fromToken.blockchain == toToken.blockchain else {
            throw SwapError.invalidTokenPair
        }

        let blockchain = fromToken.blockchain

        // Get token addresses
        let fromAddress = getTokenAddress(for: fromToken, blockchain: blockchain)
        let toAddress = getTokenAddress(for: toToken, blockchain: blockchain)

        // Build swap path
        let path = buildSwapPath(from: fromAddress, to: toAddress, blockchain: blockchain)

        // For simple quote, use price ratio
        // In production, this should call DEX smart contract or aggregator API
        let rate = fromToken.price > 0 && toToken.price > 0
            ? Decimal(fromToken.price / toToken.price)
            : Decimal(1.0)

        let amountOut = amountIn * rate

        // Calculate minimum amount out with slippage
        let slippageMultiplier = Decimal(1.0) - (Decimal(slippage) / Decimal(100.0))
        let amountOutMin = amountOut * slippageMultiplier

        // Estimate price impact (simplified)
        let priceImpact = Decimal(0.3) // 0.3% typical for DEXs

        // Gas estimate
        let gasEstimate = fromToken.isNative || toToken.isNative ? 150000 : 200000

        return DEXSwapQuote(
            amountIn: amountIn,
            amountOut: amountOut,
            amountOutMin: amountOutMin,
            path: path,
            priceImpact: priceImpact,
            gasEstimate: gasEstimate
        )
    }

    /// Execute swap
    func executeSwap(
        quote: DEXSwapQuote,
        fromToken: Token,
        toToken: Token,
        deadline: Int = 1200 // 20 minutes
    ) async throws -> SwapResult {
        let blockchain = fromToken.blockchain

        guard let routerAddress = routerAddresses[blockchain] else {
            throw SwapError.noRouterAddress
        }

        // Get user address
        _ = KeychainManager()  // Available for future use if needed
        guard let privateKeyData = try getPrivateKey(for: blockchain) else {
            throw TransactionError.noPrivateKey
        }

        let fromAddress = try deriveAddress(from: privateKeyData, blockchain: blockchain)

        // Check if approval needed for ERC-20 tokens
        if !fromToken.isNative {
            try await checkAndApproveToken(
                token: fromToken,
                spender: routerAddress,
                amount: quote.amountIn
            )
        }

        // Create swap transaction data
        let swapData = try createSwapTransactionData(
            quote: quote,
            fromToken: fromToken,
            toToken: toToken,
            recipient: fromAddress,
            deadline: deadline
        )

        // Send transaction
        let chainId = blockchain.chainId ?? 1
        let rpcUrl = blockchain.rpcUrl
        let nonce = try await fetchNonce(address: fromAddress, rpcUrl: rpcUrl)
        let gasPrice = try await fetchGasPrice(rpcUrl: rpcUrl)

        // If swapping from native token, include value in transaction
        let value = fromToken.isNative
            ? BigUInt((quote.amountIn * swapPow(Decimal(10), fromToken.decimals)).swapRounded().description) ?? BigUInt(0)
            : BigUInt(0) // 0 for ERC-20

        let gasPriceInWei = BigUInt((gasPrice * swapPow(Decimal(10), 9)).swapRounded().description) ?? BigUInt(20_000_000_000)

        // Sign transaction
        let signedTx = try signSwapTransaction(
            from: fromAddress,
            to: routerAddress,
            value: value,
            gasPrice: gasPriceInWei,
            gasLimit: BigUInt(quote.gasEstimate),
            nonce: BigUInt(nonce),
            data: swapData,
            chainId: chainId,
            privateKey: privateKeyData
        )
        let txHash = try await broadcastTransaction(signedTx: signedTx, rpcUrl: rpcUrl)

        return SwapResult(
            transactionHash: txHash,
            amountIn: quote.amountIn,
            amountOut: quote.amountOut
        )
    }

    // MARK: - Private Helper Methods

    private func getTokenAddress(for token: Token, blockchain: BlockchainType) -> String {
        if token.isNative {
            return wrappedNativeAddresses[blockchain] ?? ""
        } else {
            return token.contractAddress ?? ""
        }
    }

    private func buildSwapPath(from: String, to: String, blockchain: BlockchainType) -> [String] {
        // Simple direct path for now
        // In production, you'd use a routing algorithm to find best path
        return [from, to]
    }

    private func createSwapTransactionData(
        quote: DEXSwapQuote,
        fromToken: Token,
        toToken: Token,
        recipient: String,
        deadline: Int
    ) throws -> Data {
        // Function selector for swapExactTokensForTokens or swapExactETHForTokens
        let functionSelector: String
        if fromToken.isNative {
            // swapExactETHForTokens(uint amountOutMin, address[] path, address to, uint deadline)
            functionSelector = "7ff36ab5"
        } else if toToken.isNative {
            // swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] path, address to, uint deadline)
            functionSelector = "18cbafe5"
        } else {
            // swapExactTokensForTokens(uint amountIn, uint amountOutMin, address[] path, address to, uint deadline)
            functionSelector = "38ed1739"
        }

        var data = Data(hexString: functionSelector)!

        // Encode parameters
        // This is simplified - in production use proper ABI encoding
        let amountInWei = BigUInt((quote.amountIn * swapPow(Decimal(10), fromToken.decimals)).swapRounded().description) ?? BigUInt(0)
        let amountOutMinWei = BigUInt((quote.amountOutMin * swapPow(Decimal(10), toToken.decimals)).swapRounded().description) ?? BigUInt(0)
        _ = Int(Date().timeIntervalSince1970) + deadline  // Deadline timestamp (unused in simplified implementation)

        // Add parameters (simplified encoding)
        if !fromToken.isNative {
            data.append(paddedData(amountInWei.serialize(), size: 32))
        }
        data.append(paddedData(amountOutMinWei.serialize(), size: 32))

        // Path array offset and data would go here
        // For simplicity, we're using a basic implementation
        // In production, use proper ABI encoding library

        return data
    }

    private func checkAndApproveToken(
        token: Token,
        spender: String,
        amount: Decimal
    ) async throws {
        // Check current allowance
        // If insufficient, send approve transaction
        // This is simplified - in production, check allowance first
        print("ℹ️ Token approval may be required for \(token.symbol)")
    }

    private func paddedData(_ data: Data, size: Int) -> Data {
        var result = Data(repeating: 0, count: max(0, size - data.count))
        result.append(data)
        return result
    }

    // Reuse methods from TransactionService
    private func getPrivateKey(for blockchain: BlockchainType) throws -> Data? {
        let keychain = KeychainManager()
        let mnemonicService = MnemonicService()

        if let seedPhrase = keychain.getSeedPhrase() {
            guard let wallet = try? mnemonicService.loadWallet(from: seedPhrase) else {
                return nil
            }

            guard let coinType = blockchain.coinType else {
                return nil
            }

            let privateKey = wallet.getKey(coin: coinType, derivationPath: blockchain.derivationPath)
            return privateKey.data
        } else if let privateKeyHex = keychain.getPrivateKey() {
            return Data(hexString: privateKeyHex)
        }

        return nil
    }

    private func deriveAddress(from privateKeyData: Data, blockchain: BlockchainType) throws -> String {
        guard let coinType = blockchain.coinType else {
            throw TransactionError.failedToCreateTransaction
        }

        let privateKey = PrivateKey(data: privateKeyData)!
        let address = coinType.deriveAddress(privateKey: privateKey)

        return address.description
    }

    private func signSwapTransaction(
        from: String,
        to: String,
        value: BigUInt,
        gasPrice: BigUInt,
        gasLimit: BigUInt,
        nonce: BigUInt,
        data: Data,
        chainId: Int,
        privateKey: Data
    ) throws -> String {
        // Use same signing logic as TransactionService
        _ = TransactionService.shared  // Available for future use
        // For simplicity, we'll create a simple RLP-encoded transaction
        // In production, share the signing method between services

        var rlpItems: [Any] = []
        rlpItems.append(nonce.serialize())
        rlpItems.append(gasPrice.serialize())
        rlpItems.append(gasLimit.serialize())

        let toData = Data(hexString: String(to.dropFirst(2)))!
        rlpItems.append(toData)
        rlpItems.append(value.serialize())
        rlpItems.append(data)
        rlpItems.append(BigUInt(chainId).serialize())
        rlpItems.append(Data())
        rlpItems.append(Data())

        let txHash = Hash.keccak256(data: rlpEncode(rlpItems))

        guard let privKey = PrivateKey(data: privateKey) else {
            throw TransactionError.noPrivateKey
        }

        let signature = privKey.sign(digest: txHash, curve: .secp256k1)!
        let r = signature.dropLast(1).prefix(32)
        let s = signature.dropLast(1).suffix(32)
        let v = BigUInt(chainId * 2 + 35 + Int(signature.last ?? 0))

        var signedItems: [Any] = []
        signedItems.append(nonce.serialize())
        signedItems.append(gasPrice.serialize())
        signedItems.append(gasLimit.serialize())
        signedItems.append(toData)
        signedItems.append(value.serialize())
        signedItems.append(data)
        signedItems.append(v.serialize())
        signedItems.append(r)
        signedItems.append(s)

        return rlpEncode(signedItems).hexString
    }

    private func rlpEncode(_ items: [Any]) -> Data {
        var result = Data()

        for item in items {
            if let data = item as? Data {
                if data.isEmpty {
                    result.append(0x80)
                } else if data.count == 1 && data[0] < 0x80 {
                    result.append(data)
                } else if data.count < 56 {
                    result.append(UInt8(0x80 + data.count))
                    result.append(data)
                } else {
                    let lengthData = BigUInt(data.count).serialize()
                    result.append(UInt8(0xb7 + lengthData.count))
                    result.append(lengthData)
                    result.append(data)
                }
            }
        }

        if result.count < 56 {
            var final = Data([UInt8(0xc0 + result.count)])
            final.append(result)
            return final
        } else {
            let lengthData = BigUInt(result.count).serialize()
            var final = Data([UInt8(0xf7 + lengthData.count)])
            final.append(lengthData)
            final.append(result)
            return final
        }
    }

    private func fetchNonce(address: String, rpcUrl: String) async throws -> Int {
        let url = URL(string: rpcUrl)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_getTransactionCount",
            "params": [address, "latest"],
            "id": 1
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let result = json?["result"] as? String else {
            throw TransactionError.networkError("Failed to fetch nonce")
        }

        let hexString = result.hasPrefix("0x") ? String(result.dropFirst(2)) : result
        return Int(hexString, radix: 16) ?? 0
    }

    private func fetchGasPrice(rpcUrl: String) async throws -> Decimal {
        let url = URL(string: rpcUrl)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_gasPrice",
            "params": [],
            "id": 1
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let result = json?["result"] as? String else {
            throw TransactionError.networkError("Failed to fetch gas price")
        }

        let hexString = result.hasPrefix("0x") ? String(result.dropFirst(2)) : result
        guard let weiValue = Int(hexString, radix: 16) else {
            return 20
        }

        return Decimal(weiValue) / pow(10, 9)
    }

    private func broadcastTransaction(signedTx: String, rpcUrl: String) async throws -> String {
        let url = URL(string: rpcUrl)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_sendRawTransaction",
            "params": ["0x" + signedTx],
            "id": 1
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        if let error = json?["error"] as? [String: Any],
           let message = error["message"] as? String {
            throw TransactionError.networkError(message)
        }

        guard let txHash = json?["result"] as? String else {
            throw TransactionError.failedToSendTransaction
        }

        return txHash
    }
}
