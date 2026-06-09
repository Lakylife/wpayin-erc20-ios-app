// Autor Lukas Helebrandt, 2026

//
//  CurrencyFormatter.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import Foundation

final class CurrencyConversionService {
    static let shared = CurrencyConversionService()

    private let userDefaults = UserDefaults.standard
    private let fallbackRates: [Currency: Double] = [
        .usd: 1.0,
        .eur: 0.92,
        .gbp: 0.78,
        .jpy: 157.0,
        .cny: 7.25,
        .krw: 1380.0,
        .czk: 23.0
    ]

    private init() {
        seedFallbackRatesIfNeeded()
    }

    func seedFallbackRatesIfNeeded() {
        for (currency, rate) in fallbackRates where userDefaults.object(forKey: rateKey(for: currency)) == nil {
            userDefaults.set(rate, forKey: rateKey(for: currency))
        }
    }

    func convertUSD(_ amount: Double, to currency: Currency) -> Double {
        amount * rate(for: currency)
    }

    func rate(for currency: Currency) -> Double {
        if currency == .usd { return 1.0 }

        let cachedRate = userDefaults.double(forKey: rateKey(for: currency))
        if cachedRate > 0 {
            return cachedRate
        }

        return fallbackRates[currency] ?? 1.0
    }

    func refreshRates() async {
        let currencies = Currency.allCases
            .filter { $0 != .usd }
            .map { $0.rawValue.lowercased() }
            .joined(separator: ",")

        guard let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=usd-coin&vs_currencies=\(currencies)") else {
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return
            }

            let decoded = try JSONDecoder().decode([String: [String: Double]].self, from: data)
            guard let rates = decoded["usd-coin"] else { return }

            userDefaults.set(1.0, forKey: rateKey(for: .usd))
            for currency in Currency.allCases where currency != .usd {
                if let rate = rates[currency.rawValue.lowercased()], rate > 0 {
                    userDefaults.set(rate, forKey: rateKey(for: currency))
                }
            }
            userDefaults.set(Date().timeIntervalSince1970, forKey: "FiatRatesUpdatedAt")
        } catch {
            Logger.log("⚠️ Failed to refresh fiat conversion rates: \(error.localizedDescription)")
        }
    }

    private func rateKey(for currency: Currency) -> String {
        "FiatRate_USD_\(currency.rawValue)"
    }
}

extension Double {
    func formatted(as currency: Currency) -> String {
        let convertedValue = CurrencyConversionService.shared.convertUSD(self, to: currency)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: currency.localeIdentifier)

        switch currency {
        case .usd:
            formatter.currencyCode = "USD"
            formatter.currencySymbol = "$"
        case .eur:
            formatter.currencyCode = "EUR"
            formatter.currencySymbol = "€"
        case .gbp:
            formatter.currencyCode = "GBP"
            formatter.currencySymbol = "£"
        case .jpy:
            formatter.currencyCode = "JPY"
            formatter.currencySymbol = "¥"
            formatter.maximumFractionDigits = 0
        case .cny:
            formatter.currencyCode = "CNY"
            formatter.currencySymbol = "¥"
        case .krw:
            formatter.currencyCode = "KRW"
            formatter.currencySymbol = "₩"
            formatter.maximumFractionDigits = 0
        case .czk:
            formatter.currencyCode = "CZK"
            formatter.currencySymbol = "Kč"
            formatter.maximumFractionDigits = 0
        }

        return formatter.string(from: NSNumber(value: convertedValue)) ?? "\(currency.symbol)\(String(format: "%.2f", convertedValue))"
    }

    func formattedShort(as currency: Currency) -> String {
        let convertedValue = CurrencyConversionService.shared.convertUSD(self, to: currency)

        if convertedValue >= 1_000_000_000 {
            return "\(currency.symbol)\(String(format: "%.1f", convertedValue / 1_000_000_000))B"
        } else if convertedValue >= 1_000_000 {
            return "\(currency.symbol)\(String(format: "%.1f", convertedValue / 1_000_000))M"
        } else if convertedValue >= 1_000 {
            return "\(currency.symbol)\(String(format: "%.1f", convertedValue / 1_000))K"
        } else {
            return formatted(as: currency)
        }
    }
}
