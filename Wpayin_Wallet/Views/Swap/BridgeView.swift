// Autor Lukas Helebrandt, 2026

//
//  BridgeView.swift
//  Wpayin_Wallet
//
//  Cross-chain bridge tab content (shown inside SwapView's Bridge mode).
//  Quotes and execution go through BridgeService (LI.FI).
//

import SwiftUI

struct BridgeContentView: View {
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var settingsManager: SettingsManager

    @State private var fromNetwork: BlockchainPlatform = .ethereum
    @State private var toNetwork: BlockchainPlatform = .base
    @State private var selectedToken: Token?
    @State private var amount = ""

    @State private var showTokenPicker = false
    @State private var showFromNetworkSelector = false
    @State private var showToNetworkSelector = false

    @State private var quote: BridgeQuote?
    @State private var isQuoting = false
    @State private var showReview = false
    @State private var isBridging = false

    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var successMessage = ""

    private var availableNetworks: [BlockchainPlatform] {
        walletManager.availableBlockchains
            .filter {
                $0.network == .mainnet &&
                walletManager.selectedBlockchains.contains($0.platform) &&
                ($0.blockchainType.map { BridgeService.supportedBlockchains.contains($0) } ?? false)
            }
            .map { $0.platform }
    }

    private var availableTokens: [Token] {
        walletManager.visibleSupportedTokens.filter {
            $0.blockchain.rawValue == fromNetwork.rawValue &&
            BridgeService.supportedBlockchains.contains($0.blockchain)
        }
    }

    /// Same asset on the destination chain, when the wallet knows it.
    private var destinationToken: Token? {
        guard let token = selectedToken else { return nil }
        return walletManager.visibleSupportedTokens.first {
            $0.blockchain.rawValue == toNetwork.rawValue &&
            $0.symbol.uppercased() == token.symbol.uppercased()
        }
    }

    private var isValidBridge: Bool {
        guard let token = selectedToken,
              let value = Double(amount),
              value > 0 else { return false }
        return fromNetwork != toNetwork && value <= token.balance
    }

    private var invalidReason: String {
        guard let token = selectedToken else { return L10n.Tokens.selectToken.localized }
        if fromNetwork == toNetwork { return L10n.Bridge.sameNetwork.localized }
        guard let value = Double(amount) else { return "Enter a valid amount".localized }
        if value > token.balance { return L10n.Swap.insufficient.localized(token.symbol) }
        return "Enter a valid amount".localized
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    networksRow
                    bridgeCard

                    if let quote {
                        quoteDetailsCard(quote)
                    }

                    Spacer(minLength: 16)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }

