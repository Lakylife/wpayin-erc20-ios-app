// Autor Lukas Helebrandt, 2026

//
//  LedgerTokenCard.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI

struct LedgerTokenCard: View {
    let token: Token
    let onTokenTap: (Token) -> Void
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        Button(action: { onTokenTap(token) }) {
            HStack(spacing: 16) {
                ZStack {
                    TokenIconView(token: token, size: 48, showNetworkBadge: false)

                    // Network indicators (small circles in bottom-right)
                    if networksForToken.count > 1 {
                        HStack(spacing: -4) {
                            ForEach(Array(networksForToken.prefix(3)), id: \.self) { network in
                                NetworkIconView(blockchain: network, size: 14)
                                    .overlay(
                                        Circle()
                                            .stroke(WpayinColors.background, lineWidth: 1.5)
                                    )
                            }
                            if networksForToken.count > 3 {
                                Circle()
                                    .fill(WpayinColors.textTertiary)
                                    .frame(width: 14, height: 14)
                                    .overlay(
                                        Text("+")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(WpayinColors.background, lineWidth: 1.5)
                                    )
                            }
                        }
                        .offset(x: 20, y: 18)
                    }
                }

                // Token Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(token.symbol)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(WpayinColors.text)

                        if networksForToken.count > 1 {
                            Text("Multi-chain".localized)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(WpayinColors.primary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(WpayinColors.primary.opacity(0.1))
                                )
                        }
                    }

                    Text(token.name)
                        .font(.system(size: 13))
                        .foregroundColor(WpayinColors.textSecondary)
                        .lineLimit(1)

                    // Price with live 24h change
                    HStack(spacing: 6) {
                        Text(token.price.formatted(as: settingsManager.selectedCurrency))
                            .font(.system(size: 12))
                            .foregroundColor(WpayinColors.textTertiary)

                        PriceChangeLabel(change: walletManager.priceChanges24h[token.symbol.uppercased()])
                    }
                }

                Spacer()

                // Balance and Value
                VStack(alignment: .trailing, spacing: 4) {
                    Text(TokenIconHelper.formattedBalance(token.balance))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(WpayinColors.text)

                    Text(token.totalValue.formatted(as: settingsManager.selectedCurrency))
                        .font(.system(size: 14))
                        .foregroundColor(WpayinColors.textSecondary)

                    // Network count indicator if multi-chain
                    if networksForToken.count > 1 {
                        Text("%d networks".localized(networksForToken.count))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(WpayinColors.textTertiary)
                    }
                }

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(WpayinColors.textTertiary)
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
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Computed Properties

    private var networksForToken: [BlockchainType] {
        let allTokensForSymbol = walletManager.visibleTokens.filter { $0.symbol == token.symbol }
        return Array(Set(allTokensForSymbol.map { $0.blockchain })).sorted { networkPriority($0) < networkPriority($1) }
    }

    private func networkPriority(_ blockchain: BlockchainType) -> Int {
        switch blockchain {
        case .ethereum: return 0
        case .arbitrum: return 1
        case .base: return 2
        case .optimism: return 3
        case .polygon: return 4
        case .bsc: return 5
        case .avalanche: return 6
        default: return 999
        }
    }

}

#Preview {
    VStack(spacing: 12) {
        LedgerTokenCard(
            token: Token(contractAddress: nil, name: "Ethereum", symbol: "ETH", decimals: 18, balance: 0, price: 0, iconUrl: nil, blockchain: .ethereum, isNative: true),
            onTokenTap: { _ in }
        )
        .environmentObject(WalletManager())
    }
    .padding()
    .background(WpayinColors.background)
}
