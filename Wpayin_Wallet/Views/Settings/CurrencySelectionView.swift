//
//  CurrencySelectionView.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI
import Combine

struct CurrencySelectionView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(Currency.allCases) { currency in
                            CurrencyRow(
                                currency: currency,
                                isSelected: settingsManager.selectedCurrency == currency
                            ) {
                                settingsManager.updateCurrency(currency)
                                dismiss()
                            }
                        }
                    }
                    .background(WpayinColors.surface)
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle(L10n.Settings.currency.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.Action.cancel.localized) {
                        dismiss()
                    }
                    .foregroundColor(WpayinColors.text)
                }
            }
        }
    }
}

struct CurrencyRow: View {
    let currency: Currency
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(currency.symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(WpayinColors.primary)
                    .frame(width: 32, alignment: .center)

                VStack(alignment: .leading, spacing: 2) {
                    Text(currency.rawValue)
                        .font(.wpayinBody)
                        .foregroundColor(WpayinColors.text)

                    Text(currency.name)
                        .font(.wpayinCaption)
                        .foregroundColor(WpayinColors.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(WpayinColors.primary)
                }
            }
            .padding(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    CurrencySelectionView()
        .environmentObject(SettingsManager())
}