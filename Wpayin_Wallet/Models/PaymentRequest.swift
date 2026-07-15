// Autor Lukas Helebrandt, 2026

import Foundation

/// A shareable, non-custodial request for an on-chain payment.
///
/// The payload never authorizes a transaction. It only pre-fills the asset,
/// network, recipient and optional amount; the sender must still review and
/// sign the transfer in their wallet.
struct PaymentRequest: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let address: String
    let symbol: String
    let blockchain: BlockchainType
    let contractAddress: String?
    let tokenDecimals: Int
    let amount: Decimal?
    let note: String?
    let expiresAt: Date?

    init(
        id: UUID = UUID(),
        address: String,
        symbol: String,
        blockchain: BlockchainType,
        contractAddress: String?,
        tokenDecimals: Int,
        amount: Decimal?,
        note: String?,
        expiresAt: Date?
    ) {
        self.id = id
        self.address = address
        self.symbol = symbol.uppercased()
        self.blockchain = blockchain
        self.contractAddress = contractAddress
        self.tokenDecimals = tokenDecimals
        self.amount = amount
        self.note = note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.expiresAt = expiresAt
    }

    var isExpired: Bool {
        expiresAt.map { $0 <= Date() } ?? false
    }

    var formattedAmount: String? {
        guard let amount else { return nil }
        return PaymentRequestCodec.decimalString(amount)
    }
}

enum PaymentRequestCodec {
    private static let internalPrefix = "WPAYIN-PAY:"

    /// Produces a standards-compatible URI where possible:
    /// EIP-681 for EVM networks and BIP-21 for Bitcoin. Wpayin metadata is
    /// added as optional query items and is ignored by other compatible wallets.
    static func encode(_ request: PaymentRequest) -> String? {
        if request.blockchain == .bitcoin {
            return bitcoinURI(for: request)
        }
        if request.blockchain.isEVM, let chainId = request.blockchain.chainId {
            return ethereumURI(for: request, chainId: chainId)
        }
        return internalURI(for: request)
    }

    static func decode(_ rawValue: String) -> PaymentRequest? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if value.localizedCaseInsensitiveContains(internalPrefix) {
            return decodeInternalPayload(value)
        }

