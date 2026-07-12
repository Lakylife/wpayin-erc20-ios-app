// Autor Lukas Helebrandt, 2026

//
//  AllAssetsView.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI

struct AllAssetsView: View {
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFilter: AssetListFilter = .native

    private var allAssets: [Token] {
        walletManager.visibleSupportedTokens.sorted(by: assetSort)
    }

    private var availableFilters: [AssetListFilter] {
        var filters: [AssetListFilter] = []

        if allAssets.contains(where: { $0.isNative }) {
            filters.append(.native)
        }

        let tokenBlockchains = Array(Set(allAssets.filter { !$0.isNative }.map(\.blockchain)))
            .sorted { $0.name < $1.name }
        filters.append(contentsOf: tokenBlockchains.map { .blockchain($0) })

        if allAssets.count > 1 {
            filters.append(.all)
        }

        return filters
    }

    private var assets: [Token] {
        let filteredAssets: [Token]
        switch selectedFilter {
        case .native:
            filteredAssets = allAssets.filter { $0.isNative }
        case .blockchain(let blockchain):
            filteredAssets = allAssets.filter { !$0.isNative && $0.blockchain == blockchain }
        case .all:
            filteredAssets = allAssets
        }

        return filteredAssets.isEmpty ? allAssets : filteredAssets.sorted(by: assetSort)
    }

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
                        .frame(width: 64, alignment: .leading)

                        Spacer()

                        Text("All Assets".localized)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(WpayinColors.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        Spacer()

                        // Placeholder for balance
                        Text("")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.clear)
                            .frame(width: 64)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    if !availableFilters.isEmpty {
                        AssetFilterBar(
                            filters: availableFilters,
                            selectedFilter: $selectedFilter
                        )
                        .padding(.top, 16)
                    }

                    // Assets List
                    if assets.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "tray")
                                .font(.system(size: 44))
                                .foregroundColor(WpayinColors.textTertiary)

                            Text("No assets yet".localized)
                                .font(.wpayinSubheadline)
                                .foregroundColor(WpayinColors.text)

                            Text("Connect a wallet or receive funds to populate your portfolio.".localized)
                                .font(.wpayinBody)
                                .foregroundColor(WpayinColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 32)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(assets) { token in
                                    NavigationLink(destination: AssetDetailView(token: token)) {
                                        AllAssetsRowView(token: token)
                                            .environmentObject(settingsManager)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.top, 14)
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            ensureAvailableFilter()
        }
        .onChange(of: allAssets.map { "\($0.blockchain.rawValue):\($0.contractAddress ?? "native")" }) { _ in
            ensureAvailableFilter()
        }
    }

    private func ensureAvailableFilter() {
        guard !availableFilters.isEmpty else { return }
        if !availableFilters.contains(selectedFilter) {
            selectedFilter = availableFilters.first ?? .all
        }
    }

    private func assetSort(_ lhs: Token, _ rhs: Token) -> Bool {
        if lhs.isNative != rhs.isNative {
            return lhs.isNative && !rhs.isNative
        }
        if lhs.symbol.uppercased() != rhs.symbol.uppercased() {
            return lhs.symbol.uppercased() < rhs.symbol.uppercased()
        }
        return lhs.blockchain.name < rhs.blockchain.name
    }
}

private enum AssetListFilter: Hashable, Identifiable {
    case native
    case blockchain(BlockchainType)
    case all

    var id: String {
        switch self {
        case .native:
            return "native"
        case .blockchain(let blockchain):
            return blockchain.rawValue
        case .all:
            return "all"
        }
    }

    var title: String {
        switch self {
        case .native:
            return "Coins".localized
        case .blockchain(let blockchain):
            return blockchain.name
        case .all:
            return "All".localized
        }
    }

    var icon: String {
        switch self {
        case .native:
            return "bitcoinsign.circle"
        case .blockchain:
            return "network"
        case .all:
            return "square.grid.2x2"
        }
    }
}

private struct AssetFilterBar: View {
    let filters: [AssetListFilter]
    @Binding var selectedFilter: AssetListFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        HStack(spacing: 6) {
                            filterIcon(for: filter)

                            Text(filter.title)
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(1)
                        }
                        .foregroundColor(selectedFilter == filter ? WpayinColors.text : WpayinColors.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(selectedFilter == filter ? WpayinColors.primary.opacity(0.18) : WpayinColors.surface)
                                .overlay(
                                    Capsule()
                                        .stroke(selectedFilter == filter ? WpayinColors.primary.opacity(0.7) : WpayinColors.surfaceBorder, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private func filterIcon(for filter: AssetListFilter) -> some View {
        switch filter {
        case .blockchain(let blockchain):
            NetworkIconView(blockchain: blockchain, size: 16)
        default:
            Image(systemName: filter.icon)
                .font(.system(size: 13, weight: .semibold))
        }
    }
}

struct AllAssetsRowView: View {
    @EnvironmentObject var walletManager: WalletManager
    let token: Token
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        HStack(spacing: 12) {
            TokenIconView(token: token, size: 40, showNetworkBadge: !token.isNative)

            VStack(alignment: .leading, spacing: 4) {
                Text(token.symbol)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(WpayinColors.text)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(token.name)
                        .font(.system(size: 12))
                        .foregroundColor(WpayinColors.textTertiary)
                        .lineLimit(1)

                    if !token.isNative {
                        Text(token.blockchain.name)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(WpayinColors.primary)
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(WpayinColors.primary.opacity(0.12))
                            )
                    }
                }

                HStack(spacing: 6) {
                    Text(token.price.formatted(as: settingsManager.selectedCurrency))
                        .font(.system(size: 12))
                        .foregroundColor(WpayinColors.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    PriceChangeLabel(change: walletManager.priceChanges24h[token.symbol.uppercased()])
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                Text(TokenIconHelper.formattedBalanceWithSymbol(token.balance, symbol: token.symbol))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(WpayinColors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(token.totalValue.formatted(as: settingsManager.selectedCurrency))
                    .font(.system(size: 12))
                    .foregroundColor(WpayinColors.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(width: 86, alignment: .trailing)

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(WpayinColors.textSecondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(WpayinColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
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

}

#Preview {
    AllAssetsView()
        .environmentObject(WalletManager())
        .environmentObject(SettingsManager())
}
