// Autor Lukas Helebrandt, 2026

//
//  ExpandableTokenCard.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI

struct ExpandableTokenCard: View {
    let token: Token
    let onTokenTap: (Token) -> Void
    let onNetworkTokenTap: (Token) -> Void
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Main token row
            Button(action: {
                if networksForToken.count > 1 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                } else {
                    onTokenTap(token)
                }
            }) {
                HStack(spacing: 13) {
                    TokenIconView(token: token, size: 44, showNetworkBadge: false)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(token.symbol)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(WpayinColors.text)

                            Text(token.name)
                                .font(.system(size: 13))
                                .foregroundColor(WpayinColors.textTertiary)
                        }

                        HStack(spacing: 8) {
                            Text(token.price.formatted(as: settingsManager.selectedCurrency))
                                .font(.system(size: 13))
                                .foregroundColor(WpayinColors.textSecondary)

                            if networksForToken.count > 1 {
                                HStack(spacing: -4) {
                                    ForEach(Array(networksForToken.prefix(3)), id: \.self) { network in
                                        NetworkIconView(blockchain: network, size: 16)
                                            .overlay(
                                                Circle()
                                                    .stroke(WpayinColors.surface, lineWidth: 1)
                                            )
                                    }
                                    if networksForToken.count > 3 {
                                        Circle()
                                            .fill(WpayinColors.textTertiary)
                                            .frame(width: 16, height: 16)
                                            .overlay(
                                                Text("+\(networksForToken.count - 3)")
                                                    .font(.system(size: 8, weight: .bold))
                                                    .foregroundColor(.white)
                                            )
                                    }

                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(WpayinColors.textSecondary)
                                        .frame(width: 16, height: 16)
                                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                                        .animation(.easeInOut(duration: 0.3), value: isExpanded)
                                }
                            }
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(TokenIconHelper.formattedBalanceWithSymbol(totalBalanceAcrossNetworks, symbol: token.symbol))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(WpayinColors.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)

                        Text(totalValueAcrossNetworks.formatted(as: settingsManager.selectedCurrency))
                            .font(.system(size: 12))
                            .foregroundColor(WpayinColors.textTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(width: 92, alignment: .trailing)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(WpayinColors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())

            // Expanded network rows
            if isExpanded && networksForToken.count > 1 {
                VStack(spacing: 1) {
                    ForEach(allNetworkTokens.sorted { networkPriority($0.blockchain) < networkPriority($1.blockchain) }) { networkToken in
                        NetworkSubRow(
                            token: networkToken,
                            isMainNetwork: networkToken.blockchain == .ethereum,
                            onTap: { onNetworkTokenTap(networkToken) }
                        )
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(WpayinColors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                        )
                )
                .padding(.top, 8) // Space between main card and expanded content
            }
        }
    }

    private var networksForToken: [BlockchainType] {
        let allTokensForSymbol = walletManager.visibleTokens.filter { $0.symbol == token.symbol }
        return Array(Set(allTokensForSymbol.map { $0.blockchain })).sorted { $0.name < $1.name }
    }

    private var allNetworkTokens: [Token] {
        walletManager.visibleTokens.filter { $0.symbol == token.symbol }
    }

    private var totalBalanceAcrossNetworks: Double {
        token.balance
    }

    private var totalValueAcrossNetworks: Double {
        token.totalValue
    }

    private func networkPriority(_ blockchain: BlockchainType) -> Int {
        switch blockchain {
        case .ethereum: return 0  // Main network first
        case .arbitrum: return 1
        case .base: return 2
        case .optimism: return 3
        case .polygon: return 4
        case .bsc: return 5
        case .avalanche: return 6
        default: return 999
        }
    }

    private func networkColor(_ blockchain: BlockchainType) -> Color {
        switch blockchain {
        case .ethereum:
            return Color.blue
        case .arbitrum:
            return Color.cyan
        case .polygon:
            return Color.purple
        case .bsc:
            return Color.yellow
        case .optimism:
            return Color.red
        case .avalanche:
            return Color(red: 0.91, green: 0.24, blue: 0.20)
        case .base:
            return Color(red: 0.0, green: 0.46, blue: 0.87)
        default:
            return WpayinColors.primary
        }
    }

    private func tokenColor(for token: Token) -> LinearGradient {
        let colors: [Color]
        switch token.symbol.uppercased() {
        case "ETH":
            colors = [Color.tokenEth, Color.tokenEth.opacity(0.8)]
        case "USDT":
            colors = [Color.tokenUsdt, Color.tokenUsdt.opacity(0.8)]
        case "BNB":
            colors = [Color.tokenBnb, Color.tokenBnb.opacity(0.8)]
        case "USDC":
            colors = [Color.tokenUsdc, Color.tokenUsdc.opacity(0.8)]
        case "SOL":
            colors = [Color.tokenSol, Color.tokenSol.opacity(0.8)]
        default:
            colors = [WpayinColors.primary, WpayinColors.primaryDark]
        }

        return LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func tokenSymbol(for token: Token) -> String {
        switch token.symbol.uppercased() {
        case "ETH": return "Ξ"
        case "USDT": return "₮"
        case "BNB": return "B"
        case "USDC": return "◎"
        case "SOL": return "◎"
        default: return String(token.symbol.prefix(1))
        }
    }
}

struct NetworkSubRow: View {
    let token: Token
    let isMainNetwork: Bool
    let onTap: () -> Void
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Indentation for sub-networks
                HStack(spacing: 8) {
                    if !isMainNetwork {
                        Rectangle()
                            .fill(WpayinColors.textTertiary.opacity(0.3))
                            .frame(width: 2, height: 20)
                    }

                    NetworkIconView(blockchain: token.blockchain, size: isMainNetwork ? 32 : 28)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(token.blockchain.name)
                            .font(.system(size: isMainNetwork ? 15 : 14, weight: isMainNetwork ? .semibold : .medium))
                            .foregroundColor(WpayinColors.text)

                        if isMainNetwork {
                            Text("MAIN")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(WpayinColors.primary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(WpayinColors.primary.opacity(0.1))
                                )
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(TokenIconHelper.formattedBalance(token.balance))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(WpayinColors.text)

                    Text(token.totalValue.formatted(as: settingsManager.selectedCurrency))
                        .font(.system(size: 12))
                        .foregroundColor(WpayinColors.textSecondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Rectangle()
                    .fill(isMainNetwork ? WpayinColors.surfaceLight : WpayinColors.surfaceLight.opacity(0.5))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

}

#Preview {
    VStack {
        ExpandableTokenCard(
            token: Token(contractAddress: nil, name: "Ethereum", symbol: "ETH", decimals: 18, balance: 0, price: 0, iconUrl: nil, blockchain: .ethereum, isNative: true),
            onTokenTap: { _ in },
            onNetworkTokenTap: { _ in }
        )
        .environmentObject(WalletManager())
    }
    .padding()
    .background(WpayinColors.background)
}
