//
//  AllTransactionsView.swift
//  Wpayin_Wallet
//
//  View for displaying all transactions for a specific token
//

import SwiftUI

struct AllTransactionsView: View {
    let token: Token
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTransaction: Transaction?
    @State private var showTransactionDetail = false
    
    // Filter transactions for this token
    private var tokenTransactions: [Transaction] {
        walletManager.transactions
            .filter { $0.token == token.symbol }
            .sorted { $0.timestamp > $1.timestamp }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()
                
                if tokenTransactions.isEmpty {
                    // Empty State
                    VStack(spacing: 20) {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.system(size: 60))
                            .foregroundColor(WpayinColors.textTertiary)
                        
                        Text("No Transactions")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(WpayinColors.text)
                        
                        Text("Your \(token.symbol) transactions will appear here")
                            .font(.system(size: 16))
                            .foregroundColor(WpayinColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            // Stats Header
                            VStack(spacing: 16) {
                                HStack(spacing: 20) {
                                    StatCard(
                                        title: "Total",
                                        value: "\(tokenTransactions.count)",
                                        icon: "list.bullet"
                                    )
                                    
                                    StatCard(
                                        title: "Sent",
                                        value: "\(tokenTransactions.filter { $0.type == .send }.count)",
                                        icon: "arrow.up.circle.fill",
                                        color: .red
                                    )
                                    
                                    StatCard(
                                        title: "Received",
                                        value: "\(tokenTransactions.filter { $0.type == .receive }.count)",
                                        icon: "arrow.down.circle.fill",
                                        color: .green
                                    )
                                }
                                .padding(.horizontal, 20)
                            }
                            .padding(.vertical, 20)
                            
                            // Transactions List
                            VStack(spacing: 1) {
                                ForEach(tokenTransactions) { transaction in
                                    TransactionRow(transaction: transaction)
                                        .background(WpayinColors.surface)
                                        .onTapGesture {
                                            selectedTransaction = transaction
                                            showTransactionDetail = true
                                        }
                                }
                            }
                            .background(WpayinColors.surface)
                            .cornerRadius(16)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
            .navigationTitle("\(token.symbol) Transactions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(WpayinColors.text)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(WpayinColors.surface)
                            )
                    }
                }
            }
            .sheet(isPresented: $showTransactionDetail) {
                if let transaction = selectedTransaction {
                    TransactionDetailSheet(transaction: transaction)
                        .environmentObject(settingsManager)
                }
            }
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = WpayinColors.primary
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(WpayinColors.text)
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(WpayinColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(WpayinColors.surface)
        )
    }
}

// MARK: - Transaction Row

struct TransactionRow: View {
    let transaction: Transaction
    @EnvironmentObject var settingsManager: SettingsManager
    
    private var typeIcon: String {
        switch transaction.type {
        case .send: return "arrow.up.circle.fill"
        case .receive: return "arrow.down.circle.fill"
        case .swap: return "arrow.2.squarepath"
        case .deposit: return "arrow.down.to.line.circle.fill"
        case .withdraw: return "arrow.up.to.line.circle.fill"
        }
    }
    
    private var typeColor: Color {
        switch transaction.type {
        case .send, .withdraw: return .red
        case .receive, .deposit: return .green
        case .swap: return WpayinColors.primary
        }
    }
    
    private var statusColor: Color {
        switch transaction.status {
        case .confirmed: return .green
        case .pending: return .orange
        case .failed: return .red
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: typeIcon)
                .font(.system(size: 24))
                .foregroundColor(typeColor)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(typeColor.opacity(0.1))
                )
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(transaction.type.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(WpayinColors.text)
                    
                    // Status Badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 6, height: 6)
                        
                        Text(transaction.status.displayName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(statusColor)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(statusColor.opacity(0.1))
                    )
                }
                
                Text(formatDate(transaction.timestamp))
                    .font(.system(size: 13))
                    .foregroundColor(WpayinColors.textSecondary)
                
                Text(transaction.hash.prefix(16) + "...")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(WpayinColors.textTertiary)
            }
            
            Spacer()
            
            // Amount
            VStack(alignment: .trailing, spacing: 4) {
                Text(transaction.type == .send || transaction.type == .withdraw ? "-" : "+")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(typeColor)
                +
                Text(String(format: "%.4f", transaction.amount))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(WpayinColors.text)
                
                Text(transaction.token)
                    .font(.system(size: 13))
                    .foregroundColor(WpayinColors.textSecondary)
            }
        }
        .padding(16)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Transaction Detail Sheet

struct TransactionDetailSheet: View {
    let transaction: Transaction
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 16) {
                            Text(transaction.type.displayName)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(WpayinColors.text)
                            
                            Text(String(format: "%.6f %@", transaction.amount, transaction.token))
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(WpayinColors.text)
                        }
                        .padding(.top, 20)
                        
                        // Details
                        VStack(spacing: 16) {
                            TransactionDetailRow(title: "Status", value: transaction.status.displayName)
                            TransactionDetailRow(title: "From", value: formatAddress(transaction.from))
                            TransactionDetailRow(title: "To", value: formatAddress(transaction.to))
                            TransactionDetailRow(title: "Hash", value: transaction.hash)
                            
                            if let blockNumber = transaction.blockNumber {
                                TransactionDetailRow(title: "Block", value: blockNumber)
                            }
                            
                            TransactionDetailRow(title: "Gas Fee", value: String(format: "%.6f", transaction.gasFee))
                            TransactionDetailRow(title: "Timestamp", value: formatDate(transaction.timestamp))
                        }
                        .padding(.horizontal, 20)
                        
                        // View on Explorer
                        if let explorerUrl = transaction.explorerUrl {
                            Link(destination: explorerUrl) {
                                HStack {
                                    Image(systemName: "arrow.up.right.square")
                                    Text("View on Explorer")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(WpayinColors.primary)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(WpayinColors.primary)
                }
            }
        }
    }
    
    private func formatAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        return "\(address.prefix(6))...\(address.suffix(4))"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

struct TransactionDetailRow: View {
    let title: String
    let value: String
    @State private var copied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(WpayinColors.textSecondary)
            
            HStack {
                Text(value)
                    .font(.system(size: 15, design: .monospaced))
                    .foregroundColor(WpayinColors.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                Button(action: {
                    UIPasteboard.general.string = value
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copied = false
                    }
                }) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 14))
                        .foregroundColor(copied ? .green : WpayinColors.primary)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(WpayinColors.surface)
            )
        }
    }
}
