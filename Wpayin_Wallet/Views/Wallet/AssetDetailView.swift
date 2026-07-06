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
    @State private var coinData: CoinData?
    @State private var chartData: CoinChartData?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var lastLoadTime: Date = Date(timeIntervalSince1970: 0)

    private let timeframes = ["1D", "1W", "1M", "3M", "1Y", "ALL"]
    private let dayMappings = [1, 7, 30, 90, 365, 365]

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

                if isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(WpayinColors.primary)

                        Text(L10n.Wallet.loadingData.localized)
                            .font(.wpayinBody)
                            .foregroundColor(WpayinColors.textSecondary)
                    }
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(WpayinColors.error)

                        Text(L10n.Wallet.failedToLoad.localized)
                            .font(.wpayinHeadline)
                            .foregroundColor(WpayinColors.text)

                        Text(errorMessage)
                            .font(.wpayinBody)
                            .foregroundColor(WpayinColors.textSecondary)
                            .multilineTextAlignment(.center)

                        Button(L10n.Wallet.retry.localized) {
                            loadAssetData()
                        }
                        .foregroundColor(WpayinColors.primary)
                        .font(.wpayinBody)
                    }
                    .padding(.horizontal, 40)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            if let coinData = coinData {
                                RealAssetHeaderView(token: token, coinData: coinData)
                            }

                            if let chartData = chartData, let coinData = coinData {
                                RealAssetChartView(
                                    token: token,
                                    coinData: coinData,
                                    chartData: chartData,
                                    selectedTimeframe: $selectedTimeframe,
                                    timeframes: timeframes,
                                    onTimeframeChanged: { timeframe in
                                        loadChartData(days: dayMappings[timeframe])
                                    }
                                )
                            }

                            AssetBalanceView(
                                token: token,
                                onDeposit: { showDepositSheet = true },
                                onWithdraw: { showWithdrawSheet = true },
                                onSwap: { showSwapSheet = true }
                            )

                            if allTokensForSymbol.count > 1 {
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack {
                                        Text(L10n.Tokens.distribution.localized)
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(WpayinColors.text)

                                        Spacer()

                                        Text(L10n.Networks.networkCount.localized(allTokensForSymbol.count))
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(WpayinColors.textSecondary)
                                    }

                                    LazyVStack(spacing: 12) {
                                        ForEach(allTokensForSymbol.sorted { $0.totalValue > $1.totalValue }) { networkToken in
                                            NetworkTokenRow(token: networkToken)
                                        }
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

                            if let coinData = coinData {
                                RealAssetStatsView(token: token, coinData: coinData)
                            }

                            AssetTransactionHistoryView(token: token)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 32)
                    }
                    .refreshable {
                        loadAssetData()
                        await walletManager.refreshWalletData()
                    }
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
                    Button(action: {
                        walletManager.toggleFavorite(for: token.symbol)
                    }) {
                        Image(systemName: walletManager.isFavorite(token.symbol) ? "star.fill" : "star")
                            .foregroundColor(walletManager.isFavorite(token.symbol) ? .yellow : WpayinColors.primary)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(WpayinColors.surfaceLight))
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
        isLoading = true
        errorMessage = nil

        let coinId = APIService.getCoinId(for: token.symbol)
        Logger.log("🚀 Loading asset data for: \(token.symbol) -> \(coinId)")

        Task {
            do {
                async let coinDataTask = APIService.shared.getCoinData(coinId: coinId)
                async let chartDataTask = APIService.shared.getCoinChartData(coinId: coinId, days: dayMappings[selectedTimeframe])

                let (fetchedCoinData, fetchedChartData) = try await (coinDataTask, chartDataTask)

                await MainActor.run {
                    Logger.log("✅ Successfully loaded data for \(token.symbol)")
                    self.coinData = fetchedCoinData
                    self.chartData = fetchedChartData
                    self.isLoading = false
                    self.lastLoadTime = Date()
                }
            } catch {
                Logger.log("❌ Failed to load asset data: \(error)")

                // Try to load just basic data without chart as fallback
                do {
                    let basicData = try await APIService.shared.getCoinData(coinId: coinId)
                    await MainActor.run {
                        Logger.log("✅ Loaded basic data for \(token.symbol)")
                        self.coinData = basicData
                        self.isLoading = false
                        self.lastLoadTime = Date()
                    }
                } catch {
                    // Final fallback - show error but don't block the UI
                    await MainActor.run {
                        self.isLoading = false
                        Logger.log("⚠️ Using fallback display for \(token.symbol)")
                        // Don't set error message - just show token info without chart
                    }
                }
            }
        }
    }


    private func loadChartData(days: Int) {
        guard let coinData = coinData else { return }

        Task {
            do {
                let fetchedChartData = try await APIService.shared.getCoinChartData(coinId: coinData.id, days: days)
                await MainActor.run {
                    self.chartData = fetchedChartData
                }
            } catch {
                Logger.log("Failed to load chart data: \(error)")
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

struct RealAssetHeaderView: View {
    let token: Token
    let coinData: CoinData
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                AsyncImage(url: URL(string: coinData.image.large)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    TokenIconView(token: token, size: 54, showNetworkBadge: false)
                }
                .frame(width: 54, height: 54)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(coinData.name)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(WpayinColors.text)

                    Text(coinData.symbol.uppercased())
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(WpayinColors.textSecondary)
                }

                Spacer()

                NetworkIconView(blockchain: token.blockchain, size: 30)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text((coinData.marketData.currentPrice["usd"] ?? 0).formatted(as: settingsManager.selectedCurrency))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(WpayinColors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                let priceChange = coinData.marketData.priceChange24h
                let priceChangePercent = coinData.marketData.priceChangePercentage24h
                let isPositive = priceChange >= 0

                HStack(spacing: 6) {
                    Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 11, weight: .bold))

                    Text("\(isPositive ? "+" : "-")\(abs(priceChange).formatted(as: settingsManager.selectedCurrency)) (\(isPositive ? "+" : "")\(String(format: "%.2f", priceChangePercent))%)")
                        .font(.system(size: 13, weight: .semibold))

                    Text("24h")
                        .font(.system(size: 12, weight: .medium))
                        .opacity(0.75)
                }
                .foregroundColor(isPositive ? WpayinColors.success : WpayinColors.error)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill((isPositive ? WpayinColors.success : WpayinColors.error).opacity(0.12))
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.085),
                            Color.white.opacity(0.035)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }
}

