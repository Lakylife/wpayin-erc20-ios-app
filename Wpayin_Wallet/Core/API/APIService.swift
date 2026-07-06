// Autor Lukas Helebrandt, 2026
//
//  APIService.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import Foundation
import Combine

struct NativeBalanceRequest: Sendable {
    let config: BlockchainConfig
    let tokenType: BlockchainType
    let address: String
}

class APIService: ObservableObject {
    static let shared = APIService()

    private let session = URLSession.shared

    private struct ExplorerEndpoint {
        let apiBase: String
        let apiKeyEnvs: [String]
        let supportsTokenTransfers: Bool

        func resolveAPIKey() -> String? {
            let environment = ProcessInfo.processInfo.environment
            for key in apiKeyEnvs {
                if let value = environment[key], Self.isUsableAPIKey(value) {
                    return value
                }
            }

            return Self.isUsableAPIKey(AppConfig.etherscanApiKey)
                ? AppConfig.etherscanApiKey
                : nil
        }

        private static func isUsableAPIKey(_ value: String) -> Bool {
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return !normalized.isEmpty && !normalized.uppercased().contains("YOUR_")
        }
    }

    private enum EtherscanAction: String {
        case normal = "txlist"
        case tokenTransfers = "tokentx"
    }

    private struct ExplorerResponse<Result: Decodable>: Decodable {
        let status: String
        let message: String
        let result: Result
    }

    private struct ExplorerNormalTransaction: Decodable {
        let blockNumber: String
        let timeStamp: String
        let hash: String
        let from: String
        let to: String
        let value: String
        let gasPrice: String
        let gasUsed: String
        let isError: String?
        let txreceipt_status: String?
        let contractAddress: String?
    }

    private struct ExplorerTokenTransaction: Decodable {
        let blockNumber: String
        let timeStamp: String
        let hash: String
        let from: String
        let to: String
        let value: String
        let tokenName: String
        let tokenSymbol: String
        let tokenDecimal: String
        let gasPrice: String
        let gasUsed: String
        let txreceipt_status: String?
    }

    private init() {}

    // MARK: - Wallet Operations (Public RPC)

    func getERC20Tokens(for address: String, config: BlockchainConfig) async throws -> [Token] {
        guard let endpoint = etherscanEndpoint(for: config.platform),
              let apiKey = endpoint.resolveAPIKey() else {
            return []
        }

        // Get token transfers to discover tokens
        let tokenTransfers = try await fetchEtherscanTransactions(
            address: address,
            normalizedAddress: address.lowercased(),
            blockchain: config.platform.blockchainType!,
            config: config,
            endpoint: endpoint,
            apiKey: apiKey,
            action: .tokenTransfers
        )

        // Extract unique token contracts from transfers
        let tokenContracts = Set(tokenTransfers.compactMap { transaction in
            // Parse contract address from transaction data if available
            return extractTokenContract(from: transaction)
        })

        var tokens: [Token] = []

        // For each discovered token, get its balance
        for contractAddress in tokenContracts {
            if let token = try? await getERC20TokenBalance(
                address: address,
                contractAddress: contractAddress,
                config: config,
                endpoint: endpoint,
                apiKey: apiKey
            ) {
                tokens.append(token)
            }
        }

        return tokens.sorted { $0.name < $1.name }
    }

    private func extractTokenContract(from transaction: Transaction) -> String? {
        // This would need to be implemented based on how token contract addresses
        // are stored in transactions. For now, return some common tokens.
        return nil
    }

    private func getERC20TokenBalance(
        address: String,
        contractAddress: String,
        config: BlockchainConfig,
        endpoint: ExplorerEndpoint,
        apiKey: String
    ) async throws -> Token? {
        // Implementation for getting ERC-20 token balance via API
        // This would use the tokenbalance action in Etherscan API
        return nil
    }

    func getNativeAssets(for requests: [NativeBalanceRequest]) async -> [Token] {
        guard !requests.isEmpty else { return [] }

        let priceIds = Set(requests.compactMap { $0.tokenType.coingeckoId })
        let priceAndLogoLookup = (try? await fetchPricesAndLogos(for: Array(priceIds))) ?? [:]

        var collectedTokens: [Token] = []

        for request in requests {
            let balance: Double

            do {
                switch request.tokenType {
                case .bitcoin:
                    balance = try await fetchBitcoinBalance(address: request.address)
                case .solana:
                    balance = try await fetchSolanaBalance(
                        address: request.address,
                        rpcURL: request.config.rpcUrl
                    )
                default:
                    balance = try await fetchEVMNativeBalanceWithFailover(
                        address: request.address,
                        blockchain: request.tokenType,
                        primaryRpcUrl: request.config.rpcUrl
                    )
                }
            } catch {
                // Do NOT emit a zero-balance token on a transient RPC failure —
                // skipping keeps the last known balance in WalletManager's merge
                // instead of making the user's funds "disappear" until the next
                // successful refresh.
                Logger.log("⚠️ Balance fetch failed for \(request.tokenType.name), keeping last known value: \(error)")
                continue
            }

            let priceAndLogo = request.tokenType.coingeckoId.flatMap { priceAndLogoLookup[$0] }
            let price = priceAndLogo?.price ?? 0
            let iconUrl = priceAndLogo?.imageUrl

            let token = Token(
                contractAddress: nil,
                name: request.tokenType.name,
                symbol: request.tokenType.nativeToken,
                decimals: request.tokenType.nativeDecimals,
                balance: balance,
                price: price,
                iconUrl: iconUrl,
                blockchain: request.tokenType,
                isNative: true,
                receivingAddress: request.address
            )

            collectedTokens.append(token)
        }

        return collectedTokens.sorted { $0.name < $1.name }
    }

