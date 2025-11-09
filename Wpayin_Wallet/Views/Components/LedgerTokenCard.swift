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

    var body: some View {
        Button(action: { onTokenTap(token) }) {
            HStack(spacing: 16) {
                // Token Icon with networks overlay
                ZStack {
                    // Main token icon
                    Circle()
                        .fill(tokenGradient)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Text(tokenSymbol)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                        )

                    // Network indicators (small circles in bottom-right)
                    if networksForToken.count > 1 {
                        HStack(spacing: -4) {
                            ForEach(Array(networksForToken.prefix(3)), id: \.self) { network in
                                Circle()
                                    .fill(networkColor(network))
                                    .frame(width: 14, height: 14)
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
                            Text("Multi-chain")
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

                    // Price with change indicator
                    HStack(spacing: 6) {
                        Text(String(format: "$%.2f", token.price))
                            .font(.system(size: 12))
                            .foregroundColor(WpayinColors.textTertiary)

                    }
                }

                Spacer()

                // Balance and Value
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.4f", token.balance))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(WpayinColors.text)

                    Text(String(format: "$%.2f", token.totalValue))
                        .font(.system(size: 14))
                        .foregroundColor(WpayinColors.textSecondary)

                    // Network count indicator if multi-chain
                    if networksForToken.count > 1 {
                        Text("\(networksForToken.count) networks")
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
        let allTokensForSymbol = walletManager.tokens.filter { $0.symbol == token.symbol }
        return Array(Set(allTokensForSymbol.map { $0.blockchain })).sorted { networkPriority($0) < networkPriority($1) }
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