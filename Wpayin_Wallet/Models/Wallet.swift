//
//  Wallet.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import Foundation
import CryptoKit

// MARK: - Wallet Models

enum WalletType: String, Codable, CaseIterable {
    case seed = "seed"           // HD wallet from seed phrase (supports multiple chains)
    case imported = "imported"   // Imported private key (single chain)
    case hardware = "hardware"   // Hardware wallet connection
    case watchOnly = "watch"     // Watch-only address

    var displayName: String {
        switch self {
        case .seed:
            return "Seed Wallet"
        case .imported:
            return "Imported Wallet"
        case .hardware:
            return "Hardware Wallet"
        case .watchOnly:
            return "Watch Only"
        }
    }
}

struct MultiChainWallet: Identifiable, Codable, Sendable {
    var id = UUID()
    let name: String
    let type: WalletType
    let createdAt: Date
    let seedPhraseId: String? // Reference to keychain stored seed
    var accounts: [WalletAccount]
    var isActive: Bool

    init(name: String, type: WalletType, seedPhraseId: String? = nil) {
        self.name = name
        self.type = type
        self.createdAt = Date()
        self.seedPhraseId = seedPhraseId
        self.accounts = []
        self.isActive = true
    }
}

struct WalletAccount: Identifiable, Codable, Sendable {
    var id = UUID()
    let blockchainConfig: BlockchainConfig
    let address: String
    let derivationPath: String? // For HD wallets
    let privateKeyId: String?   // Reference to keychain stored private key
    var nickname: String?
    var isEnabled: Bool
    var tokens: [WalletToken]
    var balance: Double // Native token balance

    var displayName: String {
        nickname ?? "\(blockchainConfig.platform.name) Account"
    }

    var formattedAddress: String {
        guard address.count > 10 else { return address }
        return "\(address.prefix(6))...\(address.suffix(4))"
    }

    init(blockchainConfig: BlockchainConfig, address: String, derivationPath: String? = nil, privateKeyId: String? = nil) {
        self.blockchainConfig = blockchainConfig
        self.address = address
        self.derivationPath = derivationPath
        self.privateKeyId = privateKeyId
        self.isEnabled = true
        self.tokens = []
        self.balance = 0.0
    }
}

struct WalletToken: Identifiable, Codable, Sendable {
    var id = UUID()
    let contractAddress: String?
    let name: String
    let symbol: String
    let decimals: Int
    let balance: Double
    let price: Double
    let logoUrl: String?
    let isNative: Bool
    let blockchainPlatform: BlockchainPlatform

    var totalValue: Double {
        balance * price
    }

    var displayBalance: String {
        String(format: "%.4f", balance)
    }

    var displayValue: String {
        "$" + String(format: "%.2f", totalValue)
    }
}

// MARK: - Derivation Path Constants

struct DerivationPaths {
    // BIP44 Standard paths
    static func ethereum(accountIndex: Int = 0) -> String {
        return "m/44'/60'/0'/0/\(accountIndex)"
    }

    static func bitcoin(accountIndex: Int = 0) -> String {
        return "m/84'/0'/0'/0/\(accountIndex)" // Native SegWit (Bech32)
    }

    static func solana(accountIndex: Int = 0) -> String {
        return "m/44'/501'/\(accountIndex)'/0'"
    }

    static func polygon(accountIndex: Int = 0) -> String {
        return "m/44'/60'/0'/0/\(accountIndex)" // Same as Ethereum
    }

    static func bsc(accountIndex: Int = 0) -> String {
        return "m/44'/60'/0'/0/\(accountIndex)" // Same as Ethereum
    }

    static func arbitrum(accountIndex: Int = 0) -> String {
        return "m/44'/60'/0'/0/\(accountIndex)" // Same as Ethereum
    }

    static func optimism(accountIndex: Int = 0) -> String {
        return "m/44'/60'/0'/0/\(accountIndex)" // Same as Ethereum
    }

    static func avalanche(accountIndex: Int = 0) -> String {
        return "m/44'/9000'/0'/0/\(accountIndex)"
    }

    static func base(accountIndex: Int = 0) -> String {
        return "m/44'/60'/0'/0/\(accountIndex)"
    }

    static func path(for platform: BlockchainPlatform, accountIndex: Int = 0) -> String {
        switch platform {
        case .ethereum:
            return ethereum(accountIndex: accountIndex)
        case .bitcoin:
            return bitcoin(accountIndex: accountIndex)
        case .solana:
            return solana(accountIndex: accountIndex)
        case .polygon:
            return polygon(accountIndex: accountIndex)
        case .bsc:
            return bsc(accountIndex: accountIndex)
        case .arbitrum:
            return arbitrum(accountIndex: accountIndex)
        case .optimism:
            return optimism(accountIndex: accountIndex)
        case .avalanche:
            return avalanche(accountIndex: accountIndex)
        case .base:
            return base(accountIndex: accountIndex)
        }
    }
}

// MARK: - Mock Data

extension MultiChainWallet {
    static let mockWallet = MultiChainWallet(
        name: "Main Wallet",
        type: .seed,
        seedPhraseId: "main-seed"
    )
}

extension WalletToken {
    static let mockTokens: [WalletToken] = [
        WalletToken(
            contractAddress: nil,
            name: "Ethereum",
            symbol: "ETH",
            decimals: 18,
            balance: 2.5431,
            price: 2650.75,
            logoUrl: nil,
            isNative: true,
            blockchainPlatform: .ethereum
        ),
        WalletToken(
            contractAddress: nil,
            name: "Bitcoin",
            symbol: "BTC",
            decimals: 8,
            balance: 0.08543,
            price: 67890.50,
            logoUrl: nil,
            isNative: true,
            blockchainPlatform: .bitcoin
        ),
        WalletToken(
            contractAddress: nil,
            name: "Solana",
            symbol: "SOL",
            decimals: 9,
            balance: 47.32,
            price: 140.25,
            logoUrl: nil,
            isNative: true,
            blockchainPlatform: .solana
        )
    ]
}
