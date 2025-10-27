//
//  P2PBuyView.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI

struct P2PBuyView: View {
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedToken = "ETH"
    @State private var selectedFiatCurrency = "USD"
    @State private var buyAmount = ""
    @State private var selectedPaymentMethod: PaymentMethod? = nil
    @State private var showOffers = false

    private let availableTokens = ["ETH", "BTC", "USDT", "USDC", "BNB"]
    private let fiatCurrencies = ["USD", "EUR", "GBP", "CZK"]

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Text("Buy Crypto P2P")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(WpayinColors.text)

                            Text("Buy cryptocurrency directly from other users")
                                .font(.system(size: 16))
                                .foregroundColor(WpayinColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)

                        // Buy Amount Card
                        VStack(spacing: 20) {
                            // Token Selection
                            VStack(alignment: .leading, spacing: 12) {
                                Text("I want to buy")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(WpayinColors.textSecondary)

                                Menu {
                                    ForEach(availableTokens, id: \.self) { token in
                                        Button(action: { selectedToken = token }) {
                                            HStack {
                                                Text(token)
                                                if selectedToken == token {
                                                    Spacer()
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(selectedToken)
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(WpayinColors.text)

                                        Spacer()

                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 14))
                                            .foregroundColor(WpayinColors.textSecondary)
                                    }
                                    .padding(16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(WpayinColors.surface)
                                    )
                                }
                            }

                            // Amount Input
                            VStack(alignment: .leading, spacing: 12) {
                                Text("I will pay")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(WpayinColors.textSecondary)

                                HStack(spacing: 12) {
                                    TextField("0.00", text: $buyAmount)
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundColor(WpayinColors.text)
                                        .keyboardType(.decimalPad)
                                        .padding(16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(WpayinColors.surface)
                                        )

                                    Menu {
                                        ForEach(fiatCurrencies, id: \.self) { currency in
                                            Button(action: { selectedFiatCurrency = currency }) {
                                                HStack {
                                                    Text(currency)
                                                    if selectedFiatCurrency == currency {
                                                        Spacer()
                                                        Image(systemName: "checkmark")
                                                    }
                                                }
                                            }
                                        }
                                    } label: {
                                        Text(selectedFiatCurrency)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(WpayinColors.text)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 16)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(WpayinColors.surface)
                                            )
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(WpayinColors.surface)
                                .shadow(color: Color.black.opacity(0.1), radius: 10)
                        )

                        // Payment Methods
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Payment Method")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(WpayinColors.text)

                            VStack(spacing: 12) {
                                PaymentMethodCard(
                                    method: .bankTransfer,
                                    isSelected: selectedPaymentMethod == .bankTransfer,
                                    onSelect: { selectedPaymentMethod = .bankTransfer }
                                )

                                PaymentMethodCard(
                                    method: .card,
                                    isSelected: selectedPaymentMethod == .card,
                                    onSelect: { selectedPaymentMethod = .card }
                                )

                                PaymentMethodCard(
                                    method: .paypal,
                                    isSelected: selectedPaymentMethod == .paypal,
                                    onSelect: { selectedPaymentMethod = .paypal }
                                )

                                PaymentMethodCard(
                                    method: .revolut,
                                    isSelected: selectedPaymentMethod == .revolut,
                                    onSelect: { selectedPaymentMethod = .revolut }
                                )
                            }
                        }

                        // Search Button
                        Button(action: { showOffers = true }) {
                            Text("Find Offers")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(isValid ? WpayinColors.primary : WpayinColors.textTertiary)
                                )
                        }
                        .disabled(!isValid)
                        .padding(.top, 12)
                        .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.Action.cancel.localized) {
                        dismiss()
                    }
                    .foregroundColor(WpayinColors.primary)
                }
            }
            .sheet(isPresented: $showOffers) {
                P2POffersView(
                    token: selectedToken,
                    amount: buyAmount,
                    fiatCurrency: selectedFiatCurrency,
                    paymentMethod: selectedPaymentMethod ?? .bankTransfer
                )
                .environmentObject(settingsManager)
            }
        }
    }

    private var isValid: Bool {
        guard !buyAmount.isEmpty,
              let amount = Double(buyAmount),
              amount > 0,
              selectedPaymentMethod != nil else {
            return false
        }
        return true
    }
}

enum PaymentMethod: String, CaseIterable {
    case bankTransfer = "Bank Transfer"
    case card = "Debit/Credit Card"
    case paypal = "PayPal"
    case revolut = "Revolut"