    func getTransactions(for address: String, using configs: [BlockchainConfig]) async throws -> [Transaction] {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty else { return [] }

        let supportedConfigs = configs.filter { $0.network == .mainnet }
        guard !supportedConfigs.isEmpty else { return [] }

        let normalizedAddress = trimmedAddress.lowercased()
        var aggregated: [Transaction] = []
        var firstFailure: Error?
        var hadSuccessfulFetch = false

        for config in supportedConfigs {
            guard let blockchain = config.platform.blockchainType, blockchain.isEVM else { continue }

            let etherscan = etherscanEndpoint(for: config.platform)
            let etherscanKey = etherscan?.resolveAPIKey()
            var loadedThisChain = false

            if let etherscan, let etherscanKey {
                do {
                    let fetched = try await fetchTransactionHistory(
                        address: trimmedAddress,
                        normalizedAddress: normalizedAddress,
                        blockchain: blockchain,
                        config: config,
                        endpoint: etherscan,
                        apiKey: etherscanKey
                    )
                    aggregated.append(contentsOf: fetched)
                    hadSuccessfulFetch = true
                    loadedThisChain = true
                } catch {
                    if firstFailure == nil {
                        firstFailure = error
                    }
                    Logger.log("⚠️ Etherscan transaction fetch failed for \(config.platform.name): \(error)")
                }
            }

            guard !loadedThisChain, let fallback = blockscoutEndpoint(for: config.platform) else {
                continue
            }

            do {
                let fetched = try await fetchTransactionHistory(
                    address: trimmedAddress,
                    normalizedAddress: normalizedAddress,
                    blockchain: blockchain,
                    config: config,
                    endpoint: fallback,
                    apiKey: nil
                )
                aggregated.append(contentsOf: fetched)
                hadSuccessfulFetch = true
            } catch {
                if firstFailure == nil {
                    firstFailure = error
                }
                Logger.log("⚠️ Blockscout transaction fetch failed for \(config.platform.name): \(error)")
            }
        }

        if aggregated.isEmpty, !hadSuccessfulFetch, let failure = firstFailure {
            throw failure
        }

        var seen: Set<String> = []
        var deduped: [Transaction] = []
        for transaction in aggregated {
            let key = "\(transaction.hash.lowercased())|\(transaction.token.uppercased())|\(transaction.type.rawValue)"
            if seen.insert(key).inserted {
                deduped.append(transaction)
            }
        }

        return deduped.sorted { $0.timestamp > $1.timestamp }
    }

    private func fetchTransactionHistory(
        address: String,
        normalizedAddress: String,
        blockchain: BlockchainType,
        config: BlockchainConfig,
        endpoint: ExplorerEndpoint,
        apiKey: String?
    ) async throws -> [Transaction] {
        var transactions: [Transaction] = []
        var firstFailure: Error?
        var hadSuccessfulRequest = false

        do {
            let normalTransactions = try await fetchEtherscanTransactions(
                address: address,
                normalizedAddress: normalizedAddress,
                blockchain: blockchain,
                config: config,
                endpoint: endpoint,
                apiKey: apiKey,
                action: .normal
            )
            transactions.append(contentsOf: normalTransactions)
            hadSuccessfulRequest = true
        } catch {
            firstFailure = error
        }

        if endpoint.supportsTokenTransfers {
            do {
                let tokenTransfers = try await fetchEtherscanTransactions(
                    address: address,
                    normalizedAddress: normalizedAddress,
                    blockchain: blockchain,
                    config: config,
                    endpoint: endpoint,
                    apiKey: apiKey,
                    action: .tokenTransfers
                )
                transactions.append(contentsOf: tokenTransfers)
                hadSuccessfulRequest = true
            } catch {
                if firstFailure == nil {
                    firstFailure = error
                }
            }
        }

        if !hadSuccessfulRequest, let firstFailure {
            throw firstFailure
        }

        return transactions
    }

    private func etherscanEndpoint(for platform: BlockchainPlatform) -> ExplorerEndpoint? {
        switch platform {
        case .ethereum, .polygon, .bsc, .arbitrum, .optimism, .avalanche, .base, .gnosis:
            return ExplorerEndpoint(
                apiBase: "https://api.etherscan.io/v2/api",
                apiKeyEnvs: ["ETHERSCAN_API_KEY"],
                supportsTokenTransfers: true
            )
        default:
            return nil
        }
    }

    private func blockscoutEndpoint(for platform: BlockchainPlatform) -> ExplorerEndpoint? {
        let apiBase: String

        switch platform {
        case .ethereum:
            apiBase = "https://eth.blockscout.com/api"
        case .polygon:
            apiBase = "https://polygon.blockscout.com/api"
        case .arbitrum:
            apiBase = "https://arbitrum.blockscout.com/api"
        case .optimism:
            apiBase = "https://optimism.blockscout.com/api"
        case .base:
            apiBase = "https://base.blockscout.com/api"
        case .gnosis:
            apiBase = "https://gnosis.blockscout.com/api"
        default:
            return nil
        }

        return ExplorerEndpoint(
            apiBase: apiBase,
            apiKeyEnvs: [],
            supportsTokenTransfers: true
        )
    }

    private func getChainId(for blockchain: BlockchainType) -> Int {
        switch blockchain {
        case .ethereum:
            return 1
        case .polygon:
            return 137
        case .bsc:
            return 56
        case .arbitrum:
            return 42161
        case .optimism:
            return 10
        case .avalanche:
            return 43114
        case .base:
            return 8453
        case .gnosis:
            return 100
        default:
            return 1 // Default to Ethereum
        }
    }

    private func fetchEtherscanTransactions(
        address: String,
        normalizedAddress: String,
        blockchain: BlockchainType,
        config: BlockchainConfig,
        endpoint: ExplorerEndpoint,
        apiKey: String?,
        action: EtherscanAction
    ) async throws -> [Transaction] {
        guard var components = URLComponents(string: endpoint.apiBase) else {
            throw APIError.invalidURL
        }

        var queryItems = [
            URLQueryItem(name: "module", value: "account"),
            URLQueryItem(name: "action", value: action.rawValue),
            URLQueryItem(name: "address", value: address),
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "offset", value: "50"),
            URLQueryItem(name: "sort", value: "desc")
        ]

        if let apiKey {
            queryItems.append(URLQueryItem(name: "apikey", value: apiKey))
        }

