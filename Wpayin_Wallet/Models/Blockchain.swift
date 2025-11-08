//
//  Blockchain.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import Foundation
import SwiftUI
import WalletCore

// MARK: - Network Models

enum NetworkType: String, CaseIterable, Codable {
    case mainnet = "mainnet"
    case testnet = "testnet"
    case devnet = "devnet"

    var displayName: String {
        switch self {
        case .mainnet:
            return "Mainnet"
        case .testnet:
            return "Testnet"
        case .devnet:
            return "Devnet"
        }
    }
}

enum BlockchainPlatform: String, CaseIterable, Codable, Identifiable {
    case ethereum = "ethereum"
    case bitcoin = "bitcoin"
    case solana = "solana"
    case polygon = "polygon"
    case bsc = "binance-smart-chain"
    case arbitrum = "arbitrum"
    case optimism = "optimism"
    case avalanche = "avalanche"
    case base = "base"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .ethereum:
            return "Ethereum"
        case .bitcoin:
            return "Bitcoin"
        case .solana:
            return "Solana"
        case .polygon:
            return "Polygon"
        case .bsc:
            return "BNB Chain"
        case .arbitrum:
            return "Arbitrum"
        case .optimism:
            return "Optimism"
        case .avalanche:
            return "Avalanche"
        case .base:
            return "Base"
        }
    }

    var symbol: String {
        switch self {
        case .ethereum:
            return "ETH"
        case .bitcoin:
            return "BTC"
        case .solana:
            return "SOL"
        case .polygon:
            return "MATIC"
        case .bsc:
            return "BNB"
        case .arbitrum:
            return "ETH"
        case .optimism:
            return "ETH"
        case .avalanche:
            return "AVAX"
        case .base:
            return "ETH"
        }
    }

    var color: Color {
        switch self {
        case .ethereum:
            return Color(red: 0.39, green: 0.47, blue: 1.0)
        case .bitcoin:
            return Color(red: 1.0, green: 0.65, blue: 0.0)
        case .solana:
            return Color(red: 0.66, green: 0.36, blue: 1.0)
        case .polygon:
            return Color(red: 0.51, green: 0.29, blue: 0.93)
        case .bsc:
            return Color(red: 0.95, green: 0.77, blue: 0.19)
        case .arbitrum:
            return Color(red: 0.18, green: 0.57, blue: 1.0)
        case .optimism:
            return Color(red: 1.0, green: 0.04, blue: 0.13)
        case .avalanche:
            return Color(red: 0.91, green: 0.24, blue: 0.20)
        case .base:
            return Color(red: 0.0, green: 0.46, blue: 0.87)
        }
    }

    var iconName: String {
        switch self {
        case .ethereum:
            return "diamond.fill"
        case .bitcoin:
            return "bitcoinsign.circle.fill"
        case .solana:
            return "sun.max.fill"
        case .polygon:
            return "pentagon.fill"
        case .bsc:
            return "triangle.fill"
        case .arbitrum:
            return "circle.hexagongrid.fill"
        case .optimism:
            return "circle.fill"
        case .avalanche:
            return "mountain.2.fill"
        case .base:
            return "circle.grid.cross"
        }
    }
    
    var displayIcon: String {
        switch self {
        case .ethereum:
            return "Ξ"  // Ethereum symbol
        case .bitcoin:
            return "₿"  // Bitcoin symbol
        case .polygon:
            return "⬡"  // Hexagon
        case .bsc:
            return "B"  // BNB
        case .arbitrum:
            return "A"  // Arbitrum
        case .optimism:
            return "O"  // Optimism
        case .avalanche:
            return "A"  // Avalanche
        case .base:
            return "◼︎"  // Base square
        case .solana:
            return "S"  // Solana
        }
    }

    var supportedNetworks: [NetworkType] {
        switch self {
        case .ethereum, .polygon, .bsc, .arbitrum, .optimism, .avalanche:
            return [.mainnet, .testnet]
        case .bitcoin:
            return [.mainnet, .testnet]
        case .solana:
            return [.mainnet, .testnet, .devnet]
        case .base:
            return [.mainnet]
        }
    }

    var addressPrefix: String {
        switch self {
        case .ethereum, .polygon, .bsc, .arbitrum, .optimism, .avalanche:
            return "0x"
        case .bitcoin:
            return "bc1" // Bech32 for mainnet
        case .solana:
            return "" // Base58
        case .base:
            return "0x"
        }
    }

    var coinType: CoinType? {
        switch self {
        case .ethereum:
            return .ethereum
        case .bitcoin:
            return .bitcoin
        case .solana:
            return .solana
        case .polygon:
            return .polygon
        case .bsc:
            return .smartChain
        case .arbitrum:
            return .arbitrum
        case .optimism:
            return .optimism
        case .avalanche:
            return .avalancheCChain
        case .base:
            return .ethereum
        }
    }

    var blockchainType: BlockchainType? {
        BlockchainType(platform: self)
    }
}

