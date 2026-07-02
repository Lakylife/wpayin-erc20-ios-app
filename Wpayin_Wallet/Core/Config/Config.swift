// Autor Lukas Helebrandt, 2026
//
//  Config.swift
//  Wpayin_Wallet
//
//  Public application configuration
//

import Foundation

/// Public defaults required to build and run the app.
///
/// Optional third-party API keys can be supplied through the Xcode scheme's
/// environment variables. No key or secret is stored in the repository.
struct AppConfig {

    private static let environment = ProcessInfo.processInfo.environment

    // MARK: - Optional API Keys

    static let alchemyApiKey = environment["ALCHEMY_API_KEY"]?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    static let etherscanApiKey = environment["ETHERSCAN_API_KEY"]?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    static let coinGeckoApiKey = environment["COINGECKO_API_KEY"]?
        .trimmingCharacters(in: .whitespacesAndNewlines)

    // MARK: - RPC Endpoints

    static let ethereumRpcUrl = "https://cloudflare-eth.com"
    static let bitcoinRpcUrl = "https://blockstream.info/api"

    // MARK: - Feature Flags

    /// Enable or disable NFT functionality
    static let nftEnabled = true

    /// Enable or disable DeFi features
    static let defiEnabled = true

    /// Enable or disable swap functionality
    static let swapEnabled = true

    // MARK: - Validation

    /// Optional integrations are fully configured when both provider keys exist.
    static var isConfigured: Bool {
        !alchemyApiKey.isEmpty && !etherscanApiKey.isEmpty
    }

    static var configurationMessage: String {
        if isConfigured {
            return "✅ All API keys configured"
        }

        var missing: [String] = []
        if alchemyApiKey.isEmpty { missing.append("Alchemy API Key") }
        if etherscanApiKey.isEmpty { missing.append("Etherscan API Key") }
        return "Optional integrations unavailable: \(missing.joined(separator: ", "))"
    }
}
