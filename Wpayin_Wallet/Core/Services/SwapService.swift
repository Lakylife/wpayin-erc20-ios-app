// Autor Lukas Helebrandt, 2026

//
//  SwapService.swift
//  Wpayin_Wallet
//
//  Service for token swapping via DEX protocols
//

import Foundation
import BigInt
import WalletCore
import SwiftProtobuf

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
            return "error.swap.unsupportedBlockchain".localized
        case .invalidTokenPair:
            return "error.swap.invalidTokenPair".localized
        case .insufficientLiquidity:
            return "error.swap.insufficientLiquidity".localized
        case .slippageTooHigh:
            return "error.swap.slippageTooHigh".localized
        case .failedToGetQuote:
            return "error.swap.failedToGetQuote".localized
        case .failedToExecuteSwap:
            return "error.swap.failedToExecuteSwap".localized
        case .noRouterAddress:
            return "error.swap.noRouterAddress".localized
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

        // Ask the DEX router for a real on-chain quote (getAmountsOut);
        // fall back to the oracle price ratio if the call fails.
        var amountOut: Decimal
        if let onChainOut = try? await fetchAmountsOut(
            amountIn: amountIn,
            fromDecimals: fromToken.decimals,
            toDecimals: toToken.decimals,
            path: path,
            blockchain: blockchain
        ) {
            amountOut = onChainOut
        } else {
            guard fromToken.price > 0, toToken.price > 0 else {
                throw SwapError.failedToGetQuote
            }
            amountOut = amountIn * Decimal(fromToken.price / toToken.price)
        }

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

        guard let privateKeyData = try getPrivateKey(for: blockchain) else {
            throw TransactionError.noPrivateKey
        }

        let fromAddress = try deriveAddress(from: privateKeyData, blockchain: blockchain)

        // Check if approval needed for ERC-20 tokens
        if !fromToken.isNative {
            try await checkAndApproveToken(
                token: fromToken,
                owner: fromAddress,
                spender: routerAddress,
                amount: quote.amountIn,
                blockchain: blockchain,
                privateKey: privateKeyData
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

        // If swapping from native token, include value in transaction
        let value = fromToken.isNative
            ? BigUInt((quote.amountIn * swapPow(Decimal(10), fromToken.decimals)).swapRounded().description) ?? BigUInt(0)
            : BigUInt(0) // 0 for ERC-20

        let txHash = try await sendRawTransaction(
            from: fromAddress,
            to: routerAddress,
            value: value,
            data: swapData,
            gasLimit: BigUInt(quote.gasEstimate),
            blockchain: blockchain,
            privateKey: privateKeyData
        )

        return SwapResult(
            transactionHash: txHash,
            amountIn: quote.amountIn,
            amountOut: quote.amountOut
        )
    }

    /// Sign (via WalletCore AnySigner) and broadcast a transaction.
    /// Internal so BridgeService can reuse the same canonical path.
    func sendRawTransaction(
        from: String,
        to: String,
        value: BigUInt,
        data: Data,
        gasLimit: BigUInt,
        blockchain: BlockchainType,
        privateKey: Data
    ) async throws -> String {
        let chainId = blockchain.chainId ?? 1
        let nonce = try await fetchNonce(address: from, blockchain: blockchain)
        let gasPrice = try await fetchGasPrice(blockchain: blockchain)
        let gasPriceInWei = BigUInt((gasPrice * swapPow(Decimal(10), 9)).swapRounded().description) ?? BigUInt(20_000_000_000)

        let signedTx = try signSwapTransaction(
            from: from,
            to: to,
            value: value,
            gasPrice: gasPriceInWei,
            gasLimit: gasLimit,
            nonce: BigUInt(nonce),
            data: data,
            chainId: chainId,
            privateKey: privateKey
        )
        return try await broadcastTransaction(signedTx: signedTx, blockchain: blockchain)
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
        let amountInWei = BigUInt((quote.amountIn * swapPow(Decimal(10), fromToken.decimals)).swapRounded().description) ?? BigUInt(0)
        let amountOutMinWei = BigUInt((quote.amountOutMin * swapPow(Decimal(10), toToken.decimals)).swapRounded().description) ?? BigUInt(0)
        let deadlineTimestamp = BigUInt(UInt64(Date().timeIntervalSince1970) + UInt64(deadline))

        guard quote.path.count >= 2, quote.path.allSatisfy({ $0.hasPrefix("0x") && $0.count == 42 }) else {
            throw SwapError.invalidTokenPair
        }

        // Uniswap V2 router ABI:
        // swapExactETHForTokens(uint amountOutMin, address[] path, address to, uint deadline)          — 0x7ff36ab5
        // swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] path, address to, uint deadline)    — 0x18cbafe5
        // swapExactTokensForTokens(uint amountIn, uint amountOutMin, address[] path, address to, uint deadline) — 0x38ed1739
        var head: [Data] = []
        let selector: String

        if fromToken.isNative {
            selector = "7ff36ab5"
            head = [
                abiUInt(amountOutMinWei),
                abiUInt(BigUInt(4 * 32)), // offset of path array (4 head slots)
                abiAddress(recipient),
                abiUInt(deadlineTimestamp)
            ]
        } else {
            selector = toToken.isNative ? "18cbafe5" : "38ed1739"
            head = [
                abiUInt(amountInWei),
                abiUInt(amountOutMinWei),
                abiUInt(BigUInt(5 * 32)), // offset of path array (5 head slots)
                abiAddress(recipient),
                abiUInt(deadlineTimestamp)
            ]
        }

        var data = Data(hexString: selector)!
        head.forEach { data.append($0) }

        // Dynamic tail: address[] path
        data.append(abiUInt(BigUInt(quote.path.count)))
        for address in quote.path {
            data.append(abiAddress(address))
        }

        return data
    }

    /// Check ERC-20 allowance and send an approve transaction when insufficient.
    /// Internal so BridgeService can reuse it with the bridge's approval address.
    func checkAndApproveToken(
        token: Token,
        owner: String,
        spender: String,
        amount: Decimal,
        blockchain: BlockchainType,
        privateKey: Data
    ) async throws {
        guard let tokenAddress = token.contractAddress else {
            throw SwapError.invalidTokenPair
        }

        let requiredAmount = BigUInt((amount * swapPow(Decimal(10), token.decimals)).swapRounded().description) ?? BigUInt(0)

        // allowance(address owner, address spender) — 0xdd62ed3e
        var allowanceCall = Data(hexString: "dd62ed3e")!
        allowanceCall.append(abiAddress(owner))
        allowanceCall.append(abiAddress(spender))

        let currentAllowance: BigUInt
        do {
            let result = try await ethCall(to: tokenAddress, data: allowanceCall, blockchain: blockchain)
            currentAllowance = BigUInt(result)
        } catch {
            Logger.log("⚠️ Allowance check failed, assuming approval needed: \(error)")
            currentAllowance = BigUInt(0)
        }

        guard currentAllowance < requiredAmount else {
            Logger.log("✅ Allowance sufficient for \(token.symbol)")
            return
        }

        Logger.log("🔏 Sending approve for \(token.symbol)...")

        // approve(address spender, uint256 amount) — 0x095ea7b3
        var approveData = Data(hexString: "095ea7b3")!
        approveData.append(abiAddress(spender))
        approveData.append(abiUInt(requiredAmount))

        let approveTxHash = try await sendRawTransaction(
            from: owner,
            to: tokenAddress,
            value: BigUInt(0),
            data: approveData,
            gasLimit: BigUInt(60_000),
            blockchain: blockchain,
            privateKey: privateKey
        )
        Logger.log("✅ Approve broadcast: \(approveTxHash)")
    }

    /// Query the router's getAmountsOut for a real quote.
    private func fetchAmountsOut(
        amountIn: Decimal,
        fromDecimals: Int,
        toDecimals: Int,
        path: [String],
        blockchain: BlockchainType
    ) async throws -> Decimal {
        guard let routerAddress = routerAddresses[blockchain] else {
            throw SwapError.noRouterAddress
        }
        guard path.count >= 2, path.allSatisfy({ $0.hasPrefix("0x") && $0.count == 42 }) else {
            throw SwapError.invalidTokenPair
        }

        let amountInWei = BigUInt((amountIn * swapPow(Decimal(10), fromDecimals)).swapRounded().description) ?? BigUInt(0)

        // getAmountsOut(uint256 amountIn, address[] path) — 0xd06ca61f
        var callData = Data(hexString: "d06ca61f")!
        callData.append(abiUInt(amountInWei))
        callData.append(abiUInt(BigUInt(2 * 32))) // offset of path array
        callData.append(abiUInt(BigUInt(path.count)))
        for address in path {
            callData.append(abiAddress(address))
        }

        let result = try await ethCall(to: routerAddress, data: callData, blockchain: blockchain)

        // Decode uint256[]: [offset][length][amounts...] — take the last amount.
        guard result.count >= 96 else { throw SwapError.failedToGetQuote }
        let lengthWord = result.subdata(in: 32..<64)
        let count = Int(BigUInt(lengthWord))
        guard count >= 2, result.count >= 64 + count * 32 else { throw SwapError.failedToGetQuote }

        let lastWord = result.subdata(in: (64 + (count - 1) * 32)..<(64 + count * 32))
        let amountOutWei = BigUInt(lastWord)
        guard amountOutWei > 0 else { throw SwapError.insufficientLiquidity }

        return (Decimal(string: amountOutWei.description) ?? 0) / swapPow(Decimal(10), toDecimals)
    }

    /// POST a JSON-RPC request, failing over to the chain's next RPC endpoint
    /// when a node is unreachable or replies with garbage (HTML error pages,
    /// rate-limit text, …). A well-formed JSON-RPC error aborts immediately —
    /// the node understood the request and rejected it for a real reason.
    func rpcRequest(method: String, params: [Any], blockchain: BlockchainType) async throws -> Any {
        var lastFailure = "no RPC endpoint configured"

        for urlString in blockchain.rpcUrls {
            guard let url = URL(string: urlString) else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 15
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "jsonrpc": "2.0",
                "method": method,
                "params": params,
                "id": 1
            ])

            let responseData: Data
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    lastFailure = "HTTP \(http.statusCode) from \(urlString)"
                    Logger.log("⚠️ RPC \(method): \(lastFailure), trying next endpoint")
                    continue
                }
                responseData = data
            } catch {
                lastFailure = "\(urlString): \(error.localizedDescription)"
                Logger.log("⚠️ RPC \(method): \(lastFailure), trying next endpoint")
                continue
            }

            guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
                lastFailure = "malformed response from \(urlString)"
                Logger.log("⚠️ RPC \(method): \(lastFailure), trying next endpoint")
                continue
            }

            if let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw TransactionError.fromRPCMessage(message)
            }

            if let result = json["result"] {
                return result
            }

            lastFailure = "no result from \(urlString)"
            Logger.log("⚠️ RPC \(method): \(lastFailure), trying next endpoint")
        }

        Logger.log("🛑 All \(blockchain.rawValue) RPC endpoints failed (\(lastFailure))")
        throw TransactionError.networkError("error.networkUnavailable".localized)
    }

    /// Read-only contract call via eth_call (internal — shared with P2PTradeService).
    func ethCall(to: String, data: Data, blockchain: BlockchainType) async throws -> Data {
        let result = try await rpcRequest(
            method: "eth_call",
            params: [["to": to, "data": "0x" + data.hexString], "latest"],
            blockchain: blockchain
        )

        guard let resultHex = result as? String,
              let resultData = Data(hexString: resultHex) else {
            throw TransactionError.networkError("Invalid eth_call response")
        }
        return resultData
    }

    // MARK: - ABI Encoding Helpers

    private func abiUInt(_ value: BigUInt) -> Data {
        paddedData(value.serialize(), size: 32)
    }

    private func abiAddress(_ address: String) -> Data {
        let raw = Data(hexString: String(address.dropFirst(2))) ?? Data()
        return paddedData(raw, size: 32)
    }

    private func paddedData(_ data: Data, size: Int) -> Data {
        var result = Data(repeating: 0, count: max(0, size - data.count))
        result.append(data)
        return result
    }

    // Reuse methods from TransactionService (internal — also used by BridgeService)
    func getPrivateKey(for blockchain: BlockchainType) throws -> Data? {
        let keychain = KeychainManager()
        let mnemonicService = MnemonicService()

        if let seedPhrase = keychain.getSeedPhrase() {
            guard let wallet = try? mnemonicService.loadWallet(from: seedPhrase) else {
                return nil
            }

            guard let coinType = blockchain.coinType else {
                return nil
            }

            // Spend from the account the user currently has active (multi-wallet)
            let accountIndex = UserDefaults.standard.integer(forKey: "ActiveAccountIndex")
            let path = mnemonicService.derivationPath(for: coinType, accountIndex: accountIndex)
            let privateKey = wallet.getKey(coin: coinType, derivationPath: path)
            return privateKey.data
        } else if let privateKeyHex = keychain.getPrivateKey() {
            return Data(hexString: privateKeyHex)
        }

        return nil
    }

    func deriveAddress(from privateKeyData: Data, blockchain: BlockchainType) throws -> String {
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
        // Sign via WalletCore AnySigner — same canonical path as TransactionService.
        let input = EthereumSigningInput.with {
            $0.chainID = BigUInt(chainId).serialize()
            $0.nonce = nonce.serialize()
            $0.txMode = .legacy
            $0.gasPrice = gasPrice.serialize()
            $0.gasLimit = gasLimit.serialize()
            $0.toAddress = to
            $0.privateKey = privateKey
            $0.transaction = EthereumTransaction.with {
                $0.contractGeneric = EthereumTransaction.ContractGeneric.with {
                    $0.amount = value.serialize()
                    $0.data = data
                }
            }
        }

        let output: EthereumSigningOutput = AnySigner.sign(input: input, coin: .ethereum)

        guard output.error == .ok, !output.encoded.isEmpty else {
            Logger.log("❌ Swap signing failed: \(output.errorMessage)")
            throw TransactionError.failedToSignTransaction
        }

        return output.encoded.hexString
    }

    private func fetchNonce(address: String, blockchain: BlockchainType) async throws -> Int {
        let result = try await rpcRequest(
            method: "eth_getTransactionCount",
            params: [address, "pending"], // include queued txs (approve + swap)
            blockchain: blockchain
        )

        guard let resultHex = result as? String else {
            throw TransactionError.networkError("Failed to fetch nonce")
        }

        let hexString = resultHex.hasPrefix("0x") ? String(resultHex.dropFirst(2)) : resultHex
        return Int(hexString, radix: 16) ?? 0
    }

    private func fetchGasPrice(blockchain: BlockchainType) async throws -> Decimal {
        let result = try await rpcRequest(
            method: "eth_gasPrice",
            params: [],
            blockchain: blockchain
        )

        guard let resultHex = result as? String else {
            throw TransactionError.networkError("Failed to fetch gas price")
        }

        let hexString = resultHex.hasPrefix("0x") ? String(resultHex.dropFirst(2)) : resultHex
        guard let weiValue = Int(hexString, radix: 16) else {
            return 20
        }

        return Decimal(weiValue) / pow(10, 9)
    }

    private func broadcastTransaction(signedTx: String, blockchain: BlockchainType) async throws -> String {
        let result = try await rpcRequest(
            method: "eth_sendRawTransaction",
            params: ["0x" + signedTx],
            blockchain: blockchain
        )

        guard let txHash = result as? String else {
            throw TransactionError.failedToSendTransaction
        }

        return txHash
    }
}
