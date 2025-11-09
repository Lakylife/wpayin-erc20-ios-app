//
//  PriceOracleService.swift
//  Wpayin_Wallet
//
//  Real-time crypto price oracle using CoinGecko API
//

import Foundation

class PriceOracleService {
    static let shared = PriceOracleService()
    
    private init() {}
    
    private let baseURL = "https://api.coingecko.com/api/v3"
    private var priceCache: [String: (price: Double, timestamp: Date)] = [:]
    private let cacheExpiry: TimeInterval = 60 // 1 minute
    
    // MARK: - Get Price
    
    func getPrice(crypto: String, fiat: String = "usd") async throws -> Double {
        let cacheKey = "\(crypto.lowercased())_\(fiat.lowercased())"
        
        // Check cache
        if let cached = priceCache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < cacheExpiry {
            print("💰 Price cache hit for \(crypto): $\(cached.price)")
            return cached.price
        }
        
        // Fetch from API
        let coinId = mapToCoinGeckoID(crypto: crypto)
        let url = URL(string: "\(baseURL)/simple/price?ids=\(coinId)&vs_currencies=\(fiat)")!
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode([String: [String: Double]].self, from: data)
        
        guard let price = response[coinId]?[fiat.lowercased()] else {
            throw PriceOracleError.priceNotFound
        }
        
        // Cache it
        priceCache[cacheKey] = (price, Date())
        print("💰 Fetched price for \(crypto): $\(price)")
        
        return price
    }
    
    // MARK: - Convert Crypto
    
    func convertCrypto(from: String, to: String, amount: Double) async throws -> Double {
        let fromPrice = try await getPrice(crypto: from, fiat: "usd")
        let toPrice = try await getPrice(crypto: to, fiat: "usd")
        
        let usdValue = amount * fromPrice
        let toAmount = usdValue / toPrice
        
        print("🔄 Convert: \(amount) \(from) = \(toAmount) \(to) (via $\(usdValue) USD)")
        
        return toAmount
    }
    
    // MARK: - Batch Price Fetch
    
    func getPrices(cryptos: [String], fiat: String = "usd") async throws -> [String: Double] {
        let coinIds = cryptos.map { mapToCoinGeckoID(crypto: $0) }.joined(separator: ",")
        let url = URL(string: "\(baseURL)/simple/price?ids=\(coinIds)&vs_currencies=\(fiat)")!
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode([String: [String: Double]].self, from: data)
        
        var prices: [String: Double] = [:]
        for crypto in cryptos {
            let coinId = mapToCoinGeckoID(crypto: crypto)
            if let price = response[coinId]?[fiat.lowercased()] {
                prices[crypto] = price
                priceCache["\(crypto.lowercased())_\(fiat.lowercased())"] = (price, Date())
            }
        }
        
        print("💰 Fetched batch prices: \(prices)")
        return prices
    }
    
    // MARK: - Helper: Map Symbol to CoinGecko ID
    
    private func mapToCoinGeckoID(crypto: String) -> String {
        let symbol = crypto.uppercased()
        
        switch symbol {
        case "BTC":
            return "bitcoin"
        case "ETH":
            return "ethereum"
        case "USDT":
            return "tether"
        case "USDC":
            return "usd-coin"
        case "BNB":
            return "binancecoin"
        case "MATIC":
            return "matic-network"
        case "DAI":
            return "dai"
        case "AVAX":
            return "avalanche-2"
        case "SOL":
            return "solana"
        case "ADA":
            return "cardano"
        case "DOT":
            return "polkadot"
        case "LINK":
            return "chainlink"
        case "UNI":
            return "uniswap"
        case "AAVE":
            return "aave"
        case "SHIB":
            return "shiba-inu"
        case "DOGE":
            return "dogecoin"
        case "LTC":
            return "litecoin"
        case "XRP":
            return "ripple"
        default:
            return symbol.lowercased()
        }
    }
    
    // MARK: - Clear Cache
    
    func clearCache() {
        priceCache.removeAll()
        print("🗑️ Price cache cleared")
    }
}

// MARK: - Errors

enum PriceOracleError: Error {
    case priceNotFound
    case invalidResponse
    case networkError
    
    var localizedDescription: String {
        switch self {
        case .priceNotFound:
            return "Price not found for this cryptocurrency"
        case .invalidResponse:
            return "Invalid response from price API"
        case .networkError:
            return "Network error while fetching price"
        }
    }
}
