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
    @State private var showSwapError = false
    @State private var swapErrorMessage = ""
    @State private var showReviewSwap = false
    @State private var swapProgress: SwapProgressState?
    @State private var showSwapProgress = false
    @State private var isBridgeMode = false
    @State private var liveQuote: DEXSwapQuote?
    @State private var liveFeeEstimate: SwapNetworkFeeEstimate?
    @State private var liveEstimateKey = ""
    @State private var isEstimatingNetworkFee = false

    init(initialFromToken: Token? = nil) {
        self.initialFromToken = initialFromToken
        let initialNetwork = initialFromToken.flatMap { BlockchainPlatform(rawValue: $0.blockchain.rawValue) } ?? .ethereum
        _selectedNetwork = State(initialValue: initialNetwork)
        _selectedFromToken = State(initialValue: initialFromToken)
    }

    private var selectableTokens: [Token] {
        walletManager.visibleSupportedTokens.filter {
            Self.supportedSwapBlockchains.contains($0.blockchain)
        }
    }

    private var availableTokens: [Token] {
        selectableTokens.filter { $0.blockchain.rawValue == selectedNetwork.rawValue }
    }
    
    private var availableNetworks: [BlockchainPlatform] {
        walletManager.availableBlockchains
            .filter { 
                $0.network == .mainnet && 
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
        if let quote = currentLiveQuote, quote.amountIn > 0 {
            return NSDecimalNumber(decimal: quote.amountOut / quote.amountIn).doubleValue
        }
        guard let fromToken = selectedFromToken,
              let toToken = selectedToToken,
              fromToken.price > 0, toToken.price > 0 else { return 0.0 }
        return fromToken.price / toToken.price
    }

    private var estimatedToAmount: Double {
        if let quote = currentLiveQuote {
            return NSDecimalNumber(decimal: quote.amountOut).doubleValue
        }
        guard let amount = Double(fromAmount), amount > 0 else { return 0.0 }
        return amount * swapRate
    }

    private var platformFeeValue: Double {
        guard let token = selectedFromToken,
              token.blockchain.isEVM,
              let amount = Decimal(string: fromAmount.replacingOccurrences(of: ",", with: ".")) else {
            return 0
        }
        return NSDecimalNumber(
            decimal: TransactionService.platformFee(for: amount)
        ).doubleValue
    }

    private var totalSourceDebit: Double {
        (Double(fromAmount) ?? 0) + platformFeeValue
    }

    private var isValidSwap: Bool {
        guard let from = selectedFromToken,
              let to = selectedToToken,
              let amount = Double(fromAmount),
              amount > 0 else { return false }
        return tokenIdentity(from) != tokenIdentity(to)
            && amount + platformFeeValue <= from.balance
            && hasSufficientSwapGas
    }

    private var sourceNativeBalance: Double {
        guard let from = selectedFromToken else { return 0 }
        return walletManager.tokens.first {
            $0.blockchain == from.blockchain && $0.isNative
        }?.balance ?? 0
    }

    private var hasSufficientSwapGas: Bool {
        guard currentLiveQuote != nil,
              let from = selectedFromToken,
              let amount = Double(fromAmount),
              estimatedGasFee > 0 else { return true }

        if from.isNative {
            return amount + platformFeeValue + estimatedGasFee <= from.balance
        }
        return sourceNativeBalance >= estimatedGasFee
    }

    private var estimatedGasFee: Double {
        standardGasFee * selectedGasSpeed.multiplier
    }

    private var standardGasFee: Double {
        guard currentLiveQuote != nil, let estimate = liveFeeEstimate else { return 0 }
        return NSDecimalNumber(decimal: estimate.standardFeeNative).doubleValue
    }

    private var gasFeeInUSD: Double {
        guard let token = selectedFromToken,
              let nativePrice = walletManager.currentUSDPrice(
                for: token.blockchain.nativeToken,
                blockchain: token.blockchain
              ) else { return 0 }
        return estimatedGasFee * nativePrice
    }

    private var standardGasFeeUSD: Double {
        guard let token = selectedFromToken,
              let nativePrice = walletManager.currentUSDPrice(
                for: token.blockchain.nativeToken,
                blockchain: token.blockchain
              ) else { return 0 }
        return standardGasFee * nativePrice
    }

    private var portfolioBalance: Double {
        walletManager.visibleGroupedTokens.reduce(0) { $0 + $1.totalValue }
    }

    private var minimumReceived: Double {
        if let quote = currentLiveQuote {
            return NSDecimalNumber(decimal: quote.amountOutMin).doubleValue
        }
        return estimatedToAmount * max(0, 1 - (slippage / 100))
    }

    private var swapEstimateKey: String {
        let from = selectedFromToken.map(tokenIdentity) ?? "none"
        let to = selectedToToken.map(tokenIdentity) ?? "none"
        return "\(from)|\(to)|\(fromAmount)|\(String(format: "%.4f", slippage))"
    }

    private var currentLiveQuote: DEXSwapQuote? {
        liveEstimateKey == swapEstimateKey ? liveQuote : nil
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
                            balanceRow
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
                tokens: isSelectingFromToken ? selectableTokens : availableTokens,
                selectedToken: isSelectingFromToken ? selectedFromToken : selectedToToken,
                initialNetwork: selectedNetwork,
                availableNetworks: isSelectingFromToken ? availableNetworks : [selectedNetwork]
            ) { token in
                if isSelectingFromToken {
                    if let tokenNetwork = BlockchainPlatform(rawValue: token.blockchain.rawValue) {
                        selectedNetwork = tokenNetwork
                    }
                    selectedFromToken = token
                } else {
                    selectedToToken = token
                }
            }
        }

        .sheet(isPresented: $showGasSettings) {
            GasSettingsSheet(
                selectedSpeed: $selectedGasSpeed,
                estimatedGas: standardGasFee,
                gasInUSD: standardGasFeeUSD,
                tokenSymbol: selectedFromToken?.blockchain.nativeToken ?? "ETH"
            )
        }
        .sheet(isPresented: $showSlippageSettings) {
            SlippageSettingsSheet(slippage: $slippage)
                .swapReviewPresentation()
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
                    networkFeeNative: estimatedGasFee,
                    networkFeeUSD: gasFeeInUSD,
                    platformFee: platformFeeValue,
                    nativeTokenSymbol: fromToken.blockchain.nativeToken,
                    approvalRequired: liveFeeEstimate?.approvalRequired ?? false,
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
            if selectedFromToken?.blockchain.rawValue != selectedNetwork.rawValue {
                selectedFromToken = availableTokens.first
            }
            if selectedToToken?.blockchain.rawValue != selectedNetwork.rawValue {
                selectedToToken = firstAvailableToken(excluding: selectedFromToken)
            }
            fromAmount = ""
        }
        .onChange(of: walletManager.selectedBlockchains) { _ in
            ensureSelectedNetworkIsAvailable()
        }
        .task(id: swapEstimateKey) {
            liveQuote = nil
            liveFeeEstimate = nil
            liveEstimateKey = ""
            guard isValidSwap else { return }

            // Debounce typing, then refresh periodically while the same swap
            // remains on screen so the displayed network fee stays current.
            try? await Task.sleep(nanoseconds: 250_000_000)
            while !Task.isCancelled {
                await refreshLiveSwapEstimate(showError: false)
                try? await Task.sleep(nanoseconds: 15_000_000_000)
            }
        }
        .alert("Swap Failed".localized, isPresented: $showSwapError) {
            Button("OK".localized) { }
        } message: {
            Text(swapErrorMessage)
        }
        .sheet(isPresented: $showSwapProgress) {
            if let progress = swapProgress {
                SwapProgressSheet(state: progress)
                    .swapReviewPresentation()
            }
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

    private var balanceRow: some View {
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
        .frame(maxWidth: .infinity, alignment: .leading)
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
                    },
                    onMax: setMaximumSwapAmount
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

            if platformFeeValue > 0 {
                detailDivider

                SwapDetailRow(
                    label: "Platform fee".localized,
                    value: "\(formattedTokenAmount(platformFeeValue)) \(selectedFromToken?.symbol ?? "")"
                )
            }
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
                    Task { await prepareReviewSwap() }
                }
            } label: {
                HStack(spacing: 9) {
                    if isSwapping || isEstimatingNetworkFee {
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
            .disabled(!isValidSwap || isSwapping || isEstimatingNetworkFee)
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
        if amount + platformFeeValue > from.balance {
            return L10n.Swap.insufficient.localized(from.symbol)
        }
        if !hasSufficientSwapGas {
            return "Insufficient %@ balance for the amount and network fee".localized(from.blockchain.nativeToken)
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

    private func setMaximumSwapAmount() {
        guard let token = selectedFromToken, token.balance > 0 else { return }

        Task {
            isEstimatingNetworkFee = true
            let feeRate = AppConfig.platformFeeEnabled
                ? NSDecimalNumber(decimal: AppConfig.platformFeeRate).doubleValue
                : 0
            if token.isNative {
                // Start below the full balance so the RPC can simulate where
                // possible. If it still cannot, SwapService returns the route's
                // conservative limit specifically for this MAX calculation.
                fromAmount = editableAmount(token.balance * 0.995 / (1 + feeRate))
            } else {
                fromAmount = editableAmount(token.balance / (1 + feeRate))
            }

            await refreshLiveSwapEstimate(showError: false)

            if token.isNative, estimatedGasFee > 0 {
                let reserve = max(estimatedGasFee * 0.05, 0.00000001)
                let spendable = max(0, token.balance - estimatedGasFee - reserve) / (1 + feeRate)
                fromAmount = editableAmount(spendable)
                await refreshLiveSwapEstimate(showError: false)
            }
            isEstimatingNetworkFee = false

            if !hasSufficientSwapGas {
                swapErrorMessage = "Insufficient %@ balance for the amount and network fee".localized(token.blockchain.nativeToken)
                showSwapError = true
            }
        }
    }

    private func editableAmount(_ value: Double) -> String {
        var result = String(format: "%.12f", max(0, value))
        while result.last == "0" { result.removeLast() }
        if result.last == "." { result.removeLast() }
        return result
    }

    private func refreshLiveSwapEstimate(showError: Bool) async {
        guard let fromToken = selectedFromToken,
              let toToken = selectedToToken,
              let amount = Decimal(string: fromAmount.replacingOccurrences(of: ",", with: ".")),
              amount > 0 else { return }

        let requestedKey = swapEstimateKey
        do {
            let quote = try await SwapService.shared.getQuote(
                fromToken: fromToken,
                toToken: toToken,
                amountIn: amount,
                slippage: slippage
            )
            let fee = try await SwapService.shared.estimateNetworkFee(
                quote: quote,
                fromToken: fromToken,
                toToken: toToken
            )

            guard requestedKey == swapEstimateKey else { return }
            liveQuote = quote
            liveFeeEstimate = fee
            liveEstimateKey = requestedKey
        } catch {
            guard requestedKey == swapEstimateKey else { return }
            liveQuote = nil
            liveFeeEstimate = nil
            liveEstimateKey = ""
            if showError {
                swapErrorMessage = error.localizedDescription
                showSwapError = true
            }
        }
    }

    private func prepareReviewSwap() async {
        guard isValidSwap else { return }
        isEstimatingNetworkFee = true
        await refreshLiveSwapEstimate(showError: true)
        isEstimatingNetworkFee = false

        guard currentLiveQuote != nil, liveFeeEstimate != nil else { return }
        guard hasSufficientSwapGas else {
            let symbol = selectedFromToken?.blockchain.nativeToken ?? "ETH"
            swapErrorMessage = "Insufficient %@ balance for the amount and network fee".localized(symbol)
            showSwapError = true
            return
        }
        showReviewSwap = true
    }

    private func performSwap() {
        isSwapping = true

        Task {
            guard await settingsManager.authorizeSpending(reason: "auth.confirmPayment".localized) else {
                await MainActor.run { isSwapping = false }
                return
            }
            do {
                guard let fromToken = selectedFromToken,
                      let toToken = selectedToToken,
                      let amount = Double(fromAmount),
                      amount > 0 else {
                    throw SwapError.invalidTokenPair
                }

                // Reuse the quote and live gas simulation accepted on Review.
                // If the inputs changed unexpectedly, refresh both first.
                let quote: DEXSwapQuote
                let feeEstimate: SwapNetworkFeeEstimate
                if let reviewedQuote = currentLiveQuote,
                   let reviewedFee = liveFeeEstimate {
                    quote = reviewedQuote
                    feeEstimate = reviewedFee
                } else {
                    Logger.log("📊 Refreshing swap quote and network fee...")
                    quote = try await SwapService.shared.getQuote(
                        fromToken: fromToken,
                        toToken: toToken,
                        amountIn: Decimal(amount),
                        slippage: slippage
                    )
                    feeEstimate = try await SwapService.shared.estimateNetworkFee(
                        quote: quote,
                        fromToken: fromToken,
                        toToken: toToken
                    )
                }

                Logger.log("✅ Quote received: \(quote.amountOut) \(toToken.symbol)")

                // Hand the rest of the flow to the live progress sheet.
                let estimatedOut = NSDecimalNumber(decimal: quote.amountOut).doubleValue
                await MainActor.run {
                    swapProgress = SwapProgressState(
                        fromSymbol: fromToken.symbol,
                        toSymbol: toToken.symbol,
                        amountIn: amount,
                        amountOut: estimatedOut,
                        includesApproval: feeEstimate.approvalRequired,
                        blockchain: fromToken.blockchain,
                        phase: feeEstimate.approvalRequired ? .approving : .submitting
                    )
                    showReviewSwap = false
                }
                // Let the review sheet finish dismissing before presenting.
                try? await Task.sleep(nanoseconds: 250_000_000)
                await MainActor.run { showSwapProgress = true }

                Logger.log("🔄 Executing swap...")
                let result = try await SwapService.shared.executeSwap(
                    quote: quote,
                    fromToken: fromToken,
                    toToken: toToken,
                    gasLimit: feeEstimate.swapGasLimit,
                    approvalGasLimit: feeEstimate.approvalGasLimit,
                    gasPriceMultiplier: selectedGasSpeed.multiplier,
                    onPhase: { phase in
                        switch phase {
                        case .approving: swapProgress?.phase = .approving
                        case .submitting: swapProgress?.phase = .submitting
                        }
                    }
                )

                Logger.log("✅ Swap broadcast! TX: \(result.transactionHash)")

                await SwapService.shared.collectPlatformFee(
                    for: quote.amountIn,
                    token: fromToken
                )

                let explorerUrl = URL(
                    string: NetworkManager.shared.getExplorerUrl(
                        for: fromToken.blockchain,
                        txHash: result.transactionHash
                    )
                )

                await MainActor.run {
                    isSwapping = false
                    fromAmount = ""
                    swapProgress?.txHash = result.transactionHash
                    swapProgress?.explorerUrl = explorerUrl
                    swapProgress?.phase = .confirming

                    // Show the swap in Activity right away, as pending.
                    walletManager.registerLocalTransaction(
                        Transaction(
                            hash: result.transactionHash,
                            from: walletManager.walletAddress,
                            to: walletManager.walletAddress,
                            amount: amount,
                            token: fromToken.symbol,
                            type: .swap,
                            status: .pending,
                            timestamp: Date(),
                            gasUsed: 0,
                            gasFee: 0,
                            explorerUrl: explorerUrl,
                            blockchain: fromToken.blockchain
                        )
                    )
                }

                await trackSwapConfirmation(
                    hash: result.transactionHash,
                    fromToken: fromToken,
                    toToken: toToken
                )
            } catch {
                Logger.log("❌ Swap failed: \(error.localizedDescription)")
                await MainActor.run {
                    isSwapping = false
                    if swapProgress != nil, showSwapProgress {
                        swapProgress?.phase = .failed(error.localizedDescription)
                    } else {
                        swapErrorMessage = error.localizedDescription
                        showSwapError = true
                    }
                }
            }
        }
    }

    /// Poll the transaction receipt until the swap is mined, updating both
    /// the progress sheet and the pending entry in Activity.
    private func trackSwapConfirmation(hash: String, fromToken: Token, toToken: Token) async {
        // Matches the router's 20-minute swap deadline — a transaction not
        // mined by then reverts as EXPIRED on-chain anyway.
        let deadline = Date().addingTimeInterval(21 * 60)

        // L2 chains confirm in a couple of seconds — check early, then settle
        // into a steady cadence.
        var pollInterval: UInt64 = 2_000_000_000

        while Date() < deadline {
            try? await Task.sleep(nanoseconds: pollInterval)
            pollInterval = 3_000_000_000

            guard let state = try? await SwapService.shared.fetchTransactionState(
                hash: hash,
                blockchain: fromToken.blockchain
            ) else { continue }

            switch state {
            case .notFound:
                // Public RPCs may not expose a future-nonce transaction until
                // its predecessor confirms. Keep tracking through the router
                // deadline; absence alone is not proof that it was dropped.
                continue

            case .pending:
                continue

            case .confirmed(let blockNumber, let gasUsed, let gasFeeNative):
                await MainActor.run {
                    swapProgress?.phase = .confirmed
                    walletManager.updateLocalTransactionStatus(
                        hash: hash,
                        status: .confirmed,
                        gasUsed: gasUsed,
                        gasFee: gasFeeNative,
                        blockNumber: blockNumber
                    )
                    NotificationManager.shared.notifySwapCompleted(
                        from: fromToken.symbol,
                        to: toToken.symbol
                    )
                }
                await walletManager.refreshWalletData()
                return

            case .failed(let blockNumber, let gasUsed, let gasFeeNative):
                await MainActor.run {
                    swapProgress?.phase = .failed("The transaction was reverted on-chain".localized)
                    walletManager.updateLocalTransactionStatus(
                        hash: hash,
                        status: .failed,
                        gasUsed: gasUsed,
                        gasFee: gasFeeNative,
                        blockNumber: blockNumber
                    )
                }
                return
            }
        }

        // Deadline passed with no receipt — the swap's on-chain deadline has
        // expired, so tell the user instead of spinning forever. Activity
        // keeps the entry pending until an explorer reports the final state.
        await MainActor.run {
            swapProgress?.phase = .failed("error.swap.confirmationTimeout".localized)
        }
    }
}

// MARK: - Swap Progress

struct SwapProgressState {
    enum Phase: Equatable {
        case approving
        case submitting
        case confirming
        case confirmed
        case failed(String)
    }

    let fromSymbol: String
    let toSymbol: String
    let amountIn: Double
    let amountOut: Double
    let includesApproval: Bool
    let blockchain: BlockchainType
    var phase: Phase
    var txHash: String?
    var explorerUrl: URL?
}

/// Live view of a running swap: step timeline from token approval through
/// broadcast to on-chain confirmation, with hash + explorer link.
struct SwapProgressSheet: View {
    let state: SwapProgressState
    @Environment(\.dismiss) private var dismiss

    private var isFinished: Bool {
        switch state.phase {
        case .confirmed, .failed: return true
        default: return false
        }
    }

    private var failureMessage: String? {
        if case .failed(let message) = state.phase { return message }
        return nil
    }

    private var headline: String {
        switch state.phase {
        case .approving: return "Approving token".localized
        case .submitting: return "Submitting transaction".localized
        case .confirming: return "Waiting for network confirmation".localized
        case .confirmed: return "Swap completed".localized
        case .failed: return "Swap Failed".localized
        }
    }

    var body: some View {
        ZStack {
            WpayinColors.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    statusHeader

                    VStack(spacing: 0) {
                        if state.includesApproval {
                            SwapProgressStepRow(
                                title: "Token approval".localized,
                                state: stepState(for: .approving),
                                isFirst: true,
                                isLast: false
                            )
                        }

                        SwapProgressStepRow(
                            title: "Transaction submitted".localized,
                            state: stepState(for: .submitting),
                            isFirst: !state.includesApproval,
                            isLast: false
                        )

                        SwapProgressStepRow(
                            title: "Network confirmation".localized,
                            state: stepState(for: .confirming),
                            isFirst: false,
                            isLast: false
                        )

                        SwapProgressStepRow(
                            title: "Completed".localized,
                            state: finalStepState,
                            isFirst: false,
                            isLast: true
                        )
                    }
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(WpayinColors.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                            )
                    )

                    if let failureMessage {
                        Text(failureMessage)
                            .font(.wpayinCaption)
                            .foregroundColor(WpayinColors.error)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 6)
                    } else if !isFinished {
                        Text("This usually takes under a minute, but can take longer when the network is busy.".localized)
                            .font(.wpayinCaption)
                            .foregroundColor(WpayinColors.textTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 6)
                    }

                    if let txHash = state.txHash {
                        hashCard(txHash)
                    }

                    if let explorerUrl = state.explorerUrl {
                        Link(destination: explorerUrl) {
                            HStack(spacing: 8) {
                                Image(systemName: "safari")
                                    .font(.system(size: 14, weight: .semibold))
                                Text(L10n.Activity.viewExplorer.localized)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(WpayinColors.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(WpayinColors.primary.opacity(0.12))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    if !isFinished {
                        Text("You can close this window — track the status anytime in Activity.".localized)
                            .font(.wpayinSmall)
                            .foregroundColor(WpayinColors.textTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 6)
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text((isFinished ? "Done" : "Close").localized)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 17, style: .continuous)
                                    .fill(WpayinColors.accentGradient)
                            )
                    }
                    .buttonStyle(WpayinPressableStyle())
                }
                .padding(.horizontal, 22)
                .padding(.top, 26)
                .padding(.bottom, 30)
            }
        }
    }

    private var statusHeader: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(headerColor.opacity(0.14))
                    .frame(width: 74, height: 74)

                if isFinished {
                    Image(systemName: failureMessage == nil ? "checkmark" : "xmark")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(headerColor)
                } else {
                    ProgressView()
                        .scaleEffect(1.3)
                        .tint(WpayinColors.primary)
                }
            }

            Text(headline)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(WpayinColors.text)
                .multilineTextAlignment(.center)

            Text("\(formattedAmount(state.amountIn)) \(state.fromSymbol) → \(formattedAmount(state.amountOut)) \(state.toSymbol)")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(WpayinColors.textSecondary)
        }
    }

    private var headerColor: Color {
        switch state.phase {
        case .confirmed: return WpayinColors.success
        case .failed: return WpayinColors.error
        default: return WpayinColors.primary
        }
    }

    private func hashCard(_ hash: String) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Transaction Hash".localized)
                    .font(.wpayinSmall)
                    .foregroundColor(WpayinColors.textSecondary)

                Text(hash)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(WpayinColors.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button {
                AppToast.copyToClipboard(hash)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(WpayinColors.primary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(WpayinColors.surfaceLight))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(WpayinColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                )
        )
    }

    private func formattedAmount(_ value: Double) -> String {
        if value >= 1 {
            return String(format: "%.4f", value)
        }
        return String(format: "%.6f", value)
    }

    /// Ordering of phases along the timeline for step-state comparison.
    private func phaseIndex(_ phase: SwapProgressState.Phase) -> Int {
        switch phase {
        case .approving: return 0
        case .submitting: return 1
        case .confirming: return 2
        case .confirmed, .failed: return 3
        }
    }

    private func stepState(for step: SwapProgressState.Phase) -> SwapProgressStepRow.StepState {
        let current = phaseIndex(state.phase)
        let target = phaseIndex(step)

        if current > target { return .done }
        if current == target {
            if case .failed = state.phase { return .failed }
            return .active
        }
        return .upcoming
    }

    private var finalStepState: SwapProgressStepRow.StepState {
        switch state.phase {
        case .confirmed: return .done
        case .failed: return .failed
        default: return .upcoming
        }
    }
}

