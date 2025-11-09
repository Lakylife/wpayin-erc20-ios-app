//
//  FiatRampService.swift
//  Wpayin_Wallet
//
//  Fiat Ramp aggregator service for buying crypto
//

import Foundation

// MARK: - Fiat Ramp Provider Types

enum FiatRampProvider: String, CaseIterable, Identifiable {
    case sardine = "Sardine"
    case unlimit = "Unlimit"
    case mercury = "Mercury"
    case moonpay = "MoonPay"
    case ramp = "Ramp"
    case coinbasePay = "Coinbase Pay"
    case transak = "Transak"
    case banxa = "Banxa"
    case binance = "Binance"
    case mtPelerin = "Mt Pelerin"
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
    
    var description: String {
        switch self {
        case .sardine:
            return "Fast ACH & Card payments"
        case .unlimit:
            return "Global payment solutions"
        case .mercury:
            return "Low fees, fast processing"
        case .moonpay:
            return "Popular worldwide provider"
        case .ramp:
            return "Quick card purchases"
        case .coinbasePay:
            return "Official Coinbase integration"
        case .transak:
            return "150+ countries supported"
        case .banxa:
            return "Credit/Debit card payments"
        case .binance:
            return "Direct from Binance exchange"
        case .mtPelerin:
            return "European bank transfers"
        }
    }
    
    var logoName: String {
        switch self {
        case .sardine: return "fish.fill"
        case .unlimit: return "infinity.circle.fill"
        case .mercury: return "bolt.circle.fill"
        case .moonpay: return "moon.circle.fill"
        case .ramp: return "arrow.up.circle.fill"
        case .coinbasePay: return "dollarsign.circle.fill"
        case .transak: return "globe.europe.africa.fill"
        case .banxa: return "creditcard.fill"
        case .binance: return "b.circle.fill"
        case .mtPelerin: return "building.columns.fill"
        }
    }
    
    var feeRange: String {
        switch self {
        case .sardine: return "1.5-2.5%"
        case .unlimit: return "2-3%"
        case .mercury: return "0.5-1.5%"
        case .moonpay: return "1-4.5%"
        case .ramp: return "0.5-2.9%"
        case .coinbasePay: return "2-3.5%"
        case .transak: return "0.99-5.5%"
        case .banxa: return "2-4%"
        case .binance: return "0-2%"
        case .mtPelerin: return "1-2%"
        }
    }
    
    var estimatedFee: Double {
        switch self {
        case .sardine: return 2.0
        case .unlimit: return 2.5
        case .mercury: return 1.0
        case .moonpay: return 2.75
        case .ramp: return 1.7
        case .coinbasePay: return 2.75
        case .transak: return 3.0
        case .banxa: return 3.0
        case .binance: return 1.0
        case .mtPelerin: return 1.5
        }
    }
    
    var supportedCryptos: [String] {
        switch self {
        case .moonpay:
            return ["BTC", "ETH", "USDT", "USDC", "BNB", "MATIC", "DAI", "AVAX", "SOL", "ADA", "DOT"]
        case .transak:
            return ["BTC", "ETH", "USDT", "USDC", "BNB", "MATIC", "DAI", "AVAX", "SOL"]
        case .ramp:
            return ["BTC", "ETH", "USDC", "MATIC", "DAI", "AVAX"]
        case .banxa:
            return ["BTC", "ETH", "USDT", "USDC", "BNB", "MATIC"]
        case .mtPelerin:
            return ["BTC", "ETH", "USDT", "USDC", "BNB", "MATIC"]
        // Ostatní nemají public widget API - vypnout pro teď
        case .sardine, .unlimit, .mercury, .coinbasePay, .binance:
            return [] // Není public widget
        }
    }
    
    var paymentMethods: [String] {
        switch self {
        case .sardine:
            return ["Card", "ACH", "Wire"]
        case .unlimit:
            return ["Card", "Bank Transfer", "Local Payment"]
        case .mercury:
            return ["Card", "ACH"]
        case .moonpay:
            return ["Card", "Apple Pay", "Google Pay", "Bank Transfer"]
        case .ramp:
            return ["Card", "Apple Pay", "Bank Transfer"]
        case .coinbasePay:
            return ["Coinbase Balance", "Bank", "Card"]
        case .transak:
            return ["Card", "Bank Transfer", "Apple Pay", "Google Pay"]
        case .banxa:
            return ["Card", "Bank Transfer"]
        case .binance:
            return ["Binance Balance", "Card", "Bank Transfer"]
        case .mtPelerin:
            return ["Bank Transfer", "SEPA"]
        }
    }
}

// MARK: - Fiat Ramp Configuration

enum FiatRampAction { case buy, sell }

struct FiatRampConfig {
    let provider: FiatRampProvider
    let crypto: String
    let walletAddress: String
    let fiatCurrency: String
    let network: String?
    let action: FiatRampAction
    
    init(
        provider: FiatRampProvider,
        crypto: String,
        walletAddress: String,
        fiatCurrency: String = "USD",
        network: String? = nil,
        action: FiatRampAction = .buy
    ) {
        self.provider = provider
        self.crypto = crypto
        self.walletAddress = walletAddress
        self.fiatCurrency = fiatCurrency
        self.network = network
        self.action = action
    }
}

// MARK: - Fiat Ramp Service

class FiatRampService {
    static let shared = FiatRampService()
    
    private init() {}
    
    // MARK: - API Keys (should be in Secrets.swift in production)
    
    private var sardineAPIKey: String {
        return "" // Add your Sardine API key
    }
    
    private var unlimitAPIKey: String {
        return "" // Add your Unlimit API key
    }
    
    private var mercuryAPIKey: String {
        return "" // Add your Mercury API key
    }
    
