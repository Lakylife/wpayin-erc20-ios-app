//
//  ActivityView.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI
import UIKit

struct ActivityView: View {
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var selectedFilter: TransactionFilter = .all
    @State private var searchText = ""
    @State private var selectedTransaction: Transaction?
    @State private var showTransactionDetail = false

    private var filteredTransactions: [Transaction] {
        var transactions = walletManager.transactions

        // Filter by type
        if selectedFilter != .all {
            transactions = transactions.filter { transaction in
                switch selectedFilter {
                case .sent:
                    return transaction.type == .send
                case .received:
                    return transaction.type == .receive
                case .swapped:
                    return transaction.type == .swap
                case .all:
                    return true
                }
            }
        }

        // Filter by search text
        if !searchText.isEmpty {
            transactions = transactions.filter { transaction in
                transaction.hash.lowercased().contains(searchText.lowercased()) ||
                transaction.token.lowercased().contains(searchText.lowercased())
            }
        }

        return transactions.sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        ZStack {
            // Background gradient matching mockup
            LinearGradient(
                gradient: Gradient(colors: [
                    WpayinColors.backgroundGradientStart,
                    WpayinColors.backgroundGradientEnd
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(.all)

            VStack(spacing: 0) {
                // Modern Header
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 50)

                    HStack {
                        Text(L10n.Wallet.activity.localized)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(WpayinColors.text)

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    // Search Bar
                    SearchBar(text: $searchText)
                        .padding(.horizontal, 20)

                    // Filter Tabs
                    FilterTabsView(selectedFilter: $selectedFilter)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                }
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            WpayinColors.headerBackground,
                            Color.clear
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Transaction List
                if filteredTransactions.isEmpty {
                    EmptyStateView(filter: selectedFilter, searchText: searchText)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredTransactions) { transaction in
                                Button(action: {
                                    print("🔵 Transaction tapped: \(transaction.hash)")
                                    selectedTransaction = transaction
                                    showTransactionDetail = true
                                    print("🔵 showTransactionDetail set to: \(showTransactionDetail)")
                                }) {
                                    TransactionRowView(transaction: transaction)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.horizontal, 20)
                            }

                            // Bottom padding for tab bar
                            Spacer()
                                .frame(height: 100)
                        }
                        .padding(.top, 20)
                    }
                    .refreshable {
                        await walletManager.refreshWalletData()
                    }
                }
            }
        }
        .sheet(isPresented: $showTransactionDetail) {
            if let transaction = selectedTransaction {
                TransactionDetailView(transaction: transaction)
                    .environmentObject(settingsManager)
                    .onAppear {
                        print("🟢 TransactionDetailView opened for: \(transaction.hash)")
                    }
            }
        }
        .onChange(of: showTransactionDetail) { newValue in
            print("🟡 showTransactionDetail changed to: \(newValue)")
            if !newValue {
                print("🔴 Sheet dismissed")
            }
        }
    }
}

enum TransactionFilter: String, CaseIterable {
    case all = "All"
    case sent = "Sent"
    case received = "Received"
    case swapped = "Swapped"

    var displayName: String {
        return self.rawValue
    }
}

struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(WpayinColors.textSecondary)

            TextField("Search transactions...", text: $text)
                .font(.wpayinBody)
                .foregroundColor(WpayinColors.text)

            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(WpayinColors.textSecondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(WpayinColors.surface)
        .cornerRadius(12)
    }
}

