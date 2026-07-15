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

/// Phase reported while a swap is being executed, so the UI can show
/// live progress instead of a single opaque spinner.
enum SwapExecutionPhase {
    case approving
    case submitting
}

/// State of a broadcast transaction as reported by the chain's receipt.
enum OnChainTransactionState {
    /// Neither a receipt nor the transaction itself is known to the RPC node.
    /// This is distinct from a real pending transaction in the mempool.
    case notFound
    /// No receipt yet — still in the mempool / waiting to be mined.
    case pending
    case confirmed(blockNumber: String, gasUsed: Double, gasFeeNative: Double)
    case failed(blockNumber: String, gasUsed: Double, gasFeeNative: Double)
}

struct SwapNetworkFeeEstimate {
    let swapGasLimit: Int
    let approvalGasLimit: Int
    /// Gas limit including a safety margin and a possible ERC-20 approval.
    let totalGasLimit: Int
    let approvalRequired: Bool
    let gasPriceGwei: Decimal
    /// Maximum network fee at the node's current standard gas price.
    let standardFeeNative: Decimal
}

class SwapService {
    static let shared = SwapService()

    enum NativeWrapDirection: Equatable {
        case wrap
        case unwrap
    }

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

        // Native coins and their canonical wrapped token are the same asset.
        // Quoting them through a V2 router would create an invalid WETH -> WETH
        // path and the submitted transaction would revert on-chain.
        if nativeWrapDirection(fromToken: fromToken, toToken: toToken) != nil {
            return DEXSwapQuote(
                amountIn: amountIn,
                amountOut: amountIn,
                amountOutMin: amountIn,
                path: [],
                priceImpact: 0,
                gasEstimate: 60_000
            )
        }

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
        deadline: Int = 1200, // 20 minutes
        gasLimit: Int? = nil,
        approvalGasLimit: Int? = nil,
        gasPriceMultiplier: Double = 1,
        onPhase: (@MainActor (SwapExecutionPhase) -> Void)? = nil
    ) async throws -> SwapResult {
        let blockchain = fromToken.blockchain

        guard let privateKeyData = try getPrivateKey(for: blockchain) else {
            throw TransactionError.noPrivateKey
        }

        let fromAddress = try deriveAddress(from: privateKeyData, blockchain: blockchain)

        // ETH <-> WETH (and the equivalent pair on supported EVM chains) is
        // wrapping, not a DEX trade. Call the wrapped-native contract directly:
        // deposit() for wrapping and withdraw(uint256) for unwrapping.
        if let direction = nativeWrapDirection(fromToken: fromToken, toToken: toToken),
           let wrappedAddress = wrappedNativeAddresses[blockchain] {
            let amountUnits = BigUInt(
                (quote.amountIn * swapPow(Decimal(10), fromToken.decimals)).swapRounded().description
            ) ?? BigUInt(0)

            let value: BigUInt
            let data: Data
            switch direction {
            case .wrap:
                value = amountUnits
                data = Data(hexString: "d0e30db0")! // deposit()
            case .unwrap:
                value = BigUInt(0)
                var withdrawData = Data(hexString: "2e1a7d4d")! // withdraw(uint256)
                withdrawData.append(abiUInt(amountUnits))
                data = withdrawData
            }

            onPhase?(.submitting)
            let txHash = try await sendRawTransaction(
                from: fromAddress,
                to: wrappedAddress,
                value: value,
                data: data,
                gasLimit: BigUInt(gasLimit ?? 60_000),
                blockchain: blockchain,
                privateKey: privateKeyData,
                gasPriceMultiplier: Decimal(gasPriceMultiplier)
            )

            return SwapResult(
                transactionHash: txHash,
                amountIn: quote.amountIn,
                amountOut: quote.amountIn
            )
        }

        guard let routerAddress = routerAddresses[blockchain] else {
            throw SwapError.noRouterAddress
        }

        // Check if approval needed for ERC-20 tokens
        if !fromToken.isNative {
            onPhase?(.approving)
            // A zero estimate means the review simulation saw no approval
            // needed — fall back to a sane limit if one turns out required.
            let effectiveApprovalGas = (approvalGasLimit ?? 0) > 0 ? approvalGasLimit! : 60_000
            try await checkAndApproveToken(
                token: fromToken,
                owner: fromAddress,
                spender: routerAddress,
                amount: quote.amountIn,
                blockchain: blockchain,
                privateKey: privateKeyData,
                gasLimit: effectiveApprovalGas,
                gasPriceMultiplier: Decimal(gasPriceMultiplier)
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

        onPhase?(.submitting)
        let txHash = try await sendRawTransaction(
            from: fromAddress,
            to: routerAddress,
            value: value,
            data: swapData,
            gasLimit: BigUInt(gasLimit ?? quote.gasEstimate),
            blockchain: blockchain,
            privateKey: privateKeyData,
            gasPriceMultiplier: Decimal(gasPriceMultiplier)
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
        privateKey: Data,
        gasPriceMultiplier: Decimal = 1
    ) async throws -> String {
        let chainId = blockchain.chainId ?? 1
        async let nonceFetch = fetchNonce(address: from, blockchain: blockchain)
        async let gasPriceFetch = fetchGasPrice(blockchain: blockchain)
        let nonce = try await nonceFetch
        let gasPrice = try await gasPriceFetch
        let adjustedGasPrice = gasPrice * max(gasPriceMultiplier, Decimal(string: "0.1") ?? 0.1)
        let gasPriceInWei = BigUInt((adjustedGasPrice * swapPow(Decimal(10), 9)).swapRounded().description) ?? BigUInt(20_000_000_000)

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

    /// Collect the disclosed application fee in the source asset. This is a
    /// separate EVM transfer; a failure is logged and never turns an already
    /// broadcast swap/bridge into a failed user transaction.
    @discardableResult
    func collectPlatformFee(for amount: Decimal, token: Token) async -> String? {
        guard token.blockchain.isEVM,
              AppConfig.platformFeeEnabled else { return nil }
        let fee = TransactionService.platformFee(for: amount)
        guard fee > 0,
              let privateKey = try? getPrivateKey(for: token.blockchain) else { return nil }

        do {
            let owner = try deriveAddress(from: privateKey, blockchain: token.blockchain)
            let feeUnits = BigUInt(
                (fee * swapPow(Decimal(10), token.decimals)).swapRounded().description
            ) ?? BigUInt(0)
            guard feeUnits > 0 else { return nil }

            let target: String
            let value: BigUInt
            let data: Data
            let gasLimit: BigUInt

            if token.isNative {
                target = AppConfig.platformFeeRecipient
                value = feeUnits
                data = Data()
                gasLimit = BigUInt(21_000)
            } else {
                guard let contract = token.contractAddress else { return nil }
                target = contract
                value = BigUInt(0)
                var transferData = Data(hexString: "a9059cbb")!
                transferData.append(abiAddress(AppConfig.platformFeeRecipient))
                transferData.append(abiUInt(feeUnits))
                data = transferData
                gasLimit = BigUInt(65_000)
            }

            let hash = try await sendRawTransaction(
                from: owner,
                to: target,
                value: value,
                data: data,
                gasLimit: gasLimit,
                blockchain: token.blockchain,
                privateKey: privateKey
            )
            Logger.log("💸 Platform fee (\(AppConfig.platformFeeBps) bps) broadcast: \(hash)")
            return hash
        } catch {
            Logger.log("⚠️ Platform fee transfer failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Read the receipt of a broadcast transaction. `.pending` means no
    /// receipt exists yet; confirmed/failed include the real gas cost.
    func fetchTransactionState(hash: String, blockchain: BlockchainType) async throws -> OnChainTransactionState {
        let result = try await rpcRequest(
            method: "eth_getTransactionReceipt",
            params: [hash],
            blockchain: blockchain
        )

        guard let receipt = result as? [String: Any],
              let statusHex = receipt["status"] as? String else {
            let transaction = try await rpcRequest(
                method: "eth_getTransactionByHash",
                params: [hash],
                blockchain: blockchain
            )
            return transaction is [String: Any] ? .pending : .notFound
        }

        func hexValue(_ key: String) -> BigUInt {
            guard let hex = receipt[key] as? String else { return BigUInt(0) }
            let stripped = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
            return BigUInt(stripped, radix: 16) ?? BigUInt(0)
        }

        let blockNumber = hexValue("blockNumber").description
        let gasUsed = hexValue("gasUsed")
        let effectiveGasPrice = hexValue("effectiveGasPrice")
        let feeWei = Decimal(string: (gasUsed * effectiveGasPrice).description) ?? 0
        let gasFeeNative = NSDecimalNumber(decimal: feeWei / swapPow(Decimal(10), 18)).doubleValue
        let gasUsedDouble = NSDecimalNumber(decimal: Decimal(string: gasUsed.description) ?? 0).doubleValue

        if statusHex.lowercased() == "0x1" {
            return .confirmed(blockNumber: blockNumber, gasUsed: gasUsedDouble, gasFeeNative: gasFeeNative)
        }
        return .failed(blockNumber: blockNumber, gasUsed: gasUsedDouble, gasFeeNative: gasFeeNative)
    }

    /// Reads the current node gas price and simulates the exact swap calldata.
    /// If the input ERC-20 needs approval, its simulated gas is included too.
    func estimateNetworkFee(
        quote: DEXSwapQuote,
        fromToken: Token,
        toToken: Token
    ) async throws -> SwapNetworkFeeEstimate {
        let blockchain = fromToken.blockchain
        guard blockchain == toToken.blockchain,
              let privateKey = try getPrivateKey(for: blockchain) else {
            throw TransactionError.noPrivateKey
        }
        let owner = try deriveAddress(from: privateKey, blockchain: blockchain)
        let amountUnits = BigUInt(
            (quote.amountIn * swapPow(Decimal(10), fromToken.decimals)).swapRounded().description
        ) ?? BigUInt(0)

        let target: String
        let value: BigUInt
        let data: Data

        if let direction = nativeWrapDirection(fromToken: fromToken, toToken: toToken),
           let wrappedAddress = wrappedNativeAddresses[blockchain] {
            target = wrappedAddress
            switch direction {
            case .wrap:
                value = amountUnits
                data = Data(hexString: "d0e30db0")!
            case .unwrap:
                value = BigUInt(0)
                var withdrawData = Data(hexString: "2e1a7d4d")!
                withdrawData.append(abiUInt(amountUnits))
                data = withdrawData
            }
        } else {
            guard let router = routerAddresses[blockchain] else {
                throw SwapError.noRouterAddress
            }
            target = router
            value = fromToken.isNative ? amountUnits : BigUInt(0)
            data = try createSwapTransactionData(
                quote: quote,
                fromToken: fromToken,
                toToken: toToken,
                recipient: owner,
                deadline: 1200
            )
        }

        // The three lookups are independent — run them concurrently so the
        // review screen appears in one round-trip instead of three.
        let gasPriceTask = Task { try await self.fetchGasPrice(blockchain: blockchain) }
        let swapGasTask = Task {
            try await self.estimateGas(
                from: owner,
                to: target,
                value: value,
                data: data,
                blockchain: blockchain
            )
        }

        var approvalGas = 0
        var approvalRequired = false
        if !fromToken.isNative,
           nativeWrapDirection(fromToken: fromToken, toToken: toToken) == nil,
           let tokenAddress = fromToken.contractAddress,
           let router = routerAddresses[blockchain] {
            var allowanceData = Data(hexString: "dd62ed3e")!
            allowanceData.append(abiAddress(owner))
            allowanceData.append(abiAddress(router))
            let allowance = try await ethCall(to: tokenAddress, data: allowanceData, blockchain: blockchain)

            let currentAllowance = BigUInt(allowance)
            if currentAllowance < amountUnits {
                approvalRequired = true
                // USDT-style tokens revert when simulating a non-zero →
                // non-zero approve, so estimate approve(0) — always valid —
                // and double it when a reset transaction will be needed.
                let simulatedAmount = currentAllowance > 0 ? BigUInt(0) : amountUnits
                var approveData = Data(hexString: "095ea7b3")!
                approveData.append(abiAddress(router))
                approveData.append(abiUInt(simulatedAmount))
                approvalGas = try await estimateGas(
                    from: owner,
                    to: tokenAddress,
                    value: BigUInt(0),
                    data: approveData,
                    blockchain: blockchain
                )
                if currentAllowance > 0 {
                    approvalGas *= 2
                }
            }
        }

        let swapGas: Int
        do {
            swapGas = try await swapGasTask.value
        } catch {
            // A first ERC-20 swap cannot be simulated before its approval is
            // mined. In that one case use the route's conservative gas limit;
            // the approval itself was still estimated live above. A native
            // MAX attempt can also fail simulation because the provisional
            // value leaves no gas; its route limit lets the UI calculate the
            // actually spendable maximum before simulating again.
            guard approvalRequired || fromToken.isNative else {
                gasPriceTask.cancel()
                throw error
            }
            swapGas = quote.gasEstimate
        }

        // The estimate is the likely gas used. A 15% margin is the maximum
        // signed limit; unused gas is not charged by the EVM.
        let swapGasLimit = max(swapGas + swapGas * 15 / 100, 21_000)
        let approvalGasLimit = approvalGas > 0 ? approvalGas + approvalGas * 15 / 100 : 0
        let platformFeeGasLimit = AppConfig.platformFeeEnabled
            ? (fromToken.isNative ? 21_000 : 65_000)
            : 0
        let totalGasLimit = swapGasLimit + approvalGasLimit + platformFeeGasLimit
        let gasPriceGwei = try await gasPriceTask.value
        let standardFee = Decimal(totalGasLimit) * gasPriceGwei / swapPow(Decimal(10), 9)

        return SwapNetworkFeeEstimate(
            swapGasLimit: swapGasLimit,
            approvalGasLimit: approvalGasLimit,
            totalGasLimit: totalGasLimit,
            approvalRequired: approvalRequired,
            gasPriceGwei: gasPriceGwei,
            standardFeeNative: standardFee
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

    /// Identifies a native coin <-> canonical wrapped-native pair without
    /// relying on the display symbol, which can be supplied by custom tokens.
    func nativeWrapDirection(fromToken: Token, toToken: Token) -> NativeWrapDirection? {
        guard fromToken.blockchain == toToken.blockchain,
              let wrappedAddress = wrappedNativeAddresses[fromToken.blockchain] else {
            return nil
        }

        let fromIsWrapped = !fromToken.isNative
            && fromToken.contractAddress?.caseInsensitiveCompare(wrappedAddress) == .orderedSame
        let toIsWrapped = !toToken.isNative
            && toToken.contractAddress?.caseInsensitiveCompare(wrappedAddress) == .orderedSame

        if fromToken.isNative && toIsWrapped { return .wrap }
        if fromIsWrapped && toToken.isNative { return .unwrap }
        return nil
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
        privateKey: Data,
        gasLimit: Int = 60_000,
        gasPriceMultiplier: Decimal = 1
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

        // USDT-style tokens revert on a non-zero → non-zero approve; the
        // allowance must be reset to 0 first.
        if currentAllowance > 0 {
            Logger.log("🔏 Resetting non-zero allowance for \(token.symbol)...")
            try await sendApproval(
                spender: spender,
                amount: BigUInt(0),
                tokenAddress: tokenAddress,
                tokenSymbol: token.symbol,
                owner: owner,
                blockchain: blockchain,
                privateKey: privateKey,
                gasLimit: gasLimit,
                gasPriceMultiplier: gasPriceMultiplier
            )
        }

        Logger.log("🔏 Sending approve for \(token.symbol)...")
        try await sendApproval(
            spender: spender,
            amount: requiredAmount,
            tokenAddress: tokenAddress,
            tokenSymbol: token.symbol,
            owner: owner,
            blockchain: blockchain,
            privateKey: privateKey,
            gasLimit: gasLimit,
            gasPriceMultiplier: gasPriceMultiplier
        )
    }

    /// Broadcast an approve and wait until it is mined. Broadcasting the swap
    /// while the approve is still propagating makes load-balanced public RPC
    /// nodes hand out the same nonce twice — the second transaction then
    /// replaces the first and the swap reverts. ETH → token swaps need no
    /// approval, which is why only token → ETH swaps used to fail.
    private func sendApproval(
        spender: String,
        amount: BigUInt,
        tokenAddress: String,
        tokenSymbol: String,
        owner: String,
        blockchain: BlockchainType,
        privateKey: Data,
        gasLimit: Int,
        gasPriceMultiplier: Decimal
    ) async throws {
        // approve(address spender, uint256 amount) — 0x095ea7b3
        var approveData = Data(hexString: "095ea7b3")!
        approveData.append(abiAddress(spender))
        approveData.append(abiUInt(amount))

        let approveTxHash = try await sendRawTransaction(
            from: owner,
            to: tokenAddress,
            value: BigUInt(0),
            data: approveData,
            gasLimit: BigUInt(gasLimit),
            blockchain: blockchain,
            privateKey: privateKey,
            gasPriceMultiplier: gasPriceMultiplier
        )
        Logger.log("✅ Approve broadcast: \(approveTxHash), waiting for confirmation...")

        // Mainnet transactions can remain queued behind an earlier account
        // nonce for several minutes. Keep this aligned with the swap deadline
        // so a slow-but-valid approval is not reported as failed prematurely.
        let deadline = Date().addingTimeInterval(20 * 60)
        while Date() < deadline {
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            guard let state = try? await fetchTransactionState(
                hash: approveTxHash,
                blockchain: blockchain
            ) else { continue }

            switch state {
            case .notFound:
                // A future-nonce transaction may stay local to the accepting
                // RPC until the preceding nonce is mined, then propagate and
                // confirm normally. Treat temporary absence as queued.
                continue
            case .pending:
                continue
            case .confirmed:
                Logger.log("✅ Approve for \(tokenSymbol) confirmed")
                return
            case .failed:
                Logger.log("❌ Approve for \(tokenSymbol) reverted")
                throw TransactionError.networkError("error.swap.approvalFailed".localized)
            }
        }
        throw TransactionError.networkError("error.swap.approvalTimeout".localized)
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
            // Short timeout — a dead node must fail over quickly, the healthy
            // public nodes answer well under a second.
            request.timeoutInterval = 6
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

    /// Fetch the source account's live native-token balance from the chain.
    /// Send/withdraw validation must not rely on cached placeholder tokens.
    func fetchNativeBalance(blockchain: BlockchainType) async throws -> Decimal {
        guard let privateKey = try getPrivateKey(for: blockchain) else {
            throw TransactionError.noPrivateKey
        }
        let address = try deriveAddress(from: privateKey, blockchain: blockchain)
        let result = try await rpcRequest(
            method: "eth_getBalance",
            params: [address, "latest"],
            blockchain: blockchain
        )
        guard let hex = result as? String else {
            throw TransactionError.networkError("Invalid native balance response")
        }
        let stripped = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        guard let units = BigUInt(stripped, radix: 16) else {
            throw TransactionError.networkError("Invalid native balance response")
        }
        return (Decimal(string: units.description) ?? 0)
            / swapPow(Decimal(10), blockchain.nativeDecimals)
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

    private func estimateGas(
        from: String,
        to: String,
        value: BigUInt,
        data: Data,
        blockchain: BlockchainType
    ) async throws -> Int {
        let result = try await rpcRequest(
            method: "eth_estimateGas",
            params: [[
                "from": from,
                "to": to,
                "value": "0x" + String(value, radix: 16),
                "data": "0x" + data.hexString
            ]],
            blockchain: blockchain
        )

        guard let resultHex = result as? String else {
            throw TransactionError.networkError("Invalid eth_estimateGas response")
        }
        let stripped = resultHex.hasPrefix("0x") ? String(resultHex.dropFirst(2)) : resultHex
        guard let gas = Int(stripped, radix: 16), gas > 0 else {
            throw TransactionError.networkError("Invalid eth_estimateGas value")
        }
        return gas
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
