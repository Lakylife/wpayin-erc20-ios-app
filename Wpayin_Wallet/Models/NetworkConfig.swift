//
//  NetworkConfig.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import Foundation
import SwiftUI
import Combine

struct NetworkConfig: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var chainId: Int
    var rpcUrl: String
    var symbol: String // Native currency symbol (e.g., "ETH", "BNB")
    var blockExplorerUrl: String
    var isTestnet: Bool
    var isCustom: Bool // User-added custom network
    var blockchain: BlockchainType

    // Default initializer
    init(id: UUID = UUID(),
         name: String,
         chainId: Int,
         rpcUrl: String,
         symbol: String,
         blockExplorerUrl: String,
         isTestnet: Bool = false,
         isCustom: Bool = false,
         blockchain: BlockchainType) {
        self.id = id
        self.name = name
        self.chainId = chainId
        self.rpcUrl = rpcUrl
        self.symbol = symbol
        self.blockExplorerUrl = blockExplorerUrl
        self.isTestnet = isTestnet
        self.isCustom = isCustom
        self.blockchain = blockchain
    }

    // Default networks
    static let defaultNetworks: [NetworkConfig] = [
        // Ethereum Mainnet
        NetworkConfig(
            name: "Ethereum",
            chainId: 1,
            rpcUrl: "https://eth.llamarpc.com",
            symbol: "ETH",
            blockExplorerUrl: "https://etherscan.io",
            blockchain: .ethereum
        ),

        // Arbitrum
        NetworkConfig(
            name: "Arbitrum One",
            chainId: 42161,
            rpcUrl: "https://arb1.arbitrum.io/rpc",
            symbol: "ETH",
            blockExplorerUrl: "https://arbiscan.io",
            blockchain: .arbitrum
        ),

        // Base
        NetworkConfig(
            name: "Base",
            chainId: 8453,
            rpcUrl: "https://mainnet.base.org",
            symbol: "ETH",
            blockExplorerUrl: "https://basescan.org",
            blockchain: .base
        ),

        // Optimism
        NetworkConfig(
            name: "Optimism",
            chainId: 10,
            rpcUrl: "https://mainnet.optimism.io",
            symbol: "ETH",
            blockExplorerUrl: "https://optimistic.etherscan.io",
            blockchain: .optimism
        ),

        // Polygon
        NetworkConfig(
            name: "Polygon",
            chainId: 137,
            rpcUrl: "https://polygon-rpc.com",
            symbol: "MATIC",
            blockExplorerUrl: "https://polygonscan.com",
            blockchain: .polygon
        ),

        // BSC
        NetworkConfig(
            name: "BNB Smart Chain",
            chainId: 56,
            rpcUrl: "https://bsc-dataseed.binance.org",
            symbol: "BNB",
            blockExplorerUrl: "https://bscscan.com",
            blockchain: .bsc
        ),

        // Avalanche C-Chain
        NetworkConfig(
            name: "Avalanche C-Chain",
            chainId: 43114,
            rpcUrl: "https://api.avax.network/ext/bc/C/rpc",
            symbol: "AVAX",
            blockExplorerUrl: "https://snowtrace.io",
            blockchain: .avalanche
        )
    ]

    // Color for network
    var color: Color {
        switch blockchain {
        case .ethereum:
            return Color.blue
        case .arbitrum:
            return Color.cyan
        case .polygon:
            return Color.purple
        case .bsc:
            return Color.yellow
        case .optimism:
            return Color.red
        case .avalanche:
            return Color(red: 0.91, green: 0.24, blue: 0.20)
        case .base:
            return Color(red: 0.0, green: 0.46, blue: 0.87)
        default:
            return WpayinColors.primary
        }
    }

    // Network icon/symbol
    var iconSymbol: String {
        switch blockchain {
        case .ethereum:
            return "E"
        case .arbitrum:
            return "A"
        case .polygon:
            return "P"
        case .bsc:
            return "B"
        case .optimism:
            return "O"
        case .avalanche:
            return "V"
        case .base:
            return "B"
        default:
            return String(name.prefix(1))
        }
    }
}

// Manager for network configurations
class NetworkConfigManager: ObservableObject {
    @Published var networks: [NetworkConfig] = []

    private let userDefaults = UserDefaults.standard
    private let networksKey = "SavedNetworkConfigs"

    init() {
        loadNetworks()
    }

    private func loadNetworks() {
        // Try to load custom networks from UserDefaults
        if let data = userDefaults.data(forKey: networksKey),
           let savedNetworks = try? JSONDecoder().decode([NetworkConfig].self, from: data) {
            // Combine default networks with custom ones
            let customNetworks = savedNetworks.filter { $0.isCustom }
            networks = NetworkConfig.defaultNetworks + customNetworks
        } else {
            // First launch - use default networks only
            networks = NetworkConfig.defaultNetworks
        }
    }

    func saveNetworks() {
        // Only save custom networks
        let customNetworks = networks.filter { $0.isCustom }
        if let data = try? JSONEncoder().encode(customNetworks) {
            userDefaults.set(data, forKey: networksKey)
        }
    }

    func updateNetwork(_ network: NetworkConfig) {
        if let index = networks.firstIndex(where: { $0.id == network.id }) {
            networks[index] = network
            saveNetworks()
        }
    }

    func addCustomNetwork(_ network: NetworkConfig) {
        var customNetwork = network
        customNetwork.isCustom = true
        networks.append(customNetwork)
        saveNetworks()
    }

    func deleteNetwork(_ network: NetworkConfig) {
        // Only allow deleting custom networks
        guard network.isCustom else { return }
        networks.removeAll { $0.id == network.id }
        saveNetworks()
    }

    func getNetwork(for blockchain: BlockchainType) -> NetworkConfig? {
        return networks.first { $0.blockchain == blockchain }
    }
}
