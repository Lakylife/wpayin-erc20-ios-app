// Autor Lukas Helebrandt, 2026

//
//  AssetPickerSheet.swift
//  Wpayin_Wallet
//
//  Full-featured asset & network pickers used by Withdraw and Deposit.
//  (SwiftUI Menu flattens custom rows — icons and full names get lost —
//  so selection is done in a sheet with fully rendered rows instead.)
//

import SwiftUI

struct AssetPickerSheet: View {
    let tokens: [Token]              // may contain one entry per network
    let selectedSymbol: String?
    let onSelect: (String) -> Void
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss

    private var symbols: [String] {
        Array(Set(tokens.map { $0.symbol.uppercased() })).sorted()
    }

    private func groupedToken(for symbol: String) -> Token? {
        let symbolTokens = tokens.filter { $0.symbol.uppercased() == symbol }
        guard let first = symbolTokens.first else { return nil }
        let totalBalance = symbolTokens.reduce(0) { $0 + $1.balance }
        let bestPrice = symbolTokens.map { $0.price }.filter { $0 > 0 }.max() ?? 0
        return Token(
            contractAddress: first.contractAddress,
            name: first.name,
            symbol: first.symbol,
            decimals: first.decimals,
            balance: totalBalance,
            price: bestPrice,
            iconUrl: first.iconUrl,
            blockchain: first.blockchain,
            isNative: first.isNative,
            receivingAddress: first.receivingAddress
        )
    }

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(symbols, id: \.self) { symbol in
                            if let token = groupedToken(for: symbol) {
                                Button {
                                    onSelect(symbol)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 14) {
                                        TokenIconView(token: token, size: 38, showNetworkBadge: false)

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(symbol)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(WpayinColors.text)

                                            Text(token.name)
                                                .font(.system(size: 12))
                                                .foregroundColor(WpayinColors.textSecondary)
                                                .lineLimit(1)
                                        }

                                        Spacer()

                                        VStack(alignment: .trailing, spacing: 3) {
                                            Text(TokenIconHelper.formattedBalanceWithSymbol(token.balance, symbol: symbol, decimals: 4))
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(WpayinColors.text)

                                            Text(token.totalValue.formatted(as: settingsManager.selectedCurrency))
                                                .font(.system(size: 12))
                                                .foregroundColor(WpayinColors.textSecondary)
                                        }

                                        if selectedSymbol?.uppercased() == symbol {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 18))
                                                .foregroundColor(WpayinColors.primary)
                                        }
                                    }
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(selectedSymbol?.uppercased() == symbol
                                                  ? WpayinColors.primary.opacity(0.08)
                                                  : WpayinColors.surface)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Select Asset".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel".localized) { dismiss() }
                        .foregroundColor(WpayinColors.text)
                }
            }
        }
    }
}

struct NetworkPickerSheet: View {
    let tokens: [Token]              // networks available for the chosen asset
    let selectedNetwork: BlockchainType?
    let onSelect: (BlockchainType) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(tokens) { token in
                            Button {
                                onSelect(token.blockchain)
                                dismiss()
                            } label: {
                                HStack(spacing: 14) {
                                    NetworkIconView(blockchain: token.blockchain, size: 34)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(token.blockchain.name)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(WpayinColors.text)

                                        if let proto = token.tokenProtocol, !proto.shortName.isEmpty {
                                            Text(proto.shortName)
                                                .font(.system(size: 12))
                                                .foregroundColor(WpayinColors.textSecondary)
                                        }
                                    }

                                    Spacer()

                                    Text(TokenIconHelper.formattedBalanceWithSymbol(token.balance, symbol: token.symbol, decimals: 4))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(WpayinColors.text)

                                    if selectedNetwork == token.blockchain {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(WpayinColors.primary)
                                    }
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(selectedNetwork == token.blockchain
                                              ? WpayinColors.primary.opacity(0.08)
                                              : WpayinColors.surface)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Select Network".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel".localized) { dismiss() }
                        .foregroundColor(WpayinColors.text)
                }
            }
        }
    }
}
