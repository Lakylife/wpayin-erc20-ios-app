// Autor Lukas Helebrandt, 2026

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
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Ethereum",
            chainId: 1,
            rpcUrl: "https://eth.llamarpc.com",
            symbol: "ETH",
            blockExplorerUrl: "https://etherscan.io",
            blockchain: .ethereum
        ),

        // Arbitrum
        NetworkConfig(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            name: "Arbitrum One",
            chainId: 42161,
            rpcUrl: "https://arb1.arbitrum.io/rpc",
            symbol: "ETH",
            blockExplorerUrl: "https://arbiscan.io",
            blockchain: .arbitrum
        ),

        // Base
        NetworkConfig(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            name: "Base",
            chainId: 8453,
            rpcUrl: "https://mainnet.base.org",
            symbol: "ETH",
            blockExplorerUrl: "https://basescan.org",
            blockchain: .base
        ),

        // Optimism
        NetworkConfig(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            name: "Optimism",
            chainId: 10,
            rpcUrl: "https://mainnet.optimism.io",
            symbol: "ETH",
            blockExplorerUrl: "https://optimistic.etherscan.io",
            blockchain: .optimism
        ),

        // Polygon
        NetworkConfig(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            name: "Polygon",
            chainId: 137,
            rpcUrl: "https://polygon-rpc.com",
            symbol: "MATIC",
            blockExplorerUrl: "https://polygonscan.com",
            blockchain: .polygon
        ),

        // BSC
        NetworkConfig(
            id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
            name: "BNB Smart Chain",
            chainId: 56,
            rpcUrl: "https://bsc-dataseed.binance.org",
            symbol: "BNB",
            blockExplorerUrl: "https://bscscan.com",
            blockchain: .bsc
        ),

        // Avalanche C-Chain
        NetworkConfig(
            id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
            name: "Avalanche C-Chain",
            chainId: 43114,
            rpcUrl: "https://api.avax.network/ext/bc/C/rpc",
            symbol: "AVAX",
            blockExplorerUrl: "https://snowtrace.io",
            blockchain: .avalanche
        ),
        
        // Bitcoin
        NetworkConfig(
            id: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
            name: "Bitcoin",
            chainId: 0,  // Bitcoin doesn't use chain ID
            rpcUrl: "https://blockstream.info/api",
            symbol: "BTC",
            blockExplorerUrl: "https://blockstream.info",
            blockchain: .bitcoin
        ),

        // Solana
        NetworkConfig(
            id: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
            name: "Solana",
            chainId: 0,
            rpcUrl: "https://api.mainnet-beta.solana.com",
            symbol: "SOL",
            blockExplorerUrl: "https://explorer.solana.com",
            blockchain: .solana
        )
    ]

    // Color for network
    var color: Color {
        BlockchainPlatform(rawValue: blockchain.rawValue)?.color ?? .gray
    }

    // Network icon/symbol
    var iconSymbol: String {
        BlockchainPlatform(rawValue: blockchain.rawValue)?.displayIcon ?? "?"
    }
}

// Manager for network configurations
class NetworkConfigManager: ObservableObject {
    @Published var networks: [NetworkConfig] = []
    @Published var enabledNetworks: Set<String> = []  // Store enabled network IDs

    private let userDefaults = UserDefaults.standard
    private let networksKey = "SavedNetworkConfigs"
    private let enabledNetworksKey = "EnabledNetworks"

    init() {
        loadNetworks()
        loadEnabledNetworks()
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
    
    private func loadEnabledNetworks() {
        if let data = userDefaults.data(forKey: enabledNetworksKey),
           let saved = try? JSONDecoder().decode(Set<String>.self, from: data) {
            let validSaved = saved.filter { id in
                networks.contains { $0.id.uuidString == id }
            }
            if validSaved.isEmpty {
                enabledNetworks = defaultEnabledNetworkIds()
            } else {
                enabledNetworks = Set(validSaved)
            }
        } else {
            enabledNetworks = defaultEnabledNetworkIds()
        }
    }

    private func defaultEnabledNetworkIds() -> Set<String> {
        Set(networks.filter {
            $0.blockchain == .ethereum || $0.blockchain == .bitcoin
        }.map { $0.id.uuidString })
    }
    
    private func saveEnabledNetworks() {
        if let data = try? JSONEncoder().encode(enabledNetworks) {
            userDefaults.set(data, forKey: enabledNetworksKey)
        }
    }

    func saveNetworks() {
        // Only save custom networks
        let customNetworks = networks.filter { $0.isCustom }
        if let data = try? JSONEncoder().encode(customNetworks) {
            userDefaults.set(data, forKey: networksKey)
        }
    }
    
    func isNetworkEnabled(_ network: NetworkConfig) -> Bool {
        return enabledNetworks.contains(network.id.uuidString)
    }
    
    func setNetworkEnabled(_ network: NetworkConfig, enabled: Bool) {
        if enabled {
            enabledNetworks.insert(network.id.uuidString)
        } else {
            enabledNetworks.remove(network.id.uuidString)
        }
        saveEnabledNetworks()
    }
    
    func getEnabledNetworks() -> [NetworkConfig] {
        return networks.filter { isNetworkEnabled($0) }
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
        enabledNetworks.remove(network.id.uuidString)
        saveNetworks()
        saveEnabledNetworks()
    }

    func getNetwork(for blockchain: BlockchainType) -> NetworkConfig? {
        return networks.first { $0.blockchain == blockchain }
    }
}
