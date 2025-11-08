//
//  NetworkManager.swift
//  Wpayin_Wallet
//
//  Network configuration with multiple RPC sources for failover
//

import Foundation

// MARK: - RPC Source

struct RPCSource {
    let name: String
    let urls: [String]
    let supportsWebSocket: Bool

    init(name: String, urls: [String], supportsWebSocket: Bool = false) {
        self.name = name
        self.urls = urls
        self.supportsWebSocket = supportsWebSocket
    }

    var primaryURL: String {
        urls.first ?? ""
    }
}

// MARK: - Network Configuration

struct NetworkConfiguration {
    let blockchain: BlockchainType
    let chainId: Int
    let rpcSources: [RPCSource]
    let explorerUrl: String
    let supportsEIP1559: Bool
    let nativeSymbol: String
    let nativeDecimals: Int
    let isBitcoin: Bool  // Special handling for Bitcoin

    var currentRPCUrl: String {
        rpcSources.first?.primaryURL ?? ""
    }

    var allRPCUrls: [String] {
        rpcSources.flatMap { $0.urls }
    }
}

// MARK: - Network Manager

class NetworkManager {
    static let shared = NetworkManager()

    private init() {}

    // MARK: - Network Configurations

    func configuration(for blockchain: BlockchainType) -> NetworkConfiguration {
        switch blockchain {
        case .ethereum:
            return NetworkConfiguration(
                blockchain: .ethereum,
                chainId: 1,
                rpcSources: [
                    RPCSource(name: "LlamaNodes", urls: ["https://eth.llamarpc.com"]),
                    RPCSource(name: "Ankr", urls: ["https://rpc.ankr.com/eth"]),
                    RPCSource(name: "PublicNode", urls: ["https://ethereum.publicnode.com"]),
                    RPCSource(name: "Cloudflare", urls: ["https://cloudflare-eth.com"])
                ],
                explorerUrl: "https://etherscan.io",
                supportsEIP1559: true,
                nativeSymbol: "ETH",
                nativeDecimals: 18,
                isBitcoin: false
            )

        case .bsc:
            return NetworkConfiguration(
                blockchain: .bsc,
                chainId: 56,
                rpcSources: [
                    RPCSource(name: "Binance", urls: ["https://bsc-dataseed.binance.org"]),
                    RPCSource(name: "BSC RPC", urls: ["https://bsc-dataseed1.defibit.io"]),
                    RPCSource(name: "Ankr", urls: ["https://rpc.ankr.com/bsc"]),
                    RPCSource(name: "PublicNode", urls: ["https://bsc-rpc.publicnode.com"])
                ],
                explorerUrl: "https://bscscan.com",
                supportsEIP1559: false, // BSC doesn't support EIP-1559
                nativeSymbol: "BNB",
                nativeDecimals: 18,
                isBitcoin: false
            )

        case .polygon:
            return NetworkConfiguration(
                blockchain: .polygon,
                chainId: 137,
                rpcSources: [
                    RPCSource(name: "Polygon RPC", urls: ["https://polygon-rpc.com"]),
                    RPCSource(name: "LlamaNodes", urls: ["https://polygon.llamarpc.com"]),
                    RPCSource(name: "Ankr", urls: ["https://rpc.ankr.com/polygon"]),
                    RPCSource(name: "PublicNode", urls: ["https://polygon-bor.publicnode.com"])
                ],
                explorerUrl: "https://polygonscan.com",
                supportsEIP1559: true,
                nativeSymbol: "MATIC",
                nativeDecimals: 18,
                isBitcoin: false
            )

        case .arbitrum:
            return NetworkConfiguration(
                blockchain: .arbitrum,
                chainId: 42161,
                rpcSources: [
                    RPCSource(name: "Arbitrum", urls: ["https://arb1.arbitrum.io/rpc"]),
                    RPCSource(name: "Ankr", urls: ["https://rpc.ankr.com/arbitrum"]),
                    RPCSource(name: "PublicNode", urls: ["https://arbitrum-one.publicnode.com"])
                ],
                explorerUrl: "https://arbiscan.io",
                supportsEIP1559: true,
                nativeSymbol: "ETH",
                nativeDecimals: 18,
                isBitcoin: false
            )

        case .optimism:
            return NetworkConfiguration(
                blockchain: .optimism,
                chainId: 10,
                rpcSources: [
                    RPCSource(name: "Optimism", urls: ["https://mainnet.optimism.io"]),
                    RPCSource(name: "Ankr", urls: ["https://rpc.ankr.com/optimism"]),
                    RPCSource(name: "PublicNode", urls: ["https://optimism.publicnode.com"])
                ],
                explorerUrl: "https://optimistic.etherscan.io",
                supportsEIP1559: true,
                nativeSymbol: "ETH",
                nativeDecimals: 18,
                isBitcoin: false
            )

        case .avalanche:
            return NetworkConfiguration(
                blockchain: .avalanche,
                chainId: 43114,
                rpcSources: [
                    RPCSource(name: "Avax Network", urls: ["https://api.avax.network/ext/bc/C/rpc"]),
                    RPCSource(name: "PublicNode", urls: ["https://avalanche-evm.publicnode.com"]),
                    RPCSource(name: "Ankr", urls: ["https://rpc.ankr.com/avalanche"])
                ],
                explorerUrl: "https://snowtrace.io",
                supportsEIP1559: true,
                nativeSymbol: "AVAX",
                nativeDecimals: 18,
                isBitcoin: false
            )

        case .base:
            return NetworkConfiguration(
                blockchain: .base,
                chainId: 8453,
                rpcSources: [
                    RPCSource(name: "Base", urls: ["https://mainnet.base.org"]),
                    RPCSource(name: "PublicNode", urls: ["https://base-rpc.publicnode.com"]),
                    RPCSource(name: "Ankr", urls: ["https://rpc.ankr.com/base"])
                ],
                explorerUrl: "https://basescan.org",
                supportsEIP1559: true,
                nativeSymbol: "ETH",
                nativeDecimals: 18,
                isBitcoin: false
            )

        case .bitcoin:
            return NetworkConfiguration(
                blockchain: .bitcoin,
                chainId: 0, // Bitcoin doesn't have chainId
                rpcSources: [
                    RPCSource(name: "Blockstream", urls: ["https://blockstream.info/api"]),
                    RPCSource(name: "Mempool.space", urls: ["https://mempool.space/api"]),
                    RPCSource(name: "Blockchain.info", urls: ["https://blockchain.info"])
                ],
                explorerUrl: "https://blockstream.info",
                supportsEIP1559: false,
                nativeSymbol: "BTC",
                nativeDecimals: 8,
                isBitcoin: true
            )

        default:
            // Default fallback
            return NetworkConfiguration(
                blockchain: blockchain,
                chainId: 1,
                rpcSources: [RPCSource(name: "Default", urls: ["https://eth.llamarpc.com"])],
                explorerUrl: "https://etherscan.io",
                supportsEIP1559: false,
                nativeSymbol: "ETH",
                nativeDecimals: 18,
                isBitcoin: false
            )
        }
    }