struct RealAssetChartView: View {
    let token: Token
    let coinData: CoinData
    let chartData: CoinChartData
    @Binding var selectedTimeframe: Int
    let timeframes: [String]
    let onTimeframeChanged: (Int) -> Void
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(L10n.Market.priceChart.localized)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(WpayinColors.text)

                Spacer()
            }

            HStack(spacing: 4) {
                ForEach(Array(timeframes.enumerated()), id: \.offset) { index, timeframe in
                    Button(action: {
                        selectedTimeframe = index
                        onTimeframeChanged(index)
                    }) {
                        Text(timeframe)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(selectedTimeframe == index ? WpayinColors.primary : WpayinColors.textTertiary)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(
                                Capsule()
                                    .fill(selectedTimeframe == index ? WpayinColors.primary.opacity(0.14) : Color.clear)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(4)
            .background(Capsule().fill(WpayinColors.surfaceLight))

            VStack(spacing: 16) {
                PriceChartView(chartData: chartData)
                    .frame(height: 170)

                HStack {
                    ChartStatItem(
                        title: L10n.Market.high24h.localized,
                        value: (coinData.marketData.high24h["usd"] ?? 0).formatted(as: settingsManager.selectedCurrency),
                        color: WpayinColors.success
                    )
                    ChartStatItem(
                        title: L10n.Market.low24h.localized,
                        value: (coinData.marketData.low24h["usd"] ?? 0).formatted(as: settingsManager.selectedCurrency),
                        color: WpayinColors.error
                    )
                    ChartStatItem(
                        title: L10n.Market.volume24h.localized,
                        value: (coinData.marketData.totalVolume["usd"] ?? 0).formattedShort(as: settingsManager.selectedCurrency),
                        color: WpayinColors.primary
                    )
                }
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

}

struct PriceChartView: View {
    let chartData: CoinChartData

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard chartData.prices.count > 1 else { return }

                let prices = chartData.prices.map { $0[1] }
                let minPrice = prices.min() ?? 0
                let maxPrice = prices.max() ?? 0
                let priceRange = max(maxPrice - minPrice, max(abs(maxPrice) * 0.001, 0.000001))

                let width = geometry.size.width
                let height = geometry.size.height

                for (index, priceData) in chartData.prices.enumerated() {
                    let price = priceData[1]
                    let x = CGFloat(index) / CGFloat(chartData.prices.count - 1) * width
                    let y = height - (CGFloat(price - minPrice) / CGFloat(priceRange) * height)

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(
                LinearGradient(
                    colors: [WpayinColors.primary, WpayinColors.primaryDark],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                lineWidth: 2
            )

            // Background gradient
            Path { path in
                guard chartData.prices.count > 1 else { return }

                let prices = chartData.prices.map { $0[1] }
                let minPrice = prices.min() ?? 0
                let maxPrice = prices.max() ?? 0
                let priceRange = max(maxPrice - minPrice, max(abs(maxPrice) * 0.001, 0.000001))

                let width = geometry.size.width
                let height = geometry.size.height

                path.move(to: CGPoint(x: 0, y: height))

                for (index, priceData) in chartData.prices.enumerated() {
                    let price = priceData[1]
                    let x = CGFloat(index) / CGFloat(chartData.prices.count - 1) * width
                    let y = height - (CGFloat(price - minPrice) / CGFloat(priceRange) * height)
                    path.addLine(to: CGPoint(x: x, y: y))
                }

                path.addLine(to: CGPoint(x: width, y: height))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [
                        WpayinColors.primary.opacity(0.3),
                        WpayinColors.primary.opacity(0.1),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .background(WpayinColors.surfaceLight)
        .cornerRadius(12)
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

struct AssetBalanceView: View {
    let token: Token
    let onDeposit: () -> Void
    let onWithdraw: () -> Void
    let onSwap: () -> Void
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.Tokens.balance.localized)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(WpayinColors.textSecondary)

                    let balanceString = token.balance == 0 ? "0.00" : String(format: "%.6f", token.balance)
                    Text("\(balanceString) \(token.symbol)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(WpayinColors.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }

                Spacer()

                Text(token.totalValue.formatted(as: settingsManager.selectedCurrency))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(WpayinColors.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(WpayinColors.surfaceLight))
            }

            HStack(spacing: 12) {
                AssetActionButton(
                    icon: "arrow.down",
                    title: L10n.Action.receive.localized,
                    subtitle: L10n.Action.depositSubtitle.localized(token.symbol),
                    color: WpayinColors.primary,
                    action: onDeposit
                )

                AssetActionButton(
                    icon: "arrow.up",
                    title: L10n.Action.send.localized,
                    subtitle: L10n.Action.sendSubtitle.localized,
                    color: WpayinColors.primary,
                    action: onWithdraw
                )

                AssetActionButton(
                    icon: "arrow.left.arrow.right",
                    title: L10n.Action.swap.localized,
                    subtitle: L10n.Action.swapSubtitle.localized,
                    color: WpayinColors.primary,
                    action: onSwap
                )
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
}

struct AssetActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 9) {
                Circle()
                    .fill(color.opacity(0.14))
                    .frame(width: 46, height: 46)
                    .overlay(
                        Circle()
                            .stroke(color.opacity(0.18), lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(color)
                    )

                Text(title.localized)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(WpayinColors.text)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(WpayinPressableStyle())
    }
}

struct RealAssetStatsView: View {
    let token: Token
    let coinData: CoinData
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.Tokens.details.localized)
                .font(.wpayinHeadline)
                .foregroundColor(WpayinColors.text)

            VStack(spacing: 12) {
                StatRow(
                    title: L10n.Market.marketCap.localized,
                    value: (coinData.marketData.marketCap["usd"] ?? 0).formattedShort(as: settingsManager.selectedCurrency)
                )
                StatRow(
                    title: L10n.Market.volume24h.localized,
                    value: (coinData.marketData.totalVolume["usd"] ?? 0).formattedShort(as: settingsManager.selectedCurrency)
                )
                if let supply = coinData.marketData.circulatingSupply {
                    StatRow(
                        title: L10n.Market.circulatingSupply.localized,
                        value: formatSupply(supply) + " \(token.symbol)"
                    )
                }
                if let totalSupply = coinData.marketData.totalSupply {
                    StatRow(
                        title: L10n.Market.totalSupply.localized,
                        value: formatSupply(totalSupply) + " \(token.symbol)"
                    )
                }
                if let contractAddress = token.contractAddress {
                    StatRow(
                        title: "Contract Address".localized,
                        value: formatAddress(contractAddress)
                    )
                } else {
                    StatRow(
                        title: "Network".localized,
                        value: "%@ Native Token".localized(token.blockchain.name)
                    )
                }
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
        // Each network keeps its own history — ETH on Arbitrum must not show
        // Ethereum-mainnet transactions.
        return walletManager.transactions
            .filter {
                $0.token.caseInsensitiveCompare(token.symbol) == .orderedSame &&
                $0.resolvedBlockchain == token.blockchain
            }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(3)
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

            if relevantTransactions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.system(size: 32))
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
                .padding(.vertical, 32)
            } else {
                VStack(spacing: 12) {
                    ForEach(relevantTransactions, id: \.id) { transaction in
                        Button {
                            selectedTransaction = transaction
                        } label: {
                            TransactionRowView(transaction: transaction)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
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
        .sheet(item: $selectedTransaction) { transaction in
            TransactionDetailView(transaction: transaction)
                .environmentObject(walletManager)
                .environmentObject(settingsManager)
        }
    }
}


#Preview {
    AssetDetailView(token: Token(contractAddress: nil, name: "", symbol: "", decimals: 18, balance: 0, price: 0, iconUrl: nil, blockchain: .ethereum, isNative: true))
        .environmentObject(WalletManager())
}
