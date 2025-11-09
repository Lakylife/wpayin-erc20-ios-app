//
//  Token.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import Foundation
import WalletCore

// MARK: - Token Protocol
enum TokenProtocol: String, Codable, Sendable {
    case native = "Native"         // Native blockchain token (ETH, BTC, etc.)
    case erc20 = "ERC20"          // Ethereum ERC-20
    case bep20 = "BEP20"          // Binance Smart Chain BEP-20
    case trc20 = "TRC20"          // Tron TRC-20
    case bep2 = "BEP2"            // Binance Chain BEP-2
    case spl = "SPL"              // Solana SPL
    case bip84 = "BIP84"          // Bitcoin Native SegWit
    case bip49 = "BIP49"          // Bitcoin SegWit wrapped
    case bip44 = "BIP44"          // Bitcoin Legacy
    
    var displayName: String {
        rawValue
    }
    
    var shortName: String {
        switch self {
        case .native: return ""
        case .erc20: return "ERC20"
        case .bep20: return "BEP20"
        case .trc20: return "TRC20"
        case .bep2: return "BEP2"
        case .spl: return "SPL"
        case .bip84: return "SegWit"
        case .bip49: return "P2SH"
        case .bip44: return "Legacy"
        }
    }
}

enum BlockchainType: String, CaseIterable, Codable, Sendable {
    case ethereum = "ethereum"
    case bitcoin = "bitcoin"
    case litecoin = "litecoin"
    case bitcoinCash = "bitcoin-cash"
    case eCash = "ecash"
    case dash = "dash"
    case zcash = "zcash"
    case monero = "monero"
    case solana = "solana"
    case polygon = "polygon"
    case bsc = "binance-smart-chain"
    case arbitrum = "arbitrum"
    case optimism = "optimism"
    case avalanche = "avalanche"
    case base = "base"
    case gnosis = "gnosis"
    case zkSync = "zksync"
    case fantom = "fantom"

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
            return "Binance Smart Chain"
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

    var nativeToken: String {
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

    var addressFormat: String {
        switch self {
        case .ethereum, .polygon, .bsc, .arbitrum, .optimism, .avalanche, .base, .gnosis, .zkSync, .fantom:
            return "0x"
        case .bitcoin:
            return "bc1" // Bech32 (BIP84)
        case .litecoin:
            return "ltc1" // Bech32
        case .bitcoinCash:
            return "bitcoincash:"
        case .eCash:
            return "ecash:"
        case .dash:
            return "X"
        case .zcash:
            return "t1" // transparent
        case .monero:
            return "4" // mainnet
        case .solana:
            return "base58"
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
        case .litecoin:
            return "litecoin"
        case .bitcoinCash:
            return "bitcoin-cash"
        case .eCash:
            return "ecash"
        case .dash:
            return "dash"
        case .zcash:
            return "zcash"
        case .monero:
            return "monero"
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
        case .gnosis:
            return "gnosis"
        case .zkSync:
            return "zksync"
        case .fantom:
            return "fantom"
        }
    }

    var isEVM: Bool {
        switch self {
        case .ethereum, .polygon, .bsc, .arbitrum, .optimism, .avalanche, .base, .gnosis, .zkSync, .fantom:
            return true
        case .bitcoin, .litecoin, .bitcoinCash, .eCash, .dash, .zcash, .monero, .solana:
            return false
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
            return nil  // Monero not supported by WalletCore
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
        case .gnosis:
            return .xdai
        case .zkSync:
            return .ethereum // zkSync uses Ethereum coin type
        case .fantom:
            return .fantom
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
    let tokenProtocol: TokenProtocol?  // ERC20, BEP20, BIP84, etc.

    var totalValue: Double {
        balance * price
    }

    var displayAddress: String {
        contractAddress ?? blockchain.nativeToken
    }
    
    // Display name with protocol badge
    var displayNameWithProtocol: String {
        if let proto = tokenProtocol, !proto.shortName.isEmpty {
            return "\(symbol) (\(proto.shortName))"
        }
        return symbol
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
        receivingAddress: String? = nil,
        tokenProtocol: TokenProtocol? = nil
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
        self.tokenProtocol = tokenProtocol ?? Token.deriveProtocol(blockchain: blockchain, isNative: isNative)
    }
    
    // Auto-derive protocol based on blockchain and token type
    private static func deriveProtocol(blockchain: BlockchainType, isNative: Bool) -> TokenProtocol {
        if isNative {
            switch blockchain {
            case .bitcoin:
                return .bip84  // Native SegWit
            case .litecoin, .bitcoinCash, .eCash, .dash, .zcash, .monero:
                return .native
            case .ethereum, .polygon, .bsc, .arbitrum, .optimism, .avalanche, .base, .gnosis, .zkSync, .fantom:
                return .native
            case .solana:
                return .native
            }
        } else {
            // Token (not native)
            switch blockchain {
            case .ethereum, .polygon, .arbitrum, .optimism, .avalanche, .base, .gnosis, .zkSync, .fantom:
                return .erc20
            case .bsc:
                return .bep20
            case .solana:
                return .spl
            default:
                return .native
            }
        }
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
        case tokenProtocol
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
        tokenProtocol = try container.decodeIfPresent(TokenProtocol.self, forKey: .tokenProtocol) 
            ?? Token.deriveProtocol(blockchain: blockchain, isNative: isNative)
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
        try container.encodeIfPresent(tokenProtocol, forKey: .tokenProtocol)
    }
}

extension BlockchainType {
    init?(platform: BlockchainPlatform) {
        switch platform {
        case .ethereum:
            self = .ethereum
        case .bitcoin:
            self = .bitcoin
        case .litecoin:
            self = .litecoin
        case .bitcoinCash:
            self = .bitcoinCash
        case .eCash:
            self = .eCash
        case .dash:
            self = .dash
        case .zcash:
            self = .zcash
        case .monero:
            self = .monero
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
        case .gnosis:
            self = .gnosis
        case .zkSync:
            self = .zkSync
        case .fantom:
            self = .fantom
        }
    }
}
