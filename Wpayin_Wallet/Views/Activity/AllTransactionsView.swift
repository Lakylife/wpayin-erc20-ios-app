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
    @State private var visibleTransactionCount = 20

    private let pageSize = 20

    private var tokenTransactions: [Transaction] {
        // Scoped to the token's own network — each chain has its own history.
        walletManager.transactions
            .filter {
                $0.token.caseInsensitiveCompare(token.symbol) == .orderedSame &&
                $0.resolvedBlockchain == token.blockchain
            }
            .sorted { $0.timestamp > $1.timestamp }
    }

    private var visibleTransactions: [Transaction] {
        Array(tokenTransactions.prefix(visibleTransactionCount))
    }

    private var hasMoreTransactions: Bool {
        visibleTransactions.count < tokenTransactions.count
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

            if walletManager.isLoading && tokenTransactions.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(WpayinColors.primary)

                    Text(L10n.Wallet.syncing.localized)
                        .font(.wpayinBody)
                        .foregroundColor(WpayinColors.textSecondary)
                }
            } else if tokenTransactions.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundColor(WpayinColors.primary)
                        .frame(width: 72, height: 72)
                        .background(Circle().fill(WpayinColors.primary.opacity(0.12)))

                    Text(L10n.Activity.noTransactions.localized)
                        .font(.wpayinHeadline)
                        .foregroundColor(WpayinColors.text)

                    Text(L10n.Activity.tokenEmptyDesc.localized(token.symbol))
                        .font(.wpayinBody)
                        .foregroundColor(WpayinColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(WpayinColors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                        )
                )
                .padding(20)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 22) {
                        ActivityOverviewCard(transactions: tokenTransactions)

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
        .navigationTitle("%@ Transactions".localized("\(token.symbol) · \(token.blockchain.name)"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedTransaction) { transaction in
            TransactionDetailView(transaction: transaction)
                .environmentObject(walletManager)
                .environmentObject(settingsManager)
        }
    }

    private func loadNextPage() {
        guard hasMoreTransactions else { return }

        withAnimation(.easeOut(duration: 0.2)) {
            visibleTransactionCount = min(
                visibleTransactionCount + pageSize,
                tokenTransactions.count
            )
        }
    }
}
