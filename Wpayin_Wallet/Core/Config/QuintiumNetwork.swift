// Autor Lukas Helebrandt, 2026

//
//  QuintiumNetwork.swift
//  Wpayin_Wallet
//
//  Quintium (QU) is the project's own EVM-compatible Proof-of-Work chain.
//  The values below mirror `packages/node/src/params.js` of the Quintium node
//  (release 2.11.1). Changing chain IDs or decimals there is a hard fork, so
//  they are constants here as well.
//

import Foundation

// MARK: - Network parameters

enum QuintiumNetwork: String, CaseIterable, Codable, Identifiable, Sendable {
    case mainnet
    case testnet

    var id: String { rawValue }

    /// EIP-155 chain ID used for signing.
    var chainId: Int {
        switch self {
        case .mainnet: return 52401
        case .testnet: return 52402
        }
    }

    /// Native currency symbol (QU on mainnet, tQU on testnet).
    var symbol: String {
        switch self {
        case .mainnet: return "QU"
        case .testnet: return "tQU"
        }
    }

    var displayName: String {
        switch self {
        case .mainnet: return "Quintium"
        case .testnet: return "Quintium Testnet"
        }
    }

    /// Default JSON-RPC port of a Quintium node for this network.
    var defaultRpcPort: Int {
        switch self {
        case .mainnet: return 8545
        case .testnet: return 8546
        }
    }

    var isTestnet: Bool { self == .testnet }

    /// Mainnet genesis is planned for 1 January 2027 00:00 UTC
    /// (`genesisTimestamp: 1798761600n`). The testnet is already running.
    static let mainnetGenesis = Date(timeIntervalSince1970: 1_798_761_600)

    var isLaunched: Bool {
        switch self {
        case .mainnet: return Date() >= Self.mainnetGenesis
        case .testnet: return true
        }
    }

    /// 1 QU = 10^18 wei, like ETH.
    static let decimals = 18

    /// Target block time in seconds.
    static let blockTime: TimeInterval = 15

    /// BIP-44 path: Quintium uses Ethereum keys and addresses (coin type 60),
    /// the same path as the Quintium desktop wallet and browser extension.
    static let derivationPathPrefix = "m/44'/60'/0'/0"

    /// RPC methods of the Quintium node that return the transaction history
    /// of an address (`aether_*` is the original name, `quintium_*` its twin).
    static let addressTransactionsMethod = "aether_addressTxs"
}

// MARK: - User settings

/// Which Quintium network the wallet uses and which node it talks to.
///
/// There is no public Quintium RPC yet (no seed servers, no domain), so the
/// node URL comes from the user (Settings → Quintium) or from the
/// `QUINTIUM_RPC_URL` / `QUINTIUM_TESTNET_RPC_URL` environment variables or
/// Info.plist keys of a release build.
enum QuintiumSettings {
    static let didChangeNotification = Notification.Name("QuintiumSettingsDidChange")

    private static let defaults = UserDefaults.standard
    private static let networkKey = "Quintium.ActiveNetwork"

    private static func rpcKey(_ network: QuintiumNetwork) -> String { "Quintium.RPC.\(network.rawValue)" }
    private static func explorerKey(_ network: QuintiumNetwork) -> String { "Quintium.Explorer.\(network.rawValue)" }

    /// Active network. Testnet until the user switches; mainnet starts on 1 January 2027.
    static var network: QuintiumNetwork {
        get {
            defaults.string(forKey: networkKey).flatMap(QuintiumNetwork.init(rawValue:)) ?? .testnet
        }
        set {
            defaults.set(newValue.rawValue, forKey: networkKey)
            notifyChange()
        }
    }

    // MARK: RPC

    static func rpcUrl(for network: QuintiumNetwork) -> String {
        if let saved = cleaned(defaults.string(forKey: rpcKey(network))) {
            return saved
        }
        return buildValue(network == .mainnet ? "QUINTIUM_RPC_URL" : "QUINTIUM_TESTNET_RPC_URL") ?? ""
    }

    static func setRpcUrl(_ value: String, for network: QuintiumNetwork) {
        store(value, key: rpcKey(network))
    }

    static var rpcUrl: String { rpcUrl(for: network) }

    // MARK: Explorer

    static func explorerUrl(for network: QuintiumNetwork) -> String {
        if let saved = cleaned(defaults.string(forKey: explorerKey(network))) {
            return saved
        }
        return buildValue(network == .mainnet ? "QUINTIUM_EXPLORER_URL" : "QUINTIUM_TESTNET_EXPLORER_URL") ?? ""
    }

    static func setExplorerUrl(_ value: String, for network: QuintiumNetwork) {
        store(value, key: explorerKey(network))
    }

    static var explorerUrl: String { explorerUrl(for: network) }

    /// The wallet can reach Quintium once a usable node URL is set.
    static var isConfigured: Bool { isValidURL(rpcUrl) }

    static func isValidURL(_ value: String) -> Bool {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              url.host?.isEmpty == false else { return false }
        return true
    }

    // MARK: Helpers

