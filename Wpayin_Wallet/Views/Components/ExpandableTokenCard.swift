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
                HStack(spacing: 14) {
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

                            if networksForToken.count > 1 {
                                // Show network dots like Ledger
                                HStack(spacing: -2) {
                                    ForEach(Array(networksForToken.prefix(3)), id: \.self) { network in
                                        Circle()
                                            .fill(networkColor(network))
                                            .frame(width: 16, height: 16)
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
                                }
                            }
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(String(format: "%.4f %@", totalBalanceAcrossNetworks, token.symbol))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(WpayinColors.text)

                        Text(String(format: "$%.2f", totalValueAcrossNetworks))
                            .font(.system(size: 13))
                            .foregroundColor(WpayinColors.textTertiary)
                    }

                    // Chevron for expandable tokens
                    if networksForToken.count > 1 {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(WpayinColors.textSecondary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .animation(.easeInOut(duration: 0.3), value: isExpanded)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: isExpanded ? 20 : 20)
                        .fill(WpayinColors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: isExpanded ? 20 : 20)
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
                    RoundedRectangle(cornerRadius: 20)
                        .fill(WpayinColors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                        )
                )
                .padding(.top, 8) // Space between main card and expanded content
            }
        }
    }

    private var networksForToken: [BlockchainType] {
        let allTokensForSymbol = walletManager.tokens.filter { $0.symbol == token.symbol }
        return Array(Set(allTokensForSymbol.map { $0.blockchain })).sorted { $0.name < $1.name }
    }

    private var allNetworkTokens: [Token] {
        walletManager.tokens.filter { $0.symbol == token.symbol }
    }

    private var totalBalanceAcrossNetworks: Double {
        allNetworkTokens.reduce(0) { $0 + $1.balance }
    }

    private var totalValueAcrossNetworks: Double {
        allNetworkTokens.reduce(0) { $0 + $1.totalValue }
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

                    Circle()
                        .fill(networkColor)
                        .frame(width: isMainNetwork ? 32 : 28, height: isMainNetwork ? 32 : 28)
                        .overlay(
                            Text(networkSymbol)
                                .font(.system(size: isMainNetwork ? 14 : 12, weight: .bold))
                                .foregroundColor(.white)
                        )
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
                    Text(String(format: "%.6f", token.balance))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(WpayinColors.text)

                    Text(String(format: "$%.2f", token.totalValue))
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