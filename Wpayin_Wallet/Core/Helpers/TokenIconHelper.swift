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
            "btc_bitcoin": "bitcoin",
            "bitcoin_bitcoin": "bitcoin",
            
            // Ethereum mainnet
            "eth_ethereum": "ethereum_trx_32",
            "weth_ethereum": "ethereum_eip20_32",
            
            // Polygon
            "matic_polygon": "polygon-pos_trx_32",
            "weth_polygon": "ethereum_eip20_32",
            "eth_polygon": "ethereum_eip20_32",
            
            // BSC
            "bnb_binance-smart-chain": "binance-smart-chain_trx_32",
            "wbnb_binance-smart-chain": "binance-smart-chain_eip20_32",
            "eth_binance-smart-chain": "ethereum_eip20_32",
            
            // Arbitrum
            "eth_arbitrum": "arbitrum-one_trx_32",
            "weth_arbitrum": "ethereum_eip20_32",
            
            // Optimism
            "eth_optimism": "optimistic-ethereum_trx_32",
            "weth_optimism": "ethereum_eip20_32",
            
            // Avalanche
            "avax_avalanche": "avalanche_trx_32",
            "wavax_avalanche": "avalanche_eip20_32",
            "eth_avalanche": "ethereum_eip20_32",
            
            // Base
            "eth_base": "base_trx_32",
            "weth_base": "ethereum_eip20_32",
            
            // Solana
            "sol_solana": "solana_trx_32",
        ]
        
        return iconMap[key]
    }
    
    /// Get fallback icon name based on token symbol only (less specific)
    static func fallbackIconName(symbol: String) -> String? {
        let key = symbol.uppercased()
        
        let fallbackMap: [String: String] = [
            "BTC": "bitcoin",
            "ETH": "ethereum_trx_32",
            "WETH": "ethereum_eip20_32",
            "BNB": "binance-smart-chain_trx_32",
            "WBNB": "binance-smart-chain_eip20_32",
            "MATIC": "polygon-pos_trx_32",
            "AVAX": "avalanche_trx_32",
            "WAVAX": "avalanche_eip20_32",
            "SOL": "solana_trx_32",
            "USDT": "ethereum_eip20_32",  // Generic ERC20 icon for USDT
            "USDC": "ethereum_eip20_32",  // Generic ERC20 icon for USDC
            "DAI": "ethereum_eip20_32",   // Generic ERC20 icon for DAI
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
        default:
            if clean.count >= 1 {
                return String(clean.prefix(1))
            }
            return "?"
        }
    }
}