struct FilterTabsView: View {
    @Binding var selectedFilter: TransactionFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TransactionFilter.allCases, id: \.self) { filter in
                    FilterTab(
                        title: filter.displayName,
                        isSelected: selectedFilter == filter
                    ) {
                        selectedFilter = filter
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

struct FilterTab: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.wpayinBody)
                .foregroundColor(isSelected ? WpayinColors.secondary : WpayinColors.textSecondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(isSelected ? WpayinColors.primary : WpayinColors.surface)
                .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct TransactionRowView: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 16) {
            // Transaction Icon
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 44, height: 44)

                Image(systemName: iconName)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
            }

            // Transaction Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(transaction.type.displayName)
                        .font(.wpayinBody)
                        .foregroundColor(WpayinColors.text)

                    Spacer()

                    Text(amountText)
                        .font(.wpayinBody)
                        .foregroundColor(amountColor)
                }

                HStack {
                    Text(addressText)
                        .font(.wpayinCaption)
                        .foregroundColor(WpayinColors.textSecondary)

                    Spacer()

                    Text(transaction.timestamp, style: .relative)
                        .font(.wpayinCaption)
                        .foregroundColor(WpayinColors.textSecondary)
                }

                // Status Badge
                HStack {
                    StatusBadge(status: transaction.status)
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(WpayinColors.surface)
        .cornerRadius(16)
    }

    private var iconName: String {
        switch transaction.type {
        case .send:
            return "arrow.up"
        case .receive:
            return "arrow.down"
        case .swap:
            return "arrow.left.arrow.right"
        case .deposit:
            return "plus"
        case .withdraw:
            return "minus"
        }
    }

    private var iconColor: Color {
        switch transaction.type {
        case .send:
            return WpayinColors.error
        case .receive:
            return WpayinColors.success
        case .swap:
            return WpayinColors.primary
        case .deposit:
            return WpayinColors.success
        case .withdraw:
            return WpayinColors.primary
        }
    }

    private var iconBackgroundColor: Color {
        iconColor.opacity(0.2)
    }

    private var amountText: String {
        let sign = transaction.type == .receive || transaction.type == .deposit ? "+" : "-"
        return "\(sign)" + String(format: "%.4f", transaction.amount) + " \(transaction.token)"
    }

    private var amountColor: Color {
        switch transaction.type {
        case .receive, .deposit:
            return WpayinColors.success
        case .send, .withdraw:
            return WpayinColors.error
        case .swap:
            return WpayinColors.text
        }
    }

    private var addressText: String {
        let address = transaction.type == .send ? transaction.to : transaction.from
        return "\(address.prefix(6))...\(address.suffix(4))"
    }
}

struct StatusBadge: View {
    let status: Transaction.TransactionStatus

    var body: some View {
        Text(status.displayName)
            .font(.wpayinSmall)
            .foregroundColor(textColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(12)
    }

    private var backgroundColor: Color {
        switch status {
        case .pending:
            return WpayinColors.primary.opacity(0.2)
        case .confirmed:
            return WpayinColors.success.opacity(0.2)
        case .failed:
            return WpayinColors.error.opacity(0.2)
        }
    }

    private var textColor: Color {
        switch status {
        case .pending:
            return WpayinColors.primary
        case .confirmed:
            return WpayinColors.success
        case .failed:
            return WpayinColors.error
        }
    }
}

struct EmptyStateView: View {
    let filter: TransactionFilter
    let searchText: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 64))
                .foregroundColor(WpayinColors.textSecondary)

            VStack(spacing: 8) {
                Text(emptyTitle)
                    .font(.wpayinHeadline)
                    .foregroundColor(WpayinColors.text)

                Text(emptyMessage)
                    .font(.wpayinBody)
                    .foregroundColor(WpayinColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(.horizontal, 40)
    }

    private var emptyTitle: String {
        if !searchText.isEmpty {
            return "No Results Found"
        }

        switch filter {
        case .all:
            return "No Transactions Yet"
        case .sent:
            return "No Sent Transactions"
        case .received:
            return "No Received Transactions"
        case .swapped:
            return "No Swap Transactions"
        }
    }

    private var emptyMessage: String {
        if !searchText.isEmpty {
            return "Try adjusting your search terms or filters"
        }

        return "Your transaction history will appear here once you start using your wallet."
    }
}


#Preview {
    ActivityView()
        .environmentObject({
            let manager = WalletManager()
            manager.transactions = Transaction.mockTransactions
            return manager
        }())
}