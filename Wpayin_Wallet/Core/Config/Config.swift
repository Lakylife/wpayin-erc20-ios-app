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

    // 2026-07: cloudflare-eth.com intermittently rejects requests — PublicNode is reliable
    static let ethereumRpcUrl = "https://ethereum-rpc.publicnode.com"
    static let bitcoinRpcUrl = "https://blockstream.info/api"

    // MARK: - Platform Fee

    /// Treasury address must be configured by the release environment. Never
    /// fall back to a user/test wallet: that silently charges a second gas fee
    /// while sending the platform fee back to the sender.
    static let platformFeeRecipient = environment["PLATFORM_FEE_RECIPIENT"]?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    /// Platform fee in basis points (25 = 0.25 %) charged on top of sends,
    /// P2P trades and other outgoing transactions.
    static let platformFeeBps = 25

    static var platformFeeEnabled: Bool {
        platformFeeRecipient.hasPrefix("0x") && platformFeeRecipient.count == 42 && platformFeeBps > 0
    }

    /// Fee as a fraction (25 bps → 0.0025).
    static var platformFeeRate: Decimal {
        Decimal(platformFeeBps) / 10_000
    }

    // MARK: - Feature Flags

    /// Enable or disable NFT functionality
    static let nftEnabled = true

    /// Enable or disable DeFi features
    static let defiEnabled = true

    /// Enable or disable swap functionality
    static let swapEnabled = true

    /// Optional public P2P board. Values are supplied by the local/release
    /// environment and are intentionally never committed to this repository.
    static let p2pBoardURL = environment["P2P_BOARD_URL"]?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    static let p2pBoardAnonKey = environment["P2P_BOARD_ANON_KEY"]?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    /// Public P2P offer board is available once the Supabase project is set.
    /// Private QR/code trading remains available either way.
    static var p2pOfferBoardEnabled: Bool {
        !p2pBoardURL.isEmpty && !p2pBoardAnonKey.isEmpty
    }

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
