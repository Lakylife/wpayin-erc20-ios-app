// Autor Lukas Helebrandt, 2026

import Foundation
import Combine
import ReownWalletKit
import WalletConnectNetworking
import WalletConnectSign
import WalletConnectSigner
import WalletConnectVerify
import WalletConnectUtils
import WalletConnectRelay
import Starscream
import Web3Core
import web3swift
import WalletCore
import BigInt

extension WebSocket: @retroactive WebSocketConnecting {}

private struct WpayinSocketFactory: WebSocketFactory {
    func create(with url: URL) -> WebSocketConnecting {
        let socket = WebSocket(url: url)
        socket.callbackQueue = DispatchQueue(
            label: "io.wpayin.walletconnect.socket",
            qos: .utility,
            attributes: .concurrent
        )
        return socket
    }
}

struct WalletConnectPendingProposal: Identifiable {
    let proposal: Session.Proposal
    let context: VerifyContext?
    var id: String { proposal.id }
}

struct WalletConnectPendingRequest: Identifiable {
    let request: Request
    let context: VerifyContext?
    let peer: AppMetadata?
    var id: String { "\(request.topic)-\(request.id)" }
}

enum WalletConnectServiceError: LocalizedError {
    case notConfigured
    case invalidURI
    case noSupportedNetwork
    case unsupportedMethod(String)
    case invalidRequest
    case accountMismatch
    case chainMismatch
    case signingFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "WalletConnect is not configured. Add a Reown Project ID to the app build settings.".localized
        case .invalidURI:
            return "The WalletConnect link is invalid or has expired.".localized
        case .noSupportedNetwork:
            return "This dApp does not request a network supported by this wallet.".localized
        case .unsupportedMethod(let method):
            return "The requested WalletConnect method is not supported: %@".localized(method)
        case .invalidRequest:
            return "The dApp sent an invalid request.".localized
        case .accountMismatch:
            return "The dApp requested a different wallet account.".localized
        case .chainMismatch:
            return "The requested network does not match the signed data.".localized
        case .signingFailed:
            return "The request could not be signed.".localized
        }
    }
}

/// Wallet-side WalletConnect v2 coordinator. It never signs automatically:
/// proposals and requests are published to SwiftUI and require explicit user
/// confirmation before any private key is accessed.
@MainActor
final class WalletConnectService: ObservableObject {
    static let shared = WalletConnectService()

    static let supportedMethods: Set<String> = [
        "personal_sign",
        "eth_signTypedData",
        "eth_signTypedData_v3",
        "eth_signTypedData_v4",
        "eth_sendTransaction"
    ]
    static let supportedEvents: Set<String> = ["accountsChanged", "chainChanged"]

    @Published private(set) var isConfigured = false
    @Published private(set) var isPairing = false
    @Published private(set) var isSocketConnected = false
    @Published private(set) var sessions: [Session] = []
    @Published var pendingProposal: WalletConnectPendingProposal?
    @Published var pendingRequest: WalletConnectPendingRequest?
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()
    private var didConfigure = false

    private init() {}