        let lowercased = value.lowercased()
        if lowercased.hasPrefix("ethereum:") {
            return decodeEthereumURI(value)
        }
        if lowercased.hasPrefix("bitcoin:") {
            return decodeBitcoinURI(value)
        }
        if lowercased.hasPrefix("wpayin://pay") {
            return decodeWpayinURI(value)
        }
        return nil
    }

    static func decimalString(_ value: Decimal) -> String {
        var value = value
        return NSDecimalString(&value, Locale(identifier: "en_US_POSIX"))
    }

    // MARK: - Encoding

    private static func ethereumURI(for request: PaymentRequest, chainId: Int) -> String? {
        let isToken = request.contractAddress?.isEmpty == false
        let target = isToken ? request.contractAddress! : request.address
        var components = URLComponents()
        components.scheme = "ethereum"
        components.path = "\(target)@\(chainId)\(isToken ? "/transfer" : "")"

        var items: [URLQueryItem] = []
        if isToken {
            items.append(URLQueryItem(name: "address", value: request.address))
            if let amount = request.amount {
                items.append(URLQueryItem(
                    name: "uint256",
                    value: atomicAmount(amount, decimals: request.tokenDecimals)
                ))
            }
        } else if let amount = request.amount {
            items.append(URLQueryItem(
                name: "value",
                value: atomicAmount(amount, decimals: request.tokenDecimals)
            ))
        }
        appendMetadata(for: request, to: &items)
        components.queryItems = items.isEmpty ? nil : items
        return components.string
    }

    private static func bitcoinURI(for request: PaymentRequest) -> String? {
        var components = URLComponents()
        components.scheme = "bitcoin"
        components.path = request.address

        var items: [URLQueryItem] = []
        if let amount = request.amount {
            items.append(URLQueryItem(name: "amount", value: decimalString(amount)))
        }
        appendMetadata(for: request, to: &items)
        components.queryItems = items.isEmpty ? nil : items
        return components.string
    }

    private static func internalURI(for request: PaymentRequest) -> String? {
        guard let data = try? JSONEncoder.paymentRequestEncoder.encode(request) else { return nil }
        let payload = data.base64URLEncodedString()
        return internalPrefix + payload
    }

    private static func appendMetadata(for request: PaymentRequest, to items: inout [URLQueryItem]) {
        items.append(URLQueryItem(name: "wpayin-symbol", value: request.symbol))
        items.append(URLQueryItem(name: "wpayin-network", value: request.blockchain.rawValue))
        items.append(URLQueryItem(name: "wpayin-decimals", value: String(request.tokenDecimals)))
        if let amount = request.amount {
            items.append(URLQueryItem(name: "wpayin-amount", value: decimalString(amount)))
        }
        if let note = request.note {
            items.append(URLQueryItem(name: "message", value: note))
        }
        if let expiresAt = request.expiresAt {
            items.append(URLQueryItem(
                name: "wpayin-exp",
                value: String(Int(expiresAt.timeIntervalSince1970))
            ))
        }
    }

    private static func atomicAmount(_ amount: Decimal, decimals: Int) -> String {
        var base = Decimal(1)
        for _ in 0..<max(0, decimals) { base *= 10 }
        var value = amount * base
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .down)
        return NSDecimalNumber(decimal: rounded).stringValue
    }

    // MARK: - Decoding

    private static func decodeEthereumURI(_ value: String) -> PaymentRequest? {
        guard let components = URLComponents(string: value),
              let targetWithChain = value
                .dropFirst("ethereum:".count)
                .split(separator: "?", maxSplits: 1)
                .first else { return nil }

        let targetPath = String(targetWithChain)
        let isTokenTransfer = targetPath.lowercased().hasSuffix("/transfer")
        let targetWithoutFunction = targetPath.replacingOccurrences(
            of: "/transfer",
            with: "",
            options: [.caseInsensitive, .anchored],
            range: targetPath.range(of: "/transfer", options: [.caseInsensitive, .backwards])
        )
        let targetParts = targetWithoutFunction.split(separator: "@", maxSplits: 1)
        guard let target = targetParts.first.map(String.init), !target.isEmpty else { return nil }

        let query = queryDictionary(components)
        let chainId = targetParts.count > 1 ? Int(targetParts[1]) : nil
        let network = query["wpayin-network"].flatMap(BlockchainType.init(rawValue:))
            ?? chainId.flatMap { blockchain(forChainId: $0) }
            ?? .ethereum
        let address = isTokenTransfer ? (query["address"] ?? "") : target
        guard !address.isEmpty else { return nil }

        let decimals = Int(query["wpayin-decimals"] ?? "") ?? (isTokenTransfer ? 18 : network.nativeDecimals)
        let amount = query["wpayin-amount"].flatMap { decimal(from: $0) }
            ?? atomicDecimal(query[isTokenTransfer ? "uint256" : "value"], decimals: decimals)

        return PaymentRequest(
            address: address,
            symbol: query["wpayin-symbol"] ?? (isTokenTransfer ? "TOKEN" : network.nativeToken),
            blockchain: network,
            contractAddress: isTokenTransfer ? target : nil,
            tokenDecimals: decimals,
            amount: amount,
            note: query["message"],
            expiresAt: expiryDate(query["wpayin-exp"])
        )
    }

    private static func decodeBitcoinURI(_ value: String) -> PaymentRequest? {
        guard let components = URLComponents(string: value) else { return nil }
        let address = components.path
        guard !address.isEmpty else { return nil }
        let query = queryDictionary(components)

        return PaymentRequest(
            address: address,
            symbol: query["wpayin-symbol"] ?? "BTC",
            blockchain: .bitcoin,
            contractAddress: nil,
            tokenDecimals: 8,
            amount: query["wpayin-amount"].flatMap { decimal(from: $0) }
                ?? query["amount"].flatMap { decimal(from: $0) },
            note: query["message"],
            expiresAt: expiryDate(query["wpayin-exp"])
        )
    }

    private static func decodeWpayinURI(_ value: String) -> PaymentRequest? {
        guard let components = URLComponents(string: value) else { return nil }
        let query = queryDictionary(components)
        guard let address = query["address"],
              let symbol = query["symbol"],
              let networkValue = query["network"],
              let network = BlockchainType(rawValue: networkValue) else { return nil }

        return PaymentRequest(
            address: address,
            symbol: symbol,
            blockchain: network,
            contractAddress: query["contract"],
            tokenDecimals: Int(query["decimals"] ?? "") ?? network.nativeDecimals,
            amount: query["amount"].flatMap { decimal(from: $0) },
            note: query["message"],
            expiresAt: expiryDate(query["exp"])
        )
    }

    private static func decodeInternalPayload(_ value: String) -> PaymentRequest? {
        guard let prefixRange = value.range(of: internalPrefix, options: .caseInsensitive) else { return nil }
        let encoded = String(value[prefixRange.upperBound...])
            .components(separatedBy: .whitespacesAndNewlines)
            .first ?? ""
        guard let data = Data(base64URLString: encoded) else { return nil }
        return try? JSONDecoder.paymentRequestDecoder.decode(PaymentRequest.self, from: data)
    }

    private static func queryDictionary(_ components: URLComponents) -> [String: String] {
        Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name.lowercased(), $0) }
        })
    }

    private static func atomicDecimal(_ rawValue: String?, decimals: Int) -> Decimal? {
        guard let rawValue, let atomic = decimal(from: rawValue) else { return nil }
        var base = Decimal(1)
        for _ in 0..<max(0, decimals) { base *= 10 }
        return atomic / base
    }

    private static func expiryDate(_ rawValue: String?) -> Date? {
        rawValue.flatMap(TimeInterval.init).map(Date.init(timeIntervalSince1970:))
    }

    private static func blockchain(forChainId chainId: Int) -> BlockchainType? {
        BlockchainType.allCases.first { $0.chainId == chainId }
    }

    private static func decimal(from value: String) -> Decimal? {
        Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLString: String) {
        var value = base64URLString
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = value.count % 4
        if remainder != 0 { value += String(repeating: "=", count: 4 - remainder) }
        self.init(base64Encoded: value)
    }
}

private extension JSONEncoder {
    static var paymentRequestEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }
}

private extension JSONDecoder {
    static var paymentRequestDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }
}
