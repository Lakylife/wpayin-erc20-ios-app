//
//  Token.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import Foundation
import WalletCore

enum BlockchainType: String, CaseIterable, Codable, Sendable {
    case ethereum = "ethereum"
    case bitcoin = "bitcoin"
    case solana = "solana"
    case polygon = "polygon"
    case bsc = "binance-smart-chain"
    case arbitrum = "arbitrum"
    case optimism = "optimism"
    case avalanche = "avalanche"
    case base = "base"

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
            return "Binance Smart Chain"
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

    var nativeToken: String {
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

    var addressFormat: String {
        switch self {
        case .ethereum, .polygon, .bsc:
            return "0x"
        case .bitcoin:
            return "bc1" // Bech32 or "1", "3" for legacy
        case .solana:
            return "base58"
        case .arbitrum, .optimism, .avalanche:
            return "0x"
        case .base:
            return "0x"
        }
    }

    var nativeDecimals: Int {
        switch self {
        case .bitcoin:
            return 8
        case .solana:
            return 9
        case .avalanche:
            return 18
        case .base:
            return 18
        default:
            return 18
        }
    }

    var coingeckoId: String? {
        switch self {
        case .ethereum:
            return "ethereum"
        case .bitcoin:
            return "bitcoin"
        case .solana:
            return "solana"
        case .polygon:
            return "matic-network"
        case .bsc:
            return "binancecoin"
        case .arbitrum:
            return "arbitrum"
        case .optimism:
            return "optimism"
        case .avalanche:
            return "avalanche-2"
        case .base:
            return "base"
        }
    }

    var isEVM: Bool {
        switch self {
        case .ethereum, .polygon, .bsc, .arbitrum, .optimism, .avalanche, .base:
            return true
        case .bitcoin, .solana:
            return false
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
            return .ethereum // Base uses Ethereum coin type
        }
    }
}

struct Token: Identifiable, Codable, Sendable {
    let id: UUID
    let contractAddress: String?  // nil for native tokens
    let name: String
    let symbol: String
    let decimals: Int
    let balance: Double
    let price: Double
    let iconUrl: String?
    let blockchain: BlockchainType
    let isNative: Bool  // true for ETH, BTC, SOL, etc.
    let receivingAddress: String?

    var totalValue: Double {
        balance * price
    }

    var displayAddress: String {
        contractAddress ?? blockchain.nativeToken
    }

    init(
        contractAddress: String?,
        name: String,
        symbol: String,
        decimals: Int,
        balance: Double,
        price: Double,
        iconUrl: String?,
        blockchain: BlockchainType,
        isNative: Bool,
        id: UUID = UUID(),
        receivingAddress: String? = nil
    ) {
        self.id = id
        self.contractAddress = contractAddress
        self.name = name
        self.symbol = symbol
        self.decimals = decimals
        self.balance = balance
        self.price = price
        self.iconUrl = iconUrl
        self.blockchain = blockchain
        self.isNative = isNative
        self.receivingAddress = receivingAddress
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case contractAddress
        case name
        case symbol
        case decimals
        case balance
        case price
        case iconUrl
        case blockchain
        case isNative
        case receivingAddress
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        contractAddress = try container.decodeIfPresent(String.self, forKey: .contractAddress)
        name = try container.decode(String.self, forKey: .name)
        symbol = try container.decode(String.self, forKey: .symbol)
        decimals = try container.decode(Int.self, forKey: .decimals)
        balance = try container.decode(Double.self, forKey: .balance)
        price = try container.decode(Double.self, forKey: .price)
        iconUrl = try container.decodeIfPresent(String.self, forKey: .iconUrl)
        blockchain = try container.decode(BlockchainType.self, forKey: .blockchain)
        isNative = try container.decode(Bool.self, forKey: .isNative)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        receivingAddress = try container.decodeIfPresent(String.self, forKey: .receivingAddress)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(contractAddress, forKey: .contractAddress)
        try container.encode(name, forKey: .name)
        try container.encode(symbol, forKey: .symbol)
        try container.encode(decimals, forKey: .decimals)
        try container.encode(balance, forKey: .balance)
        try container.encode(price, forKey: .price)
        try container.encodeIfPresent(iconUrl, forKey: .iconUrl)
        try container.encode(blockchain, forKey: .blockchain)
        try container.encode(isNative, forKey: .isNative)
        try container.encodeIfPresent(receivingAddress, forKey: .receivingAddress)
    }

    static let mockTokens: [Token] = [
        // Ethereum Network
        Token(
            contractAddress: nil,
            name: "Ethereum",
            symbol: "ETH",
            decimals: 18,
            balance: 1.2345,
            price: 2650.50,
            iconUrl: "ethereum",
            blockchain: .ethereum,
            isNative: true,
            receivingAddress: "0x742d35Cc6D06b73494d45e5d2b0542f2f" // sample
        ),
        Token(
            contractAddress: "0xdAC17F958D2ee523a2206206994597C13D831ec7",
            name: "Tether USD",
            symbol: "USDT",
            decimals: 6,
            balance: 1000.0,
            price: 1.0,
            iconUrl: "tether",
            blockchain: .ethereum,
            isNative: false,
            receivingAddress: "0x742d35Cc6D06b73494d45e5d2b0542f2f"
        ),
        Token(
            contractAddress: "0xA0b86a33E6441b8C50b5d9d6fF34D4A6AF9eb9b8",
            name: "USD Coin",
            symbol: "USDC",
            decimals: 6,
            balance: 500.0,
            price: 1.0,
            iconUrl: "usdc",
            blockchain: .ethereum,
            isNative: false,
            receivingAddress: "0x742d35Cc6D06b73494d45e5d2b0542f2f"
        ),

        // Bitcoin Network
        Token(
            contractAddress: nil,
            name: "Bitcoin",
            symbol: "BTC",
            decimals: 8,
            balance: 0.05678,
            price: 67850.0,
            iconUrl: "bitcoin",
            blockchain: .bitcoin,
            isNative: true,
            receivingAddress: "bc1qw4us8r9ltnf708qj8r2h3x5y2p5r7z9k4f03c3"
        ),

        // Solana Network
        Token(
            contractAddress: nil,
            name: "Solana",
            symbol: "SOL",
            decimals: 9,
            balance: 25.67,
            price: 140.25,
            iconUrl: "solana",
            blockchain: .solana,
            isNative: true
        ),

        // Polygon Network
        Token(
            contractAddress: nil,
            name: "Polygon",
            symbol: "MATIC",
            decimals: 18,
            balance: 350.0,
            price: 0.95,
            iconUrl: "polygon",
            blockchain: .polygon,
            isNative: true
        ),

        // Binance Smart Chain
        Token(
            contractAddress: nil,
            name: "BNB",
            symbol: "BNB",
            decimals: 18,
            balance: 2.45,
            price: 635.0,
            iconUrl: "binancecoin",
            blockchain: .bsc,
            isNative: true
        )
    ]
}

extension BlockchainType {
    init?(platform: BlockchainPlatform) {
        switch platform {
        case .ethereum:
            self = .ethereum
        case .bitcoin:
            self = .bitcoin
        case .solana:
            self = .solana
        case .polygon:
            self = .polygon
        case .bsc:
            self = .bsc
        case .arbitrum:
            self = .arbitrum
        case .optimism:
            self = .optimism
        case .avalanche:
            self = .avalanche
        case .base:
            self = .base
        }
    }
}
