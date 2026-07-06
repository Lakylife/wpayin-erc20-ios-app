// Autor Lukas Helebrandt, 2026

//
//  ActivityView.swift
//  Wpayin_Wallet
//

import SwiftUI

struct ActivityView: View {
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var selectedFilter: TransactionFilter = .all
    @State private var selectedNetwork: BlockchainType?   // nil = all networks
    @State private var searchText = ""
    @State private var selectedTransaction: Transaction?
    @State private var visibleTransactionCount = 20

    private let pageSize = 20

    /// Networks that actually appear in the loaded history, in a stable order.
    private var availableNetworks: [BlockchainType] {
        let present = Set(walletManager.transactions.map { $0.resolvedBlockchain })
        return BlockchainType.allCases.filter { present.contains($0) }
    }

    private var filteredTransactions: [Transaction] {
        var transactions = walletManager.transactions

        if let selectedNetwork {
            transactions = transactions.filter { $0.resolvedBlockchain == selectedNetwork }
        }

        switch selectedFilter {
        case .all:
            break
        case .sent:
            transactions = transactions.filter { $0.type == .send || $0.type == .withdraw }
        case .received:
            transactions = transactions.filter { $0.type == .receive || $0.type == .deposit }
        case .swapped:
            transactions = transactions.filter { $0.type == .swap }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            transactions = transactions.filter {
                $0.hash.lowercased().contains(query) ||
                $0.token.lowercased().contains(query) ||
                $0.from.lowercased().contains(query) ||
                $0.to.lowercased().contains(query)
            }
        }

        return transactions.sorted { $0.timestamp > $1.timestamp }
    }

    private var visibleTransactions: [Transaction] {
        Array(filteredTransactions.prefix(visibleTransactionCount))
    }

    private var hasMoreTransactions: Bool {
        visibleTransactions.count < filteredTransactions.count
    }

    var body: some View {
        ZStack {
            activityBackground

            VStack(spacing: 0) {
                activityHeader

                if walletManager.isLoading && walletManager.transactions.isEmpty {
                    ActivityLoadingState()
                } else if filteredTransactions.isEmpty {
                    ScrollView(showsIndicators: false) {
                        ActivityEmptyState(
                            filter: selectedFilter,
                            hasSearch: !searchText.isEmpty
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 28)
                    }
                    .refreshable {
                        await walletManager.refreshWalletData()
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 22) {
                            ActivityOverviewCard(transactions: walletManager.transactions)

                            TransactionHistorySections(
                                transactions: visibleTransactions,
                                onSelect: { selectedTransaction = $0 }
                            )

                            if hasMoreTransactions {
                                ActivityLoadMoreView {
                                    loadNextPage()
                                }
                            }

                            Spacer()
                                .frame(height: 96)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                    .refreshable {
                        await walletManager.refreshWalletData()
                    }
                }
            }
        }
        .sheet(item: $selectedTransaction) { transaction in
            TransactionDetailView(transaction: transaction)
                .environmentObject(walletManager)
                .environmentObject(settingsManager)
        }
        .onChange(of: selectedFilter) { _ in
            resetPagination()
        }
        .onChange(of: selectedNetwork) { _ in
            resetPagination()
        }
        .onChange(of: searchText) { _ in
            resetPagination()
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

    private var activityBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    WpayinColors.backgroundGradientStart,
                    WpayinColors.backgroundGradientEnd
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(WpayinColors.primary.opacity(0.08))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: 150, y: -300)
        }
        .ignoresSafeArea()
    }

