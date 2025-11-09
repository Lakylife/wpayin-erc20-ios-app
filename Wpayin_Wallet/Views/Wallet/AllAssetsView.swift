//
//  AllAssetsView.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI

struct AllAssetsView: View {
    @EnvironmentObject var walletManager: WalletManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button(action: { dismiss() }) {
                            Text(L10n.Action.cancel.localized)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(WpayinColors.primary)
                        }

                        Spacer()

                        Text("All Assets")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(WpayinColors.text)

                        Spacer()

                        // Placeholder for balance
                        Text("")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.clear)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Assets List
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(walletManager.visibleGroupedTokens.filter { $0.balance > 0 }) { token in
                                NavigationLink(destination: AssetDetailView(token: token)) {
                                    AllAssetsRowView(token: token)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                }
            }
        }
        .navigationBarHidden(true)
    }
}

struct AllAssetsRowView: View {
    let token: Token

    var body: some View {
        HStack(spacing: 16) {
            // Token Logo with CoinGecko image
            if let iconUrl = token.iconUrl, let url = URL(string: iconUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(tokenColor(for: token))
                        .overlay(
                            Text(tokenSymbol(for: token))
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(tokenColor(for: token))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text(tokenSymbol(for: token))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(token.symbol)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(WpayinColors.text)

                    Text(token.name)
                        .font(.system(size: 13))
                        .foregroundColor(WpayinColors.textTertiary)
                }

                HStack(spacing: 8) {
                    Text(String(format: "$%.2f", token.price))
                        .font(.system(size: 13))
                        .foregroundColor(WpayinColors.textSecondary)

                    HStack(spacing: 2) {
                        Image(systemName: changeDirection(for: token) ? "arrow.up" : "arrow.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(changeDirection(for: token) ? WpayinColors.success : WpayinColors.error)

                        Text(String(format: "%.2f%%", percentChange(for: token)))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(changeDirection(for: token) ? WpayinColors.success : WpayinColors.error)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill((changeDirection(for: token) ? WpayinColors.success : WpayinColors.error).opacity(0.1))
                    )
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.4f %@", token.balance, token.symbol))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(WpayinColors.text)

                Text(String(format: "$%.2f", token.totalValue))
                    .font(.system(size: 13))
                    .foregroundColor(WpayinColors.textTertiary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(WpayinColors.textSecondary)
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

    private func percentChange(for token: Token) -> Double {
        let seed = abs(token.symbol.hashValue)
        return Double(seed % 1000) / 100.0
    }

    private func changeDirection(for token: Token) -> Bool {
        let seed = abs(token.symbol.hashValue)
        return seed % 2 == 0
    }
}

#Preview {
    AllAssetsView()
        .environmentObject(WalletManager())
}