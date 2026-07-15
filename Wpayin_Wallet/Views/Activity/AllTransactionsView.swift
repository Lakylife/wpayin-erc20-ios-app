// Autor Lukas Helebrandt, 2026

//
//  AllTransactionsView.swift
//  Wpayin_Wallet
//
//  Complete transaction history for a specific token
//

import SwiftUI

struct AllTransactionsView: View {
    let token: Token

    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var selectedTransaction: Transaction?
    @State private var selectedNetwork: BlockchainType?
    @State private var selectedDateFilter: TransactionDateFilter = .all
    @State private var visibleTransactionCount = 20

    private let pageSize = 20

    private var allTokenTransactions: [Transaction] {
        walletManager.transactions
            .filter {
                $0.token.caseInsensitiveCompare(token.symbol) == .orderedSame
            }
            .sorted { $0.timestamp > $1.timestamp }
    }

    /// Include every network where the asset exists, plus networks found in
    /// older history even if that token variant is not currently displayed.
    private var availableNetworks: [BlockchainType] {
        let tokenNetworks = walletManager.tokens
            .filter { $0.symbol.caseInsensitiveCompare(token.symbol) == .orderedSame }
            .map(\.blockchain)
        let historyNetworks = allTokenTransactions.map(\.resolvedBlockchain)
        let present = Set([token.blockchain] + tokenNetworks + historyNetworks)

        return BlockchainType.allCases.filter { present.contains($0) }
    }

    private var filteredTransactions: [Transaction] {
        var transactions = allTokenTransactions

        if let selectedNetwork {
            transactions = transactions.filter { $0.resolvedBlockchain == selectedNetwork }
        }

        if let startDate = selectedDateFilter.startDate {
            transactions = transactions.filter { $0.timestamp >= startDate }
        }

        return transactions
    }

    private var visibleTransactions: [Transaction] {
        Array(filteredTransactions.prefix(visibleTransactionCount))
    }

    private var hasMoreTransactions: Bool {
        visibleTransactions.count < filteredTransactions.count
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    WpayinColors.backgroundGradientStart,
                    WpayinColors.backgroundGradientEnd
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    if availableNetworks.count > 1 {
                        Text("Network".localized)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(WpayinColors.textSecondary)

                        ActivityNetworkTabs(
                            selectedNetwork: $selectedNetwork,
                            networks: availableNetworks
                        )
                    }

                    HStack(spacing: 12) {
                        Label("Date".localized, systemImage: "calendar")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(WpayinColors.textSecondary)

                        Spacer()

                        Menu {
                            ForEach(TransactionDateFilter.allCases) { filter in
                                Button {
                                    selectedDateFilter = filter
                                } label: {
                                    Label(
                                        filter.title,
                                        systemImage: selectedDateFilter == filter
                                            ? "checkmark"
                                            : filter.icon
                                    )
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: selectedDateFilter.icon)
                                    .font(.system(size: 12, weight: .semibold))

                                Text(selectedDateFilter.title)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))

                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundColor(
                                selectedDateFilter == .all
                                    ? WpayinColors.textSecondary
                                    : WpayinColors.primary
                            )
                            .padding(.horizontal, 13)
                            .frame(height: 36)
                            .background(
                                Capsule()
                                    .fill(
                                        selectedDateFilter == .all
                                            ? WpayinColors.surface
                                            : WpayinColors.primary.opacity(0.16)
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(
                                                selectedDateFilter == .all
                                                    ? WpayinColors.surfaceBorder
                                                    : WpayinColors.primary.opacity(0.55),
                                                lineWidth: 1
                                            )
                                    )
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 12)
                .background(
                    LinearGradient(
                        colors: [WpayinColors.primary.opacity(0.10), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                if walletManager.isLoading && allTokenTransactions.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(WpayinColors.primary)

                        Text(L10n.Wallet.syncing.localized)
                            .font(.wpayinBody)
                            .foregroundColor(WpayinColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredTransactions.isEmpty {
                    ScrollView(showsIndicators: false) {
                        emptyState
                            .padding(20)
                    }
                    .refreshable {
                        await walletManager.refreshWalletData()
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 22) {
                            ActivityOverviewCard(transactions: filteredTransactions)

                            TransactionHistorySections(
                                transactions: visibleTransactions,
                                onSelect: { selectedTransaction = $0 }
                            )

                            if hasMoreTransactions {
                                ActivityLoadMoreView {
                                    loadNextPage()
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                    }
                    .refreshable {
                        await walletManager.refreshWalletData()
                    }
                }
            }
        }
        .navigationTitle("%@ Transactions".localized(token.symbol.uppercased()))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedTransaction) { transaction in
            TransactionDetailView(transaction: transaction)
                .environmentObject(walletManager)
                .environmentObject(settingsManager)
        }
        .onChange(of: selectedNetwork) { _ in
            visibleTransactionCount = pageSize
        }
        .onChange(of: selectedDateFilter) { _ in
            visibleTransactionCount = pageSize
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

    private var emptyState: some View {
        let hasActiveFilter = selectedNetwork != nil || selectedDateFilter != .all

        return VStack(spacing: 20) {
            Image(systemName: hasActiveFilter ? "line.3.horizontal.decrease.circle" : "clock.arrow.circlepath")
                .font(.system(size: 30, weight: .medium))
                .foregroundColor(WpayinColors.primary)
                .frame(width: 72, height: 72)
                .background(Circle().fill(WpayinColors.primary.opacity(0.12)))

            Text(
                hasActiveFilter
                    ? L10n.Activity.noResultsFound.localized
                    : L10n.Activity.noTransactions.localized
            )
            .font(.wpayinHeadline)
            .foregroundColor(WpayinColors.text)

            Text(
                hasActiveFilter
                    ? L10n.Activity.tryAdjusting.localized
                    : L10n.Activity.tokenEmptyDesc.localized(token.symbol)
            )
            .font(.wpayinBody)
            .foregroundColor(WpayinColors.textSecondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(WpayinColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                )
        )
    }

    private func loadNextPage() {
        guard hasMoreTransactions else { return }

        withAnimation(.easeOut(duration: 0.2)) {
            visibleTransactionCount = min(
                visibleTransactionCount + pageSize,
                filteredTransactions.count
            )
        }
    }
}

private enum TransactionDateFilter: String, CaseIterable, Identifiable {
    case all
    case today
    case sevenDays
    case thirtyDays
    case ninetyDays
    case oneYear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All time".localized
        case .today: return L10n.Activity.today.localized
        case .sevenDays: return "Last 7 days".localized
        case .thirtyDays: return "Last 30 days".localized
        case .ninetyDays: return "Last 90 days".localized
        case .oneYear: return "Last year".localized
        }
    }

    var icon: String {
        switch self {
        case .all: return "calendar"
        case .today: return "calendar.badge.clock"
        case .sevenDays, .thirtyDays, .ninetyDays, .oneYear: return "calendar.circle"
        }
    }

    var startDate: Date? {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .all:
            return nil
        case .today:
            return calendar.startOfDay(for: now)
        case .sevenDays:
            return calendar.date(byAdding: .day, value: -7, to: now)
        case .thirtyDays:
            return calendar.date(byAdding: .day, value: -30, to: now)
        case .ninetyDays:
            return calendar.date(byAdding: .day, value: -90, to: now)
        case .oneYear:
            return calendar.date(byAdding: .year, value: -1, to: now)
        }
    }
}