struct SwapProgressStepRow: View {
    enum StepState {
        case done
        case active
        case upcoming
        case failed
    }

    let title: String
    let state: StepState
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(isFirst ? Color.clear : connectorColor)
                    .frame(width: 2, height: 12)

                indicator

                Rectangle()
                    .fill(isLast ? Color.clear : connectorColor)
                    .frame(width: 2, height: 12)
            }
            .frame(width: 28)

            Text(title)
                .font(.system(size: 15, weight: state == .active ? .semibold : .medium, design: .rounded))
                .foregroundColor(titleColor)

            Spacer()
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var indicator: some View {
        switch state {
        case .done:
            Circle()
                .fill(WpayinColors.success)
                .frame(width: 24, height: 24)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                )
        case .active:
            ProgressView()
                .scaleEffect(0.8)
                .tint(WpayinColors.primary)
                .frame(width: 24, height: 24)
                .background(Circle().fill(WpayinColors.primary.opacity(0.14)))
        case .upcoming:
            Circle()
                .stroke(WpayinColors.surfaceBorder, lineWidth: 2)
                .frame(width: 24, height: 24)
        case .failed:
            Circle()
                .fill(WpayinColors.error)
                .frame(width: 24, height: 24)
                .overlay(
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                )
        }
    }

    private var connectorColor: Color {
        state == .done ? WpayinColors.success.opacity(0.55) : WpayinColors.surfaceBorder
    }

    private var titleColor: Color {
        switch state {
        case .done, .active: return WpayinColors.text
        case .upcoming: return WpayinColors.textTertiary
        case .failed: return WpayinColors.error
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
    var onMax: (() -> Void)? = nil
    var showsMax: Bool = true
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.localized)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(WpayinColors.textSecondary)

            HStack(spacing: 12) {
                Group {
                    if isInput && showsMax {
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
                            if let onMax {
                                onMax()
                            } else {
                                amount = fullBalanceAmount(for: token)
                            }
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

    private func fullBalanceAmount(for token: Token) -> String {
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
    let networkFeeNative: Double
    let networkFeeUSD: Double
    let platformFee: Double
    let nativeTokenSymbol: String
    let approvalRequired: Bool
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

                    SwapDetailRow(
                        label: L10n.Swap.networkFee.localized,
                        value: "≈ \(formattedFee(networkFeeNative)) \(nativeTokenSymbol) · \(networkFeeUSD.formatted(as: settingsManager.selectedCurrency))",
                        showsInfo: true,
                        highlightsValue: true
                    )

                    if platformFee > 0 {
                        SwapDetailRow(
                            label: "Platform fee".localized,
                            value: "\(formatted(platformFee)) \(fromToken.symbol)"
                        )
                    }

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

    private func formattedFee(_ value: Double) -> String {
        guard value > 0 else { return "0" }
        return String(format: value < 0.0001 ? "%.8f" : "%.6f", value)
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

    @ViewBuilder
    func swapPickerPresentation() -> some View {
        if #available(iOS 16.4, *) {
            self
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(28)
        } else if #available(iOS 16.0, *) {
            self
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        } else {
            self
        }
    }
}

struct TokenPickerView: View {
    let tokens: [Token]
    let selectedToken: Token?
    let initialNetwork: BlockchainPlatform
    let availableNetworks: [BlockchainPlatform]
    let onSelect: (Token) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var walletManager: WalletManager
    @State private var searchText = ""
    @State private var selectedNetworkFilter: BlockchainPlatform?
    @State private var showFavoritesOnly = false

    init(
        tokens: [Token],
        selectedToken: Token?,
        initialNetwork: BlockchainPlatform,
        availableNetworks: [BlockchainPlatform],
        onSelect: @escaping (Token) -> Void
    ) {
        self.tokens = tokens
        self.selectedToken = selectedToken
        self.initialNetwork = initialNetwork
        self.availableNetworks = availableNetworks
        self.onSelect = onSelect
        _selectedNetworkFilter = State(initialValue: initialNetwork)
    }

    init(
        tokens: [Token],
        selectedToken: Token?,
        onSelect: @escaping (Token) -> Void
    ) {
        let tokenNetworks = tokens.compactMap {
            BlockchainPlatform(rawValue: $0.blockchain.rawValue)
        }
        let startingNetwork = selectedToken.flatMap {
            BlockchainPlatform(rawValue: $0.blockchain.rawValue)
        } ?? tokenNetworks.first ?? .ethereum

        self.tokens = tokens
        self.selectedToken = selectedToken
        self.initialNetwork = startingNetwork
        self.availableNetworks = Array(Set(tokenNetworks))
        self.onSelect = onSelect
        _selectedNetworkFilter = State(initialValue: startingNetwork)
    }

    private var networkOptions: [BlockchainPlatform] {
        var networks = availableNetworks
        for token in tokens {
            guard let platform = BlockchainPlatform(rawValue: token.blockchain.rawValue),
                  !networks.contains(platform) else { continue }
            networks.append(platform)
        }
        return networks.sorted { networkRank($0) < networkRank($1) }
    }

    private var filteredTokens: [Token] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return tokens
            .filter { token in
                if showFavoritesOnly, !walletManager.isFavorite(token.symbol) {
                    return false
                }
                if !showFavoritesOnly,
                   let selectedNetworkFilter,
                   token.blockchain.rawValue != selectedNetworkFilter.rawValue {
                    return false
                }
                guard !query.isEmpty else { return true }
                return token.symbol.lowercased().contains(query)
                    || token.name.lowercased().contains(query)
                    || (token.contractAddress?.lowercased().contains(query) ?? false)
                    || token.blockchain.name.lowercased().contains(query)
            }
            .sorted { first, second in
                let firstFavorite = walletManager.isFavorite(first.symbol)
                let secondFavorite = walletManager.isFavorite(second.symbol)
                if firstFavorite != secondFavorite { return firstFavorite }
                if first.totalValue != second.totalValue { return first.totalValue > second.totalValue }
                return first.symbol < second.symbol
            }
    }

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    PickerSearchField(
                        placeholder: "Token name or contract".localized,
                        text: $searchText
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 9) {
                            TokenNetworkFilterChip(
                                title: "Favorites".localized,
                                systemIcon: "star.fill",
                                platform: nil,
                                isSelected: showFavoritesOnly
                            ) {
                                withAnimation(.easeOut(duration: 0.18)) {
                                    showFavoritesOnly = true
                                    selectedNetworkFilter = nil
                                }
                            }

                            ForEach(networkOptions, id: \.self) { network in
                                TokenNetworkFilterChip(
                                    title: network.name,
                                    systemIcon: nil,
                                    platform: network,
                                    isSelected: !showFavoritesOnly && selectedNetworkFilter == network
                                ) {
                                    withAnimation(.easeOut(duration: 0.18)) {
                                        if !walletManager.selectedBlockchains.contains(network) {
                                            walletManager.toggleBlockchain(network)
                                        }
                                        showFavoritesOnly = false
                                        selectedNetworkFilter = network
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 14)

                    if filteredTokens.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: showFavoritesOnly ? "star.slash" : "magnifyingglass")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(WpayinColors.textTertiary)

                            Text(showFavoritesOnly ? "No favorite tokens".localized : "No tokens found".localized)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(WpayinColors.textSecondary)
                        }
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 8) {
                                ForEach(filteredTokens) { token in
                                    SwapTokenPickerRow(
                                        token: token,
                                        isSelected: selectedToken?.id == token.id,
                                        isFavorite: walletManager.isFavorite(token.symbol),
                                        onSelect: {
                                            onSelect(token)
                                            dismiss()
                                        },
                                        onFavorite: {
                                            walletManager.toggleFavorite(for: token.symbol)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 28)
                        }
                    }
                }
            }
            .navigationTitle(L10n.Tokens.selectToken.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(WpayinColors.text)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(WpayinColors.surfaceLight))
                    }
                    .accessibilityLabel(L10n.Action.close.localized)
                }
            }
        }
        .swapPickerPresentation()
    }

    private func networkRank(_ network: BlockchainPlatform) -> Int {
        let preferred: [BlockchainPlatform] = [
            .ethereum, .base, .arbitrum, .bsc, .polygon, .optimism,
            .avalanche, .solana, .bitcoin
        ]
        return preferred.firstIndex(of: network)
            ?? (preferred.count + (BlockchainPlatform.allCases.firstIndex(of: network) ?? 0))
    }
}

