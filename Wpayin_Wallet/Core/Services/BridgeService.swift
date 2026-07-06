// Autor Lukas Helebrandt, 2026

//
//  BridgeService.swift
//  Wpayin_Wallet
//
//  Cross-chain bridging via the LI.FI aggregator (https://li.quest).
//  LI.FI picks the best bridge route (Stargate, Across, Hop, …) and returns
//  ready-to-sign calldata; signing and broadcasting reuse the same
//  WalletCore path as SwapService.
//

import Foundation
import BigInt

enum BridgeError: LocalizedError {
    case unsupportedNetwork
    case noRoute
    case quoteFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedNetwork:
            return "error.bridge.unsupportedNetwork".localized
        case .noRoute:
            return "error.bridge.noRoute".localized
        case .quoteFailed:
            return "error.bridge.quoteFailed".localized
        }
    }
}

struct BridgeQuote {
    let fromAmount: Decimal
    let toAmount: Decimal          // estimated amount on the destination chain
    let toAmountMin: Decimal       // guaranteed minimum after bridge slippage
    let toSymbol: String
    let toolName: String           // e.g. "Stargate", "Across"
    let executionDuration: TimeInterval
    let approvalAddress: String?   // spender for ERC-20 source tokens
    let txTo: String
    let txData: Data
    let txValue: BigUInt
    let gasLimit: BigUInt
}

final class BridgeService {
    static let shared = BridgeService()
    private init() {}

    /// EVM chains LI.FI can bridge between (must have a chainId).
    static let supportedBlockchains: Set<BlockchainType> = [
        .ethereum, .arbitrum, .base, .optimism, .polygon, .bsc, .avalanche
    ]

    private let quoteEndpoint = "https://li.quest/v1/quote"
    private let nativeAddress = "0x0000000000000000000000000000000000000000"

    // MARK: - Quote

    /// Ask LI.FI for the best route bridging `amount` of `fromToken` to the
    /// same asset on `toBlockchain`. `toTokenAddress` is the asset's contract
    /// on the destination chain when known; nil falls back to the symbol,
    /// which LI.FI resolves for all common tokens.
    func getQuote(
        fromToken: Token,
        toBlockchain: BlockchainType,
        toTokenAddress: String?,
        amount: Decimal,
        slippage: Double = 0.5
    ) async throws -> BridgeQuote {
        guard let fromChain = fromToken.blockchain.chainId,
              let toChain = toBlockchain.chainId,
              Self.supportedBlockchains.contains(fromToken.blockchain),
              Self.supportedBlockchains.contains(toBlockchain) else {
            throw BridgeError.unsupportedNetwork
        }

        guard let privateKey = try SwapService.shared.getPrivateKey(for: fromToken.blockchain) else {
            throw TransactionError.noPrivateKey
        }
        let fromAddress = try SwapService.shared.deriveAddress(from: privateKey, blockchain: fromToken.blockchain)

        let amountWei = (amount * swapPow(Decimal(10), fromToken.decimals)).swapRounded().description
        let fromTokenParam = fromToken.isNative ? nativeAddress : (fromToken.contractAddress ?? nativeAddress)
        let toTokenParam = toTokenAddress ?? (fromToken.isNative ? nativeAddress : fromToken.symbol.uppercased())

        var components = URLComponents(string: quoteEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "fromChain", value: String(fromChain)),
            URLQueryItem(name: "toChain", value: String(toChain)),
            URLQueryItem(name: "fromToken", value: fromTokenParam),
            URLQueryItem(name: "toToken", value: toTokenParam),
            URLQueryItem(name: "fromAmount", value: amountWei),
            URLQueryItem(name: "fromAddress", value: fromAddress),
            URLQueryItem(name: "slippage", value: String(slippage / 100))
        ]

        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
            Logger.log("🛑 LI.FI quote failed (HTTP \(http.statusCode)): \(message ?? "?")")
            // 404 = no route between the requested pair, anything else = provider trouble
            throw http.statusCode == 404 ? BridgeError.noRoute : BridgeError.quoteFailed
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let estimate = json["estimate"] as? [String: Any],
              let action = json["action"] as? [String: Any],
              let toTokenInfo = action["toToken"] as? [String: Any],
              let toDecimals = toTokenInfo["decimals"] as? Int,
              let toSymbol = toTokenInfo["symbol"] as? String,
              let toAmountRaw = estimate["toAmount"] as? String,
              let toAmountMinRaw = estimate["toAmountMin"] as? String,
              let txRequest = json["transactionRequest"] as? [String: Any],
              let txTo = txRequest["to"] as? String,
              let txDataHex = txRequest["data"] as? String,
              let txData = Data(hexString: txDataHex) else {
            Logger.log("🛑 LI.FI quote: unexpected response shape")
            throw BridgeError.quoteFailed
        }

        let toolName = (json["toolDetails"] as? [String: Any])?["name"] as? String
            ?? json["tool"] as? String
            ?? "Bridge"
        let duration = estimate["executionDuration"] as? Double ?? 300

        let divisor = swapPow(Decimal(10), toDecimals)
        let toAmount = (Decimal(string: toAmountRaw) ?? 0) / divisor
        let toAmountMin = (Decimal(string: toAmountMinRaw) ?? 0) / divisor
        guard toAmount > 0 else { throw BridgeError.noRoute }

        return BridgeQuote(
            fromAmount: amount,
            toAmount: toAmount,
            toAmountMin: toAmountMin,
            toSymbol: toSymbol,
            toolName: toolName,
            executionDuration: duration,
            approvalAddress: estimate["approvalAddress"] as? String,
            txTo: txTo,
            txData: txData,
            txValue: hexToBigUInt(txRequest["value"] as? String) ?? BigUInt(0),
            gasLimit: hexToBigUInt(txRequest["gasLimit"] as? String) ?? BigUInt(500_000)
        )
    }

    // MARK: - Execute

    /// Approve (when bridging an ERC-20) and broadcast the bridge transaction
    /// on the source chain. Returns the transaction hash.
    func executeBridge(quote: BridgeQuote, fromToken: Token) async throws -> String {
        let blockchain = fromToken.blockchain

        guard let privateKey = try SwapService.shared.getPrivateKey(for: blockchain) else {
            throw TransactionError.noPrivateKey
        }
        let fromAddress = try SwapService.shared.deriveAddress(from: privateKey, blockchain: blockchain)

        if !fromToken.isNative, let approvalAddress = quote.approvalAddress {
            try await SwapService.shared.checkAndApproveToken(
                token: fromToken,
                owner: fromAddress,
                spender: approvalAddress,
                amount: quote.fromAmount,
                blockchain: blockchain,
                privateKey: privateKey
            )
        }

        return try await SwapService.shared.sendRawTransaction(
            from: fromAddress,
            to: quote.txTo,
            value: quote.txValue,
            data: quote.txData,
            gasLimit: quote.gasLimit,
            blockchain: blockchain,
            privateKey: privateKey
        )
    }

    private func hexToBigUInt(_ hex: String?) -> BigUInt? {
        guard let hex else { return nil }
        let stripped = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        return BigUInt(stripped, radix: 16)
    }
}
