//
//  TransactionDetailView.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 19.10.2025.
//

import SwiftUI

struct TransactionDetailView: View {
    let transaction: Transaction
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settingsManager: SettingsManager

    private var estimatedValue: Double {
        // Estimate value - could be enhanced with real-time prices
        transaction.amount * 2000 // Placeholder: assume ~$2000 per ETH
    }

    private var nativeSymbol: String {
        // Extract blockchain from explorerUrl or default to ETH
        if let url = transaction.explorerUrl?.absoluteString {
            if url.contains("polygonscan") { return "MATIC" }
            if url.contains("bscscan") { return "BNB" }
            if url.contains("arbiscan") { return "ETH" }
            if url.contains("optimistic") { return "ETH" }
            if url.contains("snowtrace") { return "AVAX" }
            if url.contains("basescan") { return "ETH" }
        }
        return "ETH"
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Status Icon
                    ZStack {
                        Circle()
                            .fill(statusColor.opacity(0.15))
                            .frame(width: 80, height: 80)

                        Image(systemName: statusIcon)
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundColor(statusColor)
                    }
                    .padding(.top, 20)

                    // Amount
                    VStack(spacing: 8) {
                        Text("\(transaction.type == .send ? "-" : "+")\(String(format: "%.6f", transaction.amount)) \(transaction.token)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(WpayinColors.text)

                        // Value in USD (calculated from amount * token price if available)
                        if transaction.amount > 0 {
                            Text(estimatedValue.formatted(as: settingsManager.selectedCurrency))
                                .font(.system(size: 18))
                                .foregroundColor(WpayinColors.textSecondary)
                        }
                    }

                    // Status Badge
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)

                        Text(transaction.status.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(statusColor)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(statusColor.opacity(0.15))
                    )

                    // Transaction Details
                    VStack(spacing: 0) {
                        DetailRow(title: "Type", value: transaction.type.displayName)
                        Divider().background(WpayinColors.surfaceBorder)
                        DetailRow(title: "Date", value: formatDate(transaction.timestamp))
                        Divider().background(WpayinColors.surfaceBorder)
                        DetailRow(title: "Network", value: "Ethereum") // Simplified
                        Divider().background(WpayinColors.surfaceBorder)
                        DetailRow(title: "Transaction Hash", value: transaction.hash, isCopyable: true)

                        Divider().background(WpayinColors.surfaceBorder)
                        DetailRow(title: "To", value: transaction.to, isCopyable: true)

                        Divider().background(WpayinColors.surfaceBorder)
                        DetailRow(title: "From", value: transaction.from, isCopyable: true)

                        if transaction.gasFee > 0 {
                            Divider().background(WpayinColors.surfaceBorder)
                            DetailRow(title: "Gas Fee", value: "\(String(format: "%.6f", transaction.gasFee)) \(nativeSymbol)")
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(WpayinColors.surface)
                    )
                    .padding(.horizontal, 20)

                    // View on Explorer Button
                    Button(action: {
                        if let url = explorerURL {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 16, weight: .semibold))

                            Text("View on Explorer")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(WpayinColors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(WpayinColors.primary.opacity(0.1))
                        )
                    }
                    .padding(.horizontal, 20)

                    Spacer()
                }
                .padding(.bottom, 40)
            }
            .background(WpayinColors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Transaction Details")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(WpayinColors.text)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(WpayinColors.textSecondary)
                            .padding(8)
                            .background(Circle().fill(WpayinColors.surface))
                    }
                }
            }
        }
    }

    private var statusIcon: String {
        switch transaction.status {
        case .confirmed:
            return "checkmark.circle.fill"
        case .pending:
            return "clock.fill"
        case .failed:
            return "xmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch transaction.status {
        case .confirmed:
            return WpayinColors.success
        case .pending:
            return WpayinColors.warning
        case .failed:
            return WpayinColors.error
        }
    }

    private var explorerURL: URL? {
        // Use the explorerUrl from transaction if available, otherwise construct from hash
        if let url = transaction.explorerUrl {
            return url
        }
        // Fallback to Etherscan for transactions without explorerUrl
        return URL(string: "https://etherscan.io/tx/" + transaction.hash)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    var isCopyable: Bool = false
    @State private var showCopied = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(WpayinColors.textSecondary)
                .frame(width: 100, alignment: .leading)

            Spacer()

            HStack(spacing: 8) {
                Text(formatValue(value))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(WpayinColors.text)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(isCopyable ? 1 : nil)

                if isCopyable {
                    Button(action: {
                        UIPasteboard.general.string = value
                        showCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showCopied = false
                        }
                    }) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12))
                            .foregroundColor(showCopied ? WpayinColors.success : WpayinColors.primary)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func formatValue(_ value: String) -> String {
        // Format long addresses
        if value.count > 20 && (value.hasPrefix("0x") || value.count > 40) {
            return "\(value.prefix(6))...\(value.suffix(4))"
        }
        return value
    }
}