private struct TokenNetworkFilterChip: View {
    let title: String
    let systemIcon: String?
    let platform: BlockchainPlatform?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let platform {
                    PlatformIconView(platform: platform, size: 24)
                } else if let systemIcon {
                    Image(systemName: systemIcon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(WpayinColors.warning)
                        .frame(width: 24, height: 24)
                }

                if isSelected {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(WpayinColors.text)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, isSelected ? 11 : 8)
            .frame(height: 42)
            .background(
                Capsule()
                    .fill(isSelected ? WpayinColors.primary.opacity(0.14) : Color.clear)
                    .overlay(
                        Capsule()
                            .stroke(isSelected ? WpayinColors.primary.opacity(0.55) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(WpayinPressableStyle())
        .accessibilityLabel(title)
    }
}

private struct SwapTokenPickerRow: View {
    let token: Token
    let isSelected: Bool
    let isFavorite: Bool
    let onSelect: () -> Void
    let onFavorite: () -> Void
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    TokenIconView(token: token, size: 38, showNetworkBadge: true)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(token.symbol.uppercased())
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(WpayinColors.text)

                            if let tokenProtocol = token.tokenProtocol {
                                TokenProtocolBadge(tokenProtocol: tokenProtocol, size: .small)
                            }
                        }

                        HStack(spacing: 5) {
                            Text(token.name)
                                .lineLimit(1)

                            Text("•")

                            Text(token.blockchain.name)
                                .lineLimit(1)
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(WpayinColors.textSecondary)
                    }

                    Spacer(minLength: 6)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(TokenIconHelper.formattedBalance(token.balance, decimals: token.balance < 1 ? 6 : 4))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(WpayinColors.text)
                            .lineLimit(1)

                        Text(token.totalValue.formatted(as: settingsManager.selectedCurrency))
                            .font(.system(size: 11))
                            .foregroundColor(WpayinColors.textSecondary)
                    }

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(WpayinColors.primary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: onFavorite) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isFavorite ? WpayinColors.warning : WpayinColors.textTertiary)
                    .frame(width: 32, height: 38)
            }
            .buttonStyle(WpayinPressableStyle())
            .accessibilityLabel("Favorites".localized)
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? WpayinColors.primary.opacity(0.10) : WpayinColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isSelected ? WpayinColors.primary.opacity(0.45) : WpayinColors.surfaceBorder, lineWidth: 1)
                )
        )
    }
}

