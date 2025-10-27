//
//  CurrencyFormatter.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import Foundation

extension Double {
    func formatted(as currency: Currency) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency

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

        return formatter.string(from: NSNumber(value: self)) ?? "\(currency.symbol)\(String(format: "%.2f", self))"
    }

    func formattedShort(as currency: Currency) -> String {
        if self >= 1_000_000 {
            return "\(currency.symbol)\(String(format: "%.1f", self / 1_000_000))M"
        } else if self >= 1_000 {
            return "\(currency.symbol)\(String(format: "%.1f", self / 1_000))K"
        } else {
            return formatted(as: currency)
        }
    }
}