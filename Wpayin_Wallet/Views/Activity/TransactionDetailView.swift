// Autor Lukas Helebrandt, 2026

//
//  TransactionDetailView.swift
//  Wpayin_Wallet
//

import SwiftUI
import UIKit

struct TransactionDetailView: View {
    let transaction: Transaction

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var walletManager: WalletManager
    @EnvironmentObject private var settingsManager: SettingsManager
    /// Live receipt result, refined while the view is open (pending txs only).
    @State private var liveStatus: Transaction.TransactionStatus?

    private var displayStatus: Transaction.TransactionStatus {
        liveStatus ?? transaction.status
    }

    private var fiatValue: Double? {
        walletManager.currentUSDValue(for: transaction)
    }

    private var gasFeeFiatValue: Double? {
        walletManager.currentGasFeeUSDValue(for: transaction)
    }

    var body: some View {
        NavigationView {
            ZStack {
                detailBackground

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        TransactionHeroCard(
                            transaction: transaction,
                            fiatValue: fiatValue,
                            status: displayStatus
                        )

                        TransactionProgressCard(status: displayStatus)

                        TransactionInformationCard(
                            transaction: transaction,
                            formattedDate: formattedDate,
                            networkName: transaction.resolvedBlockchain.name,
                            gasFeeFiatValue: gasFeeFiatValue
                        )

                        VStack(spacing: 12) {
                            TransactionCopyCard(
                                icon: "arrow.up.right",
                                title: "To".localized,
                                value: transaction.to
                            )

                            TransactionCopyCard(
                                icon: "arrow.down.left",
                                title: "From".localized,
                                value: transaction.from
                            )

                            TransactionCopyCard(
                                icon: "number",
                                title: "Transaction Hash".localized,
                                value: transaction.hash
                            )
                        }

                        if let explorerURL = transaction.explorerUrl {
                            Link(destination: explorerURL) {
                                HStack(spacing: 10) {
                                    Image(systemName: "safari")
                                        .font(.system(size: 16, weight: .semibold))

                                    Text(L10n.Activity.viewExplorer.localized)
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)

                                    Spacer()

                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 13, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 18)
                                .frame(height: 56)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            WpayinColors.primary,
                                            WpayinColors.primaryDark
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    in: RoundedRectangle(cornerRadius: 17, style: .continuous)
                                )
                                .shadow(color: WpayinColors.primary.opacity(0.22), radius: 16, y: 8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 36)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(L10n.Activity.details.localized)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(WpayinColors.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(WpayinColors.textSecondary)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(WpayinColors.surfaceLight))
                            .overlay(
                                Circle()
                                    .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .task {
                await watchPendingStatus()
            }
        }
    }

    /// While the shown transaction is still pending on an EVM chain, poll its
    /// receipt so the detail reflects the real on-chain phase live.
    private func watchPendingStatus() async {
        guard transaction.status == .pending,
              transaction.resolvedBlockchain.isEVM,
              !transaction.hash.isEmpty else { return }

        let deadline = Date().addingTimeInterval(15 * 60)
        while Date() < deadline, !Task.isCancelled {
            if let state = try? await SwapService.shared.fetchTransactionState(
                hash: transaction.hash,
                blockchain: transaction.resolvedBlockchain
            ) {
                switch state {
                case .notFound:
                    break
                case .pending:
                    break
                case .confirmed(let blockNumber, let gasUsed, let gasFeeNative):
                    await MainActor.run {
                        liveStatus = .confirmed
                        walletManager.updateLocalTransactionStatus(
                            hash: transaction.hash,
                            status: .confirmed,
                            gasUsed: gasUsed,
                            gasFee: gasFeeNative,
                            blockNumber: blockNumber
                        )
                    }
                    return
                case .failed(let blockNumber, let gasUsed, let gasFeeNative):
                    await MainActor.run {
                        liveStatus = .failed
                        walletManager.updateLocalTransactionStatus(
                            hash: transaction.hash,
                            status: .failed,
                            gasUsed: gasUsed,
                            gasFee: gasFeeNative,
                            blockNumber: blockNumber
                        )
                    }
                    return
                }
            }
            try? await Task.sleep(nanoseconds: 5_000_000_000)
        }
    }

    private var detailBackground: some View {
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
                .fill(transaction.activityColor.opacity(0.1))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(y: -320)
        }
        .ignoresSafeArea()
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: settingsManager.selectedLanguage.rawValue)
        formatter.timeZone = settingsManager.resolvedTimeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: transaction.timestamp)
    }
}

private struct TransactionHeroCard: View {
    let transaction: Transaction
    let fiatValue: Double?
    let status: Transaction.TransactionStatus