        // Etherscan V2 uses one endpoint for every supported EVM chain.
        if endpoint.apiBase.contains("api.etherscan.io/v2/") {
            let chainId = getChainId(for: blockchain)
            queryItems.append(URLQueryItem(name: "chainid", value: "\(chainId)"))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        let decoder = JSONDecoder()

        switch action {
        case .normal:
            let decoded = try decoder.decode(ExplorerResponse<[ExplorerNormalTransaction]>.self, from: data)
            if decoded.status == "0" {
                if decoded.result.isEmpty || decoded.message.lowercased().contains("no transactions") {
                    return []
                } else {
                    throw APIError.invalidResponse
                }
            }

            return decoded.result.compactMap { entry in
                mapNormalTransaction(entry, normalizedAddress: normalizedAddress, blockchain: blockchain, config: config)
            }
        case .tokenTransfers:
            let decoded = try decoder.decode(ExplorerResponse<[ExplorerTokenTransaction]>.self, from: data)
            if decoded.status == "0" {
                if decoded.result.isEmpty || decoded.message.lowercased().contains("no transactions") {
                    return []
                } else {
                    throw APIError.invalidResponse
                }
            }

            return decoded.result.compactMap { entry in
                mapTokenTransaction(entry, normalizedAddress: normalizedAddress, blockchain: blockchain, config: config)
            }
        }
    }

    private func mapNormalTransaction(
        _ entry: ExplorerNormalTransaction,
        normalizedAddress: String,
        blockchain: BlockchainType,
        config: BlockchainConfig
    ) -> Transaction? {
        guard let timestamp = TimeInterval(entry.timeStamp) else { return nil }
        let amount = normalizedAmount(from: entry.value, decimals: blockchain.nativeDecimals)
        let gasFeeValue = gasFee(fromGasUsed: entry.gasUsed, gasPrice: entry.gasPrice, decimals: blockchain.nativeDecimals)
        let gasUsedDouble = Double(entry.gasUsed) ?? 0
        let status = transactionStatus(receipt: entry.txreceipt_status, isError: entry.isError)
        let isOutgoing = entry.from.lowercased() == normalizedAddress
        let transactionType: Transaction.TransactionType = isOutgoing ? .send : .receive
        let destination = entry.to.isEmpty ? (entry.contractAddress ?? entry.to) : entry.to
        let explorer = explorerURL(base: config.explorerUrl, hash: entry.hash)

        return Transaction(
            hash: entry.hash,
            from: entry.from,
            to: destination,
            amount: amount,
            token: blockchain.nativeToken,
            type: transactionType,
            status: status,
            timestamp: Date(timeIntervalSince1970: timestamp),
            gasUsed: gasUsedDouble,
            gasFee: gasFeeValue,
            blockNumber: entry.blockNumber,
            explorerUrl: explorer,
            blockchain: blockchain
        )
    }

    private func mapTokenTransaction(
        _ entry: ExplorerTokenTransaction,
        normalizedAddress: String,
        blockchain: BlockchainType,
        config: BlockchainConfig
    ) -> Transaction? {
        guard let timestamp = TimeInterval(entry.timeStamp) else { return nil }
        let decimals = Int(entry.tokenDecimal) ?? 18
        let amount = normalizedAmount(from: entry.value, decimals: decimals)
        let gasFeeValue = gasFee(fromGasUsed: entry.gasUsed, gasPrice: entry.gasPrice, decimals: blockchain.nativeDecimals)
        let gasUsedDouble = Double(entry.gasUsed) ?? 0
        let isOutgoing = entry.from.lowercased() == normalizedAddress
        let transactionType: Transaction.TransactionType = isOutgoing ? .send : .receive
        let explorer = explorerURL(base: config.explorerUrl, hash: entry.hash)
        let status = transactionStatus(receipt: entry.txreceipt_status, isError: nil)
        let symbol = entry.tokenSymbol.isEmpty ? entry.tokenName : entry.tokenSymbol

        return Transaction(
            hash: entry.hash,
            from: entry.from,
            to: entry.to,
            amount: amount,
            token: symbol,
            type: transactionType,
            status: status,
            timestamp: Date(timeIntervalSince1970: timestamp),
            gasUsed: gasUsedDouble,
            gasFee: gasFeeValue,
            blockNumber: entry.blockNumber,
            explorerUrl: explorer,
            blockchain: blockchain
        )
    }

    private func explorerURL(base: String, hash: String) -> URL? {
        var trimmed = base
        if trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        return URL(string: "\(trimmed)/tx/\(hash)")
    }

    private func normalizedAmount(from value: String, decimals: Int) -> Double {
        guard let amountDecimal = Decimal(string: value) else { return 0 }
        let divisor = powerOfTen(decimals)
        let normalized = decimalDividing(amountDecimal, by: divisor)
        return NSDecimalNumber(decimal: normalized).doubleValue
    }

    private func gasFee(fromGasUsed gasUsed: String, gasPrice: String, decimals: Int) -> Double {
        guard let gasUsedDecimal = Decimal(string: gasUsed), let gasPriceDecimal = Decimal(string: gasPrice) else { return 0 }
        let fee = gasPriceDecimal * gasUsedDecimal
        let normalized = decimalDividing(fee, by: powerOfTen(decimals))
        return NSDecimalNumber(decimal: normalized).doubleValue
    }

    private func transactionStatus(receipt: String?, isError: String?) -> Transaction.TransactionStatus {
        if let receipt = receipt {
            if receipt == "1" { return .confirmed }
            if receipt == "0" { return .failed }
        }
        if let isError = isError {
            if isError == "0" { return .confirmed }
            if isError == "1" { return .failed }
        }
        return .pending
    }

    // MARK: - Gas Price Operations