    var icon: String {
        switch self {
        case .bankTransfer: return "building.columns.fill"
        case .card: return "creditcard.fill"
        case .paypal: return "dollarsign.circle.fill"
        case .revolut: return "r.circle.fill"
        }
    }

    var description: String {
        switch self {
        case .bankTransfer: return "Direct bank transfer"
        case .card: return "Instant with card"
        case .paypal: return "PayPal account"
        case .revolut: return "Revolut transfer"
        }
    }
}

struct PaymentMethodCard: View {
    let method: PaymentMethod
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                Circle()
                    .fill(WpayinColors.primary.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: method.icon)
                            .font(.system(size: 20))
                            .foregroundColor(WpayinColors.primary)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(method.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(WpayinColors.text)

                    Text(method.description)
                        .font(.system(size: 14))
                        .foregroundColor(WpayinColors.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(WpayinColors.primary)
                } else {
                    Circle()
                        .stroke(WpayinColors.textTertiary, lineWidth: 2)
                        .frame(width: 24, height: 24)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? WpayinColors.primary.opacity(0.1) : WpayinColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? WpayinColors.primary : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct P2POffersView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settingsManager: SettingsManager

    let token: String
    let amount: String
    let fiatCurrency: String
    let paymentMethod: PaymentMethod

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Filter Summary
                        VStack(spacing: 12) {
                            HStack {
                                Text("Buy \(token)")
                                    .font(.system(size: 20, weight: .bold))
                                Spacer()
                                Text("\(amount) \(fiatCurrency)")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(WpayinColors.primary)
                            }

                            HStack {
                                Text("Payment:")
                                    .foregroundColor(WpayinColors.textSecondary)
                                Text(paymentMethod.rawValue)
                                    .font(.system(size: 14, weight: .medium))
                                Spacer()
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(WpayinColors.surface)
                        )

                        // Offers List
                        VStack(spacing: 12) {
                            ForEach(mockOffers, id: \.id) { offer in
                                P2POfferCard(offer: offer, fiatCurrency: fiatCurrency)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Available Offers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.Action.cancel.localized) {
                        dismiss()
                    }
                    .foregroundColor(WpayinColors.primary)
                }
            }
        }
    }

    private var mockOffers: [P2POffer] {
        [
            P2POffer(id: "1", seller: "CryptoTrader123", rating: 4.8, trades: 156, price: 2650.00, available: 2.5, limit: "100 - 5000"),
            P2POffer(id: "2", seller: "BitcoinBob", rating: 4.9, trades: 324, price: 2645.50, available: 1.8, limit: "50 - 3000"),
            P2POffer(id: "3", seller: "ETHQueen", rating: 5.0, trades: 89, price: 2655.00, available: 3.2, limit: "200 - 10000")
        ]
    }
}

struct P2POffer: Identifiable {
    let id: String
    let seller: String
    let rating: Double
    let trades: Int
    let price: Double
    let available: Double
    let limit: String
}

struct P2POfferCard: View {
    let offer: P2POffer
    let fiatCurrency: String

    var body: some View {
        VStack(spacing: 16) {
            // Seller Info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(offer.seller)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(WpayinColors.text)

                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", offer.rating))
                                .font(.system(size: 13))
                                .foregroundColor(WpayinColors.textSecondary)
                        }

                        Text("•")
                            .foregroundColor(WpayinColors.textTertiary)

                        Text("\(offer.trades) trades")
                            .font(.system(size: 13))
                            .foregroundColor(WpayinColors.textSecondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(String(format: "%.2f", offer.price)) \(fiatCurrency)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(WpayinColors.primary)

                    Text("Available: \(String(format: "%.2f", offer.available))")
                        .font(.system(size: 12))
                        .foregroundColor(WpayinColors.textSecondary)
                }
            }

            Divider()

            // Limits & Action
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Limit")
                        .font(.system(size: 12))
                        .foregroundColor(WpayinColors.textSecondary)
                    Text(offer.limit + " \(fiatCurrency)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(WpayinColors.text)
                }

                Spacer()

                Button(action: {}) {
                    Text("Buy")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(WpayinColors.primary)
                        )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(WpayinColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                )
        )
    }
}

#Preview {
    P2PBuyView()
        .environmentObject(WalletManager())
        .environmentObject(SettingsManager())
}
