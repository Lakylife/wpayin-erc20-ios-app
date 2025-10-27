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
                WpayinColors.background.ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(WpayinColors.primary)

                        Text("Loading market data...")
                            .font(.wpayinBody)
                            .foregroundColor(WpayinColors.textSecondary)
                    }
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(WpayinColors.error)

                        Text("Failed to load data")
                            .font(.wpayinHeadline)
                            .foregroundColor(WpayinColors.text)

                        Text(errorMessage)
                            .font(.wpayinBody)
                            .foregroundColor(WpayinColors.textSecondary)
                            .multilineTextAlignment(.center)

                        Button("Retry") {
                            loadAssetData()
                        }
                        .foregroundColor(WpayinColors.primary)
                        .font(.wpayinBody)
                    }
                    .padding(.horizontal, 40)
                } else {
                    ScrollView {
                        VStack(spacing: 32) {
                            // Header with real token info
                            if let coinData = coinData {
                                RealAssetHeaderView(token: token, coinData: coinData)
                            }

                            // Real Price Chart
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

                            // Balance & Actions
                            AssetBalanceView(
                                token: token,
                                onDeposit: { showDepositSheet = true },
                                onWithdraw: { showWithdrawSheet = true },
                                onSwap: { showSwapSheet = true }
                            )

                            // Network Breakdown
                            if allTokensForSymbol.count > 1 {
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack {
                                        Text("Network Distribution")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(WpayinColors.text)

                                        Spacer()

                                        Text("\(allTokensForSymbol.count) networks")
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
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(WpayinColors.surface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                                        )
                                )
                            }

                            // Real Asset Stats
                            if let coinData = coinData {
                                RealAssetStatsView(token: token, coinData: coinData)
                            }

                            // Transaction History for this token
                            AssetTransactionHistoryView(token: token)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                    .refreshable {
                        loadAssetData()
                    }
                }
            }
            .navigationTitle(token.symbol)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(WpayinColors.text)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        walletManager.toggleFavorite(for: token.symbol)
                    }) {
                        Image(systemName: walletManager.isFavorite(token.symbol) ? "star.fill" : "star")
                            .foregroundColor(walletManager.isFavorite(token.symbol) ? .yellow : WpayinColors.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showDepositSheet) {
            DepositView()
                .environmentObject(walletManager)
        }
        .sheet(isPresented: $showWithdrawSheet) {
            WithdrawView()
                .environmentObject(walletManager)
        }
        .sheet(isPresented: $showSwapSheet) {
            SwapView()
                .environmentObject(walletManager)
        }
        .onAppear {
            // Only load data if we don't have it yet or it's been more than 5 minutes
            if coinData == nil || Date().timeIntervalSince(lastLoadTime) > 300 {
                loadAssetData()
            }
        }
    }

    private func loadAssetData() {
        isLoading = true
        errorMessage = nil

        let coinId = APIService.getCoinId(for: token.symbol)
        print("🚀 Loading asset data for: \(token.symbol) -> \(coinId)")

        Task {
            do {
                async let coinDataTask = APIService.shared.getCoinData(coinId: coinId)
                async let chartDataTask = APIService.shared.getCoinChartData(coinId: coinId, days: dayMappings[selectedTimeframe])

                let (fetchedCoinData, fetchedChartData) = try await (coinDataTask, chartDataTask)

                await MainActor.run {
                    print("✅ Successfully loaded data for \(token.symbol)")
                    self.coinData = fetchedCoinData
                    self.chartData = fetchedChartData
                    self.isLoading = false
                    self.lastLoadTime = Date()
                }
            } catch {
                print("❌ Failed to load asset data: \(error)")

                // Try to load just basic data without chart as fallback
                do {
                    let basicData = try await APIService.shared.getCoinData(coinId: coinId)
                    await MainActor.run {
                        print("✅ Loaded basic data for \(token.symbol)")
                        self.coinData = basicData
                        self.isLoading = false
                        self.lastLoadTime = Date()
                    }
                } catch {
                    // Final fallback - show error but don't block the UI
                    await MainActor.run {
                        self.isLoading = false
                        print("⚠️ Using fallback display for \(token.symbol)")
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
                print("Failed to load chart data: \(error)")
            }
        }
    }
}

// MARK: - Real Data Components

struct RealAssetHeaderView: View {
    let token: Token
    let coinData: CoinData

    var body: some View {
        VStack(spacing: 20) {
            // Token Icon and Name with real CoinGecko image
            HStack(spacing: 16) {
                AsyncImage(url: URL(string: coinData.image.large)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    TokenIconView(symbol: token.symbol, blockchain: token.blockchain)
                }
                .frame(width: 64, height: 64)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(coinData.name)
                        .font(.wpayinHeadline)
                        .foregroundColor(WpayinColors.text)

                    Text(coinData.symbol.uppercased())
                        .font(.wpayinBody)
                        .foregroundColor(WpayinColors.textSecondary)
                }

                Spacer()
            }

            // Real Current Price
            VStack(spacing: 8) {
                Text("$" + String(format: "%.2f", coinData.marketData.currentPrice["usd"] ?? 0))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(WpayinColors.text)

                // Real price change
                let priceChange = coinData.marketData.priceChange24h
                let priceChangePercent = coinData.marketData.priceChangePercentage24h
                let isPositive = priceChange > 0

                HStack(spacing: 6) {
                    Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                        .font(.system(size: 12))
                        .foregroundColor(isPositive ? WpayinColors.success : WpayinColors.error)

                    Text("\(isPositive ? "+" : "")$\(String(format: "%.2f", abs(priceChange))) (\(isPositive ? "+" : "")\(String(format: "%.2f", priceChangePercent))%)")
                        .font(.wpayinBody)
                        .foregroundColor(isPositive ? WpayinColors.success : WpayinColors.error)

                    Text("24h")
                        .font(.wpayinCaption)
                        .foregroundColor(WpayinColors.textSecondary)
                }
            }
        }
        .padding(24)
        .background(WpayinColors.surface)
        .cornerRadius(20)
    }
}