    /// Fetch current gas price from Ethereum network (in Gwei)
    func getCurrentGasPrice() async throws -> Double {
        // Use Ethereum mainnet RPC
        let rpcURL = URL(string: "https://ethereum-rpc.publicnode.com")!

        var request = URLRequest(url: rpcURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // JSON-RPC request for eth_gasPrice
        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_gasPrice",
            "params": [],
            "id": 1
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await session.data(for: request)

        struct GasPriceResponse: Codable {
            let result: String
        }

        let response = try JSONDecoder().decode(GasPriceResponse.self, from: data)

        // Convert hex Wei to Gwei (1 Gwei = 1e9 Wei)
        // Remove "0x" prefix and convert hex to decimal
        let hexString = String(response.result.dropFirst(2))
        guard let weiString = hexString.hexToDecimal(),
              let weiDouble = Double(weiString) else {
            throw APIError.invalidResponse
        }

        let gwei = weiDouble / 1_000_000_000
        return gwei
    }

    // MARK: - ERC-20 Token Operations

    /// Fetch ERC-20 token balance for a specific contract
    func getERC20TokenBalance(
        address: String,
        contractAddress: String,
        config: BlockchainConfig,
        name: String,
        symbol: String,
        decimals: Int
    ) async throws -> Token? {
        // Use Ethereum RPC to call balanceOf
        let rpcURL = URL(string: config.rpcUrl)!

        var request = URLRequest(url: rpcURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // ERC-20 balanceOf function signature: 0x70a08231
        // Followed by the address (padded to 32 bytes)
        let addressParam = address.replacingOccurrences(of: "0x", with: "").lowercased().padLeft(toLength: 64, withPad: "0")
        let data = "0x70a08231" + addressParam

        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_call",
            "params": [
                [
                    "to": contractAddress.lowercased(),
                    "data": data
                ],
                "latest"
            ],
            "id": 1
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (responseData, _) = try await session.data(for: request)

        struct BalanceResponse: Codable {
            let result: String
        }

        let response = try JSONDecoder().decode(BalanceResponse.self, from: responseData)

        // Convert hex balance to decimal
        let hexBalance = String(response.result.dropFirst(2))
        guard let balanceString = hexBalance.hexToDecimal(),
              let balanceWei = Double(balanceString) else {
            throw APIError.invalidResponse
        }

        // Convert from Wei to token units using decimals
        let balance = balanceWei / pow(10, Double(decimals))

        // Fetch price from CoinGecko
        let coingeckoId = APIService.getCoinId(for: symbol)
        let priceAndLogos = (try? await fetchPricesAndLogos(for: [coingeckoId])) ?? [:]
        let priceInfo = priceAndLogos[coingeckoId]
        let price = priceInfo?.price ?? 0
        let iconUrl = priceInfo?.imageUrl

        return Token(
            contractAddress: contractAddress,
            name: name,
            symbol: symbol,
            decimals: decimals,
            balance: balance,
            price: price,
            iconUrl: iconUrl,
            blockchain: config.blockchainType ?? .ethereum,
            isNative: false  // ERC-20 tokens are not native
        )
    }

    // MARK: - Transaction Operations

    func sendTransaction(_ request: SendTransactionRequest) async throws -> TransactionResponse {
        _ = request
        throw APIError.unsupportedFeature
    }

    func estimateGas(for transaction: EstimateGasRequest) async throws -> GasEstimate {
        _ = transaction
        throw APIError.unsupportedFeature
    }

    // MARK: - Swap Operations

    func getSwapQuote(_ request: SwapQuoteRequest) async throws -> SwapQuote {
        _ = request
        throw APIError.unsupportedFeature
    }

    func executeSwap(_ request: ExecuteSwapRequest) async throws -> TransactionResponse {
        _ = request
        throw APIError.unsupportedFeature
    }

    // MARK: - DeFi Operations

    func getDeFiProtocols() async throws -> [DeFiProtocol] {
        throw APIError.unsupportedFeature
    }

    func getDeFiPositions(for address: String) async throws -> [DeFiPosition] {
        _ = address
        throw APIError.unsupportedFeature
    }

    // MARK: - Token Information

    /// Fetch ERC-20 token information (name, symbol, decimals) from contract address
    func getTokenInfo(contractAddress: String, config: BlockchainConfig? = nil) async throws -> TokenInfo {
        Logger.log("🔍 Fetching token info for contract: \(contractAddress)")
        
        let blockchainConfig = config ?? BlockchainConfig.defaultConfigs.first(where: { $0.platform == .ethereum })!

        guard let rpcURL = URL(string: blockchainConfig.rpcUrl) else {
            throw APIError.invalidURL
        }

        // Fetch name, symbol, and decimals in parallel
        async let name = fetchTokenName(contractAddress: contractAddress, rpcURL: rpcURL)
        async let symbol = fetchTokenSymbol(contractAddress: contractAddress, rpcURL: rpcURL)
        async let decimals = fetchTokenDecimals(contractAddress: contractAddress, rpcURL: rpcURL)

        let (tokenName, tokenSymbol, tokenDecimals) = try await (name, symbol, decimals)

        Logger.log("✅ Token info: \(tokenName) (\(tokenSymbol)) - \(tokenDecimals) decimals")

        return TokenInfo(
            address: contractAddress,
            name: tokenName,
            symbol: tokenSymbol,
            decimals: tokenDecimals,
            totalSupply: "0", // Not fetching total supply for now
            price: 0.0 // Price will be fetched separately if needed
        )
    }

    private func fetchTokenName(contractAddress: String, rpcURL: URL) async throws -> String {
        // ERC-20 name() function signature: 0x06fdde03
        let data = "0x06fdde03"
        let result = try await makeRPCCall(to: contractAddress, data: data, rpcURL: rpcURL)
        return try decodeString(from: result)
    }

    private func fetchTokenSymbol(contractAddress: String, rpcURL: URL) async throws -> String {
        // ERC-20 symbol() function signature: 0x95d89b41
        let data = "0x95d89b41"
        let result = try await makeRPCCall(to: contractAddress, data: data, rpcURL: rpcURL)
        return try decodeString(from: result)
    }

    private func fetchTokenDecimals(contractAddress: String, rpcURL: URL) async throws -> Int {
        // ERC-20 decimals() function signature: 0x313ce567
        let data = "0x313ce567"
        let result = try await makeRPCCall(to: contractAddress, data: data, rpcURL: rpcURL)
        return try decodeUInt8(from: result)
    }

    private func makeRPCCall(to contractAddress: String, data: String, rpcURL: URL) async throws -> String {
        var request = URLRequest(url: rpcURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_call",
            "params": [
                [
                    "to": contractAddress.lowercased(),
                    "data": data
                ],
                "latest"
            ],
            "id": 1
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (responseData, _) = try await URLSession.shared.data(for: request)

        guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let result = json["result"] as? String else {
            throw APIError.decodingError
        }

        return result
    }

    private func decodeString(from hex: String) throws -> String {
        guard hex.hasPrefix("0x") else { throw APIError.decodingError }
        let hexString = String(hex.dropFirst(2))

        // Skip offset and length (first 64 bytes = offset, next 64 bytes = length)
        guard hexString.count > 128 else { throw APIError.decodingError }
        let dataHex = String(hexString.dropFirst(128))

        // Convert hex to data
        var data = Data()
        var index = dataHex.startIndex
        while index < dataHex.endIndex {
            let nextIndex = dataHex.index(index, offsetBy: 2, limitedBy: dataHex.endIndex) ?? dataHex.endIndex
            let byteString = dataHex[index..<nextIndex]
            if let byte = UInt8(byteString, radix: 16) {
                data.append(byte)
            }
            index = nextIndex
        }

        // Convert to string and remove null bytes
        guard let string = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters) else {
            throw APIError.decodingError
        }

        return string.isEmpty ? "Unknown" : string
    }

    private func decodeUInt8(from hex: String) throws -> Int {
        guard hex.hasPrefix("0x") else { throw APIError.decodingError }
        let hexString = String(hex.dropFirst(2))
        guard let value = Int(hexString, radix: 16) else {
            throw APIError.decodingError
        }
        return value
    }

    func getTokenPrices(symbols: [String]) async throws -> [String: Double] {
        let ids = symbols.map { APIService.getCoinId(for: $0) }
        let priceLookup = try await fetchPrices(for: ids)
        var results: [String: Double] = [:]
        for symbol in symbols {
            let coinId = APIService.getCoinId(for: symbol)
            if let price = priceLookup[coinId] {
                results[symbol.uppercased()] = price
            }
        }
        return results
    }

    // MARK: - NFT Methods

    func fetchNFTs(for address: String) async throws -> [NFT] {
        Logger.log("🎨 Fetching NFTs for address: \(address)")

        let alchemyApiKey = AppConfig.alchemyApiKey
        guard !alchemyApiKey.isEmpty else {
            Logger.log("ℹ️ NFT loading skipped: optional Alchemy API key is not configured")
            return []
        }

        let alchemyUrl = "https://eth-mainnet.g.alchemy.com/nft/v3/\(alchemyApiKey)/getNFTsForOwner"

        guard var urlComponents = URLComponents(string: alchemyUrl) else {
            Logger.log("❌ Invalid Alchemy URL")
            throw APIError.invalidURL
        }

        urlComponents.queryItems = [
            URLQueryItem(name: "owner", value: address),
            URLQueryItem(name: "withMetadata", value: "true"),
            URLQueryItem(name: "pageSize", value: "100")
        ]

        guard let url = urlComponents.url else {
            Logger.log("❌ Failed to construct URL")
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30.0

        do {
            Logger.log("🚀 Making Alchemy NFT API request")
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                Logger.log("❌ Invalid HTTP response")
                throw APIError.invalidResponse
            }

            Logger.log("📡 NFT API Response status: \(httpResponse.statusCode)")

            if httpResponse.statusCode != 200 {
                if let responseString = String(data: data, encoding: .utf8) {
                    Logger.log("❌ API Error Response: \(responseString)")
                }
                return []
            }

            let decoder = JSONDecoder()

            do {
                let alchemyResponse = try decoder.decode(AlchemyNFTResponse.self, from: data)
                Logger.log("✅ Successfully decoded \(alchemyResponse.ownedNfts.count) NFTs from Alchemy")

                let fetchedNFTs: [NFT] = alchemyResponse.ownedNfts.compactMap { nft in
                    // Get image from metadata
                    let img = nft.image
                    let imageUrl = img?.thumbnailUrl ?? img?.cachedUrl ?? img?.originalUrl

                    // Get name and description from metadata
                    let nftName = nft.name ?? nft.title ?? "NFT #\(nft.tokenId)"
                    let nftDescription = nft.description ?? ""
                    let collectionName = nft.contract.name ?? nft.contract.symbol ?? "Unknown Collection"

                    return NFT(
                        contractAddress: nft.contract.address,
                        tokenId: nft.tokenId,
                        name: nftName,
                        description: nftDescription,
                        imageUrl: imageUrl,
                        collectionName: collectionName,
                        blockchain: .ethereum,
                        ownerAddress: address
                    )
                }

                Logger.log("🎨 Parsed \(fetchedNFTs.count) NFTs with valid data")
                return fetchedNFTs
            } catch {
                Logger.log("❌ Failed to decode Alchemy response: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    Logger.log("📄 Response data: \(responseString.prefix(1000))")
                }
                return []
            }
        } catch {
            Logger.log("❌ Network error fetching NFTs: \(error)")
            return []
        }
    }

    // MARK: - CoinGecko API Methods

    func getCoinData(coinId: String) async throws -> CoinData {
        let endpoint = "https://api.coingecko.com/api/v3/coins/\(coinId)"
        var components = URLComponents(string: endpoint)!
        components.queryItems = [
            URLQueryItem(name: "localization", value: "false"),
            URLQueryItem(name: "tickers", value: "false"),
            URLQueryItem(name: "market_data", value: "true"),
            URLQueryItem(name: "community_data", value: "false"),
            URLQueryItem(name: "developer_data", value: "false"),
            URLQueryItem(name: "sparkline", value: "false")
        ]

        guard let url = components.url else {
            Logger.log("❌ Invalid URL: \(endpoint)")
            throw APIError.invalidURL
        }

        Logger.log("🔍 Fetching coin data from: \(url.absoluteString)")

        do {
            let (data, response) = try await session.data(from: url)

            if let httpResponse = response as? HTTPURLResponse {
                Logger.log("📡 Response status: \(httpResponse.statusCode)")

                if httpResponse.statusCode == 429 {
                    Logger.log("⚠️ Rate limit exceeded")
                    throw APIError.rateLimitExceeded
                }

                if httpResponse.statusCode != 200 {
                    let responseString = String(data: data, encoding: .utf8) ?? "No response data"
                    Logger.log("❌ HTTP Error \(httpResponse.statusCode): \(responseString)")
                    throw APIError.invalidResponse
                }
            }

            let decoder = JSONDecoder()
            return try decoder.decode(CoinData.self, from: data)
        } catch let decodingError as DecodingError {
            Logger.log("❌ Decoding error: \(decodingError)")
            throw APIError.decodingError
        } catch {
            Logger.log("❌ Network error: \(error)")
            throw error
        }
    }

    func getCoinChartData(coinId: String, days: Int = 1) async throws -> CoinChartData {
        let endpoint = "https://api.coingecko.com/api/v3/coins/\(coinId)/market_chart"
        var components = URLComponents(string: endpoint)!
        components.queryItems = [
            URLQueryItem(name: "vs_currency", value: "usd"),
            URLQueryItem(name: "days", value: String(days))
        ]

        guard let url = components.url else {
            Logger.log("❌ Invalid chart URL: \(endpoint)")
            throw APIError.invalidURL
        }

        Logger.log("📈 Fetching chart data from: \(url.absoluteString)")

        do {
            let (data, response) = try await session.data(from: url)

            if let httpResponse = response as? HTTPURLResponse {
                Logger.log("📊 Chart response status: \(httpResponse.statusCode)")

                if httpResponse.statusCode == 429 {
                    Logger.log("⚠️ Chart rate limit exceeded")
                    throw APIError.rateLimitExceeded
                }

                if httpResponse.statusCode != 200 {
                    let responseString = String(data: data, encoding: .utf8) ?? "No response data"
                    Logger.log("❌ Chart HTTP Error \(httpResponse.statusCode): \(responseString)")
                    throw APIError.invalidResponse
                }
            }

            let decoder = JSONDecoder()
            return try decoder.decode(CoinChartData.self, from: data)
        } catch let decodingError as DecodingError {
            Logger.log("❌ Chart decoding error: \(decodingError)")
            throw APIError.decodingError
        } catch {
            Logger.log("❌ Chart network error: \(error)")
            throw error
        }
    }

    static func getCoinId(for symbol: String) -> String {
        switch symbol.uppercased() {
        case "ETH":
            return "ethereum"
        case "BTC":
            return "bitcoin"
        case "USDC":
            return "usd-coin"
        case "USDT":
            return "tether"
        case "BNB":
            return "binancecoin"
        case "ADA":
            return "cardano"
        case "SOL":
            return "solana"
        case "DOT":
            return "polkadot"
        case "LINK":
            return "chainlink"
        case "UNI":
            return "uniswap"
        case "MATIC", "POL":
            return "polygon-ecosystem-token"  // Updated: MATIC migrated to POL in Sept 2024
        case "AVAX":
            return "avalanche-2"
        case "ATOM":
            return "cosmos"
        case "NEAR":
            return "near"
        case "FTM":
            return "fantom"
        case "ALGO":
            return "algorand"
        case "ARB":
            return "arbitrum"
        case "OP":
            return "optimism"
        case "WETH":
            return "weth"
        case "WBTC":
            return "wrapped-bitcoin"
        case "CBBTC":
            return "coinbase-wrapped-btc"
        case "BTCB":
            return "bitcoin-bep2"
        case "BTC.B":
            return "bitcoin-avalanche-bridged-btc-b"
        case "WBNB":
            return "wbnb"
        case "WMATIC":
            return "wmatic"
        case "WAVAX":
            return "wrapped-avax"
        default:
            return symbol.lowercased()
        }
    }
}

// MARK: - String Extension for Hex Conversion
extension String {
    func hexToDecimal() -> String? {
        guard self.allSatisfy({ $0.isHexDigit }) else { return nil }
        let decimal = self.reduce(0) { acc, char in
            let value = char.hexDigitValue ?? 0
            return acc * 16 + value
        }
        return String(decimal)
    }

    func padLeft(toLength: Int, withPad: String) -> String {
        guard self.count < toLength else { return self }
        let padding = String(repeating: withPad, count: (toLength - self.count) / withPad.count)
        return padding + self
    }
}

// MARK: - API Models

extension APIService {
    struct RPCResponse<Result: Decodable>: Decodable {
        struct RPCError: Decodable {
            let code: Int
            let message: String
        }

        let result: Result?
        let error: RPCError?
    }

    /// Fetch a native balance trying the configured endpoint first and then
    /// every fallback node NetworkManager knows for the chain.
    func fetchEVMNativeBalanceWithFailover(
        address: String,
        blockchain: BlockchainType,
        primaryRpcUrl: String
    ) async throws -> Double {
        var urls = [primaryRpcUrl]
        for url in NetworkManager.shared.getAllRPCUrls(for: blockchain) where !urls.contains(url) {
            urls.append(url)
        }

        var lastError: Error = APIError.invalidResponse
        for url in urls {
            do {
                return try await fetchEVMNativeBalance(
                    address: address,
                    rpcURL: url,
                    decimals: blockchain.nativeDecimals
                )
            } catch {
                Logger.log("⚠️ eth_getBalance failed on \(url), trying next: \(error.localizedDescription)")
                lastError = error
            }
        }
        throw lastError
    }

    func fetchEVMNativeBalance(address: String, rpcURL: String, decimals: Int) async throws -> Double {
        guard let url = URL(string: rpcURL) else {
            throw APIError.invalidURL
        }

        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_getBalance",
            "params": [address, "latest"],
            "id": Int.random(in: 1...Int(Int32.max))
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        let rpcResponse = try JSONDecoder().decode(RPCResponse<String>.self, from: data)

        if let error = rpcResponse.error {
            throw APIError.rpcError(code: error.code, message: error.message)
        }

        guard let hexValue = rpcResponse.result else {
            throw APIError.noData
        }

        let rawAmount = decimalFromHex(hexValue)
        let divisor = powerOfTen(decimals)
        let normalized = decimalDividing(rawAmount, by: divisor)
        return NSDecimalNumber(decimal: normalized).doubleValue
    }

    func fetchSolanaBalance(address: String, rpcURL: String) async throws -> Double {
        guard let url = URL(string: rpcURL) else {
            throw APIError.invalidURL
        }

        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "getBalance",
            "params": [address],
            "id": Int.random(in: 1...Int(Int32.max))
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        struct SolanaBalanceResult: Decodable {
            let value: UInt64
        }

        let rpcResponse = try JSONDecoder().decode(RPCResponse<SolanaBalanceResult>.self, from: data)

        if let error = rpcResponse.error {
            throw APIError.rpcError(code: error.code, message: error.message)
        }

        guard let lamports = rpcResponse.result?.value else {
            throw APIError.noData
        }

        return Double(lamports) / 1_000_000_000 // lamports → SOL
    }

    func fetchBitcoinBalance(address: String) async throws -> Double {
        guard let url = URL(string: "https://blockstream.info/api/address/\(address)") else {
            throw APIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        struct AddressResponse: Decodable {
            struct Stats: Decodable {
                let funded_txo_sum: Int64
                let spent_txo_sum: Int64
            }

            let chain_stats: Stats
        }

        let decoded = try JSONDecoder().decode(AddressResponse.self, from: data)
        let sats = decoded.chain_stats.funded_txo_sum - decoded.chain_stats.spent_txo_sum
        return Double(sats) / 100_000_000.0
    }

    func fetchPrices(for coinIds: [String]) async throws -> [String: Double] {
        let uniqueIds = Array(Set(coinIds)).filter { !$0.isEmpty }
        guard !uniqueIds.isEmpty else { return [:] }

        var components = URLComponents(string: "https://api.coingecko.com/api/v3/simple/price")!
        components.queryItems = [
            URLQueryItem(name: "ids", value: uniqueIds.joined(separator: ",")),
            URLQueryItem(name: "vs_currencies", value: "usd")
        ]

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

                let decoded = try JSONDecoder().decode([String: [String: Double]].self, from: data)
        var results: [String: Double] = [:]
        for (key, value) in decoded {
            if let usd = value["usd"] {
                results[key] = usd
            }
        }
        return results
    }

    // Fetch both prices and logo URLs from CoinGecko
    func fetchPricesAndLogos(for coinIds: [String]) async throws -> [String: CoinPriceAndImage] {
        let uniqueIds = Array(Set(coinIds)).filter { !$0.isEmpty }
        guard !uniqueIds.isEmpty else { return [:] }

        // CoinGecko's simple/price doesn't include images, so we need to use the markets endpoint
        // or make individual calls. For efficiency, we'll use the coins/markets endpoint
        var components = URLComponents(string: "https://api.coingecko.com/api/v3/coins/markets")!
        components.queryItems = [
            URLQueryItem(name: "vs_currency", value: "usd"),
            URLQueryItem(name: "ids", value: uniqueIds.joined(separator: ",")),
            URLQueryItem(name: "order", value: "market_cap_desc"),
            URLQueryItem(name: "per_page", value: "250"),
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "sparkline", value: "false")
        ]

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        let decoded = try JSONDecoder().decode([CoinMarketData].self, from: data)
        var results: [String: CoinPriceAndImage] = [:]
        for coin in decoded {
            results[coin.id] = CoinPriceAndImage(
                price: coin.currentPrice,
                imageUrl: coin.image,
                priceChange24h: coin.priceChange24h
            )
        }
        return results
    }

    func decimalFromHex(_ hexString: String) -> Decimal {
        let trimmed: String
        if hexString.hasPrefix("0x") {
            trimmed = String(hexString.dropFirst(2))
        } else {
            trimmed = hexString
        }

        guard !trimmed.isEmpty else { return 0 }

        let digits = Array(trimmed.uppercased())
        let hexBase = Decimal(16)
        var value = Decimal(0)

        for digitChar in digits {
            guard let digit = Int(String(digitChar), radix: 16) else { continue }
            value *= hexBase
            value += Decimal(digit)
        }

        return value
    }

    func powerOfTen(_ exponent: Int) -> Decimal {
        guard exponent > 0 else { return 1 }
        var result = Decimal(1)
        let ten = Decimal(10)
        for _ in 0..<exponent {
            result *= ten
        }
        return result
    }

    func decimalDividing(_ lhs: Decimal, by rhs: Decimal) -> Decimal {
        var numerator = lhs
        var denominator = rhs
        var result = Decimal()
        NSDecimalDivide(&result, &numerator, &denominator, .plain)
        return result
    }

}

enum APIError: Error {
    case invalidURL
    case invalidResponse
    case noData
    case decodingError
    case rateLimitExceeded
    case rpcError(code: Int, message: String)
    case unsupportedFeature
    case missingAPIKeys([String])

    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .noData:
            return "No data received"
        case .decodingError:
            return "Failed to parse data"
        case .rateLimitExceeded:
            return "Too many requests - please wait a moment"
        case .rpcError(let code, let message):
            return "RPC error (\(code)): \(message)"
        case .unsupportedFeature:
            return "This feature is not available without a dedicated backend"
        case .missingAPIKeys(let keys):
            let joined = keys.sorted().joined(separator: ", ")
            return "Missing API key(s): \(joined). Set environment variables before running."
        }
    }
}