    // MARK: - RPC URL Selection

    /// Get current RPC URL for a blockchain (with failover support)
    func getRPCUrl(for blockchain: BlockchainType, preferredSourceName: String? = nil) -> String {
        let config = configuration(for: blockchain)

        if let preferredName = preferredSourceName,
           let source = config.rpcSources.first(where: { $0.name == preferredName }) {
            return source.primaryURL
        }

        return config.currentRPCUrl
    }

    /// Get all available RPC URLs for failover
    func getAllRPCUrls(for blockchain: BlockchainType) -> [String] {
        configuration(for: blockchain).allRPCUrls
    }

    /// Get explorer URL for transaction
    func getExplorerUrl(for blockchain: BlockchainType, txHash: String) -> String {
        let config = configuration(for: blockchain)
        return "\(config.explorerUrl)/tx/\(txHash)"
    }

    /// Get explorer URL for address
    func getExplorerUrl(for blockchain: BlockchainType, address: String) -> String {
        let config = configuration(for: blockchain)
        return "\(config.explorerUrl)/address/\(address)"
    }

    // MARK: - Network Helpers

    func supportsEIP1559(_ blockchain: BlockchainType) -> Bool {
        configuration(for: blockchain).supportsEIP1559
    }

    func chainId(for blockchain: BlockchainType) -> Int {
        configuration(for: blockchain).chainId
    }
}
