// Autor Lukas Helebrandt, 2026
//
//  Config.swift
//  Wpayin_Wallet
//
//  Configuration for API keys and sensitive data
//

import Foundation

/// Application configuration containing API keys and endpoints
struct AppConfig {

    // MARK: - API Keys

    /// Alchemy API key for NFT and blockchain data
    static let alchemyApiKey = "YOUR_ALCHEMY_API_KEY_HERE"

    /// Etherscan API key for transaction history and blockchain data
    static let etherscanApiKey = "YOUR_ETHERSCAN_API_KEY_HERE"

    /// CoinGecko API key (optional - free tier works without key)
    static let coinGeckoApiKey: String? = nil

    // MARK: - RPC Endpoints

    /// Default Ethereum RPC endpoint
    static let ethereumRpcUrl = "https://cloudflare-eth.com"

    /// Default Bitcoin RPC endpoint
    static let bitcoinRpcUrl = "https://blockstream.info/api"

    // MARK: - Feature Flags

    /// Enable or disable NFT functionality
    static let nftEnabled = true

    /// Enable or disable DeFi features
    static let defiEnabled = true

    /// Enable or disable swap functionality
    static let swapEnabled = true

    // MARK: - Validation

    /// Check if all required API keys are configured
    static var isConfigured: Bool {
        return !alchemyApiKey.contains("YOUR_") &&
               !etherscanApiKey.contains("YOUR_")
    }

    /// Get configuration status message
    static var configurationMessage: String {
        if isConfigured {
            return "✅ All API keys configured"
        } else {
            var missing: [String] = []
            if alchemyApiKey.contains("YOUR_") {
                missing.append("Alchemy API Key")
            }
            if etherscanApiKey.contains("YOUR_") {
                missing.append("Etherscan API Key")
            }
            return "⚠️ Missing: \(missing.joined(separator: ", "))"
        }
    }
}