// Response Models
struct BalanceResponse: Codable {
    let balance: Double
}

struct TokensResponse: Codable {
    let tokens: [Token]
}

struct TransactionsResponse: Codable {
    let transactions: [Transaction]
}

struct TransactionResponse: Codable {
    let hash: String
    let status: String
}

struct PricesResponse: Codable {
    let prices: [String: Double]
}

struct DeFiProtocolsResponse: Codable {
    let protocols: [DeFiProtocol]
}

struct DeFiPositionsResponse: Codable {
    let positions: [DeFiPosition]
}

// Request Models
struct SendTransactionRequest: Codable {
    let from: String
    let to: String
    let amount: String
    let tokenAddress: String?
    let gasLimit: String
    let gasPrice: String
    let privateKey: String
}

struct EstimateGasRequest: Codable {
    let from: String
    let to: String
    let amount: String
    let tokenAddress: String?
}

struct GasEstimate: Codable {
    let gasLimit: String
    let gasPrice: String
    let estimatedFee: String
}

struct SwapQuoteRequest: Codable {
    let fromToken: String
    let toToken: String
    let amount: String
    let slippage: Double
}

struct SwapQuote: Codable {
    let fromAmount: String
    let toAmount: String
    let rate: String
    let priceImpact: String
    let minimumReceived: String
    let gas: GasEstimate
}

