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
    // Base Layer 1 Blockchains
    case ethereum = "ethereum"
    case bitcoin = "bitcoin"
    case litecoin = "litecoin"
    case bitcoinCash = "bitcoin-cash"
    case eCash = "ecash"
    case dash = "dash"
    case zcash = "zcash"
    case monero = "monero"
    case solana = "solana"
    
    // EVM-Compatible Chains (Ethereum-based)
    case polygon = "polygon"
    case bsc = "binance-smart-chain"
    case arbitrum = "arbitrum"
    case optimism = "optimism"
    case avalanche = "avalanche"
    case base = "base"
    case gnosis = "gnosis"
    case zkSync = "zksync"
    case fantom = "fantom"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .ethereum:
            return "Ethereum"
        case .bitcoin:
            return "Bitcoin"
        case .litecoin:
            return "Litecoin"
        case .bitcoinCash:
            return "Bitcoin Cash"
        case .eCash:
            return "eCash"
        case .dash:
            return "Dash"
        case .zcash:
            return "Zcash"
        case .monero:
            return "Monero"
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
        case .gnosis:
            return "Gnosis"
        case .zkSync:
            return "zkSync Era"
        case .fantom:
            return "Fantom"
        }
    }

    var symbol: String {
        switch self {
        case .ethereum:
            return "ETH"
        case .bitcoin:
            return "BTC"
        case .litecoin:
            return "LTC"
        case .bitcoinCash:
            return "BCH"
        case .eCash:
            return "XEC"
        case .dash:
            return "DASH"
        case .zcash:
            return "ZEC"
        case .monero:
            return "XMR"
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
        case .gnosis:
            return "xDAI"
        case .zkSync:
            return "ETH"
        case .fantom:
            return "FTM"
        }
    }

    var color: Color {
        switch self {
        case .ethereum:
            return Color(red: 0.39, green: 0.47, blue: 1.0)  // Blue
        case .bitcoin:
            return Color(red: 1.0, green: 0.65, blue: 0.0)  // Orange
        case .litecoin:
            return Color(red: 0.2, green: 0.38, blue: 0.62)  // Light blue
        case .bitcoinCash:
            return Color(red: 0.0, green: 0.71, blue: 0.39)  // Green
        case .eCash:
            return Color(red: 0.0, green: 0.48, blue: 0.8)  // Blue
        case .dash:
            return Color(red: 0.0, green: 0.55, blue: 0.88)  // Dash blue
        case .zcash:
            return Color(red: 0.96, green: 0.66, blue: 0.2)  // Yellow/gold
        case .monero:
            return Color(red: 1.0, green: 0.39, blue: 0.0)  // Orange
        case .solana:
            return Color(red: 0.66, green: 0.36, blue: 1.0)  // Purple
        case .polygon:
            return Color(red: 0.51, green: 0.29, blue: 0.93)  // Purple
        case .bsc:
            return Color(red: 0.95, green: 0.77, blue: 0.19)  // Yellow
        case .arbitrum:
            return Color(red: 0.18, green: 0.57, blue: 1.0)  // Blue
        case .optimism:
            return Color(red: 1.0, green: 0.04, blue: 0.13)  // Red
        case .avalanche:
            return Color(red: 0.91, green: 0.24, blue: 0.20)  // Red
        case .base:
            return Color(red: 0.0, green: 0.46, blue: 0.87)  // Blue
        case .gnosis:
            return Color(red: 0.0, green: 0.51, blue: 0.47)  // Teal
        case .zkSync:
            return Color(red: 0.32, green: 0.42, blue: 0.98)  // Blue/purple
        case .fantom:
            return Color(red: 0.08, green: 0.49, blue: 0.96)  // Blue
        }
    }

    var iconName: String {
        switch self {
        case .ethereum:
            return "diamond.fill"
        case .bitcoin:
            return "bitcoinsign.circle.fill"
        case .litecoin:
            return "l.circle.fill"
        case .bitcoinCash:
            return "b.circle.fill"
        case .eCash:
            return "e.circle.fill"
        case .dash:
            return "d.circle.fill"
        case .zcash:
            return "z.circle.fill"
        case .monero:
            return "m.circle.fill"
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
        case .gnosis:
            return "g.circle.fill"
        case .zkSync:
            return "z.square.fill"
        case .fantom:
            return "f.circle.fill"
        }
    }
    
    var displayIcon: String {
        switch self {
        case .ethereum:
            return "Ξ"  // Ethereum symbol
        case .bitcoin:
            return "₿"  // Bitcoin symbol
        case .litecoin:
            return "Ł"  // Litecoin symbol
        case .bitcoinCash:
            return "฿"  // Bitcoin Cash
        case .eCash:
            return "XEC"
        case .dash:
            return "D"
        case .zcash:
            return "Z"
        case .monero:
            return "ɱ"  // Monero symbol
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
        case .gnosis:
            return "G"
        case .zkSync:
            return "Z"
        case .fantom:
            return "F"
        case .solana:
            return "S"  // Solana
        }
    }
    
    var assetIconName: String? {
        switch self {
        case .ethereum:
            return "ethereum_trx_32"
        case .bitcoin:
            return "bitcoin"
        case .polygon:
            return "polygon-pos_trx_32"
        case .bsc:
            return "binance-smart-chain_trx_32"
        case .arbitrum:
            return "arbitrum-one_trx_32"
        case .optimism:
            return "optimistic-ethereum_trx_32"
        case .avalanche:
            return "avalanche_trx_32"
        case .base:
            return "base_trx_32"
        case .gnosis:
            return "gnosis_trx_32"
        case .zkSync:
            return "zksync_trx_32"
        case .fantom:
            return "fantom_trx_32"
        default:
            return nil
        }
    }
    
    // Blockchain category for UI grouping
    enum Category {
        case baseLayer1      // Bitcoin, Ethereum, Litecoin, etc.
        case evmChain       // Polygon, BSC, Arbitrum, etc.
        case altLayer1      // Solana, etc.
        
        var displayName: String {
            switch self {
            case .baseLayer1:
                return "Base Layer 1"
            case .evmChain:
                return "EVM Chains"
            case .altLayer1:
                return "Other L1s"
            }
        }
    }
    
    var category: Category {
        switch self {
        case .bitcoin, .litecoin, .bitcoinCash, .eCash, .dash, .zcash, .monero:
            return .baseLayer1
        case .ethereum:
            return .baseLayer1
        case .polygon, .bsc, .arbitrum, .optimism, .avalanche, .base, .gnosis, .zkSync, .fantom:
            return .evmChain
        case .solana:
            return .altLayer1
        }
    }
    
    var isEVM: Bool {
        category == .evmChain || self == .ethereum
    }

    var supportedNetworks: [NetworkType] {
        switch self {
        case .ethereum, .polygon, .bsc, .arbitrum, .optimism, .avalanche, .gnosis, .zkSync, .fantom:
            return [.mainnet, .testnet]
        case .bitcoin, .litecoin, .bitcoinCash, .dash, .zcash:
            return [.mainnet, .testnet]
        case .eCash, .monero:
            return [.mainnet]
        case .solana:
            return [.mainnet, .testnet, .devnet]
        case .base:
            return [.mainnet]
        }
    }

    var addressPrefix: String {
        switch self {
        case .ethereum, .polygon, .bsc, .arbitrum, .optimism, .avalanche, .base, .gnosis, .zkSync, .fantom:
            return "0x"
        case .bitcoin:
            return "bc1" // Bech32 for mainnet
        case .litecoin:
            return "ltc1"
        case .bitcoinCash:
            return "bitcoincash:"
        case .eCash:
            return "ecash:"
        case .dash:
            return "X"
        case .zcash:
            return "t1"
        case .monero:
            return "4"
        case .solana:
            return "" // Base58
        }
    }

    var coinType: CoinType? {
        switch self {
        case .ethereum:
            return .ethereum
        case .bitcoin:
            return .bitcoin
        case .litecoin:
            return .litecoin
        case .bitcoinCash:
            return .bitcoinCash
        case .eCash:
            return .ecash
        case .dash:
            return .dash
        case .zcash:
            return .zcash
        case .monero:
            return nil  // Not supported by WalletCore
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
        case .gnosis:
            return .xdai
        case .zkSync:
            return .ethereum
        case .fantom:
            return .fantom
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