            bottomAction
        }
        .sheet(isPresented: $showTokenPicker) {
            TokenPickerView(tokens: availableTokens, selectedToken: selectedToken) { token in
                selectedToken = token
            }
        }
        .sheet(isPresented: $showFromNetworkSelector) {
            NetworkSelectorSheet(selectedNetwork: $fromNetwork, availableNetworks: availableNetworks)
        }
        .sheet(isPresented: $showToNetworkSelector) {
            NetworkSelectorSheet(
                selectedNetwork: $toNetwork,
                availableNetworks: availableNetworks.filter { $0 != fromNetwork }
            )
        }
        .sheet(isPresented: $showReview) {
            if let quote, let token = selectedToken {
                BridgeReviewSheet(
                    quote: quote,
                    fromToken: token,
                    fromNetwork: fromNetwork,
                    toNetwork: toNetwork,
                    isBridging: isBridging,
                    onConfirm: performBridge
                )
                .environmentObject(settingsManager)
            }
        }
        .alert(L10n.Bridge.failed.localized, isPresented: $showError) {
            Button("OK".localized) { }
        } message: {
            Text(errorMessage)
        }
        .alert(L10n.Bridge.submitted.localized, isPresented: $showSuccess) {
            Button("OK".localized) { }
        } message: {
            Text(successMessage)
        }
        .onAppear {
            ensureNetworksAreAvailable()
            if selectedToken == nil {
                selectedToken = availableTokens.first
            }
        }
        .onChange(of: fromNetwork) { _ in
            if toNetwork == fromNetwork {
                toNetwork = availableNetworks.first { $0 != fromNetwork } ?? toNetwork
            }
            selectedToken = availableTokens.first
            amount = ""
            quote = nil
        }
        .onChange(of: toNetwork) { _ in quote = nil }
        .onChange(of: amount) { _ in quote = nil }
        .onChange(of: selectedToken?.id) { _ in quote = nil }
        .onChange(of: walletManager.selectedBlockchains) { _ in
            ensureNetworksAreAvailable()
        }
    }

    // MARK: - Cards

    /// From/to network pickers side by side — one compact row above the card.
    private var networksRow: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.Bridge.fromNetwork.localized)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(WpayinColors.textSecondary)

                NetworkSelectorButton(
                    selectedNetwork: $fromNetwork,
                    availableNetworks: availableNetworks,
                    onTap: { showFromNetworkSelector = true }
                )
            }

            Spacer(minLength: 4)

            Image(systemName: "arrow.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(WpayinColors.textTertiary)
                .padding(.top, 18)

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 6) {
                Text(L10n.Bridge.toNetwork.localized)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(WpayinColors.textSecondary)

                NetworkSelectorButton(
                    selectedNetwork: $toNetwork,
                    availableNetworks: availableNetworks.filter { $0 != fromNetwork },
                    onTap: { showToNetworkSelector = true }
                )
            }
        }
    }

    /// Pay + receive cards stacked tight with the direction circle overlapping,
    /// mirroring the swap card layout.
    private var bridgeCard: some View {
        ZStack {
            VStack(spacing: 10) {
                ModernTokenSelector(
                    title: L10n.Swap.youPay.localized,
                    selectedToken: selectedToken,
                    amount: $amount,
                    isInput: true,
                    onTokenSelect: { showTokenPicker = true }
                )

                receiveCard
            }

            Circle()
                .fill(WpayinColors.backgroundGradientStart)
                .frame(width: 48, height: 48)
                .overlay(
                    Circle()
                        .stroke(WpayinColors.primary, lineWidth: 1.5)
                )
                .overlay(
                    Image(systemName: "arrow.down")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(WpayinColors.accentGradient)
                )
                .shadow(color: WpayinColors.primary.opacity(0.32), radius: 12)
        }
    }

    private var receiveCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.Swap.youReceive.localized)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(WpayinColors.textSecondary)

            HStack(spacing: 12) {
                Text(receivedAmountText)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundColor(WpayinColors.text.opacity(quote == nil ? 0.5 : 0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let token = selectedToken {
                    HStack(spacing: 8) {
                        TokenIconView(token: destinationToken ?? token, size: 34, showNetworkBadge: false)

                        Text(token.symbol)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(WpayinColors.text)
                    }
                    .padding(.leading, 9)
                    .padding(.trailing, 13)
                    .frame(height: 48)
                    .background(
                        Capsule()
                            .fill(WpayinColors.surfaceLight)
                            .overlay(
                                Capsule()
                                    .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                            )
                    )
                }
            }

            HStack {
                Text(quote == nil ? L10n.Swap.estimatedAmount.localized : secondaryReceivedText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(WpayinColors.textSecondary)

                Spacer()
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: WpayinRadius.card, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            WpayinColors.primary.opacity(0.075),
                            WpayinColors.surface,
                            WpayinColors.surface
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: WpayinRadius.card, style: .continuous)
                        .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                )
        )
    }

    private func quoteDetailsCard(_ quote: BridgeQuote) -> some View {
        VStack(spacing: 0) {
            SwapDetailRow(
                label: L10n.Bridge.provider.localized,
                value: quote.toolName
            )

            divider

            SwapDetailRow(
                label: L10n.Bridge.estimatedTime.localized,
                value: formattedDuration(quote.executionDuration)
            )

            divider

            SwapDetailRow(
                label: L10n.Swap.minimumReceived.localized,
                value: "\(formattedAmount(quote.toAmountMin)) \(quote.toSymbol)",
                highlightsValue: true
            )
        }
        .background(
            RoundedRectangle(cornerRadius: WpayinRadius.card, style: .continuous)
                .fill(WpayinColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: WpayinRadius.card, style: .continuous)
                        .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                )
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(WpayinColors.surfaceBorder)
            .frame(height: 1)
            .padding(.horizontal, 16)
    }

    private var bottomAction: some View {
        VStack(spacing: 8) {
            if !isValidBridge && !amount.isEmpty {
                Text(invalidReason)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(WpayinColors.error)
                    .lineLimit(2)
            }

            Button(action: requestQuoteAndReview) {
                HStack(spacing: 9) {
                    if isQuoting || isBridging {
                        ProgressView()
                            .tint(.white)
                    }

                    Text(buttonTitle)
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundColor(isValidBridge ? .white : WpayinColors.textTertiary)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: isValidBridge
                                    ? [WpayinColors.primary, WpayinColors.accent]
                                    : [WpayinColors.surfaceLight, WpayinColors.surfaceLight],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(
                            isValidBridge ? WpayinColors.primary.opacity(0.45) : WpayinColors.surfaceBorder,
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: isValidBridge ? WpayinColors.primary.opacity(0.24) : .clear,
                    radius: 14,
                    y: 7
                )
            }
            .disabled(!isValidBridge || isQuoting || isBridging)
            .buttonStyle(WpayinPressableStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(
            LinearGradient(
                colors: [
                    WpayinColors.background.opacity(0),
                    WpayinColors.background.opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .center
            )
        )
    }

    // MARK: - Helpers

    private var buttonTitle: String {
        if isBridging { return L10n.Bridge.bridging.localized }
        if isQuoting { return L10n.Bridge.gettingQuote.localized }
        return L10n.Bridge.review.localized
    }

    private var receivedAmountText: String {
        guard let quote else { return "0.0" }
        return formattedAmount(quote.toAmount)
    }

    private var secondaryReceivedText: String {
        guard let quote, let token = selectedToken else { return "" }
        let price = destinationToken?.price ?? token.price
        let value = (quote.toAmount as NSDecimalNumber).doubleValue * price
        return "≈ \(value.formatted(as: settingsManager.selectedCurrency))"
    }

    private func formattedAmount(_ value: Decimal) -> String {
        let doubleValue = (value as NSDecimalNumber).doubleValue
        guard doubleValue.isFinite, doubleValue > 0 else { return "0.0" }
        let decimals = doubleValue >= 1_000 ? 2 : (doubleValue >= 1 ? 4 : 6)
        var result = String(format: "%.\(decimals)f", doubleValue)
        while result.contains("."), result.last == "0" {
            result.removeLast()
        }
        if result.last == "." {
            result.append("0")
        }
        return result
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "< 1 min"
        }
        return "~\(Int((seconds / 60).rounded(.up))) min"
    }

    private func ensureNetworksAreAvailable() {
        guard !availableNetworks.isEmpty else { return }
        if !availableNetworks.contains(fromNetwork) {
            fromNetwork = availableNetworks.first ?? .ethereum
        }
        if toNetwork == fromNetwork || !availableNetworks.contains(toNetwork) {
            toNetwork = availableNetworks.first { $0 != fromNetwork } ?? toNetwork
        }
    }

    private func requestQuoteAndReview() {
        guard isValidBridge,
              let token = selectedToken,
              let value = Double(amount),
              let toBlockchain = toNetwork.blockchainType else { return }

        isQuoting = true

        Task {
            do {
                let destinationAddress = destinationToken.flatMap {
                    $0.isNative ? "0x0000000000000000000000000000000000000000" : $0.contractAddress
                }

                let newQuote = try await BridgeService.shared.getQuote(
                    fromToken: token,
                    toBlockchain: toBlockchain,
                    toTokenAddress: destinationAddress,
                    amount: Decimal(value)
                )

                await MainActor.run {
                    isQuoting = false
                    quote = newQuote
                    showReview = true
                }
            } catch {
                Logger.log("❌ Bridge quote failed: \(error.localizedDescription)")
                await MainActor.run {
                    isQuoting = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func performBridge() {
        guard let quote, let token = selectedToken else { return }
        isBridging = true

        Task {
            do {
                let txHash = try await BridgeService.shared.executeBridge(quote: quote, fromToken: token)
                Logger.log("✅ Bridge submitted! TX: \(txHash)")

                await MainActor.run {
                    isBridging = false
                    amount = ""
                    self.quote = nil
                    successMessage = "Transaction: %@".localized(txHash)
                    showSuccess = true

                    Task {
                        await walletManager.refreshWalletData()
                    }
                }
            } catch {
                Logger.log("❌ Bridge failed: \(error.localizedDescription)")
                await MainActor.run {
                    isBridging = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Review sheet

struct BridgeReviewSheet: View {
    let quote: BridgeQuote
    let fromToken: Token
    let fromNetwork: BlockchainPlatform
    let toNetwork: BlockchainPlatform
    let isBridging: Bool
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsManager: SettingsManager

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
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Capsule()
                    .fill(WpayinColors.textTertiary.opacity(0.7))
                    .frame(width: 42, height: 5)
                    .padding(.top, 10)

                Text(L10n.Bridge.review.localized)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(WpayinColors.text)

                VStack(spacing: 16) {
                    HStack(spacing: 10) {
                        endpoint(
                            network: fromNetwork,
                            amount: quote.fromAmount,
                            symbol: fromToken.symbol
                        )

                        Image(systemName: "arrow.right")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(WpayinColors.textTertiary)

                        endpoint(
                            network: toNetwork,
                            amount: quote.toAmount,
                            symbol: quote.toSymbol
                        )
                    }

                    Rectangle()
                        .fill(WpayinColors.surfaceBorder)
                        .frame(height: 1)

                    SwapDetailRow(
                        label: L10n.Bridge.provider.localized,
                        value: quote.toolName
                    )

                    SwapDetailRow(
                        label: L10n.Bridge.estimatedTime.localized,
                        value: quote.executionDuration < 60
                            ? "< 1 min"
                            : "~\(Int((quote.executionDuration / 60).rounded(.up))) min"
                    )

                    SwapDetailRow(
                        label: L10n.Swap.minimumReceived.localized,
                        value: "\(formatted(quote.toAmountMin)) \(quote.toSymbol)",
                        highlightsValue: true
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 8)
                .background(
                    RoundedRectangle(cornerRadius: WpayinRadius.card, style: .continuous)
                        .fill(WpayinColors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: WpayinRadius.card, style: .continuous)
                                .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                        )
                )

                Button {
                    dismiss()
                    onConfirm()
                } label: {
                    HStack(spacing: 8) {
                        if isBridging {
                            ProgressView()
                                .tint(.white)
                        }

                        Text(L10n.Swap.confirm.localized)
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(WpayinColors.accentGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
                .disabled(isBridging)
                .buttonStyle(WpayinPressableStyle())

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 20)
        }
        .swapReviewPresentation()
    }

    private func endpoint(network: BlockchainPlatform, amount: Decimal, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                PlatformIconView(platform: network, size: 26)

                Text(network.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(WpayinColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Text("\(formatted(amount)) \(symbol)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(WpayinColors.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatted(_ value: Decimal) -> String {
        let doubleValue = (value as NSDecimalNumber).doubleValue
        let decimals = doubleValue >= 1_000 ? 2 : (doubleValue >= 1 ? 4 : 6)
        var result = String(format: "%.\(decimals)f", doubleValue)
        while result.contains("."), result.last == "0" {
            result.removeLast()
        }
        if result.last == "." {
            result.append("0")
        }
        return result
    }
}