struct ExecuteSwapRequest: Codable {
    let fromToken: String
    let toToken: String
    let amount: String
    let slippage: Double
    let walletAddress: String
    let privateKey: String
}

// DeFi Models
struct DeFiProtocol: Codable, Identifiable {
    var id = UUID()
    let name: String
    let type: String
    let apy: Double
    let tvl: String
    let riskLevel: String
}

struct DeFiPosition: Codable, Identifiable {
    var id = UUID()
    let protocolName: String
    let type: String
    let amount: String
    let value: String
    let apy: Double
    let rewards: String
}

struct TokenInfo: Codable {
    let address: String
    let name: String
    let symbol: String
    let decimals: Int
    let totalSupply: String
    let price: Double
}

// MARK: - CoinGecko Models

struct CoinData: Codable {
    let id: String
    let symbol: String
    let name: String
    let image: CoinImage
    let marketData: MarketData
    let description: CoinDescription

    enum CodingKeys: String, CodingKey {
        case id, symbol, name, image, description
        case marketData = "market_data"
    }
}

struct CoinImage: Codable {
    let thumb: String
    let small: String
    let large: String
}

struct MarketData: Codable {
    let currentPrice: [String: Double]
    let priceChange24h: Double
    let priceChangePercentage24h: Double
    let marketCap: [String: Double]
    let totalVolume: [String: Double]
    let high24h: [String: Double]
    let low24h: [String: Double]
    let circulatingSupply: Double?
    let totalSupply: Double?