    var body: some View {
        VStack(spacing: 18) {
            HStack(alignment: .top) {
                TransactionTokenIcon(transaction: transaction, size: 68)

                Spacer()

                TransactionStatusPill(status: status)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(transaction.type.displayName)
                    .font(.wpayinCaption)
                    .foregroundColor(Color.white.opacity(0.72))

                Text(transactionDetailAmount)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Text(fiatValue.map { "\($0.formatted(as: .usd)) USD" } ?? "— USD")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            transaction.activityColor.opacity(0.68),
                            WpayinColors.primaryDark.opacity(0.52),
                            WpayinColors.surface
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: transaction.activityColor.opacity(0.14), radius: 22, y: 10)
        )
    }

    private var transactionDetailAmount: String {
        "\(transaction.activityAmountSign)\(String(format: "%.6f", transaction.amount)) \(transaction.token)"
    }
}

private struct TransactionStatusPill: View {
    let status: Transaction.TransactionStatus

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)

            Text(status.displayName)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 11)
        .frame(height: 32)
        .background(Capsule().fill(Color.black.opacity(0.2)))
        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    private var color: Color {
        switch status {
        case .pending: return WpayinColors.warning
        case .confirmed: return WpayinColors.success
        case .failed: return WpayinColors.error
        }
    }
}

private struct TransactionInformationCard: View {
    let transaction: Transaction
    let formattedDate: String
    let networkName: String
    let gasFeeFiatValue: Double?

    var body: some View {
        VStack(spacing: 0) {
            TransactionInformationRow(
                icon: "calendar",
                title: "Date".localized,
                value: formattedDate
            )

            Divider()
                .overlay(WpayinColors.surfaceBorder)
                .padding(.leading, 52)

            TransactionInformationRow(
                icon: "network",
                title: "Network".localized,
                value: networkName
            )

            if transaction.gasFee > 0 {
                Divider()
                    .overlay(WpayinColors.surfaceBorder)
                    .padding(.leading, 52)

                TransactionInformationRow(
                    icon: "fuelpump",
                    title: "Gas Fee".localized,
                    value: "\(String(format: "%.6f", transaction.gasFee)) \(transaction.resolvedBlockchain.nativeToken)\n\(gasFeeFiatValue.map { "\($0.formatted(as: .usd)) USD" } ?? "— USD")"
                )
            }

            if let blockNumber = transaction.blockNumber {
                Divider()
                    .overlay(WpayinColors.surfaceBorder)
                    .padding(.leading, 52)

                TransactionInformationRow(
                    icon: "cube",
                    title: "Block".localized,
                    value: blockNumber
                )
            }
        }
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

private struct TransactionInformationRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(WpayinColors.primary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(WpayinColors.primary.opacity(0.12)))

            Text(title)
                .font(.wpayinCaption)
                .foregroundColor(WpayinColors.textSecondary)

            Spacer(minLength: 12)

            Text(value)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(WpayinColors.text)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }
}

private struct TransactionCopyCard: View {
    let icon: String
    let title: String
    let value: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 9) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(WpayinColors.primary)

                    Text(title)
                        .font(.wpayinCaption)
                        .foregroundColor(WpayinColors.textSecondary)
                }

                Spacer()

                Button {
                    AppToast.copyToClipboard(value)
                    withAnimation(.easeOut(duration: 0.2)) {
                        copied = true
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            copied = false
                        }
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(copied ? WpayinColors.success : WpayinColors.primary)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(WpayinColors.surfaceLight))
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(L10n.Action.copy.localized)
            }

            Text(displayValue)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(WpayinColors.text)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(WpayinColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            copied
                                ? WpayinColors.success.opacity(0.45)
                                : WpayinColors.surfaceBorder,
                            lineWidth: 1
                        )
                )
        )
    }

    private var displayValue: String {
        guard !value.isEmpty else { return "—" }
        return value
    }
}

/// Phase timeline: submitted → network confirmation → completed. Reuses the
/// step rows from the live swap progress sheet.
private struct TransactionProgressCard: View {
    let status: Transaction.TransactionStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Progress".localized)
                .font(.wpayinCaption)
                .foregroundColor(WpayinColors.textSecondary)
                .padding(.horizontal, 16)
                .padding(.top, 14)

            VStack(spacing: 0) {
                SwapProgressStepRow(
                    title: "Transaction submitted".localized,
                    state: .done,
                    isFirst: true,
                    isLast: false
                )

                SwapProgressStepRow(
                    title: "Network confirmation".localized,
                    state: confirmationState,
                    isFirst: false,
                    isLast: false
                )

                SwapProgressStepRow(
                    title: "Completed".localized,
                    state: completedState,
                    isFirst: false,
                    isLast: true
                )
            }
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(WpayinColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                )
        )
    }

    private var confirmationState: SwapProgressStepRow.StepState {
        switch status {
        case .pending: return .active
        case .confirmed: return .done
        case .failed: return .failed
        }
    }

    private var completedState: SwapProgressStepRow.StepState {
        switch status {
        case .pending: return .upcoming
        case .confirmed: return .done
        case .failed: return .failed
        }
    }
}
