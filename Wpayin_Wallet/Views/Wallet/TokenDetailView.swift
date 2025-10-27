//
//  TokenDetailView.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI

struct TokenDetailView: View {
    let token: Token
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Token Header
                    VStack(spacing: 16) {
                        // Token Icon
                        Circle()
                            .fill(tokenGradient)
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text(tokenSymbol)
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(.white)
                            )

                        VStack(spacing: 8) {
                            Text(token.name)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(WpayinColors.text)

                            Text(token.symbol)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(WpayinColors.textSecondary)
                        }

                        // Total Balance
                        VStack(spacing: 4) {
                            Text(String(format: "%.6f %@", token.balance, token.symbol))
                                .font(.system(size: 28, weight: .heavy, design: .rounded))
                                .foregroundColor(WpayinColors.text)

                            Text(token.totalValue.formatted(as: settingsManager.selectedCurrency))
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(WpayinColors.textSecondary)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 20)

                    // Network Breakdown
                    if allTokensForSymbol.count > 1 {
                        VStack(alignment: .leading, spacing: 20) {
                            // Header
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(L10n.Networks.title.localized)
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(WpayinColors.text)

                                    Text(String(format: L10n.Networks.available.localized, allTokensForSymbol.count))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(WpayinColors.textSecondary)
                                }

                                Spacer()

                                // Total networks badge
                                HStack(spacing: 6) {
                                    Image(systemName: "network")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(WpayinColors.primary)

                                    Text("\(allTokensForSymbol.count)")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(WpayinColors.primary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(WpayinColors.primary.opacity(0.15))
                                )
                            }

                            // Network list
                            VStack(spacing: 12) {
                                ForEach(allTokensForSymbol.sorted { $0.totalValue > $1.totalValue }) { networkToken in
                                    NetworkTokenRow(token: networkToken)
                                }
                            }
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            WpayinColors.surface,
                                            WpayinColors.surface.opacity(0.8)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    WpayinColors.primary.opacity(0.3),
                                                    WpayinColors.primary.opacity(0.1)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.5
                                        )
                                )
                                .shadow(color: WpayinColors.primary.opacity(0.1), radius: 12, x: 0, y: 6)
                        )
                    }

                    // Token Actions
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            TokenActionButton(
                                icon: "arrow.up.circle.fill",
                                title: "Send",
                                action: { /* TODO: Implement send */ }
                            )

                            TokenActionButton(
                                icon: "arrow.down.circle.fill",
                                title: "Receive",
                                action: { /* TODO: Implement receive */ }
                            )

                            TokenActionButton(
                                icon: "arrow.left.arrow.right.circle.fill",
                                title: "Swap",
                                action: { /* TODO: Implement swap */ }
                            )
                        }

                        if !token.isNative {
                            HStack(spacing: 12) {
                                TokenActionButton(
                                    icon: "plus.circle.fill",
                                    title: "Add to Wallet",
                                    action: { /* TODO: Implement add to wallet */ }
                                )

                                TokenActionButton(
                                    icon: "doc.on.doc.fill",
                                    title: "Copy Contract",
                                    action: {
                                        if let contractAddress = token.contractAddress {
                                            UIPasteboard.general.string = contractAddress
                                        }
                                    }
                                )
                            }
                        }
                    }

                    // Contract Info (for non-native tokens)
                    if !token.isNative, let contractAddress = token.contractAddress {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Contract Information")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(WpayinColors.text)

                            VStack(spacing: 8) {
                                HStack {
                                    Text("Contract Address")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(WpayinColors.textSecondary)

                                    Spacer()
                                }

                                HStack {
                                    Text(formatAddress(contractAddress))
                                        .font(.system(size: 14, design: .monospaced))
                                        .foregroundColor(WpayinColors.text)

                                    Spacer()

                                    Button(action: {
                                        UIPasteboard.general.string = contractAddress
                                    }) {
                                        Image(systemName: "doc.on.doc")
                                            .font(.system(size: 14))
                                            .foregroundColor(WpayinColors.primary)
                                    }
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(WpayinColors.surfaceLight)
                                )
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(WpayinColors.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                                )
                        )
                    }
                }
                .padding(20)
            }
            .background(WpayinColors.background)
            .navigationTitle(token.symbol)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(WpayinColors.primary)
                }
            }
        }
    }

    private var allTokensForSymbol: [Token] {
        let tokensForSymbol = walletManager.tokens.filter { $0.symbol == token.symbol }

        // If it's ETH, make sure all networks use the same price
        if token.symbol == "ETH" {
            let ethPrice = tokensForSymbol.first?.price ?? 0
            return tokensForSymbol.map { networkToken in
                Token(
                    contractAddress: networkToken.contractAddress,
                    name: networkToken.name,
                    symbol: networkToken.symbol,
                    decimals: networkToken.decimals,
                    balance: networkToken.balance,
                    price: ethPrice, // Same ETH price for all networks!
                    iconUrl: networkToken.iconUrl,
                    blockchain: networkToken.blockchain,
                    isNative: networkToken.isNative,
                    id: networkToken.id,
                    receivingAddress: networkToken.receivingAddress
                )
            }
        }

        return tokensForSymbol
    }

    private var tokenGradient: LinearGradient {
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

    private var tokenSymbol: String {
        switch token.symbol.uppercased() {
        case "ETH": return "Ξ"
        case "USDT": return "₮"
        case "BNB": return "B"
        case "USDC": return "◎"
        case "SOL": return "◎"
        default: return String(token.symbol.prefix(1))
        }
    }

    private func formatAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        return "\(address.prefix(6))...\(address.suffix(4))"
    }
}

struct NetworkTokenRow: View {
    let token: Token
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        HStack(spacing: 16) {
            // Network Icon - Modern design
            ZStack {
                Circle()
                    .fill(networkColor.opacity(0.15))
                    .frame(width: 48, height: 48)

                Circle()
                    .fill(networkColor)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(networkSymbol)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    )
            }

            // Network Info
            VStack(alignment: .leading, spacing: 4) {
                Text(token.blockchain.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(WpayinColors.text)

                HStack(spacing: 4) {
                    Text(String(format: "%.6f %@", token.balance, token.symbol))
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(WpayinColors.textSecondary)
                }
            }

            Spacer()

            // Value
            VStack(alignment: .trailing, spacing: 4) {
                Text(token.totalValue.formatted(as: settingsManager.selectedCurrency))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(WpayinColors.text)

                if token.totalValue > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(WpayinColors.success)
                        Text(L10n.Networks.active.localized)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(WpayinColors.success)
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(WpayinColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(networkColor.opacity(0.2), lineWidth: 1.5)
                )
                .shadow(color: networkColor.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }

    private var networkColor: Color {
        switch token.blockchain {
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

    private var networkSymbol: String {
        switch token.blockchain {
        case .ethereum:
            return "E"
        case .arbitrum:
            return "A"
        case .polygon:
            return "P"
        case .bsc:
            return "B"
        case .optimism:
            return "O"
        case .avalanche:
            return "V"
        case .base:
            return "B"
        default:
            return "?"
        }
    }
}

struct TokenActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(WpayinColors.primary)

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(WpayinColors.text)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(WpayinColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    TokenDetailView(token: Token.mockTokens[0])
        .environmentObject(WalletManager())
}