    enum CodingKeys: String, CodingKey {
        case currentPrice = "current_price"
        case priceChange24h = "price_change_24h"
        case priceChangePercentage24h = "price_change_percentage_24h"
        case marketCap = "market_cap"
        case totalVolume = "total_volume"
        case high24h = "high_24h"
        case low24h = "low_24h"
        case circulatingSupply = "circulating_supply"
        case totalSupply = "total_supply"
    }
}

struct CoinDescription: Codable {
    let en: String
}

struct CoinChartData: Codable {
    let prices: [[Double]]
    let marketCaps: [[Double]]
    let totalVolumes: [[Double]]

    enum CodingKeys: String, CodingKey {
        case prices
        case marketCaps = "market_caps"
        case totalVolumes = "total_volumes"
    }
}

// Price and Image data from CoinGecko markets endpoint
struct CoinPriceAndImage {
    let price: Double
    let imageUrl: String
    let priceChange24h: Double?   // percentage, e.g. -2.4
}

// CoinGecko markets endpoint response
struct CoinMarketData: Codable {
    let id: String
    let symbol: String
    let name: String
    let image: String
    let currentPrice: Double
    let priceChange24h: Double?

    enum CodingKeys: String, CodingKey {
        case id, symbol, name, image
        case currentPrice = "current_price"
        case priceChange24h = "price_change_percentage_24h"
    }
}