struct RealAssetChartView: View {
    let token: Token
    let coinData: CoinData
    let chartData: CoinChartData
    @Binding var selectedTimeframe: Int
    let timeframes: [String]
    let onTimeframeChanged: (Int) -> Void

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Price Chart")
                    .font(.wpayinHeadline)
                    .foregroundColor(WpayinColors.text)

                Spacer()
            }

            // Timeframe selector
            HStack(spacing: 8) {
                ForEach(Array(timeframes.enumerated()), id: \.offset) { index, timeframe in
                    Button(action: {
                        selectedTimeframe = index
                        onTimeframeChanged(index)
                    }) {
                        Text(timeframe)
                            .font(.wpayinCaption)
                            .foregroundColor(selectedTimeframe == index ? WpayinColors.secondary : WpayinColors.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedTimeframe == index ? WpayinColors.primary : WpayinColors.surfaceLight)
                            .cornerRadius(16)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            // Real Chart Area
            VStack(spacing: 16) {
                // Actual price chart
                PriceChartView(chartData: chartData)
                    .frame(height: 200)

                // Real Chart stats
                HStack {
                    ChartStatItem(
                        title: "High 24h",
                        value: "$\(String(format: "%.2f", coinData.marketData.high24h["usd"] ?? 0))",
                        color: WpayinColors.success
                    )
                    ChartStatItem(
                        title: "Low 24h",
                        value: "$\(String(format: "%.2f", coinData.marketData.low24h["usd"] ?? 0))",
                        color: WpayinColors.error
                    )
                    ChartStatItem(
                        title: "Volume 24h",
                        value: formatLargeNumber(coinData.marketData.totalVolume["usd"] ?? 0),
                        color: WpayinColors.primary
                    )
                }
            }
        }
        .padding(24)
        .background(WpayinColors.surface)
        .cornerRadius(20)
    }

    private func formatLargeNumber(_ number: Double) -> String {
        let billion = 1_000_000_000.0
        let million = 1_000_000.0

        if number >= billion {
            return "$\(String(format: "%.1f", number / billion))B"
        } else if number >= million {
            return "$\(String(format: "%.1f", number / million))M"
        } else {
            return "$\(String(format: "%.0f", number))"
        }
    }
}

struct PriceChartView: View {
    let chartData: CoinChartData

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard !chartData.prices.isEmpty else { return }

                let prices = chartData.prices.map { $0[1] }
                let minPrice = prices.min() ?? 0
                let maxPrice = prices.max() ?? 0
                let priceRange = maxPrice - minPrice

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
                guard !chartData.prices.isEmpty else { return }

                let prices = chartData.prices.map { $0[1] }
                let minPrice = prices.min() ?? 0
                let maxPrice = prices.max() ?? 0
                let priceRange = maxPrice - minPrice

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
            Text(title)
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