    private var activityHeader: some View {
        VStack(spacing: 16) {
            HStack {
                Text(L10n.Activity.title.localized)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(WpayinColors.text)

                Spacer()

                Button {
                    Task {
                        await walletManager.refreshWalletData()
                    }
                } label: {
                    Group {
                        if walletManager.isLoading {
                            ProgressView()
                                .tint(WpayinColors.primary)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(WpayinColors.primary)
                        }
                    }
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(WpayinColors.surfaceLight))
                    .overlay(
                        Circle()
                            .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(walletManager.isLoading)
            }

            ActivitySearchBar(text: $searchText)
            ActivityFilterTabs(selectedFilter: $selectedFilter)

            if availableNetworks.count > 1 {
                ActivityNetworkTabs(
                    selectedNetwork: $selectedNetwork,
                    networks: availableNetworks
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(
            LinearGradient(
                colors: [
                    WpayinColors.primary.opacity(0.12),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func resetPagination() {
        visibleTransactionCount = pageSize
    }

    private func loadNextPage() {
        guard hasMoreTransactions else { return }

        withAnimation(.easeOut(duration: 0.22)) {
            visibleTransactionCount = min(
                visibleTransactionCount + pageSize,
                filteredTransactions.count
            )
        }
    }
}

enum TransactionFilter: CaseIterable {
    case all
    case sent
    case received
    case swapped

    var displayName: String {
        switch self {
        case .all: return L10n.Activity.filterAll.localized
        case .sent: return L10n.Activity.filterSent.localized
        case .received: return L10n.Activity.filterReceived.localized
        case .swapped: return L10n.Activity.filterSwapped.localized
        }
    }

    var icon: String {
        switch self {
        case .all: return "square.stack.3d.up.fill"
        case .sent: return "arrow.up"
        case .received: return "arrow.down"
        case .swapped: return "arrow.left.arrow.right"
        }
    }
}

struct ActivitySearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(WpayinColors.textSecondary)

            TextField(L10n.Activity.search.localized, text: $text)
                .font(.wpayinBody)
                .foregroundColor(WpayinColors.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(WpayinColors.textTertiary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(WpayinColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                )
        )
    }
}

struct ActivityFilterTabs: View {
    @Binding var selectedFilter: TransactionFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(TransactionFilter.allCases, id: \.self) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: filter.icon)
                                .font(.system(size: 11, weight: .semibold))

                            Text(filter.displayName)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                        }
                        .foregroundColor(
                            selectedFilter == filter
                                ? WpayinColors.text
                                : WpayinColors.textSecondary
                        )
                        .padding(.horizontal, 15)
                        .frame(height: 38)
                        .background(
                            Capsule()
                                .fill(
                                    selectedFilter == filter
                                        ? WpayinColors.primary.opacity(0.22)
                                        : WpayinColors.surface
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            selectedFilter == filter
                                                ? WpayinColors.primary.opacity(0.65)
                                                : WpayinColors.surfaceBorder,
                                            lineWidth: 1
                                        )
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 1)
        }
    }
}

/// Per-network filter row — every chain keeps its own history.
struct ActivityNetworkTabs: View {
    @Binding var selectedNetwork: BlockchainType?
    let networks: [BlockchainType]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                chip(
                    isSelected: selectedNetwork == nil,
                    action: { selectedNetwork = nil }
                ) {
                    Text("All Networks".localized)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                }

                ForEach(networks, id: \.self) { network in
                    chip(
                        isSelected: selectedNetwork == network,
                        action: { selectedNetwork = network }
                    ) {
                        HStack(spacing: 7) {
                            NetworkIconView(blockchain: network, size: 17)

                            Text(network.name)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private func chip<Content: View>(
        isSelected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button(action: action) {
            content()
                .foregroundColor(isSelected ? WpayinColors.text : WpayinColors.textSecondary)
                .padding(.horizontal, 13)
                .frame(height: 34)
                .background(
                    Capsule()
                        .fill(isSelected ? WpayinColors.primary.opacity(0.22) : WpayinColors.surface)
                        .overlay(
                            Capsule()
                                .stroke(
                                    isSelected ? WpayinColors.primary.opacity(0.65) : WpayinColors.surfaceBorder,
                                    lineWidth: 1
                                )
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ActivityOverviewCard: View {
    let transactions: [Transaction]

    private var sentCount: Int {
        transactions.filter { $0.type == .send || $0.type == .withdraw }.count
    }

    private var receivedCount: Int {
        transactions.filter { $0.type == .receive || $0.type == .deposit }.count
    }

    private var swappedCount: Int {
        transactions.filter { $0.type == .swap }.count
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack(alignment: .center) {
                HStack(spacing: 12) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Color.white.opacity(0.12)))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.Activity.overview.localized)
                            .font(.wpayinCaption)
                            .foregroundColor(Color.white.opacity(0.7))

                        Text(L10n.Activity.transactions.localized)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }

                Spacer()

                Text("\(transactions.count)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            Divider()
                .overlay(Color.white.opacity(0.14))

            HStack(spacing: 8) {
                ActivityOverviewMetric(
                    title: L10n.Activity.filterSent.localized,
                    value: sentCount,
                    icon: "arrow.up",
                    color: WpayinColors.error
                )

                ActivityOverviewMetric(
                    title: L10n.Activity.filterReceived.localized,
                    value: receivedCount,
                    icon: "arrow.down",
                    color: WpayinColors.success
                )

                ActivityOverviewMetric(
                    title: L10n.Activity.filterSwapped.localized,
                    value: swappedCount,
                    icon: "arrow.left.arrow.right",
                    color: Color.white
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            WpayinColors.primary.opacity(0.82),
                            WpayinColors.primaryDark.opacity(0.62),
                            WpayinColors.surface
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: WpayinColors.primary.opacity(0.16), radius: 20, y: 10)
        )
    }
}

private struct ActivityOverviewMetric: View {
    let title: String
    let value: Int
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(color)

            Text("\(value)")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(Color.white.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
    }
}

struct TransactionHistorySections: View {
    let transactions: [Transaction]
    let onSelect: (Transaction) -> Void
    @EnvironmentObject private var settingsManager: SettingsManager

    private var groups: [TransactionDayGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: transactions) {
            calendar.startOfDay(for: $0.timestamp)
        }

        return grouped
            .map { TransactionDayGroup(date: $0.key, transactions: $0.value.sorted { $0.timestamp > $1.timestamp }) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(spacing: 22) {
            ForEach(groups) { group in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(sectionTitle(for: group.date))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(WpayinColors.text)

                        Spacer()

                        Text("\(group.transactions.count)")
                            .font(.wpayinSmall)
                            .foregroundColor(WpayinColors.textSecondary)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(WpayinColors.surfaceLight))
                    }

                    VStack(spacing: 10) {
                        ForEach(group.transactions) { transaction in
                            Button {
                                onSelect(transaction)
                            } label: {
                                TransactionRowView(transaction: transaction)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
    }

    private func sectionTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return L10n.Activity.today.localized
        }
        if calendar.isDateInYesterday(date) {
            return L10n.Activity.yesterday.localized
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: settingsManager.selectedLanguage.rawValue)
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

private struct TransactionDayGroup: Identifiable {
    let date: Date
    let transactions: [Transaction]
    var id: Date { date }
}

struct TransactionRowView: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 13) {
            TransactionTokenIcon(transaction: transaction, size: 46)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(transaction.type.displayName)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(WpayinColors.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    CompactStatusBadge(status: transaction.status)
                }

                HStack(spacing: 6) {
                    NetworkIconView(blockchain: transaction.resolvedBlockchain, size: 13)

                    Text(transaction.resolvedBlockchain.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(WpayinColors.textTertiary)
                        .lineLimit(1)

                    Text(transaction.counterpartyShortAddress)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(WpayinColors.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 7) {
                Text(transaction.formattedActivityAmount)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(transaction.activityColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)

                Text(transaction.timestamp, style: .time)
                    .font(.wpayinSmall)
                    .foregroundColor(WpayinColors.textSecondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(WpayinColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
    }
}

struct TransactionTokenIcon: View {
    let transaction: Transaction
    let size: CGFloat
    @EnvironmentObject private var walletManager: WalletManager

    private var token: Token {
        walletManager.tokens.first {
            $0.symbol.caseInsensitiveCompare(transaction.token) == .orderedSame &&
            $0.blockchain == transaction.resolvedBlockchain
        } ?? walletManager.tokens.first {
            $0.symbol.caseInsensitiveCompare(transaction.token) == .orderedSame
        } ?? Token(
            contractAddress: nil,
            name: transaction.token,
            symbol: transaction.token,
            decimals: 18,
            balance: 0,
            price: 0,
            iconUrl: nil,
            blockchain: transaction.resolvedBlockchain,
            isNative: transaction.resolvedBlockchain.nativeToken.caseInsensitiveCompare(transaction.token) == .orderedSame
        )
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TokenIconView(token: token, size: size, showNetworkBadge: false)
                .frame(width: size, height: size)

            Circle()
                .fill(transaction.activityColor)
                .frame(width: size * 0.42, height: size * 0.42)
                .overlay(
                    Image(systemName: transaction.activityIcon)
                        .font(.system(size: size * 0.18, weight: .bold))
                        .foregroundColor(.white)
                )
                .overlay(
                    Circle()
                        .stroke(WpayinColors.background, lineWidth: 2)
                )
                .offset(x: 2, y: 2)
        }
    }
}

struct CompactStatusBadge: View {
    let status: Transaction.TransactionStatus

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .accessibilityLabel(status.displayName)
    }

    private var color: Color {
        switch status {
        case .pending: return WpayinColors.warning
        case .confirmed: return WpayinColors.success
        case .failed: return WpayinColors.error
        }
    }
}

private struct ActivityLoadingState: View {
    var body: some View {
        VStack(spacing: 18) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(WpayinColors.primary)

            Text(L10n.Wallet.syncing.localized)
                .font(.wpayinBody)
                .foregroundColor(WpayinColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ActivityEmptyState: View {
    let filter: TransactionFilter
    let hasSearch: Bool

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: hasSearch ? "magnifyingglass" : filter.icon)
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(WpayinColors.primary)
                .frame(width: 74, height: 74)
                .background(Circle().fill(WpayinColors.primary.opacity(0.12)))

            VStack(spacing: 8) {
                Text(title)
                    .font(.wpayinHeadline)
                    .foregroundColor(WpayinColors.text)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.wpayinBody)
                    .foregroundColor(WpayinColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28)
        .padding(.vertical, 54)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(WpayinColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                )
        )
    }

    private var title: String {
        if hasSearch {
            return L10n.Activity.noResultsFound.localized
        }

        switch filter {
        case .all: return L10n.Activity.noTransactions.localized
        case .sent: return "No Sent Transactions".localized
        case .received: return "No Received Transactions".localized
        case .swapped: return "No Swap Transactions".localized
        }
    }

    private var message: String {
        hasSearch
            ? L10n.Activity.tryAdjusting.localized
            : L10n.Activity.emptyDesc.localized
    }
}

struct ActivityLoadMoreView: View {
    let onAppearAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(WpayinColors.primary)

            Text(L10n.Wallet.syncing.localized)
                .font(.wpayinCaption)
                .foregroundColor(WpayinColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .onAppear(perform: onAppearAction)
    }
}

extension Transaction {
    var activityIcon: String {
        switch type {
        case .send: return "arrow.up"
        case .receive: return "arrow.down"
        case .swap: return "arrow.left.arrow.right"
        case .deposit: return "plus"
        case .withdraw: return "minus"
        }
    }

    var activityColor: Color {
        switch type {
        case .send, .withdraw: return WpayinColors.error
        case .receive, .deposit: return WpayinColors.success
        case .swap: return WpayinColors.primary
        }
    }

    var activityAmountSign: String {
        switch type {
        case .receive, .deposit: return "+"
        case .send, .withdraw: return "-"
        case .swap: return ""
        }
    }

    var formattedActivityAmount: String {
        "\(activityAmountSign)\(String(format: "%.4f", amount)) \(token)"
    }

    var counterpartyShortAddress: String {
        let address = type == .send || type == .withdraw ? to : from
        guard address.count > 12 else { return address }
        return "\(address.prefix(6))…\(address.suffix(4))"
    }

    /// Real network of the transaction; explorer-URL inference only covers
    /// legacy cached entries that predate the `blockchain` field.
    var resolvedBlockchain: BlockchainType {
        blockchain ?? inferredBlockchain
    }

    var inferredBlockchain: BlockchainType {
        let url = explorerUrl?.absoluteString.lowercased() ?? ""

        if url.contains("polygon") { return .polygon }
        if url.contains("bsc") { return .bsc }
        if url.contains("arbi") { return .arbitrum }
        if url.contains("optim") { return .optimism }
        if url.contains("snowtrace") || url.contains("avalanche") { return .avalanche }
        if url.contains("base") { return .base }
        if url.contains("gnosis") { return .gnosis }
        if token.caseInsensitiveCompare("BTC") == .orderedSame { return .bitcoin }
        if token.caseInsensitiveCompare("SOL") == .orderedSame { return .solana }
        return .ethereum
    }
}

#Preview {
    ActivityView()
        .environmentObject(WalletManager())
        .environmentObject(SettingsManager())
}