// MARK: - Blockchain Configuration

struct BlockchainConfig: Identifiable, Codable, Sendable {
    var id = UUID()
    let platform: BlockchainPlatform
    let network: NetworkType
    let rpcUrl: String
    let explorerUrl: String
    let chainId: Int?
    let isEnabled: Bool

    var displayName: String {
        "\(platform.name) \(network.displayName)"
    }

    var fullName: String {
        platform.name + (network != .mainnet ? " (\(network.displayName))" : "")
    }

    static let defaultConfigs: [BlockchainConfig] = [
        // Ethereum
        BlockchainConfig(
            platform: .ethereum,
            network: .mainnet,
            rpcUrl: "https://mainnet.infura.io/v3/f6a4dd53d9f945c4a29b9cd2a3af0ad6",
            explorerUrl: "https://etherscan.io",
            chainId: 1,
            isEnabled: true
        ),
        BlockchainConfig(
            platform: .ethereum,
            network: .testnet,
            rpcUrl: "https://goerli.infura.io/v3/YOUR_API_KEY",
            explorerUrl: "https://goerli.etherscan.io",
            chainId: 5,
            isEnabled: false
        ),

        // Bitcoin
        BlockchainConfig(
            platform: .bitcoin,
            network: .mainnet,
            rpcUrl: "https://bitcoin-mainnet.g.alchemy.com/v2/eU9nuznz2dU1ZKQNK8mYIeBrLOUcDsaP",
            explorerUrl: "https://www.blockchain.com/explorer/addresses/btc",
            chainId: nil,
            isEnabled: true
        ),
        BlockchainConfig(
            platform: .bitcoin,
            network: .testnet,
            rpcUrl: "https://blockstream.info/testnet/api",
            explorerUrl: "https://blockstream.info/testnet",
            chainId: nil,
            isEnabled: false
        ),

        // Solana
        BlockchainConfig(
            platform: .solana,
            network: .mainnet,
            rpcUrl: "https://api.mainnet-beta.solana.com",
            explorerUrl: "https://explorer.solana.com",
            chainId: nil,
            isEnabled: false
        ),

        // Polygon
        BlockchainConfig(
            platform: .polygon,
            network: .mainnet,
            rpcUrl: "https://polygon-mainnet.infura.io/v3/f6a4dd53d9f945c4a29b9cd2a3af0ad6",
            explorerUrl: "https://polygonscan.com",
            chainId: 137,
            isEnabled: true
        ),

        // BNB Chain
        BlockchainConfig(
            platform: .bsc,
            network: .mainnet,
            rpcUrl: "https://bsc-mainnet.infura.io/v3/f6a4dd53d9f945c4a29b9cd2a3af0ad6",
            explorerUrl: "https://bscscan.com",
            chainId: 56,
            isEnabled: true
        ),

        // Arbitrum
        BlockchainConfig(
            platform: .arbitrum,
            network: .mainnet,
            rpcUrl: "https://arbitrum-mainnet.infura.io/v3/f6a4dd53d9f945c4a29b9cd2a3af0ad6",
            explorerUrl: "https://arbiscan.io",
            chainId: 42161,
            isEnabled: true
        ),

        // Optimism
        BlockchainConfig(
            platform: .optimism,
            network: .mainnet,
            rpcUrl: "https://optimism-mainnet.infura.io/v3/f6a4dd53d9f945c4a29b9cd2a3af0ad6",
            explorerUrl: "https://optimistic.etherscan.io",
            chainId: 10,
            isEnabled: false
        ),

        // Avalanche
        BlockchainConfig(
            platform: .avalanche,
            network: .mainnet,
            rpcUrl: "https://api.avax.network/ext/bc/C/rpc",
            explorerUrl: "https://snowtrace.io",
            chainId: 43114,
            isEnabled: false
        ),

        // Base
        BlockchainConfig(
            platform: .base,
            network: .mainnet,
            rpcUrl: "https://base-mainnet.infura.io/v3/f6a4dd53d9f945c4a29b9cd2a3af0ad6",
            explorerUrl: "https://basescan.org",
            chainId: 8453,
            isEnabled: false
        )
    ]
}

extension BlockchainConfig {
    var blockchainType: BlockchainType? {
        platform.blockchainType
    }

    var coinType: CoinType? {
        platform.coinType
    }
}