    var body: some View {
        VStack(spacing: 20) {
            // Balance section
            VStack(spacing: 12) {
                Text("Your Balance")
                    .font(.wpayinBody)
                    .foregroundColor(WpayinColors.textSecondary)

                Text(String(format: "%.6f", token.balance) + " \(token.symbol)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(WpayinColors.text)

                Text("≈ $" + String(format: "%.2f", token.totalValue))
                    .font(.wpayinBody)
                    .foregroundColor(WpayinColors.textSecondary)
            }

            // Action buttons
            HStack(spacing: 12) {
                AssetActionButton(
                    icon: "arrow.down.circle.fill",
                    title: "Deposit",
                    subtitle: "Add \(token.symbol)",
                    color: WpayinColors.success,
                    action: onDeposit
                )

                AssetActionButton(
                    icon: "arrow.up.circle.fill",
                    title: "Send",
                    subtitle: "Transfer out",
                    color: WpayinColors.primary,
                    action: onWithdraw
                )

                AssetActionButton(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Swap",
                    subtitle: "Exchange",
                    color: WpayinColors.primary,
                    action: onSwap
                )
            }
        }
        .padding(24)
        .background(WpayinColors.surface)
        .cornerRadius(20)
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
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(color)

                VStack(spacing: 2) {
                    Text(title)
                        .font(.wpayinBody)
                        .foregroundColor(WpayinColors.text)

                    Text(subtitle)
                        .font(.wpayinCaption)
                        .foregroundColor(WpayinColors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(WpayinColors.surfaceLight)
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RealAssetStatsView: View {
    let token: Token
    let coinData: CoinData

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Token Details")
                .font(.wpayinHeadline)
                .foregroundColor(WpayinColors.text)

            VStack(spacing: 12) {
                StatRow(
                    title: "Market Cap",
                    value: formatLargeNumber(coinData.marketData.marketCap["usd"] ?? 0)
                )
                StatRow(
                    title: "24h Volume",
                    value: formatLargeNumber(coinData.marketData.totalVolume["usd"] ?? 0)
                )
                if let supply = coinData.marketData.circulatingSupply {
                    StatRow(
                        title: "Circulating Supply",
                        value: formatSupply(supply) + " \(token.symbol)"
                    )
                }
                if let totalSupply = coinData.marketData.totalSupply {
                    StatRow(
                        title: "Total Supply",
                        value: formatSupply(totalSupply) + " \(token.symbol)"
                    )
                }
                if let contractAddress = token.contractAddress {
                    StatRow(
                        title: "Contract Address",
                        value: formatAddress(contractAddress)
                    )
                } else {
                    StatRow(
                        title: "Network",
                        value: token.blockchain.name + " Native Token"
                    )
                }
            }
        }
        .padding(24)
        .background(WpayinColors.surface)
        .cornerRadius(20)
    }

    private func formatLargeNumber(_ number: Double) -> String {
        let billion = 1_000_000_000.0
        let million = 1_000_000.0

        if number >= billion {
            return "$\(String(format: "%.1f", number / billion))B"
        } else if number >= million {
            return "$\(String(format: "%.1f", number / million))M"
        } else {
            return "$\(String(format: "%.0f", number))"
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Token Details")
                .font(.wpayinHeadline)
                .foregroundColor(WpayinColors.text)

            VStack(spacing: 12) {
                StatRow(title: "Market Cap", value: "$456.7B")
                StatRow(title: "24h Volume", value: "$12.3B")
                StatRow(title: "Circulating Supply", value: "120.3M \(token.symbol)")
                StatRow(title: "Contract Address", value: formatAddress(token.contractAddress ?? "N/A"))
            }
        }
        .padding(24)
        .background(WpayinColors.surface)
        .cornerRadius(20)
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
            Text(title)
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

    var relevantTransactions: [Transaction] {
        return walletManager.transactions
            .filter { $0.token == token.symbol }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Transactions")
                    .font(.wpayinHeadline)
                    .foregroundColor(WpayinColors.text)

                Spacer()

                Button("View All") {
                    // Navigate to full transaction history
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

                    Text("No transactions yet")
                        .font(.wpayinBody)
                        .foregroundColor(WpayinColors.textSecondary)

                    Text("Your \(token.symbol) transactions will appear here")
                        .font(.wpayinCaption)
                        .foregroundColor(WpayinColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                VStack(spacing: 12) {
                    ForEach(relevantTransactions, id: \.id) { transaction in
                        NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
                            TransactionRowView(transaction: transaction)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .padding(24)
        .background(WpayinColors.surface)
        .cornerRadius(20)
    }
}


#Preview {
    AssetDetailView(token: Token.mockTokens[0])
        .environmentObject(WalletManager())
}