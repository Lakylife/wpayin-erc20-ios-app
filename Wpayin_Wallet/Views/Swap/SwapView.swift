// Autor Lukas Helebrandt, 2026

//
//  SwapView.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI

enum GasSpeed: String, CaseIterable {
    case slow
    case standard
    case fast

    var displayName: String {
        switch self {
        case .slow: return "🐢 \("Slow".localized)"
        case .standard: return "🐰 \("Standard".localized)"
        case .fast: return "⚡ \("Fast".localized)"
        }
    }

    var multiplier: Double {
        switch self {
        case .slow: return 0.8
        case .standard: return 1.0
        case .fast: return 1.3
        }
    }

    var icon: String {
        switch self {
        case .slow: return "tortoise.fill"
        case .standard: return "hare.fill"
        case .fast: return "bolt.fill"
        }
    }
}

struct SwapView: View {
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var settingsManager: SettingsManager
    private let initialFromToken: Token?
    @State private var selectedFromToken: Token?
    @State private var selectedToToken: Token?
    @State private var fromAmount = ""
    @State private var toAmount = ""
    @State private var isSwapping = false
    @State private var showTokenPicker = false
    @State private var isSelectingFromToken = true
    @State private var slippage: Double = 0.5
    @State private var showSlippageSettings = false
    @State private var selectedGasSpeed: GasSpeed = .standard
    @State private var showGasSettings = false
    @State private var selectedNetwork: BlockchainPlatform = .ethereum
    @State private var showNetworkSelector = false
    @State private var showSwapError = false
    @State private var swapErrorMessage = ""
    @State private var showSwapSuccess = false
    @State private var swapSuccessMessage = ""
    @State private var showReviewSwap = false
    @State private var isBridgeMode = false

    init(initialFromToken: Token? = nil) {
        self.initialFromToken = initialFromToken
        let initialNetwork = initialFromToken.flatMap { BlockchainPlatform(rawValue: $0.blockchain.rawValue) } ?? .ethereum
        _selectedNetwork = State(initialValue: initialNetwork)
        _selectedFromToken = State(initialValue: initialFromToken)
    }

    private var availableTokens: [Token] {
        walletManager.visibleSupportedTokens.filter {
            $0.blockchain.rawValue == selectedNetwork.rawValue && 
            Self.supportedSwapBlockchains.contains($0.blockchain)
        }
    }
    
    private var availableNetworks: [BlockchainPlatform] {
        walletManager.availableBlockchains
            .filter { 
                $0.network == .mainnet && 
                walletManager.selectedBlockchains.contains($0.platform) &&
                ($0.blockchainType.map { Self.supportedSwapBlockchains.contains($0) } ?? false)
            }
            .map { $0.platform }
    }

    private static let supportedSwapBlockchains: Set<BlockchainType> = [
        .ethereum,
        .bsc,
        .polygon,
        .arbitrum,
        .optimism,
        .base
    ]

    private var swapRate: Double {
        guard let fromToken = selectedFromToken,
              let toToken = selectedToToken,
              fromToken.price > 0, toToken.price > 0 else { return 0.0 }
        return fromToken.price / toToken.price
    }

    private var estimatedToAmount: Double {
        guard let amount = Double(fromAmount), amount > 0 else { return 0.0 }
        return amount * swapRate
    }

    private var isValidSwap: Bool {
        guard let from = selectedFromToken,
              let to = selectedToToken,
              let amount = Double(fromAmount),
              amount > 0 else { return false }
        return tokenIdentity(from) != tokenIdentity(to) && amount <= from.balance
    }

    private var estimatedGasFee: Double {
        guard let token = selectedFromToken else { return 0 }

        // Base gas fees vary by network
        let baseGas: Double
        switch token.blockchain {
        case .ethereum:
            baseGas = 0.003  // ~$8-10 typical
        case .arbitrum:
            baseGas = 0.0001 // Very cheap L2
        case .base:
            baseGas = 0.0001 // Very cheap L2
        case .optimism:
            baseGas = 0.0002 // Cheap L2
        case .polygon:
            baseGas = 0.01   // MATIC is cheap
        case .bsc:
            baseGas = 0.001  // BNB for gas
        case .avalanche:
            baseGas = 0.01   // AVAX for gas
        default:
            baseGas = 0.001
        }

        // Apply gas speed multiplier
        return baseGas * selectedGasSpeed.multiplier
    }