    private static func store(_ value: String, key: String) {
        if let cleaned = cleaned(value) {
            defaults.set(cleaned, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
        notifyChange()
    }

    private static func cleaned(_ value: String?) -> String? {
        guard var trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func buildValue(_ key: String) -> String? {
        if let env = cleaned(ProcessInfo.processInfo.environment[key]) {
            return env
        }
        let plist = cleaned(Bundle.main.object(forInfoDictionaryKey: key) as? String)
        return plist?.contains("$(") == true ? nil : plist
    }

    private static func notifyChange() {
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
}

// MARK: - Node check

/// Talks to a Quintium node directly over JSON-RPC.
enum QuintiumNodeClient {
    struct NodeStatus: Sendable {
        let chainId: Int
        let blockNumber: Int
    }

    enum NodeError: LocalizedError {
        case invalidURL
        case wrongChain(expected: Int, actual: Int)
        case badResponse(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Enter a valid node URL starting with https:// or http://".localized
            case .wrongChain(let expected, let actual):
                return "The node belongs to another network (chain ID %@, expected %@)".localized("\(actual)", "\(expected)")
            case .badResponse(let message):
                return message
            }
        }
    }

    /// Calls `eth_chainId` and `eth_blockNumber`, and checks the chain ID matches the network.
    static func check(rpcUrl: String, network: QuintiumNetwork) async throws -> NodeStatus {
        guard QuintiumSettings.isValidURL(rpcUrl), let url = URL(string: rpcUrl) else {
            throw NodeError.invalidURL
        }
        let chainHex: String = try await call(url: url, method: "eth_chainId", params: [])
        let chainId = Int(chainHex.dropHexPrefix, radix: 16) ?? -1
        guard chainId == network.chainId else {
            throw NodeError.wrongChain(expected: network.chainId, actual: chainId)
        }
        let blockHex: String = try await call(url: url, method: "eth_blockNumber", params: [])
        return NodeStatus(chainId: chainId, blockNumber: Int(blockHex.dropHexPrefix, radix: 16) ?? 0)
    }

    /// Transaction history of an address from the node's index (`aether_addressTxs`).
    static func addressTransactions(
        address: String,
        rpcUrl: String,
        limit: Int = 50
    ) async throws -> [QuintiumIndexedTransaction] {
        guard let url = URL(string: rpcUrl) else { throw NodeError.invalidURL }
        let page: QuintiumAddressTxPage = try await call(
            url: url,
            method: QuintiumNetwork.addressTransactionsMethod,
            params: [address, limit, 0]
        )
        return page.items
    }

    private struct RPCEnvelope<T: Decodable>: Decodable {
        struct RPCError: Decodable { let code: Int; let message: String }
        let result: T?
        let error: RPCError?
    }

    private static func call<T: Decodable>(url: URL, method: String, params: [Any]) async throws -> T {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "jsonrpc": "2.0", "id": 1, "method": method, "params": params
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NodeError.badResponse("The node did not answer (HTTP error)".localized)
        }
        let envelope = try JSONDecoder().decode(RPCEnvelope<T>.self, from: data)
        if let error = envelope.error { throw NodeError.badResponse(error.message) }
        guard let result = envelope.result else { throw NodeError.badResponse("Empty answer from the node".localized) }
        return result
    }
}

/// One page of `aether_addressTxs`: `{ total, items: [...] }` (only `items` is read).
struct QuintiumAddressTxPage: Decodable {
    let items: [QuintiumIndexedTransaction]
}

/// A transaction as the Quintium node returns it (Ethereum RPC shape plus
/// `status`, `gasUsed` and `timestamp` from the receipt and block).
struct QuintiumIndexedTransaction: Decodable {
    let hash: String
    let from: String
    let to: String?
    let value: String
    let gasPrice: String?
    let gasUsed: String?
    let blockNumber: String?
    let timestamp: Int?
    let status: Int?
    let input: String?

    private enum CodingKeys: String, CodingKey {
        case hash, from, to, value, gasPrice, gasUsed, blockNumber, timestamp, status, input
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hash = try c.decode(String.self, forKey: .hash)
        from = try c.decode(String.self, forKey: .from)
        to = try c.decodeIfPresent(String.self, forKey: .to)
        value = (try? c.decode(String.self, forKey: .value)) ?? "0x0"
        gasPrice = try? c.decodeIfPresent(String.self, forKey: .gasPrice)
        gasUsed = try? c.decodeIfPresent(String.self, forKey: .gasUsed)
        blockNumber = try? c.decodeIfPresent(String.self, forKey: .blockNumber)
        timestamp = try? c.decodeIfPresent(Int.self, forKey: .timestamp)
        input = try? c.decodeIfPresent(String.self, forKey: .input)
        // Receipt status arrives as a number (1/0), a hex quantity or a bool depending on the node version.
        if let number = try? c.decodeIfPresent(Int.self, forKey: .status) {
            status = number
        } else if let text = try? c.decodeIfPresent(String.self, forKey: .status) {
            status = Int(text.dropHexPrefix, radix: 16)
        } else if let flag = try? c.decodeIfPresent(Bool.self, forKey: .status) {
            status = flag ? 1 : 0
        } else {
            status = nil
        }
    }
}

extension String {
    /// "0x1a" → "1a"
    var dropHexPrefix: String {
        hasPrefix("0x") || hasPrefix("0X") ? String(dropFirst(2)) : self
    }
}
