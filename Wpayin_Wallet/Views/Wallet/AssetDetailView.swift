// Autor Lukas Helebrandt, 2026

//
//  AssetDetailView.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI

struct AssetDetailView: View {
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var settingsManager: SettingsManager
    let token: Token
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTimeframe = 0
    @State private var showDepositSheet = false
    @State private var showWithdrawSheet = false
    @State private var showSwapSheet = false
    @State private var showRemoveConfirmation = false
    @State private var coinData: CoinData?
    @State private var lastLoadTime: Date = Date(timeIntervalSince1970: 0)

    private let timeframes = ["1D", "1W", "1M", "3M", "1Y", "ALL"]

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

    var body: some View {
        NavigationView {
            ZStack {
                WalletFlowBackground()

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 26) {
                        AssetOverviewView(
                            token: token,
                            tokens: allTokensForSymbol,
                            coinData: coinData
                        )

                        AssetQuickActionsView(
                            onDeposit: { showDepositSheet = true },
                            onWithdraw: { showWithdrawSheet = true },
                            onSwap: { showSwapSheet = true }
                        )

                        AssetBalanceChartView(
                            token: token,
                            tokens: allTokensForSymbol,
                            transactions: walletManager.transactions,
                            selectedTimeframe: $selectedTimeframe,
                            timeframes: timeframes
                        )

                        if allTokensForSymbol.count > 1 {
                            AssetNetworkDistributionView(tokens: allTokensForSymbol)
                        }

                        AssetTransactionHistoryView(token: token)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
                .refreshable {
                    loadAssetData()
                    await walletManager.refreshWalletData()
                }
            }
            .navigationTitle(token.symbol)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(WpayinColors.text)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(WpayinColors.surfaceLight))
                    }
                    .accessibilityLabel(L10n.Action.close.localized)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 8) {
                        Button(action: {
                            walletManager.toggleFavorite(for: token.symbol)
                        }) {
                            Image(systemName: walletManager.isFavorite(token.symbol) ? "star.fill" : "star")
                                .foregroundColor(walletManager.isFavorite(token.symbol) ? .yellow : WpayinColors.primary)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(WpayinColors.surfaceLight))
                        }

                        if walletManager.canRemoveFromAssets(token) {
                            Menu {
                                Button(role: .destructive) {
                                    showRemoveConfirmation = true
                                } label: {
                                    Label("Remove from Your Assets".localized, systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(WpayinColors.text)
                                    .frame(width: 32, height: 32)
                                    .background(Circle().fill(WpayinColors.surfaceLight))
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showDepositSheet) {
            DepositView(initialToken: token)
                .environmentObject(walletManager)
                .environmentObject(settingsManager)
        }
        .sheet(isPresented: $showWithdrawSheet) {
            WithdrawView(initialToken: token)
                .environmentObject(walletManager)
                .environmentObject(settingsManager)
        }
        .sheet(isPresented: $showSwapSheet) {
            SwapView(initialFromToken: token)
                .environmentObject(walletManager)
                .environmentObject(settingsManager)
        }
        .alert("Remove %@?".localized(token.symbol), isPresented: $showRemoveConfirmation) {
            Button("Cancel".localized, role: .cancel) { }
            Button("Remove".localized, role: .destructive) {
                walletManager.removeTokenSymbolFromAssets(token)
                dismiss()
            }
        } message: {
            Text("This only removes the token from Your Assets. Your funds remain on the blockchain.".localized)
        }
        .onAppear {
            // Only load data if we don't have it yet or it's been more than 5 minutes
            if coinData == nil || Date().timeIntervalSince(lastLoadTime) > 300 {
                loadAssetData()
            }
        }
        .task {
            guard walletManager.hasWallet,
                  walletManager.transactions.isEmpty,
                  !walletManager.isLoading else {
                return
            }

            await walletManager.refreshWalletData()
        }
    }

    private func loadAssetData() {
        let coinId = APIService.getCoinId(for: token.symbol)
        Logger.log("🚀 Loading asset data for: \(token.symbol) -> \(coinId)")

        Task {
            do {
                let fetchedCoinData = try await APIService.shared.getCoinData(coinId: coinId)

                await MainActor.run {
                    Logger.log("✅ Successfully loaded data for \(token.symbol)")
                    self.coinData = fetchedCoinData
                    self.lastLoadTime = Date()
                }
            } catch {
                Logger.log("❌ Failed to load asset data: \(error)")
            }
        }
    }
}

struct WalletFlowBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    WpayinColors.backgroundGradientStart,
                    WpayinColors.background
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(WpayinColors.primary.opacity(0.13))
                .frame(width: 280, height: 280)
                .blur(radius: 90)
                .offset(x: 160, y: -280)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Real Data Components

struct AssetOverviewView: View {
    let token: Token
    let tokens: [Token]
    let coinData: CoinData?
    @EnvironmentObject var settingsManager: SettingsManager

    private var totalBalance: Double {
        tokens.isEmpty ? token.balance : tokens.reduce(0) { $0 + $1.balance }
    }

    private var totalValue: Double {
        tokens.isEmpty ? token.totalValue : tokens.reduce(0) { $0 + $1.totalValue }
    }

    private var balanceText: String {
        let decimals = totalBalance == 0 ? 2 : (totalBalance < 1 ? 6 : 4)
        return TokenIconHelper.formattedBalanceWithSymbol(
            totalBalance,
            symbol: token.symbol.uppercased(),
            decimals: decimals
        )
    }

    private var priceChangePercent: Double {
        coinData?.marketData.priceChangePercentage24h ?? 0
    }

    private var isPriceChangePositive: Bool {
        priceChangePercent >= 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                if let imageURL = coinData?.image.large {
                    AsyncImage(url: URL(string: imageURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        TokenIconView(token: token, size: 54, showNetworkBadge: false)
                    }
                    .frame(width: 58, height: 58)
                    .clipShape(Circle())
                } else {
                    TokenIconView(token: token, size: 54, showNetworkBadge: false)
                        .frame(width: 58, height: 58)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(coinData?.name ?? token.name)
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundColor(WpayinColors.text)

                    Text(L10n.Networks.networkCount.localized(max(tokens.count, 1)))
                        .font(.system(size: 12, weight: .medium))
                    .foregroundColor(WpayinColors.textSecondary)
                }

                Spacer()

                if coinData != nil {
                    HStack(spacing: 5) {
                        Image(systemName: isPriceChangePositive ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))

                        Text("\(isPriceChangePositive ? "+" : "")\(String(format: "%.2f", priceChangePercent))%")
                            .font(.system(size: 12, weight: .bold))

                        Text("24h")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(isPriceChangePositive ? WpayinColors.success : WpayinColors.error)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        Capsule().fill(
                            (isPriceChangePositive ? WpayinColors.success : WpayinColors.error)
                                .opacity(0.11)
                        )
                    )
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("Total balance".localized)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(WpayinColors.textSecondary)

                Text(totalValue.formatted(as: settingsManager.selectedCurrency))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(WpayinColors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                Text(balanceText)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(WpayinColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            WpayinColors.primary.opacity(0.13),
                            WpayinColors.surface
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(WpayinColors.primary.opacity(0.18), lineWidth: 1)
                )
        )
    }
}

private struct AssetBalancePoint {
    let timestamp: Date
    let balance: Double
}

struct AssetBalanceChartView: View {
    let token: Token
    let tokens: [Token]
    let transactions: [Transaction]
    @Binding var selectedTimeframe: Int
    let timeframes: [String]

    private let timeframeDurations: [TimeInterval?] = [
        24 * 60 * 60,
        7 * 24 * 60 * 60,
        30 * 24 * 60 * 60,
        90 * 24 * 60 * 60,
        365 * 24 * 60 * 60,
        nil
    ]

    private var totalBalance: Double {
        tokens.isEmpty ? token.balance : tokens.reduce(0) { $0 + $1.balance }
    }

    private var relevantTransactions: [Transaction] {
        transactions
            .filter {
                $0.token.caseInsensitiveCompare(token.symbol) == .orderedSame
                    && $0.status == .confirmed
            }
            .sorted { $0.timestamp > $1.timestamp }
    }

    /// Rebuild historical holdings from the authoritative current balance by
    /// walking real wallet activity backwards. Two points around each event
    /// produce a correct step chart for deposits and withdrawals.
    private var reconstructedPoints: [AssetBalancePoint] {
        let now = Date()
        var balanceAfterEvent = totalBalance
        var result = [AssetBalancePoint(timestamp: now, balance: totalBalance)]

        for transaction in relevantTransactions {
            // Keep the final live-balance point strictly last even if a cached
            // transaction has a slightly future-skewed timestamp.
            let eventDate = min(
                transaction.timestamp,
                now.addingTimeInterval(-0.1)
            )
            let balanceBeforeEvent = max(0, balanceAfterEvent - balanceDelta(for: transaction))

            result.append(
                AssetBalancePoint(
                    timestamp: eventDate.addingTimeInterval(0.05),
                    balance: balanceAfterEvent
                )
            )
            result.append(
                AssetBalancePoint(
                    timestamp: eventDate.addingTimeInterval(-0.05),
                    balance: balanceBeforeEvent
                )
            )
            balanceAfterEvent = balanceBeforeEvent
        }

        if relevantTransactions.isEmpty {
            result.append(
                AssetBalancePoint(
                    timestamp: now.addingTimeInterval(-365 * 24 * 60 * 60),
                    balance: totalBalance
                )
            )
        }
        return result.sorted { $0.timestamp < $1.timestamp }
    }

    private var displayedPoints: [AssetBalancePoint] {
        let allPoints = reconstructedPoints
        guard selectedTimeframe < timeframeDurations.count,
              let duration = timeframeDurations[selectedTimeframe] else {
            return allPoints
        }

        let cutoff = Date().addingTimeInterval(-duration)
        let boundaryBalance = allPoints.last(where: { $0.timestamp <= cutoff })?.balance
            ?? allPoints.first?.balance
            ?? totalBalance
        var result = [AssetBalancePoint(timestamp: cutoff, balance: boundaryBalance)]
        result.append(contentsOf: allPoints.filter { $0.timestamp > cutoff })
        return result
    }

    private var balanceChange: Double {
        guard let first = displayedPoints.first?.balance,
              let last = displayedPoints.last?.balance else { return 0 }
        return last - first
    }

    private var hasBalanceChanges: Bool {
        let values = displayedPoints.map(\.balance)
        guard let minimum = values.min(), let maximum = values.max() else { return false }
        return abs(maximum - minimum) > 0.0000000001
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Balance history".localized)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(WpayinColors.text)

                    Text("Based on your wallet activity".localized)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(WpayinColors.textTertiary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(formattedBalance(totalBalance))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(WpayinColors.text)

                    Text(formattedChange)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(balanceChange >= 0 ? WpayinColors.success : WpayinColors.error)
                }
            }

            VStack(spacing: 16) {
                HStack(spacing: 4) {
                    ForEach(Array(timeframes.enumerated()), id: \.offset) { index, timeframe in
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                selectedTimeframe = index
                            }
                        } label: {
                            Text(timeframe)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(
                                    selectedTimeframe == index
                                        ? WpayinColors.text
                                        : WpayinColors.textTertiary
                                )
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(
                                    Capsule().fill(
                                        selectedTimeframe == index
                                            ? WpayinColors.surfaceLight
                                            : Color.clear
                                    )
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(4)
                .background(Capsule().fill(WpayinColors.background.opacity(0.55)))

                BalanceLineChart(points: displayedPoints)
                    .frame(height: 164)

                HStack {
                    Text(displayedPoints.first?.timestamp ?? Date(), style: .date)
                    Spacer()
                    Text("Now".localized)
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(WpayinColors.textTertiary)

                if !hasBalanceChanges {
                    Text("No balance changes in this period".localized)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(WpayinColors.textSecondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(WpayinColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                    )
            )
        }
    }

    private var formattedChange: String {
        let sign = balanceChange > 0 ? "+" : ""
        return "\(sign)\(formattedNumber(balanceChange)) \(token.symbol.uppercased())"
    }

    private func formattedBalance(_ value: Double) -> String {
        "\(formattedNumber(value)) \(token.symbol.uppercased())"
    }

    private func formattedNumber(_ value: Double) -> String {
        let decimals = abs(value) < 1 ? 6 : 4
        var result = String(format: "%.*f", decimals, value)
        while result.contains("."), result.last == "0" { result.removeLast() }
        if result.last == "." { result.removeLast() }
        return result
    }

    private func balanceDelta(for transaction: Transaction) -> Double {
        let nativeGas = transaction.resolvedBlockchain.nativeToken
            .caseInsensitiveCompare(token.symbol) == .orderedSame
            ? transaction.gasFee
            : 0

        switch transaction.type {
        case .receive, .deposit, .bridgeReceive:
            return transaction.amount
        case .send, .withdraw, .bridge, .swap:
            return -(transaction.amount + nativeGas)
        }
    }
}

private struct BalanceLineChart: View {
    let points: [AssetBalancePoint]

    private var minimum: Double {
        let value = points.map(\.balance).min() ?? 0
        return value - verticalPadding
    }

    private var range: Double {
        let values = points.map(\.balance)
        let rawRange = (values.max() ?? 0) - (values.min() ?? 0)
        return max(rawRange + verticalPadding * 2, 0.00000001)
    }

    private var verticalPadding: Double {
        let values = points.map(\.balance)
        let rawRange = (values.max() ?? 0) - (values.min() ?? 0)
        let reference = max(abs(values.max() ?? 0), 0.000001)
        return max(rawRange * 0.10, reference * 0.015)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Path { path in
                    addStepLine(to: &path, size: geometry.size)
                }
                .fill(
                    LinearGradient(
                        colors: [
                            WpayinColors.primary.opacity(0.28),
                            WpayinColors.primary.opacity(0.05),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                Path { path in
                    addStepLine(to: &path, size: geometry.size, closesAtBottom: false)
                }
                .stroke(
                    LinearGradient(
                        colors: [WpayinColors.primary, WpayinColors.primaryDark],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .clipped()
    }

    private func addStepLine(
        to path: inout Path,
        size: CGSize,
        closesAtBottom: Bool = true
    ) {
        guard points.count > 1,
              let firstDate = points.first?.timestamp,
              let lastDate = points.last?.timestamp else { return }
        let duration = max(lastDate.timeIntervalSince(firstDate), 1)

        func position(for point: AssetBalancePoint) -> CGPoint {
            let x = CGFloat(point.timestamp.timeIntervalSince(firstDate) / duration) * size.width
            let normalized = (point.balance - minimum) / range
            return CGPoint(x: x, y: size.height - CGFloat(normalized) * size.height)
        }

        let firstPosition = position(for: points[0])
        if closesAtBottom {
            path.move(to: CGPoint(x: firstPosition.x, y: size.height))
            path.addLine(to: firstPosition)
        } else {
            path.move(to: firstPosition)
        }

        var previous = firstPosition
        for point in points.dropFirst() {
            let current = position(for: point)
            path.addLine(to: CGPoint(x: current.x, y: previous.y))
            path.addLine(to: current)
            previous = current
        }

        if closesAtBottom {
            path.addLine(to: CGPoint(x: previous.x, y: size.height))
            path.closeSubpath()
        }
    }
}

struct ChartStatItem: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title.localized)
                .font(.wpayinCaption)
                .foregroundColor(WpayinColors.textSecondary)

            Text(value)
                .font(.wpayinBody)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

struct AssetQuickActionsView: View {
    let onDeposit: () -> Void
    let onWithdraw: () -> Void
    let onSwap: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            QuickActionButton(
                icon: "arrow.down",
                title: L10n.Action.receive.localized,
                action: onDeposit
            )

            QuickActionButton(
                icon: "arrow.up",
                title: L10n.Action.send.localized,
                action: onWithdraw
            )

            QuickActionButton(
                icon: "arrow.left.arrow.right",
                title: L10n.Action.swap.localized,
                action: onSwap
            )
        }
    }
}

struct AssetNetworkDistributionView: View {
    let tokens: [Token]

    private var sortedTokens: [Token] {
        tokens.sorted { $0.totalValue > $1.totalValue }
    }

    private var totalValue: Double {
        tokens.reduce(0) { $0 + $1.totalValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L10n.Tokens.distribution.localized)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(WpayinColors.text)

                Spacer()

                Text(L10n.Networks.networkCount.localized(tokens.count))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(WpayinColors.textSecondary)
            }

            VStack(spacing: 0) {
                ForEach(Array(sortedTokens.enumerated()), id: \.element.id) { index, networkToken in
                    AssetNetworkDistributionRow(
                        token: networkToken,
                        share: totalValue > 0 ? networkToken.totalValue / totalValue : 0
                    )

                    if index < sortedTokens.count - 1 {
                        Divider()
                            .overlay(WpayinColors.surfaceBorder)
                            .padding(.leading, 50)
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(WpayinColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                    )
            )
        }
    }
}

private struct AssetNetworkDistributionRow: View {
    let token: Token
    let share: Double
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                NetworkIconView(blockchain: token.blockchain, size: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text(token.blockchain.name)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(WpayinColors.text)

                    Text(TokenIconHelper.formattedBalanceWithSymbol(
                        token.balance,
                        symbol: token.symbol,
                        decimals: token.balance < 1 ? 6 : 4
                    ))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(WpayinColors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(token.totalValue.formatted(as: settingsManager.selectedCurrency))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(WpayinColors.text)

                    Text("\(Int((share * 100).rounded()))%")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(WpayinColors.textSecondary)
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(WpayinColors.surfaceLight)
                    Capsule()
                        .fill(WpayinColors.primary)
                        .frame(width: max(4, geometry.size.width * CGFloat(share)))
                }
            }
            .frame(height: 4)
            .padding(.leading, 46)
        }
        .padding(.vertical, 14)
    }
}

struct RealAssetStatsView: View {
    let token: Token
    let coinData: CoinData
    @EnvironmentObject var settingsManager: SettingsManager

    private var items: [(title: String, value: String)] {
        var result: [(title: String, value: String)] = [
            (
                L10n.Market.marketCap.localized,
                (coinData.marketData.marketCap["usd"] ?? 0).formattedShort(as: settingsManager.selectedCurrency)
            ),
            (
                L10n.Market.volume24h.localized,
                (coinData.marketData.totalVolume["usd"] ?? 0).formattedShort(as: settingsManager.selectedCurrency)
            )
        ]

        if let supply = coinData.marketData.circulatingSupply {
            result.append((L10n.Market.circulatingSupply.localized, formatSupply(supply) + " \(token.symbol)"))
        }
        if let totalSupply = coinData.marketData.totalSupply {
            result.append((L10n.Market.totalSupply.localized, formatSupply(totalSupply) + " \(token.symbol)"))
        }
        if let contractAddress = token.contractAddress {
            result.append(("Contract Address".localized, formatAddress(contractAddress)))
        } else {
            result.append(("Network".localized, "%@ Native Token".localized(token.blockchain.name)))
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.Tokens.details.localized)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(WpayinColors.text)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    StatRow(title: item.title, value: item.value)
                        .padding(.vertical, 13)

                    if index < items.count - 1 {
                        Divider()
                            .overlay(WpayinColors.surfaceBorder)
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(WpayinColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                    )
            )
        }
    }

    private func formatSupply(_ supply: Double) -> String {
        let billion = 1_000_000_000.0
        let million = 1_000_000.0

        if supply >= billion {
            return "\(String(format: "%.1f", supply / billion))B"
        } else if supply >= million {
            return "\(String(format: "%.1f", supply / million))M"
        } else {
            return "\(String(format: "%.0f", supply))"
        }
    }

    private func formatAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        return "\(address.prefix(6))...\(address.suffix(4))"
    }
}

struct AssetStatsView: View {
    let token: Token
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.Tokens.details.localized)
                .font(.wpayinHeadline)
                .foregroundColor(WpayinColors.text)

            VStack(spacing: 12) {
                StatRow(title: L10n.Market.marketCap.localized, value: 456_700_000_000.formattedShort(as: settingsManager.selectedCurrency))
                StatRow(title: L10n.Market.volume24h.localized, value: 12_300_000_000.formattedShort(as: settingsManager.selectedCurrency))
                StatRow(title: L10n.Market.circulatingSupply.localized, value: "120.3M \(token.symbol)")
                StatRow(title: "Contract Address".localized, value: formatAddress(token.contractAddress ?? "N/A"))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(WpayinColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                )
        )
    }

    private func formatAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        return "\(address.prefix(6))...\(address.suffix(4))"
    }
}