    private var gasFeeInUSD: Double {
        guard let token = selectedFromToken else { return 0 }
        return estimatedGasFee * token.price
    }

    private var portfolioBalance: Double {
        walletManager.visibleGroupedTokens.reduce(0) { $0 + $1.totalValue }
    }

    private var minimumReceived: Double {
        estimatedToAmount * max(0, 1 - (slippage / 100))
    }

    private var estimatedAmountText: String {
        formattedTokenAmount(estimatedToAmount)
    }

    var body: some View {
        ZStack {
            swapBackground

            VStack(spacing: 0) {
                header
                modePicker

                if isBridgeMode {
                    BridgeContentView()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            balanceAndNetworkRow
                            swapCard
                            swapDetailsCard
                            Spacer(minLength: 16)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)
                    }
                    bottomAction
                }
            }
        }
        .sheet(isPresented: $showTokenPicker) {
            TokenPickerView(
                tokens: availableTokens,
                selectedToken: isSelectingFromToken ? selectedFromToken : selectedToToken
            ) { token in
                if isSelectingFromToken {
                    selectedFromToken = token
                } else {
                    selectedToToken = token
                }
            }
        }

        .sheet(isPresented: $showGasSettings) {
            GasSettingsSheet(selectedSpeed: $selectedGasSpeed, estimatedGas: estimatedGasFee, gasInUSD: gasFeeInUSD, tokenSymbol: selectedFromToken?.symbol ?? "ETH")
        }
        .sheet(isPresented: $showSlippageSettings) {
            SlippageSettingsSheet(slippage: $slippage)
                .swapReviewPresentation()
        }
        .sheet(isPresented: $showNetworkSelector) {
            NetworkSelectorSheet(
                selectedNetwork: $selectedNetwork,
                availableNetworks: availableNetworks
            )
        }
        .sheet(isPresented: $showReviewSwap) {
            if let fromToken = selectedFromToken,
               let toToken = selectedToToken,
               let amount = Double(fromAmount) {
                SwapReviewSheet(
                    fromToken: fromToken,
                    toToken: toToken,
                    fromAmount: amount,
                    toAmount: estimatedToAmount,
                    minimumReceived: minimumReceived,
                    rate: swapRate,
                    isSwapping: isSwapping,
                    onConfirm: performSwap
                )
                .environmentObject(settingsManager)
                .swapReviewPresentation()
            }
        }
        .onAppear {
            ensureSelectedNetworkIsAvailable()
            if selectedFromToken == nil && !availableTokens.isEmpty {
                selectedFromToken = availableTokens.first
            }
            if selectedToToken == nil {
                selectedToToken = firstAvailableToken(excluding: selectedFromToken)
            }
        }
        .onChange(of: selectedNetwork) { _ in
            // Reset token selection when network changes
            selectedFromToken = availableTokens.first
            selectedToToken = firstAvailableToken(excluding: selectedFromToken)
            fromAmount = ""
        }
        .onChange(of: walletManager.selectedBlockchains) { _ in
            ensureSelectedNetworkIsAvailable()
        }
        .alert("Swap Failed".localized, isPresented: $showSwapError) {
            Button("OK".localized) { }
        } message: {
            Text(swapErrorMessage)
        }
        .alert("Swap Submitted".localized, isPresented: $showSwapSuccess) {
            Button("OK".localized) { }
        } message: {
            Text(swapSuccessMessage)
        }
    }

    private var swapBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    WpayinColors.backgroundGradientStart,
                    WpayinColors.backgroundGradientEnd
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(WpayinColors.primary.opacity(0.12))
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(x: -170, y: -260)

            Circle()
                .fill(WpayinColors.accent.opacity(0.08))
                .frame(width: 260, height: 260)
                .blur(radius: 90)
                .offset(x: 180, y: 120)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack {
            Color.clear
                .frame(width: 44, height: 44)

            Spacer()

            Text((isBridgeMode ? L10n.Bridge.title : L10n.Swap.title).localized)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(WpayinColors.text)

            Spacer()

            Button {
                showSlippageSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(WpayinColors.text)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(WpayinColors.surfaceLight)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(WpayinPressableStyle())
            .accessibilityLabel(L10n.Swap.slippageTolerance.localized)
            .opacity(isBridgeMode ? 0 : 1)
            .disabled(isBridgeMode)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    private var modePicker: some View {
        HStack(spacing: 4) {
            modeButton(bridge: false, label: L10n.Swap.title.localized, icon: "arrow.up.arrow.down")
            modeButton(bridge: true, label: L10n.Bridge.title.localized, icon: "link")
        }
        .padding(4)
        .background(
            Capsule()
                .fill(WpayinColors.surface)
                .overlay(
                    Capsule()
                        .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }

    private func modeButton(bridge: Bool, label: String, icon: String) -> some View {
        let isSelected = isBridgeMode == bridge
        return Button {
            withAnimation(.easeOut(duration: 0.2)) {
                isBridgeMode = bridge
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))

                Text(label)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .foregroundColor(isSelected ? .white : WpayinColors.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(
                Capsule()
                    .fill(isSelected ? AnyShapeStyle(WpayinColors.accentGradient) : AnyShapeStyle(Color.clear))
            )
        }
        .buttonStyle(WpayinPressableStyle())
    }

    private var balanceAndNetworkRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.Tokens.balance.localized)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(WpayinColors.textSecondary)

                Text(portfolioBalance.formatted(as: settingsManager.selectedCurrency))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(WpayinColors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 8)

            if !availableNetworks.isEmpty {
                NetworkSelectorButton(
                    selectedNetwork: $selectedNetwork,
                    availableNetworks: availableNetworks,
                    onTap: { showNetworkSelector = true }
                )
            }
        }
    }

    private var swapCard: some View {
        ZStack {
            VStack(spacing: 10) {
                ModernTokenSelector(
                    title: L10n.Swap.youPay.localized,
                    selectedToken: selectedFromToken,
                    amount: $fromAmount,
                    isInput: true,
                    onTokenSelect: {
                        isSelectingFromToken = true
                        showTokenPicker = true
                    }
                )

                ModernTokenSelector(
                    title: L10n.Swap.youReceive.localized,
                    selectedToken: selectedToToken,
                    amount: .constant(estimatedAmountText),
                    isInput: false,
                    onTokenSelect: {
                        isSelectingFromToken = false
                        showTokenPicker = true
                    }
                )
            }

            Button(action: swapTokens) {
                Circle()
                    .fill(WpayinColors.backgroundGradientStart)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle()
                            .stroke(WpayinColors.primary, lineWidth: 1.5)
                    )
                    .overlay(
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(WpayinColors.accentGradient)
                    )
                    .shadow(color: WpayinColors.primary.opacity(0.32), radius: 12)
            }
            .buttonStyle(WpayinPressableStyle())
        }
    }

    private var swapDetailsCard: some View {
        VStack(spacing: 0) {
            SwapDetailRow(
                label: L10n.Swap.rate.localized,
                value: rateDescription
            )

            detailDivider

            Button {
                showGasSettings = true
            } label: {
                SwapDetailRow(
                    label: L10n.Swap.networkFee.localized,
                    value: gasFeeInUSD > 0
                        ? "≈ \(gasFeeInUSD.formatted(as: settingsManager.selectedCurrency))"
                        : "—",
                    showsInfo: true
                )
            }
            .buttonStyle(PlainButtonStyle())

            detailDivider

            Button {
                showSlippageSettings = true
            } label: {
                SwapDetailRow(
                    label: L10n.Swap.slippageTolerance.localized,
                    value: "\(String(format: "%.1f", slippage))%",
                    showsInfo: true,
                    highlightsValue: true
                )
            }
            .buttonStyle(PlainButtonStyle())

            detailDivider

            SwapDetailRow(
                label: L10n.Swap.minimumReceived.localized,
                value: selectedToToken.map {
                    "\(formattedTokenAmount(minimumReceived)) \($0.symbol)"
                } ?? "—",
                showsInfo: true,
                highlightsValue: minimumReceived > 0
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

    private var detailDivider: some View {
        Rectangle()
            .fill(WpayinColors.surfaceBorder)
            .frame(height: 1)
            .padding(.horizontal, 16)
    }

    private var bottomAction: some View {
        VStack(spacing: 8) {
            if !isValidSwap && !fromAmount.isEmpty {
                Text(invalidSwapReason)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(WpayinColors.error)
                    .lineLimit(2)
            }

            Button {
                if isValidSwap {
                    showReviewSwap = true
                }
            } label: {
                HStack(spacing: 9) {
                    if isSwapping {
                        ProgressView()
                            .tint(.white)
                    }

                    Text(isSwapping ? "Swapping...".localized : L10n.Swap.review.localized)
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundColor(isValidSwap ? .white : WpayinColors.textTertiary)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: isValidSwap
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
                            isValidSwap ? WpayinColors.primary.opacity(0.45) : WpayinColors.surfaceBorder,
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: isValidSwap ? WpayinColors.primary.opacity(0.24) : .clear,
                    radius: 14,
                    y: 7
                )
            }
            .disabled(!isValidSwap || isSwapping)
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

    private var rateDescription: String {
        guard let from = selectedFromToken,
              let to = selectedToToken,
              swapRate > 0 else {
            return "—"
        }
        return "1 \(from.symbol) = \(formattedTokenAmount(swapRate)) \(to.symbol)"
    }

    private func formattedTokenAmount(_ value: Double) -> String {
        guard value.isFinite, value > 0 else { return "0.0" }

        let decimals: Int
        if value >= 1_000 {
            decimals = 2
        } else if value >= 1 {
            decimals = 4
        } else {
            decimals = 6
        }

        var result = String(format: "%.\(decimals)f", value)
        while result.contains("."), result.last == "0" {
            result.removeLast()
        }
        if result.last == "." {
            result.append("0")
        }
        return result
    }

    private func ensureSelectedNetworkIsAvailable() {
        guard !availableNetworks.isEmpty else {
            selectedFromToken = nil
            selectedToToken = nil
            return
        }

        if !availableNetworks.contains(selectedNetwork) {
            selectedNetwork = availableNetworks.first ?? .ethereum
        }

        if selectedFromToken == nil || selectedFromToken?.blockchain.rawValue != selectedNetwork.rawValue {
            selectedFromToken = availableTokens.first
        }
        if selectedToToken == nil || selectedToToken?.blockchain.rawValue != selectedNetwork.rawValue {
            selectedToToken = firstAvailableToken(excluding: selectedFromToken)
        }
        if let from = selectedFromToken, let to = selectedToToken, tokenIdentity(from) == tokenIdentity(to) {
            selectedToToken = firstAvailableToken(excluding: from)
        }
    }

    private func firstAvailableToken(excluding token: Token?) -> Token? {
        guard let token else { return availableTokens.first }
        return availableTokens.first { tokenIdentity($0) != tokenIdentity(token) }
    }

    private func tokenIdentity(_ token: Token) -> String {
        "\(token.blockchain.rawValue):\((token.contractAddress ?? "native").lowercased())"
    }

    private var invalidSwapReason: String {
        guard let from = selectedFromToken else { return "Select a token to swap from".localized }
        guard let to = selectedToToken else { return "Select a token to swap to".localized }
        guard let amount = Double(fromAmount) else { return "Enter a valid amount".localized }

        if tokenIdentity(from) == tokenIdentity(to) {
            return "Cannot swap the same token".localized
        }
        if amount > from.balance {
            return L10n.Swap.insufficient.localized(from.symbol)
        }
        return "Enter an amount to swap".localized
    }

    private func swapTokens() {
        withAnimation(.easeInOut(duration: 0.3)) {
            let temp = selectedFromToken
            selectedFromToken = selectedToToken
            selectedToToken = temp
            fromAmount = ""
        }
    }

    private func performSwap() {
        isSwapping = true

        Task {
            do {
                guard let fromToken = selectedFromToken,
                      let toToken = selectedToToken,
                      let amount = Double(fromAmount),
                      amount > 0 else {
                    throw SwapError.invalidTokenPair
                }

                // Get swap quote
                Logger.log("📊 Getting swap quote...")
                let quote = try await SwapService.shared.getQuote(
                    fromToken: fromToken,
                    toToken: toToken,
                    amountIn: Decimal(amount),
                    slippage: slippage
                )

                Logger.log("✅ Quote received: \(quote.amountOut) \(toToken.symbol)")
                Logger.log("💰 Minimum amount out: \(quote.amountOutMin)")
                Logger.log("⛽ Estimated gas: \(quote.gasEstimate)")

                // Execute swap
                Logger.log("🔄 Executing swap...")
                let result = try await SwapService.shared.executeSwap(
                    quote: quote,
                    fromToken: fromToken,
                    toToken: toToken
                )

                Logger.log("✅ Swap successful! TX: \(result.transactionHash)")

                await MainActor.run {
                    isSwapping = false
                    fromAmount = ""
                    swapSuccessMessage = "Transaction: %@".localized(result.transactionHash)
                    showSwapSuccess = true
                    NotificationManager.shared.notifySwapCompleted(
                        from: fromToken.symbol,
                        to: toToken.symbol
                    )

                    // Refresh wallet data to show updated balances
                    Task {
                        await walletManager.refreshWalletData()
                    }
                }
            } catch {
                Logger.log("❌ Swap failed: \(error.localizedDescription)")
                await MainActor.run {
                    isSwapping = false
                    swapErrorMessage = error.localizedDescription
                    showSwapError = true
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct ModernTokenSelector: View {
    let title: String
    let selectedToken: Token?
    @Binding var amount: String
    let isInput: Bool
    let onTokenSelect: () -> Void
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.localized)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(WpayinColors.textSecondary)

            HStack(spacing: 12) {
                Group {
                    if isInput {
                        TextField("0.0", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.leading)
                    } else {
                        Text(amount.isEmpty ? "0.0" : amount)
                    }
                }
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .foregroundColor(isInput ? WpayinColors.text : WpayinColors.text.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .frame(maxWidth: .infinity, alignment: .leading)

                tokenButton
            }

            HStack(spacing: 8) {
                Text(secondaryAmountText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(WpayinColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 6)

                if let token = selectedToken {
                    Text("\(L10n.Tokens.balance.localized): \(TokenIconHelper.formattedBalance(token.balance)) \(token.symbol)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(WpayinColors.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)

                    if isInput {
                        Button {
                            amount = maximumAmount(for: token)
                        } label: {
                            Text("MAX".localized)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(WpayinColors.primary)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(WpayinColors.primary.opacity(0.11))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                                .stroke(WpayinColors.primary.opacity(0.65), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(WpayinPressableStyle())
                        .disabled(token.balance <= 0)
                        .opacity(token.balance > 0 ? 1 : 0.45)
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: WpayinRadius.card, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            WpayinColors.primary.opacity(isInput ? 0.11 : 0.075),
                            WpayinColors.surface,
                            WpayinColors.surface
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: WpayinRadius.card, style: .continuous)
                        .stroke(
                            isInput
                                ? WpayinColors.primary.opacity(0.32)
                                : WpayinColors.surfaceBorder,
                            lineWidth: 1
                        )
                )
        )
    }

    private var tokenButton: some View {
        Button(action: onTokenSelect) {
            HStack(spacing: 8) {
                if let token = selectedToken {
                    TokenIconView(token: token, size: 34, showNetworkBadge: true)

                    Text(token.symbol)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(WpayinColors.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                } else {
                    Text(L10n.Tokens.selectToken.localized)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(WpayinColors.text)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(WpayinColors.textSecondary)
            }
            .padding(.leading, 9)
            .padding(.trailing, 11)
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
        .buttonStyle(WpayinPressableStyle())
    }

    private var secondaryAmountText: String {
        guard isInput,
              let token = selectedToken,
              let amountValue = Double(amount),
              amountValue > 0 else {
            return isInput ? "≈ \(0.0.formatted(as: settingsManager.selectedCurrency))" : L10n.Swap.estimatedAmount.localized
        }
        return "≈ \((amountValue * token.price).formatted(as: settingsManager.selectedCurrency))"
    }

    private func maximumAmount(for token: Token) -> String {
        var result = String(format: "%.8f", token.balance)
        while result.contains("."), result.last == "0" {
            result.removeLast()
        }
        if result.last == "." {
            result.removeLast()
        }
        return result
    }
}

struct SwapDetailRow: View {
    let label: String
    let value: String
    var showsInfo = false
    var highlightsValue = false

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(WpayinColors.textSecondary)

            if showsInfo {
                Image(systemName: "info.circle")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(WpayinColors.textTertiary)
            }

            Spacer(minLength: 12)

            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(highlightsValue ? WpayinColors.primary : WpayinColors.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 48)
        .contentShape(Rectangle())
    }
}

struct SwapReviewSheet: View {
    let fromToken: Token
    let toToken: Token
    let fromAmount: Double
    let toAmount: Double
    let minimumReceived: Double
    let rate: Double
    let isSwapping: Bool
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

                Text(L10n.Swap.review.localized)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(WpayinColors.text)

                VStack(spacing: 16) {
                    HStack(spacing: 10) {
                        reviewToken(token: fromToken, amount: fromAmount)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(WpayinColors.textTertiary)

                        reviewToken(token: toToken, amount: toAmount)
                    }

                    Rectangle()
                        .fill(WpayinColors.surfaceBorder)
                        .frame(height: 1)

                    SwapDetailRow(
                        label: L10n.Swap.rate.localized,
                        value: "1 \(fromToken.symbol) = \(formatted(rate)) \(toToken.symbol)"
                    )

                    SwapDetailRow(
                        label: L10n.Swap.minimumReceived.localized,
                        value: "\(formatted(minimumReceived)) \(toToken.symbol)",
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
                        if isSwapping {
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
                .disabled(isSwapping)
                .buttonStyle(WpayinPressableStyle())

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 20)
        }
    }

    private func reviewToken(token: Token, amount: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                TokenIconView(token: token, size: 30, showNetworkBadge: true)

                Text(token.symbol)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(WpayinColors.textSecondary)
            }

            Text(formatted(amount))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(WpayinColors.text)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text((amount * token.price).formatted(as: settingsManager.selectedCurrency))
                .font(.system(size: 12))
                .foregroundColor(WpayinColors.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatted(_ value: Double) -> String {
        let decimals = value >= 1_000 ? 2 : (value >= 1 ? 4 : 6)
        var result = String(format: "%.\(decimals)f", value)
        while result.contains("."), result.last == "0" {
            result.removeLast()
        }
        if result.last == "." {
            result.append("0")
        }
        return result
    }
}

extension View {
    // Internal — BridgeReviewSheet uses the same presentation.
    @ViewBuilder
    func swapReviewPresentation() -> some View {
        if #available(iOS 16.4, *) {
            self
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(28)
        } else if #available(iOS 16.0, *) {
            self
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        } else {
            self
        }
    }
}

struct TokenPickerView: View {
    let tokens: [Token]
    let selectedToken: Token?
    let onSelect: (Token) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(L10n.Action.cancel.localized) {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(WpayinColors.primary)
                    .frame(width: 64, alignment: .leading)

                    Spacer()

                    Text(L10n.Tokens.selectToken.localized)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(WpayinColors.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Spacer()

                    Text("")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.clear)
                        .frame(width: 64)
                }
                .padding(20)

                // Token List
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(tokens) { token in
                            Button(action: {
                                onSelect(token)
                                dismiss()
                            }) {
                                HStack(spacing: 12) {
                                    TokenIconView(token: token, size: 34, showNetworkBadge: true)

                                    VStack(alignment: .leading, spacing: 4) {
                                        let tokenPlatform = BlockchainPlatform(rawValue: token.blockchain.rawValue) ?? .ethereum
                                        HStack(spacing: 6) {
                                            Text(token.symbol)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(WpayinColors.text)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.75)
                                            
                                            if let proto = token.tokenProtocol {
                                                TokenProtocolBadge(tokenProtocol: proto, size: .small)
                                            }

                                            // Network badge — real chain icon
                                            NetworkIconView(blockchain: token.blockchain, size: 14)

                                            Text(tokenPlatform.name)
                                                .font(.system(size: 11))
                                                .foregroundColor(WpayinColors.textSecondary)
                                                .lineLimit(1)
                                        }

                                        Text(token.name)
                                            .font(.system(size: 12))
                                            .foregroundColor(WpayinColors.textSecondary)
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(TokenIconHelper.formattedBalance(token.balance))
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(WpayinColors.text)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)

                                        Text(token.totalValue.formatted(as: settingsManager.selectedCurrency))
                                            .font(.system(size: 12))
                                            .foregroundColor(WpayinColors.textSecondary)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.75)
                                    }
                                    .frame(width: 78, alignment: .trailing)

                                    if selectedToken?.id == token.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(WpayinColors.primary)
                                    }
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedToken?.id == token.id ? WpayinColors.primary.opacity(0.1) : WpayinColors.surface)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .background(WpayinColors.background)
        }
    }

    private func tokenGradient(for token: Token) -> LinearGradient {
        let colors: [Color]
        switch token.symbol.uppercased() {
        case "ETH":
            colors = [Color.blue, Color.cyan]
        case "BTC":
            colors = [Color.orange, Color.yellow]
        case "USDT", "USDC":
            colors = [Color.green, Color.mint]
        default:
            colors = [WpayinColors.primary, WpayinColors.primary.opacity(0.7)]
        }

        return LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}



struct GasSettingsSheet: View {
    @Binding var selectedSpeed: GasSpeed
    let estimatedGas: Double
    let gasInUSD: Double
    let tokenSymbol: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    ForEach(GasSpeed.allCases, id: \.self) { speed in
                        Button(action: {
                            selectedSpeed = speed
                            dismiss()
                        }) {
                            HStack(spacing: 16) {
                                // Icon
                                ZStack {
                                    Circle()
                                        .fill(selectedSpeed == speed ? WpayinColors.primary.opacity(0.2) : WpayinColors.surface)
                                        .frame(width: 50, height: 50)

                                    Image(systemName: speed.icon)
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(selectedSpeed == speed ? WpayinColors.primary : WpayinColors.textSecondary)
                                }

                                // Info
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(speed.displayName)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(WpayinColors.text)

                                    Text("~\(String(format: "%.4f", estimatedGas * speed.multiplier)) \(tokenSymbol)")
                                        .font(.system(size: 14))
                                        .foregroundColor(WpayinColors.textSecondary)
                                }

                                Spacer()

                                // Price in USD
                                Text((gasInUSD * speed.multiplier).formatted(as: settingsManager.selectedCurrency))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(WpayinColors.text)

                                if selectedSpeed == speed {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(WpayinColors.primary)
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(selectedSpeed == speed ? WpayinColors.primary.opacity(0.1) : WpayinColors.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(selectedSpeed == speed ? WpayinColors.primary : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Spacer()
            }
            .background(WpayinColors.background)
            .navigationTitle(L10n.Swap.gasSpeed.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.Action.done.localized) {
                        dismiss()
                    }
                    .foregroundColor(WpayinColors.primary)
                }
            }
        }
    }
}

struct SlippageSettingsSheet: View {
    @Binding var slippage: Double
    @Environment(\.dismiss) private var dismiss
    @State private var customSlippage = ""
    @FocusState private var customFieldFocused: Bool

    private let presetSlippages = [0.1, 0.5, 1.0, 3.0]

    private var customValue: Double? {
        guard let value = Double(customSlippage.replacingOccurrences(of: ",", with: ".")),
              value > 0, value <= 50 else { return nil }
        return value
    }

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                VStack(spacing: 20) {
                    // Current value
                    VStack(spacing: 8) {
                        Text("\(String(format: "%.1f", slippage))%")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundColor(WpayinColors.primary)

                        Text(L10n.Swap.slippageWarning.localized)
                            .font(.system(size: 13))
                            .foregroundColor(WpayinColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 12)

                    // Presets
                    HStack(spacing: 10) {
                        ForEach(presetSlippages, id: \.self) { preset in
                            let isSelected = slippage == preset
                            Button {
                                slippage = preset
                                customSlippage = ""
                                customFieldFocused = false
                            } label: {
                                Text("\(String(format: preset < 1 ? "%.1f" : "%.0f", preset))%")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(isSelected ? WpayinColors.primary : WpayinColors.text)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 46)
                                    .background(
                                        RoundedRectangle(cornerRadius: WpayinRadius.medium, style: .continuous)
                                            .fill(isSelected ? WpayinColors.primary.opacity(0.12) : WpayinColors.surface)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: WpayinRadius.medium, style: .continuous)
                                            .stroke(isSelected ? WpayinColors.primary : WpayinColors.surfaceBorder,
                                                    lineWidth: isSelected ? 1.5 : 1)
                                    )
                            }
                            .buttonStyle(WpayinPressableStyle())
                        }
                    }

                    // Custom value
                    HStack(spacing: 10) {
                        HStack(spacing: 6) {
                            TextField("Custom %".localized, text: $customSlippage)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(WpayinColors.text)
                                .keyboardType(.decimalPad)
                                .focused($customFieldFocused)

                            Text("%")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(WpayinColors.textSecondary)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 46)
                        .background(
                            RoundedRectangle(cornerRadius: WpayinRadius.medium, style: .continuous)
                                .fill(WpayinColors.surfaceLight)
                                .overlay(
                                    RoundedRectangle(cornerRadius: WpayinRadius.medium, style: .continuous)
                                        .stroke(customFieldFocused ? WpayinColors.primary : WpayinColors.surfaceBorder,
                                                lineWidth: customFieldFocused ? 1.5 : 1)
                                )
                        )

                        Button {
                            if let value = customValue {
                                slippage = value
                                customFieldFocused = false
                            }
                        } label: {
                            Text(L10n.Action.set.localized)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 22)
                                .frame(height: 46)
                                .background(
                                    RoundedRectangle(cornerRadius: WpayinRadius.medium, style: .continuous)
                                        .fill(WpayinColors.accentGradient)
                                        .opacity(customValue == nil ? 0.4 : 1)
                                )
                        }
                        .buttonStyle(WpayinPressableStyle())
                        .disabled(customValue == nil)
                    }

                    // High slippage caution
                    if slippage >= 3 {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(WpayinColors.warning)

                            Text(L10n.Swap.slippageHighWarning.localized)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(WpayinColors.warning)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: WpayinRadius.medium, style: .continuous)
                                .fill(WpayinColors.warning.opacity(0.1))
                        )
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .animation(.easeOut(duration: 0.15), value: slippage >= 3)
            }
            .navigationTitle(L10n.Swap.slippageTolerance.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.Action.done.localized) {
                        dismiss()
                    }
                    .foregroundColor(WpayinColors.primary)
                }
            }
        }
        .onAppear {
            if !presetSlippages.contains(slippage) {
                customSlippage = String(format: "%.1f", slippage)
            }
        }
    }
}

struct NetworkSelectorButton: View {
    @Binding var selectedNetwork: BlockchainPlatform
    let availableNetworks: [BlockchainPlatform]
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 9) {
                PlatformIconView(platform: selectedNetwork, size: 25)

                Text(selectedNetwork.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(WpayinColors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(WpayinColors.textSecondary)
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(
                Capsule()
                    .fill(WpayinColors.surfaceLight)
                    .overlay(
                        Capsule()
                            .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(WpayinPressableStyle())
        .accessibilityLabel(L10n.Swap.selectNetwork.localized)
    }
}

struct NetworkSelectorSheet: View {
    @Binding var selectedNetwork: BlockchainPlatform
    let availableNetworks: [BlockchainPlatform]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header (same style as TokenPickerView)
                HStack {
                    Button(L10n.Action.cancel.localized) {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(WpayinColors.primary)

                    Spacer()

                    Text(L10n.Swap.selectNetwork.localized)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(WpayinColors.text)

                    Spacer()

                    Text("")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.clear)
                }
                .padding(20)

                // Network List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(availableNetworks, id: \.self) { network in
                            Button(action: {
                                selectedNetwork = network
                                dismiss()
                            }) {
                                HStack(spacing: 16) {
                                    PlatformIconView(platform: network, size: 36)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(network.name)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(WpayinColors.text)
                                        
                                        Text(network.symbol)
                                            .font(.system(size: 14))
                                            .foregroundColor(WpayinColors.textSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedNetwork == network {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(WpayinColors.primary)
                                    }
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedNetwork == network ? WpayinColors.primary.opacity(0.1) : WpayinColors.surface)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .background(WpayinColors.background)
        }
    }
}

#Preview {
    let walletManager = WalletManager()
    let settingsManager = SettingsManager()
    // walletManager.tokens = Token.mockTokens // disabled

    return SwapView()
        .environmentObject(walletManager)
        .environmentObject(settingsManager)
}