    func configureIfNeeded() {
        guard !didConfigure else { return }
        guard AppConfig.walletConnectEnabled else {
            isConfigured = false
            return
        }

        Networking.configure(
            groupIdentifier: "group.io.noriskservis.standart.Wpayin-Wallet",
            projectId: AppConfig.walletConnectProjectId,
            socketFactory: WpayinSocketFactory()
        )

        do {
            let redirect = try AppMetadata.Redirect(
                native: "wpayin://wc",
                universal: nil,
                linkMode: false
            )
            let metadata = AppMetadata(
                name: "Wpayin Wallet",
                description: "Non-custodial multichain wallet",
                url: "https://wpayin.com",
                icons: ["https://wpayin.com/apple-touch-icon.png"],
                redirect: redirect
            )
            WalletKit.configure(metadata: metadata, crypto: WpayinWalletConnectCryptoProvider())
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        didConfigure = true
        isConfigured = true
        subscribe()
        reloadSessions()
    }

    func pair(uriString: String) async {
        configureIfNeeded()
        guard isConfigured else {
            errorMessage = WalletConnectServiceError.notConfigured.localizedDescription
            return
        }

        isPairing = true
        defer { isPairing = false }
        do {
            let uri = try WalletConnectURI(uriString: extractedURI(from: uriString))
            try await WalletKit.instance.pair(uri: uri)
        } catch {
            errorMessage = error.localizedDescription.isEmpty
                ? WalletConnectServiceError.invalidURI.localizedDescription
                : error.localizedDescription
        }
    }

    func handleDeepLink(_ url: URL) {
        guard AppConfig.walletConnectEnabled else { return }
        configureIfNeeded()

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let embeddedURI = components.queryItems?.first(where: { $0.name == "uri" })?.value,
           embeddedURI.lowercased().hasPrefix("wc:") {
            Task { await pair(uriString: embeddedURI) }
            return
        }

        if url.absoluteString.lowercased().hasPrefix("wc:") {
            Task { await pair(uriString: url.absoluteString) }
            return
        }

        do {
            try WalletKit.instance.dispatchEnvelope(url.absoluteString)
        } catch {
            Logger.log("WalletConnect deep link ignored: \(error.localizedDescription)")
        }
    }

    func approve(_ item: WalletConnectPendingProposal) async {
        do {
            let chains = requestedEVMChains(in: item.proposal)
                .filter { blockchainType(for: $0) != nil }
            guard !chains.isEmpty else { throw WalletConnectServiceError.noSupportedNetwork }

            guard let firstType = chains.compactMap(blockchainType(for:)).first,
                  let privateKey = try SwapService.shared.getPrivateKey(for: firstType) else {
                throw TransactionError.noPrivateKey
            }
            let address = try SwapService.shared.deriveAddress(from: privateKey, blockchain: firstType)
            let accounts = chains.compactMap { Account(blockchain: $0, address: address) }

            let requestedMethods = proposalMethods(item.proposal)
            let requestedEvents = proposalEvents(item.proposal)
            let namespaces = try AutoNamespaces.build(
                sessionProposal: item.proposal,
                chains: chains,
                methods: Array(requestedMethods.intersection(Self.supportedMethods)),
                events: Array(requestedEvents.intersection(Self.supportedEvents)),
                accounts: accounts
            )

            _ = try await WalletKit.instance.approve(
                proposalId: item.proposal.id,
                namespaces: namespaces
            )
            pendingProposal = nil
            reloadSessions()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reject(_ item: WalletConnectPendingProposal) async {
        do {
            try await WalletKit.instance.rejectSession(
                proposalId: item.proposal.id,
                reason: .userRejected
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        pendingProposal = nil
    }

    func approve(
        _ item: WalletConnectPendingRequest,
        settingsManager: SettingsManager
    ) async {
        guard await settingsManager.authorizeSpending(reason: "Approve WalletConnect request".localized) else {
            return
        }

        do {
            let response = try await execute(item.request)
            try await WalletKit.instance.respond(
                topic: item.request.topic,
                requestId: item.request.id,
                response: .response(response)
            )
            pendingRequest = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reject(_ item: WalletConnectPendingRequest) async {
        do {
            try await WalletKit.instance.respond(
                topic: item.request.topic,
                requestId: item.request.id,
                response: .error(.init(code: 4001, message: "User rejected the request"))
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        pendingRequest = nil
    }

    func disconnect(_ session: Session) async {
        do {
            try await WalletKit.instance.disconnect(topic: session.topic)
            reloadSessions()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reloadSessions() {
        guard isConfigured else {
            sessions = []
            return
        }
        sessions = WalletKit.instance.getSessions().sorted { $0.expiryDate > $1.expiryDate }
    }

    // MARK: - Presentation helpers

    func requestedChainNames(for proposal: Session.Proposal) -> [String] {
        requestedEVMChains(in: proposal).map { chain in
            blockchainType(for: chain)?.name ?? chain.absoluteString
        }
    }

    func requestedMethodNames(for proposal: Session.Proposal) -> [String] {
        Array(proposalMethods(proposal)).sorted()
    }

    func validationLabel(_ context: VerifyContext?) -> String {
        guard let context else { return "Origin not verified".localized }
        switch context.validation {
        case .valid: return "Verified domain".localized
        case .invalid: return "Domain mismatch".localized
        case .scam: return "Known scam".localized
        case .unknown: return "Origin not verified".localized
        }
    }

    func isDangerous(_ context: VerifyContext?) -> Bool {
        guard let context else { return false }
        switch context.validation {
        case .invalid, .scam: return true
        case .valid, .unknown: return false
        }
    }

    func prettyParameters(for request: Request) -> String {
        guard let data = try? JSONEncoder().encode(request.params),
              let object = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: pretty, encoding: .utf8) else {
            return String(describing: request.params)
        }
        return string
    }

    func transactionSummary(for request: Request) -> WalletConnectTransactionSummary? {
        guard request.method == "eth_sendTransaction",
              let payload = try? request.params.get([EthereumTransactionPayload].self).first else {
            return nil
        }
        let value = Self.parseHexQuantity(payload.value ?? "0x0") ?? 0
        let network = blockchainType(for: request.chainId)
        let divisor = Decimal(string: "1000000000000000000") ?? 1
        let nativeAmount = Decimal(string: value.description).map { $0 / divisor }
        return WalletConnectTransactionSummary(
            from: payload.from,
            to: payload.to,
            amount: nativeAmount,
            symbol: network?.nativeToken ?? "",
            network: network?.name ?? request.chainId.absoluteString,
            data: payload.data
        )
    }

    // MARK: - SDK subscriptions

    private func subscribe() {
        WalletKit.instance.sessionProposalPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] proposal, context in
                self?.pendingProposal = WalletConnectPendingProposal(
                    proposal: proposal,
                    context: context
                )
            }
            .store(in: &cancellables)

        WalletKit.instance.sessionRequestPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] request, context in
                guard let self else { return }
                guard Self.supportedMethods.contains(request.method) else {
                    Task { await self.rejectUnsupported(request) }
                    return
                }
                let peer = self.sessions.first { $0.topic == request.topic }?.peer
                self.pendingRequest = WalletConnectPendingRequest(
                    request: request,
                    context: context,
                    peer: peer
                )
            }
            .store(in: &cancellables)

        WalletKit.instance.sessionsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                self?.sessions = sessions.sorted { $0.expiryDate > $1.expiryDate }
            }
            .store(in: &cancellables)

        WalletKit.instance.socketConnectionStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                switch status {
                case .connected: self?.isSocketConnected = true
                case .disconnected: self?.isSocketConnected = false
                }
            }
            .store(in: &cancellables)
    }

    private func rejectUnsupported(_ request: Request) async {
        do {
            try await WalletKit.instance.respond(
                topic: request.topic,
                requestId: request.id,
                response: .error(.init(code: 4200, message: "Unsupported method"))
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Signing and transaction execution

    private func execute(_ request: Request) async throws -> AnyCodable {
        guard let blockchain = blockchainType(for: request.chainId), blockchain.isEVM else {
            throw WalletConnectServiceError.noSupportedNetwork
        }
        guard let privateKey = try SwapService.shared.getPrivateKey(for: blockchain) else {
            throw TransactionError.noPrivateKey
        }
        let address = try SwapService.shared.deriveAddress(from: privateKey, blockchain: blockchain)

        switch request.method {
        case "personal_sign":
            return try personalSign(request.params, privateKey: privateKey, expectedAddress: address)

        case "eth_signTypedData", "eth_signTypedData_v3", "eth_signTypedData_v4":
            return try typedDataSign(
                request.params,
                privateKey: privateKey,
                expectedAddress: address,
                expectedChainId: blockchain.chainId
            )

        case "eth_sendTransaction":
            return try await sendTransaction(
                request.params,
                privateKey: privateKey,
                expectedAddress: address,
                blockchain: blockchain
            )

        default:
            throw WalletConnectServiceError.unsupportedMethod(request.method)
        }
    }

    private func personalSign(
        _ params: AnyCodable,
        privateKey: Data,
        expectedAddress: String
    ) throws -> AnyCodable {
        let values = try params.get([String].self)
        guard values.count >= 2 else { throw WalletConnectServiceError.invalidRequest }

        let firstIsAddress = Self.isEVMAddress(values[0])
        let address = firstIsAddress ? values[0] : values[1]
        let messageValue = firstIsAddress ? values[1] : values[0]
        guard address.caseInsensitiveCompare(expectedAddress) == .orderedSame else {
            throw WalletConnectServiceError.accountMismatch
        }

        let message = Data(hexString: messageValue) ?? Data(messageValue.utf8)
        guard let keystore = PlainKeystore(privateKey: privateKey),
              let account = keystore.addresses?.first,
              let signature = try Web3Signer.signPersonalMessage(
                message,
                keystore: keystore,
                account: account,
                password: ""
              ) else {
            throw WalletConnectServiceError.signingFailed
        }
        return AnyCodable("0x" + signature.toHexString())
    }

    private func typedDataSign(
        _ params: AnyCodable,
        privateKey: Data,
        expectedAddress: String,
        expectedChainId: Int?
    ) throws -> AnyCodable {
        let values = try params.get([AnyCodable].self)
        guard values.count >= 2,
              let address = values[0].value as? String,
              address.caseInsensitiveCompare(expectedAddress) == .orderedSame else {
            throw WalletConnectServiceError.accountMismatch
        }

        let typedDataJSON: String
        if let string = values[1].value as? String {
            typedDataJSON = string
        } else {
            let data = try JSONEncoder().encode(values[1])
            guard let string = String(data: data, encoding: .utf8) else {
                throw WalletConnectServiceError.invalidRequest
            }
            typedDataJSON = string
        }

        try validateTypedDataChain(typedDataJSON, expectedChainId: expectedChainId)
        let typedData = try EIP712Parser.parse(typedDataJSON)
        guard let keystore = PlainKeystore(privateKey: privateKey),
              let account = keystore.addresses?.first else {
            throw WalletConnectServiceError.signingFailed
        }
        let signature = try Web3Signer.signEIP712(
            typedData,
            keystore: keystore,
            account: account
        )
        return AnyCodable("0x" + signature.toHexString())
    }

    private func sendTransaction(
        _ params: AnyCodable,
        privateKey: Data,
        expectedAddress: String,
        blockchain: BlockchainType
    ) async throws -> AnyCodable {
        guard let payload = try params.get([EthereumTransactionPayload].self).first,
              payload.from.caseInsensitiveCompare(expectedAddress) == .orderedSame,
              Self.isEVMAddress(payload.to) else {
            throw WalletConnectServiceError.accountMismatch
        }

        guard let value = Self.parseHexQuantity(payload.value ?? "0x0"),
              let data = Self.parseHexData(payload.data ?? "0x") else {
            throw WalletConnectServiceError.invalidRequest
        }

        let gasValue = payload.gas ?? payload.gasLimit
        let requestedGas: BigUInt?
        if let gasValue {
            guard let parsedGas = Self.parseHexQuantity(gasValue) else {
                throw WalletConnectServiceError.invalidRequest
            }
            requestedGas = parsedGas
        } else {
            requestedGas = nil
        }
        let gasLimit: BigUInt
        if let requestedGas, requestedGas > 0 {
            guard requestedGas <= 10_000_000 else {
                throw WalletConnectServiceError.invalidRequest
            }
            gasLimit = requestedGas
        } else {
            let estimate = try await estimateGas(
                from: expectedAddress,
                to: payload.to,
                value: value,
                data: data,
                blockchain: blockchain
            )
            gasLimit = estimate * 12 / 10
        }

        let transactionHash = try await SwapService.shared.sendRawTransaction(
            from: expectedAddress,
            to: payload.to,
            value: value,
            data: data,
            gasLimit: gasLimit,
            blockchain: blockchain,
            privateKey: privateKey
        )
        return AnyCodable(transactionHash)
    }

    private func estimateGas(
        from: String,
        to: String,
        value: BigUInt,
        data: Data,
        blockchain: BlockchainType
    ) async throws -> BigUInt {
        let result = try await SwapService.shared.rpcRequest(
            method: "eth_estimateGas",
            params: [[
                "from": from,
                "to": to,
                "value": "0x" + String(value, radix: 16),
                "data": "0x" + data.hexString
            ]],
            blockchain: blockchain
        )
        guard let hex = result as? String else { throw WalletConnectServiceError.invalidRequest }
        guard let amount = Self.parseHexQuantity(hex) else {
            throw WalletConnectServiceError.invalidRequest
        }
        return amount
    }

    private func validateTypedDataChain(_ json: String, expectedChainId: Int?) throws {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let domain = object["domain"] as? [String: Any],
              let chainValue = domain["chainId"] else { return }

        let typedChainId: Int?
        if let int = chainValue as? Int {
            typedChainId = int
        } else if let number = chainValue as? NSNumber {
            typedChainId = number.intValue
        } else if let string = chainValue as? String {
            typedChainId = string.lowercased().hasPrefix("0x")
                ? Int(string.dropFirst(2), radix: 16)
                : Int(string)
        } else {
            typedChainId = nil
        }

        guard let typedChainId else {
            throw WalletConnectServiceError.invalidRequest
        }
        if let expectedChainId, typedChainId != expectedChainId {
            throw WalletConnectServiceError.chainMismatch
        }
    }

    // MARK: - Namespace and URI helpers

    private func requestedEVMChains(in proposal: Session.Proposal) -> [WalletConnectUtils.Blockchain] {
        var result: [WalletConnectUtils.Blockchain] = []
        for namespaces in [proposal.requiredNamespaces, proposal.optionalNamespaces ?? [:]] {
            for (key, namespace) in namespaces {
                if key == "eip155" {
                    result.append(contentsOf: namespace.chains ?? [])
                } else if key.hasPrefix("eip155:"), let chain = WalletConnectUtils.Blockchain(key) {
                    result.append(chain)
                }
            }
        }
        return Array(Set(result)).sorted { $0.absoluteString < $1.absoluteString }
    }

    private func proposalMethods(_ proposal: Session.Proposal) -> Set<String> {
        let required = proposal.requiredNamespaces.values.flatMap(\.methods)
        let optional = proposal.optionalNamespaces?.values.flatMap(\.methods) ?? []
        return Set(required + optional)
    }

    private func proposalEvents(_ proposal: Session.Proposal) -> Set<String> {
        let required = proposal.requiredNamespaces.values.flatMap(\.events)
        let optional = proposal.optionalNamespaces?.values.flatMap(\.events) ?? []
        return Set(required + optional)
    }

    private func blockchainType(for chain: WalletConnectUtils.Blockchain) -> BlockchainType? {
        guard chain.namespace == "eip155", let chainId = Int(chain.reference) else { return nil }
        return BlockchainType.allCases.first { $0.chainId == chainId && $0.isEVM }
    }

    private func extractedURI(from value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("wc:") { return trimmed }
        if let components = URLComponents(string: trimmed),
           let embedded = components.queryItems?.first(where: { $0.name == "uri" })?.value,
           embedded.lowercased().hasPrefix("wc:") {
            return embedded
        }
        throw WalletConnectServiceError.invalidURI
    }

    private static func isEVMAddress(_ value: String) -> Bool {
        value.hasPrefix("0x") && value.count == 42 && value.dropFirst(2).allSatisfy(\.isHexDigit)
    }

    private static func parseHexQuantity(_ value: String) -> BigUInt? {
        guard value.lowercased().hasPrefix("0x") else { return nil }
        let stripped = String(value.dropFirst(2))
        guard stripped.allSatisfy(\.isHexDigit) else { return nil }
        return BigUInt(stripped.isEmpty ? "0" : stripped, radix: 16)
    }

    private static func parseHexData(_ value: String) -> Data? {
        guard value.lowercased().hasPrefix("0x") else { return nil }
        let stripped = String(value.dropFirst(2))
        guard stripped.count.isMultiple(of: 2), stripped.allSatisfy(\.isHexDigit) else { return nil }
        return stripped.isEmpty ? Data() : Data(hexString: stripped)
    }
}

struct WalletConnectTransactionSummary {
    let from: String
    let to: String
    let amount: Decimal?
    let symbol: String
    let network: String
    let data: String?
}

private struct EthereumTransactionPayload: Codable {
    let from: String
    let to: String
    let value: String?
    let data: String?
    let gas: String?
    let gasLimit: String?
}

private struct WpayinWalletConnectCryptoProvider: CryptoProvider {
    func recoverPubKey(signature: EthereumSignature, message: Data) throws -> Data {
        let serialized = Data(signature.r + signature.s + [signature.v])
        guard let publicKey = SECP256K1.recoverPublicKey(
            hash: message,
            signature: serialized,
            compressed: false
        ) else {
            throw WalletConnectServiceError.signingFailed
        }
        return publicKey
    }

    func keccak256(_ data: Data) -> Data {
        Hash.keccak256(data: data)
    }
}
