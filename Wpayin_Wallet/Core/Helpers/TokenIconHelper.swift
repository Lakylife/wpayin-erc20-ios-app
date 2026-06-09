// Autor Lukas Helebrandt, 2026

//
//  TokenIconHelper.swift
//  Wpayin_Wallet
//
//  Helper for mapping tokens to their icon asset names
//

import Foundation
import SwiftUI

struct TokenIconHelper {
    /// Get local asset name for well-known tokens
    /// Returns nil if no local asset exists (will fall back to iconUrl or blockchain icon)
    static func localIconName(symbol: String, blockchain: BlockchainType) -> String? {
        let key = "\(symbol)_\(blockchain.rawValue)".lowercased()
        
        // Map of well-known tokens to their asset names
        let iconMap: [String: String] = [
            // Bitcoin
            "btc_bitcoin": "BTC",
            "bitcoin_bitcoin": "BTC",
            
            // Ethereum mainnet
            "eth_ethereum": "ETH",
            "weth_ethereum": "ETH",
            
            // Polygon
            "matic_polygon": "polygon-pos_eip20_32",
            "weth_polygon": "ETH",
            "eth_polygon": "ethereum_eip20_32",
            
            // BSC
            "bnb_binance-smart-chain": "BNB",
            "wbnb_binance-smart-chain": "binance-smart-chain_eip20_32",
            "eth_binance-smart-chain": "ethereum_eip20_32",
            
            // Arbitrum
            "eth_arbitrum": "arbitrum-one_trx_32",
            "weth_arbitrum": "ETH",
            
            // Optimism
            "eth_optimism": "optimistic-ethereum_trx_32",
            "weth_optimism": "ETH",
            
            // Avalanche
            "avax_avalanche": "avalanche_trx_32",
            "wavax_avalanche": "avalanche_eip20_32",
            "eth_avalanche": "ethereum_eip20_32",
            
            // Base
            "eth_base": "base_trx_32",
            "weth_base": "ETH",
            
            // Solana has no bundled raster asset yet; use placeholder fallback.
        ]
        
        return iconMap[key]
    }
    
    /// Get fallback icon name based on token symbol only (less specific)
    static func fallbackIconName(symbol: String) -> String? {
        let key = symbol.uppercased()
        
        let fallbackMap: [String: String] = [
            "BTC": "BTC",
            "ETH": "ETH",
            "WETH": "ETH",
            "BNB": "BNB",
            "WBNB": "binance-smart-chain_eip20_32",
            "MATIC": "polygon-pos_eip20_32",
            "AVAX": "avalanche_trx_32",
            "WAVAX": "avalanche_eip20_32",
        ]
        
        return fallbackMap[key]
    }
    
    /// Get the best icon name for a token
    /// For most tokens, icon is based on symbol only (USDT is USDT on any chain)
    /// For native blockchain tokens, we use blockchain-specific icons
    static func iconName(symbol: String, blockchain: BlockchainType) -> String? {
        // For native tokens, try blockchain-specific icon first
        if isNativeToken(symbol: symbol, blockchain: blockchain) {
            if let specific = localIconName(symbol: symbol, blockchain: blockchain) {
                return specific
            }
        }
        
        // For all tokens, try symbol-only mapping
        return fallbackIconName(symbol: symbol)
    }
    
    /// Check if token is a native blockchain token
    private static func isNativeToken(symbol: String, blockchain: BlockchainType) -> Bool {
        let sym = symbol.uppercased()
        switch blockchain {
        case .ethereum: return sym == "ETH"
        case .bitcoin: return sym == "BTC"
        case .polygon: return sym == "MATIC"
        case .bsc: return sym == "BNB"
        case .arbitrum: return sym == "ETH"
        case .optimism: return sym == "ETH"
        case .avalanche: return sym == "AVAX"
        case .base: return sym == "ETH"
        case .solana: return sym == "SOL"
        default: return false
        }
    }
    
    /// Get color for token based on symbol (for placeholder icons)
    static func tokenColor(symbol: String) -> Color {
        switch symbol.uppercased() {
        case "USDT":
            return Color(red: 0.20, green: 0.63, blue: 0.54) // Tether green
        case "USDC":
            return Color(red: 0.16, green: 0.52, blue: 0.95) // Circle blue
        case "DAI":
            return Color(red: 0.96, green: 0.68, blue: 0.20) // MakerDAO yellow/gold
        case "BUSD":
            return Color(red: 0.95, green: 0.77, blue: 0.19) // Binance yellow
        case "WETH":
            return Color(red: 0.39, green: 0.47, blue: 1.0) // WETH blue
        case "SOL":
            return Color(red: 0.66, green: 0.36, blue: 1.0) // Solana purple
        default:
            return Color.gray
        }
    }
    
    /// Get symbol letter/text for placeholder icon
    static func symbolLetter(symbol: String) -> String {
        let clean = symbol.uppercased()
        
        // Special multi-char symbols for well-known tokens
        switch clean {
        case "USDT":
            return "₮"  // Tether symbol
        case "USDC":
            return "C"  // Circle/USD Coin
        case "DAI":
            return "DAI"
        case "WETH":
            return "Ξ"  // Ethereum symbol (wrapped)
        case "SOL":
            return "S"
        default:
            if clean.count >= 1 {
                return String(clean.prefix(1))
            }
            return "?"
        }
    }

    static func formattedBalance(_ balance: Double, decimals: Int = 2) -> String {
        String(format: "%.\(decimals)f", balance)
    }

    static func formattedBalanceWithSymbol(_ balance: Double, symbol: String, decimals: Int = 2) -> String {
        "\(formattedBalance(balance, decimals: decimals)) \(symbol)"
    }
}