private struct PickerSearchField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(WpayinColors.textTertiary)

            TextField(placeholder, text: $text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(WpayinColors.text)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)

            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(WpayinColors.textTertiary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(WpayinColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                )
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
    @EnvironmentObject private var walletManager: WalletManager
    @State private var searchText = ""

    private var networks: [BlockchainPlatform] {
        Array(Set(availableNetworks)).sorted { networkRank($0) < networkRank($1) }
    }

    private var trendingNetworks: [BlockchainPlatform] {
        let trending: [BlockchainPlatform] = [
            .ethereum, .base, .arbitrum, .solana, .bsc, .polygon, .optimism, .avalanche
        ]
        return trending.filter { networks.contains($0) }
    }

    private var filteredNetworks: [BlockchainPlatform] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return networks }
        return networks.filter { network in
            network.name.lowercased().contains(query)
                || network.symbol.lowercased().contains(query)
                || network.rawValue.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        PickerSearchField(
                            placeholder: "Search networks".localized,
                            text: $searchText
                        )

                        if searchText.isEmpty, !trendingNetworks.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                NetworkPickerSectionTitle(title: "Trending Networks".localized)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(trendingNetworks, id: \.self) { network in
                                            TrendingNetworkButton(
                                                network: network,
                                                isSelected: selectedNetwork == network
                                            ) {
                                                select(network)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                                .padding(.horizontal, -20)
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            NetworkPickerSectionTitle(title: "All Networks".localized)

                            if filteredNetworks.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 28, weight: .medium))
                                        .foregroundColor(WpayinColors.textTertiary)

                                    Text("No networks found".localized)
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundColor(WpayinColors.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 48)
                            } else {
                                LazyVStack(spacing: 8) {
                                    ForEach(filteredNetworks, id: \.self) { network in
                                        NetworkPickerRow(
                                            network: network,
                                            isSelected: selectedNetwork == network
                                        ) {
                                            select(network)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle(L10n.Swap.selectNetwork.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(WpayinColors.text)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(WpayinColors.surfaceLight))
                    }
                    .accessibilityLabel(L10n.Action.close.localized)
                }
            }
        }
        .swapPickerPresentation()
    }

    private func select(_ network: BlockchainPlatform) {
        if !walletManager.selectedBlockchains.contains(network) {
            walletManager.toggleBlockchain(network)
        }
        selectedNetwork = network
        dismiss()
    }

    private func networkRank(_ network: BlockchainPlatform) -> Int {
        let preferred: [BlockchainPlatform] = [
            .ethereum, .base, .arbitrum, .bsc, .polygon, .optimism,
            .avalanche, .solana, .bitcoin
        ]
        return preferred.firstIndex(of: network)
            ?? (preferred.count + (BlockchainPlatform.allCases.firstIndex(of: network) ?? 0))
    }
}

private struct NetworkPickerSectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(WpayinColors.textSecondary)
            .textCase(.uppercase)
    }
}

private struct TrendingNetworkButton: View {
    let network: BlockchainPlatform
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 9) {
                PlatformIconView(platform: network, size: 34)

                Text(network.name)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(WpayinColors.text)
                    .lineLimit(1)
            }
            .frame(width: 94, height: 82)
            .background(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(isSelected ? WpayinColors.primary.opacity(0.12) : WpayinColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .stroke(isSelected ? WpayinColors.primary.opacity(0.55) : WpayinColors.surfaceBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(WpayinPressableStyle())
    }
}

private struct NetworkPickerRow: View {
    let network: BlockchainPlatform
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                PlatformIconView(platform: network, size: 38)

                VStack(alignment: .leading, spacing: 3) {
                    Text(network.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(WpayinColors.text)

                    Text(network.symbol)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(WpayinColors.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 19))
                        .foregroundColor(WpayinColors.primary)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 64)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? WpayinColors.primary.opacity(0.10) : WpayinColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isSelected ? WpayinColors.primary.opacity(0.45) : WpayinColors.surfaceBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(WpayinPressableStyle())
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
