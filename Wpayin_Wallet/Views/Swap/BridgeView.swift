// Autor Lukas Helebrandt, 2026

//
//  BridgeView.swift
//  Wpayin_Wallet
//
//  Cross-chain bridge tab content (shown inside SwapView's Bridge mode).
//  Quotes and execution go through BridgeService (LI.FI).
//

import SwiftUI

private struct BridgeSubmission: Identifiable {
    enum Status {
        case submitted
        case completed
        case failed
    }

    let id: String
    let sourceHash: String
    var destinationHash: String?
    let fromNetwork: BlockchainPlatform
    let toNetwork: BlockchainPlatform
    let sentAmount: Decimal
    let expectedAmount: Decimal
    let minimumAmount: Decimal
    let symbol: String
    let destinationSymbol: String
    let provider: String
    let estimatedDuration: TimeInterval
    let networkFeeNative: Double
    let networkFeeUSD: Double
    var status: Status
}

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
    @State private var feeEstimate: BridgeNetworkFeeEstimate?
    @State private var quoteEstimateKey = ""
    @State private var isQuoting = false
    @State private var showReview = false
    @State private var isBridging = false

    @State private var showError = false
    @State private var errorMessage = ""
    @State private var bridgeSubmission: BridgeSubmission?

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
        return fromNetwork != toNetwork && value <= token.balance && hasSufficientBridgeGas
    }

    private var sourceNativeBalance: Double {
        guard let token = selectedToken else { return 0 }
        return walletManager.tokens.first {
            $0.blockchain == token.blockchain && $0.isNative
        }?.balance ?? 0
    }

    private var networkFeeNative: Double {
        guard quoteEstimateKey == bridgeEstimateKey, let feeEstimate else { return 0 }
        return NSDecimalNumber(decimal: feeEstimate.feeNative).doubleValue
    }

    private var networkFeeUSD: Double {
        guard let token = selectedToken,
              let price = walletManager.currentUSDPrice(
                for: token.blockchain.nativeToken,
                blockchain: token.blockchain
              ) else { return 0 }
        return networkFeeNative * price
    }

    private var hasSufficientBridgeGas: Bool {
        guard let token = selectedToken,
              let value = Double(amount),
              networkFeeNative > 0 else { return true }
        return token.isNative
            ? value + networkFeeNative <= token.balance
            : sourceNativeBalance >= networkFeeNative
    }

    private var bridgeEstimateKey: String {
        "\(selectedToken?.id.uuidString ?? "none")|\(fromNetwork.rawValue)|\(toNetwork.rawValue)|\(amount)"
    }

    private var invalidReason: String {
        guard let token = selectedToken else { return L10n.Tokens.selectToken.localized }
        if fromNetwork == toNetwork { return L10n.Bridge.sameNetwork.localized }
        guard let value = Double(amount) else { return "Enter a valid amount".localized }
        if value > token.balance { return L10n.Swap.insufficient.localized(token.symbol) }
        if !hasSufficientBridgeGas {
            return "Insufficient %@ balance for the amount and network fee".localized(token.blockchain.nativeToken)
        }
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
                    networkFeeNative: networkFeeNative,
                    networkFeeUSD: networkFeeUSD,
                    approvalRequired: feeEstimate?.approvalRequired ?? false,
                    isBridging: isBridging,
                    onConfirm: performBridge
                )
                .environmentObject(settingsManager)
            }
        }
        .sheet(item: $bridgeSubmission) { submission in
            BridgeStatusSheet(submission: submission)
                .environmentObject(settingsManager)
        }
        .alert(L10n.Bridge.failed.localized, isPresented: $showError) {
            Button("OK".localized) { }
        } message: {
            Text(errorMessage)
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
            clearQuote()
        }
        .onChange(of: toNetwork) { _ in clearQuote() }
        .onChange(of: amount) { _ in clearQuote() }
        .onChange(of: selectedToken?.id) { _ in clearQuote() }
        .onChange(of: walletManager.selectedBlockchains) { _ in
            ensureNetworksAreAvailable()
        }
        .task(id: bridgeEstimateKey) {
            guard isValidBridge else { return }
            try? await Task.sleep(nanoseconds: 280_000_000)
            while !Task.isCancelled {
                await refreshBridgeQuote(showError: false)
                try? await Task.sleep(nanoseconds: 20_000_000_000)
            }
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
                    onTokenSelect: { showTokenPicker = true },
                    onMax: setMaximumBridgeAmount
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
                label: L10n.Swap.networkFee.localized,
                value: "≈ \(formattedFee(networkFeeNative)) \(selectedToken?.blockchain.nativeToken ?? "ETH") · \(networkFeeUSD.formatted(as: settingsManager.selectedCurrency))",
                showsInfo: true
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

    private func formattedFee(_ value: Double) -> String {
        guard value > 0 else { return "0" }
        return String(format: value < 0.0001 ? "%.8f" : "%.6f", value)
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
        Task {
            guard isValidBridge else { return }
            isQuoting = true
            await refreshBridgeQuote(showError: true)
            isQuoting = false

            guard quote != nil, feeEstimate != nil else { return }
            guard hasSufficientBridgeGas else {
                let symbol = selectedToken?.blockchain.nativeToken ?? "ETH"
                errorMessage = "Insufficient %@ balance for the amount and network fee".localized(symbol)
                self.showError = true
                return
            }
            showReview = true
        }
    }

    private func refreshBridgeQuote(showError: Bool) async {
        guard let token = selectedToken,
              let value = Decimal(string: amount.replacingOccurrences(of: ",", with: ".")),
              value > 0,
              let toBlockchain = toNetwork.blockchainType else { return }

        let requestedKey = bridgeEstimateKey
        do {
            let destinationAddress = destinationToken.flatMap {
                $0.isNative ? "0x0000000000000000000000000000000000000000" : $0.contractAddress
            }
            let newQuote = try await BridgeService.shared.getQuote(
                fromToken: token,
                toBlockchain: toBlockchain,
                toTokenAddress: destinationAddress,
                amount: value
            )
            let newFee = try await BridgeService.shared.estimateNetworkFee(
                quote: newQuote,
                fromToken: token
            )

            guard requestedKey == bridgeEstimateKey else { return }
            quote = newQuote
            feeEstimate = newFee
            quoteEstimateKey = requestedKey
        } catch {
            guard requestedKey == bridgeEstimateKey else { return }
            clearQuote()
            if showError {
                Logger.log("❌ Bridge quote failed: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
                self.showError = true
            }
        }
    }

    private func setMaximumBridgeAmount() {
        guard let token = selectedToken, token.balance > 0 else { return }
        Task {
            isQuoting = true
            amount = editableBridgeAmount(token.isNative ? token.balance * 0.99 : token.balance)
            await refreshBridgeQuote(showError: false)

            if token.isNative, networkFeeNative > 0 {
                let reserve = max(networkFeeNative * 0.05, 0.00000001)
                amount = editableBridgeAmount(max(0, token.balance - networkFeeNative - reserve))
                await refreshBridgeQuote(showError: true)
            }
            isQuoting = false

            if !hasSufficientBridgeGas {
                errorMessage = "Insufficient %@ balance for the amount and network fee".localized(token.blockchain.nativeToken)
                showError = true
            }
        }
    }

    private func editableBridgeAmount(_ value: Double) -> String {
        var result = String(format: "%.12f", max(0, value))
        while result.last == "0" { result.removeLast() }
        if result.last == "." { result.removeLast() }
        return result
    }

    private func clearQuote() {
        quote = nil
        feeEstimate = nil
        quoteEstimateKey = ""
    }

    private func performBridge() {
        guard let quote, let token = selectedToken else { return }
        let submittedFeeNative = networkFeeNative
        let submittedFeeUSD = networkFeeUSD
        isBridging = true

        Task {
            guard await settingsManager.authorizeSpending(reason: "auth.confirmPayment".localized) else {
                await MainActor.run { isBridging = false }
                return
            }
            do {
                let txHash = try await BridgeService.shared.executeBridge(
                    quote: quote,
                    fromToken: token,
                    feeEstimate: feeEstimate
                )
                Logger.log("✅ Bridge submitted! TX: \(txHash)")

                let sourceNetwork = token.blockchain
                let destinationNetwork = toNetwork.blockchainType ?? sourceNetwork
                let sentAmount = (quote.fromAmount as NSDecimalNumber).doubleValue
                let expectedAmount = (quote.toAmount as NSDecimalNumber).doubleValue
                let explorerUrl = URL(
                    string: NetworkManager.shared.getExplorerUrl(for: sourceNetwork, txHash: txHash)
                )
                // The arrival hash is unknown until the bridge settles — track
                // it under a placeholder and swap in the real hash later.
                let arrivalPlaceholder = "bridge-arrival-\(txHash)"

                await MainActor.run {
                    isBridging = false
                    amount = ""
                    clearQuote()
                    bridgeSubmission = BridgeSubmission(
                        id: txHash,
                        sourceHash: txHash,
                        destinationHash: nil,
                        fromNetwork: fromNetwork,
                        toNetwork: toNetwork,
                        sentAmount: quote.fromAmount,
                        expectedAmount: quote.toAmount,
                        minimumAmount: quote.toAmountMin,
                        symbol: token.symbol,
                        destinationSymbol: quote.toSymbol,
                        provider: quote.toolName,
                        estimatedDuration: quote.executionDuration,
                        networkFeeNative: submittedFeeNative,
                        networkFeeUSD: submittedFeeUSD,
                        status: .submitted
                    )

                    // Both sides of the bridge appear in Activity right away:
                    // the source-chain send and the pending destination arrival.
                    walletManager.registerLocalTransaction(
                        Transaction(
                            hash: txHash,
                            from: walletManager.walletAddress,
                            to: quote.txTo,
                            amount: sentAmount,
                            token: token.symbol,
                            type: .bridge,
                            status: .pending,
                            timestamp: Date(),
                            gasUsed: 0,
                            gasFee: 0,
                            explorerUrl: explorerUrl,
                            blockchain: sourceNetwork
                        )
                    )
                    walletManager.registerLocalTransaction(
                        Transaction(
                            hash: arrivalPlaceholder,
                            from: quote.txTo,
                            to: walletManager.walletAddress,
                            amount: expectedAmount,
                            token: quote.toSymbol,
                            type: .bridgeReceive,
                            status: .pending,
                            timestamp: Date(),
                            gasUsed: 0,
                            gasFee: 0,
                            blockchain: destinationNetwork
                        )
                    )

                    Task {
                        await walletManager.refreshWalletData()
                    }
                }

                // Follow the bridge until the funds land on the destination
                // chain, then flip both Activity entries to their final state.
                if let fromChain = sourceNetwork.chainId, let toChain = destinationNetwork.chainId {
                    let arrival = await BridgeService.shared.waitForArrival(
                        sourceTxHash: txHash,
                        fromChain: fromChain,
                        toChain: toChain
                    )
                    await MainActor.run {
                        guard let arrival else { return }
                        walletManager.updateLocalTransactionStatus(hash: txHash, status: .confirmed)
                        if arrival.succeeded {
                            if bridgeSubmission?.id == txHash {
                                bridgeSubmission?.destinationHash = arrival.txHash
                                bridgeSubmission?.status = .completed
                            }
                            walletManager.updateLocalTransactionStatus(
                                hash: arrivalPlaceholder,
                                status: .confirmed,
                                newHash: arrival.txHash,
                                newAmount: arrival.amount.map { ($0 as NSDecimalNumber).doubleValue },
                                newExplorerUrl: URL(
                                    string: NetworkManager.shared.getExplorerUrl(
                                        for: destinationNetwork,
                                        txHash: arrival.txHash
                                    )
                                )
                            )
                            AppToast.show(
                                "Bridge completed — %@ arrived on %@".localized(
                                    "\(String(format: "%.4f", arrival.amount.map { ($0 as NSDecimalNumber).doubleValue } ?? expectedAmount)) \(quote.toSymbol)",
                                    destinationNetwork.name
                                ),
                                icon: "checkmark.seal.fill"
                            )
                            Task { await walletManager.refreshWalletData() }
                        } else {
                            if bridgeSubmission?.id == txHash {
                                bridgeSubmission?.status = .failed
                            }
                            walletManager.updateLocalTransactionStatus(hash: arrivalPlaceholder, status: .failed)
                        }
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

// MARK: - Submitted bridge status

private struct BridgeStatusSheet: View {
    let submission: BridgeSubmission

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsManager: SettingsManager

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 18) {
                    statusHeader
                    routeCard
                    detailsCard
                    transactionCard

                    Button("Done".localized) { dismiss() }
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(WpayinColors.accentGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                        .buttonStyle(WpayinPressableStyle())
                }
                .padding(20)
            }
            .background(
                LinearGradient(
                    colors: [WpayinColors.backgroundGradientStart, WpayinColors.background],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Bridge details".localized)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var statusHeader: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.14))
                    .frame(width: 76, height: 76)

                if submission.status == .submitted {
                    ProgressView()
                        .tint(statusColor)
                        .scaleEffect(1.25)
                } else {
                    Image(systemName: submission.status == .completed ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 38))
                        .foregroundColor(statusColor)
                }
            }

            Text(statusTitle)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(WpayinColors.text)

            Text(statusDescription)
                .font(.system(size: 14))
                .foregroundColor(WpayinColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var routeCard: some View {
        HStack(spacing: 10) {
            endpoint(
                network: submission.fromNetwork,
                amount: submission.sentAmount,
                symbol: submission.symbol
            )

            Image(systemName: "arrow.right")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(WpayinColors.primary)

            endpoint(
                network: submission.toNetwork,
                amount: submission.expectedAmount,
                symbol: submission.destinationSymbol
            )
        }
        .padding(18)
        .bridgeStatusCard()
    }

    private var detailsCard: some View {
        VStack(spacing: 0) {
            detailRow("Status".localized, statusTitle)
            divider
            detailRow(L10n.Bridge.provider.localized, submission.provider)
            divider
            detailRow(L10n.Bridge.estimatedTime.localized, estimatedTime)
            divider
            detailRow(
                L10n.Swap.minimumReceived.localized,
                "\(formatted(submission.minimumAmount)) \(submission.destinationSymbol)"
            )
            divider
            detailRow(
                L10n.Swap.networkFee.localized,
                "≈ \(formattedFee(submission.networkFeeNative)) \(submission.fromNetwork.blockchainType?.nativeToken ?? "ETH") · \(submission.networkFeeUSD.formatted(as: settingsManager.selectedCurrency))"
            )
        }
        .padding(.horizontal, 16)
        .bridgeStatusCard()
    }

    private var transactionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Transactions".localized)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(WpayinColors.text)

            transactionLink(
                title: "Source transaction".localized,
                hash: submission.sourceHash,
                network: submission.fromNetwork
            )

            if let destinationHash = submission.destinationHash {
                transactionLink(
                    title: "Destination transaction".localized,
                    hash: destinationHash,
                    network: submission.toNetwork
                )
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Destination transaction".localized)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(WpayinColors.textSecondary)
                        Text("Waiting for arrival".localized)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(WpayinColors.text)
                    }
                    Spacer()
                    ProgressView().tint(WpayinColors.primary)
                }
            }
        }
        .padding(18)
        .bridgeStatusCard()
    }

    private func endpoint(network: BlockchainPlatform, amount: Decimal, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                PlatformIconView(platform: network, size: 28)
                Text(network.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(WpayinColors.textSecondary)
                    .lineLimit(1)
            }
            Text("\(formatted(amount)) \(symbol)")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(WpayinColors.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .foregroundColor(WpayinColors.textSecondary)
            Spacer()
            Text(value)
                .foregroundColor(WpayinColors.text)
                .multilineTextAlignment(.trailing)
        }
        .font(.system(size: 14, weight: .medium))
        .padding(.vertical, 13)
    }

    private func transactionLink(title: String, hash: String, network: BlockchainPlatform) -> some View {
        let blockchain = network.blockchainType ?? .ethereum
        let url = URL(string: NetworkManager.shared.getExplorerUrl(for: blockchain, txHash: hash))
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(WpayinColors.textSecondary)
                Text(shortHash(hash))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(WpayinColors.text)
            }
            Spacer()
            if let url {
                Link(destination: url) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(WpayinColors.primary)
                }
            }
        }
    }

    private var divider: some View {
        Rectangle().fill(WpayinColors.surfaceBorder).frame(height: 1)
    }

    private var statusTitle: String {
        switch submission.status {
        case .submitted: return "Bridge in progress".localized
        case .completed: return "Bridge completed".localized
        case .failed: return "Bridge failed".localized
        }
    }

    private var statusDescription: String {
        switch submission.status {
        case .submitted:
            return "Your source transaction was submitted. Funds will appear after the destination chain confirms the bridge.".localized
        case .completed:
            return "Funds arrived on %@.".localized(submission.toNetwork.name)
        case .failed:
            return "The bridge provider reported a failure. Open the source transaction for details.".localized
        }
    }

    private var statusColor: Color {
        switch submission.status {
        case .submitted: return WpayinColors.primary
        case .completed: return WpayinColors.success
        case .failed: return WpayinColors.error
        }
    }

    private var estimatedTime: String {
        submission.estimatedDuration < 60
            ? "< 1 min"
            : "~\(Int((submission.estimatedDuration / 60).rounded(.up))) min"
    }

    private func formatted(_ value: Decimal) -> String {
        let doubleValue = (value as NSDecimalNumber).doubleValue
        var result = String(format: doubleValue >= 1 ? "%.4f" : "%.6f", doubleValue)
        while result.contains("."), result.last == "0" { result.removeLast() }
        if result.last == "." { result.append("0") }
        return result
    }

    private func formattedFee(_ value: Double) -> String {
        String(format: value < 0.0001 ? "%.8f" : "%.6f", value)
    }

    private func shortHash(_ hash: String) -> String {
        guard hash.count > 16 else { return hash }
        return "\(hash.prefix(10))…\(hash.suffix(8))"
    }
}

private extension View {
    func bridgeStatusCard() -> some View {
        background(
            RoundedRectangle(cornerRadius: WpayinRadius.card, style: .continuous)
                .fill(WpayinColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: WpayinRadius.card, style: .continuous)
                        .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                )
        )
    }
}

// MARK: - Review sheet

struct BridgeReviewSheet: View {
    let quote: BridgeQuote
    let fromToken: Token
    let fromNetwork: BlockchainPlatform
    let toNetwork: BlockchainPlatform
    let networkFeeNative: Double
    let networkFeeUSD: Double
    let approvalRequired: Bool
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

                    SwapDetailRow(
                        label: L10n.Swap.networkFee.localized,
                        value: "≈ \(formattedFee(networkFeeNative)) \(fromToken.blockchain.nativeToken) · \(networkFeeUSD.formatted(as: settingsManager.selectedCurrency))",
                        showsInfo: true,
                        highlightsValue: true
                    )

                    if approvalRequired {
                        Text("Includes the ERC-20 approval network fee".localized)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(WpayinColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.horizontal, 16)
                    }
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

    private func formattedFee(_ value: Double) -> String {
        guard value > 0 else { return "0" }
        return String(format: value < 0.0001 ? "%.8f" : "%.6f", value)
    }
}