struct StatRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title.localized)
                .font(.wpayinBody)
                .foregroundColor(WpayinColors.textSecondary)

            Spacer()

            Text(value)
                .font(.wpayinBody)
                .foregroundColor(WpayinColors.text)
        }
    }
}

struct AssetTransactionHistoryView: View {
    let token: Token
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var selectedTransaction: Transaction?

    var relevantTransactions: [Transaction] {
        return walletManager.transactions
            .filter {
                $0.token.caseInsensitiveCompare(token.symbol) == .orderedSame
            }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(4)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(L10n.Activity.recent.localized)
                    .font(.wpayinHeadline)
                    .foregroundColor(WpayinColors.text)

                Spacer()

                NavigationLink(
                    destination: AllTransactionsView(token: token)
                        .environmentObject(walletManager)
                        .environmentObject(settingsManager)
                ) {
                    HStack(spacing: 5) {
                        Text(L10n.Wallet.viewAll.localized)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
                .foregroundColor(WpayinColors.primary)
                .font(.wpayinCaption)
            }

            Group {
                if relevantTransactions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.system(size: 28))
                        .foregroundColor(WpayinColors.textSecondary)
                        .opacity(0.5)

                    Text(L10n.Activity.noTransactions.localized)
                        .font(.wpayinBody)
                        .foregroundColor(WpayinColors.textSecondary)

                    Text(L10n.Activity.tokenEmptyDesc.localized(token.symbol))
                        .font(.wpayinCaption)
                        .foregroundColor(WpayinColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(relevantTransactions.enumerated()), id: \.element.id) { index, transaction in
                            Button {
                                selectedTransaction = transaction
                            } label: {
                                AssetRecentTransactionRow(transaction: transaction)
                            }
                            .buttonStyle(WpayinPressableStyle())

                            if index < relevantTransactions.count - 1 {
                                Divider()
                                    .overlay(WpayinColors.surfaceBorder)
                                    .padding(.leading, 54)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(WpayinColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                    )
            )
        }
        .sheet(item: $selectedTransaction) { transaction in
            TransactionDetailView(transaction: transaction)
                .environmentObject(walletManager)
                .environmentObject(settingsManager)
        }
    }
}

private struct AssetRecentTransactionRow: View {
    let transaction: Transaction

    private var statusColor: Color {
        switch transaction.status {
        case .confirmed: return WpayinColors.success
        case .pending: return WpayinColors.warning
        case .failed: return WpayinColors.error
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            TransactionTokenIcon(transaction: transaction, size: 40)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(transaction.type.displayName)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(WpayinColors.text)

                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                }

                HStack(spacing: 5) {
                    NetworkIconView(blockchain: transaction.resolvedBlockchain, size: 12)

                    Text(transaction.resolvedBlockchain.name)
                        .lineLimit(1)

                    Text("•")

                    Text(transaction.timestamp, style: .relative)
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(WpayinColors.textTertiary)
            }

            Spacer(minLength: 8)

            Text(transaction.formattedActivityAmount)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(transaction.activityColor)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(WpayinColors.textTertiary)
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}


#Preview {
    AssetDetailView(token: Token(contractAddress: nil, name: "", symbol: "", decimals: 18, balance: 0, price: 0, iconUrl: nil, blockchain: .ethereum, isNative: true))
        .environmentObject(WalletManager())
}