// MARK: - OpenSea NFT Models

struct OpenSeaResponse: Codable {
    let assets: [OpenSeaAsset]
}

struct OpenSeaAsset: Codable {
    let tokenId: String?
    let name: String?
    let description: String?
    let imageUrl: String?
    let imagePreviewUrl: String?
    let assetContract: OpenSeaAssetContract?
    let collection: OpenSeaCollection?

    enum CodingKeys: String, CodingKey {
        case tokenId = "token_id"
        case name
        case description
        case imageUrl = "image_url"
        case imagePreviewUrl = "image_preview_url"
        case assetContract = "asset_contract"
        case collection
    }
}

struct OpenSeaAssetContract: Codable {
    let address: String?
}

struct OpenSeaCollection: Codable {
    let name: String?
}

// MARK: - Alchemy NFT Models

// MARK: - Reservoir NFT Response Models
struct ReservoirNFTResponse: Codable {
    let tokens: [ReservoirTokenWrapper]
}

struct ReservoirTokenWrapper: Codable {
    let token: ReservoirToken
}

struct ReservoirToken: Codable {
    let contract: String
    let tokenId: String
    let name: String?
    let description: String?
    let image: String?
    let imageSmall: String?
    let imageLarge: String?
    let collection: ReservoirCollection?
}

struct ReservoirCollection: Codable {
    let name: String?
}

// MARK: - Alchemy NFT Response Models (v3 API)
struct AlchemyNFTResponse: Codable {
    let ownedNfts: [AlchemyNFT]
}

struct AlchemyNFT: Codable {
    let contract: AlchemyNFTContract
    let tokenId: String
    let name: String?
    let title: String?
    let description: String?
    let image: AlchemyNFTImage?
    let raw: AlchemyNFTRaw?

    enum CodingKeys: String, CodingKey {
        case contract
        case tokenId
        case name
        case title
        case description
        case image
        case raw
    }
}

struct AlchemyNFTContract: Codable {
    let address: String
    let name: String?
    let symbol: String?
}

struct AlchemyNFTImage: Codable {
    let cachedUrl: String?
    let thumbnailUrl: String?
    let originalUrl: String?
}

struct AlchemyNFTRaw: Codable {
    let metadata: AlchemyNFTMetadata?
}

struct AlchemyNFTMetadata: Codable {
    let image: String?
    let name: String?
    let description: String?
}