    private var moonpayAPIKey: String {
        return "" // MoonPay key removed - require production key
    }
    
    private var rampAPIKey: String {
        return "" // Add your Ramp API key
    }
    
    private var transakAPIKey: String {
        return "" // Add your Transak API key
    }
    
    private var banxaAPIKey: String {
        return "" // Add your Banxa API key
    }
    
    private var mtPelerinAPIKey: String {
        return "" // Add your Mt Pelerin API key
    }
    
    // MARK: - Generate Widget URLs
    
    func generateURL(for config: FiatRampConfig) -> URL? {
        switch config.provider {
        case .moonpay:
            return generateMoonPayURL(config: config)
        case .transak:
            return generateTransakURL(config: config)
        case .ramp:
            return generateRampURL(config: config)
        case .banxa:
            return generateBanxaURL(config: config)
        case .mtPelerin:
            return generateMtPelerinURL(config: config)
        // Providers without public widget
        case .sardine, .unlimit, .mercury, .coinbasePay, .binance:
            print("⚠️ \(config.provider.displayName) widget disabled/unsupported")
            return nil
        }
    }
    
    // MARK: - Provider-specific URL generation
    
    private func generateBanxaURL(config: FiatRampConfig) -> URL? {
        return nil // Requires API key
    }
    
    private func generateMtPelerinURL(config: FiatRampConfig) -> URL? {
        var components = URLComponents(string: "https://widget.mtpelerin.com")!
        
        var items: [URLQueryItem] = [
            URLQueryItem(name: "type", value: "direct-link"),
            URLQueryItem(name: "tabs", value: config.action == .sell ? "sell" : "buy"),
            URLQueryItem(name: "tab", value: config.action == .sell ? "sell" : "buy"),
            URLQueryItem(name: config.action == .sell ? "ssc" : "bdc", value: config.crypto),
            URLQueryItem(name: "addr", value: config.walletAddress),
            URLQueryItem(name: config.action == .sell ? "sdc" : "bsc", value: config.fiatCurrency),
            URLQueryItem(name: "lang", value: Locale.current.languageCode ?? "en")
        ]
        if let net = config.network { items.append(URLQueryItem(name: "net", value: net)) }
        components.queryItems = items
        return components.url
    }
    
    private func generateSardineURL(config: FiatRampConfig) -> URL? {
        var components = URLComponents(string: "https://checkout.sardine.ai")!
        
        components.queryItems = [
            URLQueryItem(name: "currency", value: config.crypto),
            URLQueryItem(name: "address", value: config.walletAddress),
            URLQueryItem(name: "fiat", value: config.fiatCurrency)
        ]
        
        return components.url
    }
    
    private func generateUnlimitURL(config: FiatRampConfig) -> URL? {
        var components = URLComponents(string: "https://buy.unlimit.com")!
        
        components.queryItems = [
            URLQueryItem(name: "crypto", value: config.crypto),
            URLQueryItem(name: "wallet", value: config.walletAddress),
            URLQueryItem(name: "fiat", value: config.fiatCurrency)
        ]
        
        return components.url
    }
    
    private func generateMercuryURL(config: FiatRampConfig) -> URL? {
        var components = URLComponents(string: "https://pay.mercury.com")!
        
        components.queryItems = [
            URLQueryItem(name: "asset", value: config.crypto),
            URLQueryItem(name: "destination", value: config.walletAddress),
            URLQueryItem(name: "currency", value: config.fiatCurrency)
        ]
        
        return components.url
    }
    
    private func generateMoonPayURL(config: FiatRampConfig) -> URL? {
        return nil // Requires API key
    }
    
    private func generateRampURL(config: FiatRampConfig) -> URL? {
        return nil // Requires API key
    }
    
    private func generateCoinbasePayURL(config: FiatRampConfig) -> URL? {
        // Coinbase Pay uses their hosted URL
        var components = URLComponents(string: "https://pay.coinbase.com/buy")!
        
        components.queryItems = [
            URLQueryItem(name: "appId", value: "wpayin_wallet"),
            URLQueryItem(name: "type", value: "buy"),
            URLQueryItem(name: "asset", value: config.crypto),
            URLQueryItem(name: "address", value: config.walletAddress)
        ]
        
        return components.url
    }
    
    private func generateTransakURL(config: FiatRampConfig) -> URL? {
        return nil // Requires API key
    }
    
    private func generateBinanceURL(config: FiatRampConfig) -> URL? {
        // Binance uses their fiat gateway
        var components = URLComponents(string: "https://www.binance.com/en/crypto/buy")!
        
        components.queryItems = [
            URLQueryItem(name: "crypto", value: config.crypto),
            URLQueryItem(name: "fiat", value: config.fiatCurrency),
            URLQueryItem(name: "amount", value: "100")
        ]
        
        return components.url
    }
    
    // MARK: - Helper Methods
    
    func isCryptoSupported(_ crypto: String, by provider: FiatRampProvider) -> Bool {
        return provider.supportedCryptos.contains(crypto.uppercased())
    }
    
    private func isProviderConfigured(_ provider: FiatRampProvider) -> Bool {
        switch provider {
        case .mtPelerin: return true
        case .moonpay, .transak, .ramp, .banxa:
            return false // Require API keys - disabled for now
        default: return false
        }
    }
    
    func availableProviders(for crypto: String) -> [FiatRampProvider] {
        FiatRampProvider.allCases.filter { isCryptoSupported(crypto, by: $0) && isProviderConfigured($0) }
    }
    
    func recommendedProvider(for crypto: String) -> FiatRampProvider {
        // Choose first configured provider supporting the crypto
        return availableProviders(for: crypto).first ?? .mtPelerin
    }
}
