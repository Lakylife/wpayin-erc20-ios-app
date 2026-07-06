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

    /// Address that receives the platform fee (EVM chains). An empty or
    /// invalid address disables fee collection entirely — fill in your
    /// treasury address to turn the fee on.
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

    /// Public P2P offer board (CloudKit). Requires a PAID Apple Developer
    /// Program membership — free personal teams don't support the iCloud
    /// capability at all. To enable:
    ///  1. join the Apple Developer Program,
    ///  2. in Xcode → Signing & Capabilities add iCloud → CloudKit with
    ///     container iCloud.io.noriskservis.standart.Wpayin-Wallet
    ///     (rename Wpayin_Wallet.entitlements.prepared to
    ///     Wpayin_Wallet.entitlements when enabling the capability),
    ///  3. flip this flag to true.
    /// Direct P2P trading via QR/share works regardless of this flag.
    static let p2pOfferBoardEnabled = false

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
