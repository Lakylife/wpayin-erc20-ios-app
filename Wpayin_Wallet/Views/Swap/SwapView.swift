//
//  SwapView.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI

enum GasSpeed: String, CaseIterable {
    case slow = "Slow"
    case standard = "Standard"
    case fast = "Fast"

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

    private var availableTokens: [Token] {
        walletManager.visibleTokens.filter { 
            $0.blockchain.rawValue == selectedNetwork.rawValue && 
            $0.blockchain != .bitcoin  // Bitcoin doesn't support swaps
        }
    }
    
    private var availableNetworks: [BlockchainPlatform] {
        walletManager.availableBlockchains
            .filter { 
                $0.network == .mainnet && 
                $0.isEnabled &&
                $0.blockchainType != .bitcoin  // Exclude Bitcoin from swap networks
            }
            .map { $0.platform }
    }

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
        return from.id != to.id && amount <= from.balance
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

    var body: some View {
        ZStack {
            // Background gradient
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
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Swap")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(WpayinColors.text)

                        Text("Exchange tokens instantly")
                            .font(.system(size: 16))
                            .foregroundColor(WpayinColors.textSecondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 20)

                // Swap Content
                ScrollView {
                    VStack(spacing: 20) {
                        // Network Selector
                        if !availableNetworks.isEmpty {
                            NetworkSelectorButton(
                                selectedNetwork: $selectedNetwork,
                                availableNetworks: availableNetworks,
                                onTap: { showNetworkSelector = true }
                            )
                        }
                        
                        // Swap Card
                        VStack(spacing: 0) {
                            // From Token Section
                            ModernTokenSelector(
                                title: "From",
                                selectedToken: selectedFromToken,
                                amount: $fromAmount,
                                isInput: true,
                                onTokenSelect: {
                                    isSelectingFromToken = true
                                    showTokenPicker = true
                                }
                            )

                            // Swap Direction Button
                            HStack {
                                Spacer()

                                Button(action: swapTokens) {
                                    Circle()
                                        .fill(WpayinColors.primary)
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                            Image(systemName: "arrow.up.arrow.down")
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundColor(.white)
                                        )
                                        .shadow(color: WpayinColors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                                }

                                Spacer()
                            }
                            .padding(.vertical, -22)
                            .zIndex(1)

                            // To Token Section
                            ModernTokenSelector(
                                title: "To (estimated)",
                                selectedToken: selectedToToken,
                                amount: .constant(String(format: "%.6f", estimatedToAmount)),
                                isInput: false,
                                onTokenSelect: {
                                    isSelectingFromToken = false
                                    showTokenPicker = true
                                }
                            )
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(WpayinColors.surface)
                                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                        )

                        // Exchange Rate & Details
                        if let from = selectedFromToken, let to = selectedToToken, swapRate > 0 {
                            VStack(spacing: 16) {
                                // Exchange Rate
                                HStack {
                                    Text("1 \(from.symbol) = \(String(format: "%.6f", swapRate)) \(to.symbol)")
                                        .font(.system(size: 14))
                                        .foregroundColor(WpayinColors.textSecondary)

                                    Spacer()

                                    Button(action: {}) {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 12))
                                            .foregroundColor(WpayinColors.primary)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(WpayinColors.surface.opacity(0.5))
                                .cornerRadius(12)

                                // Gas Fee with Speed Selection
                                Button(action: { showGasSettings.toggle() }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Network Fee")
                                                .font(.system(size: 14))
                                                .foregroundColor(WpayinColors.textSecondary)

                                            HStack(spacing: 4) {
                                                Image(systemName: selectedGasSpeed.icon)
                                                    .font(.system(size: 10))
                                                Text(selectedGasSpeed.rawValue)
                                                    .font(.system(size: 12))
                                            }
                                            .foregroundColor(WpayinColors.primary)
                                        }

                                        Spacer()

                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("~\(String(format: "%.4f", estimatedGasFee)) \(from.symbol)")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(WpayinColors.text)

                                            Text(gasFeeInUSD.formatted(as: settingsManager.selectedCurrency))
                                                .font(.system(size: 12))
                                                .foregroundColor(WpayinColors.textTertiary)
                                        }

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12))
                                            .foregroundColor(WpayinColors.textTertiary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(WpayinColors.surface.opacity(0.5))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(PlainButtonStyle())

                                // Slippage Settings
                                HStack {
                                    Text("Slippage: \(String(format: "%.1f", slippage))%")
                                        .font(.system(size: 14))
                                        .foregroundColor(WpayinColors.textSecondary)

                                    Spacer()

                                    Button("Edit") {
                                        showSlippageSettings = true
                                    }
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(WpayinColors.primary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(WpayinColors.surface.opacity(0.5))
                                .cornerRadius(12)
                            }
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                }

                // Bottom Action
                VStack(spacing: 12) {
                    if !isValidSwap && !fromAmount.isEmpty {
                        Text(invalidSwapReason)
                            .font(.system(size: 14))
                            .foregroundColor(WpayinColors.error)
                            .padding(.horizontal, 20)
                    }

                    Button(action: {
                        if isValidSwap {
                            performSwap()
                        }
                    }) {
                        Text(isSwapping ? "Swapping..." : "Swap")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(isValidSwap ? WpayinColors.primary : WpayinColors.textTertiary)
                            )
                    }
                    .disabled(!isValidSwap || isSwapping)
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 34)
                .background(
                    Rectangle()
                        .fill(WpayinColors.background.opacity(0.95))
                        .background(.ultraThinMaterial)
                )
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
        }
        .sheet(isPresented: $showNetworkSelector) {
            NetworkSelectorSheet(
                selectedNetwork: $selectedNetwork,
                availableNetworks: availableNetworks
            )
        }
        .onAppear {
            if selectedFromToken == nil && !availableTokens.isEmpty {
                selectedFromToken = availableTokens.first
            }
            if selectedToToken == nil && availableTokens.count > 1 {
                selectedToToken = availableTokens[1]
            }
        }
        .onChange(of: selectedNetwork) { _ in
            // Reset token selection when network changes
            selectedFromToken = availableTokens.first
            selectedToToken = availableTokens.count > 1 ? availableTokens[1] : nil
            fromAmount = ""
        }
    }

    private var invalidSwapReason: String {
        guard let from = selectedFromToken else { return "Select a token to swap from" }
        guard let to = selectedToToken else { return "Select a token to swap to" }
        guard let amount = Double(fromAmount) else { return "Enter a valid amount" }

        if from.id == to.id {
            return "Cannot swap the same token"
        }
        if amount > from.balance {
            return "Insufficient \(from.symbol) balance"
        }
        return "Enter an amount to swap"
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
                print("📊 Getting swap quote...")
                let quote = try await SwapService.shared.getQuote(
                    fromToken: fromToken,
                    toToken: toToken,
                    amountIn: Decimal(amount),
                    slippage: slippage
                )

                print("✅ Quote received: \(quote.amountOut) \(toToken.symbol)")
                print("💰 Minimum amount out: \(quote.amountOutMin)")
                print("⛽ Estimated gas: \(quote.gasEstimate)")

                // Execute swap
                print("🔄 Executing swap...")
                let result = try await SwapService.shared.executeSwap(
                    quote: quote,
                    fromToken: fromToken,
                    toToken: toToken
                )

                print("✅ Swap successful! TX: \(result.transactionHash)")

                await MainActor.run {
                    isSwapping = false
                    fromAmount = ""

                    // Refresh wallet data to show updated balances
                    Task {
                        await walletManager.refreshWalletData()
                    }
                }
            } catch {
                print("❌ Swap failed: \(error.localizedDescription)")
                await MainActor.run {
                    isSwapping = false
                    // Show error to user
                    // You could add @State var showError and errorMessage here
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
        VStack(spacing: 16) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(WpayinColors.textSecondary)

                Spacer()

                if let token = selectedToken {
                    HStack(spacing: 8) {
                        Text("Balance: \(String(format: "%.4f", token.balance))")
                            .font(.system(size: 12))
                            .foregroundColor(WpayinColors.textSecondary)

                        if isInput && token.balance > 0 {
                            Button(action: {
                                amount = String(format: "%.6f", token.balance)
                            }) {
                                Text("MAX")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(WpayinColors.primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(WpayinColors.primary.opacity(0.1))
                                    )
                            }
                        }
                    }
                }
            }

            HStack(spacing: 16) {
                // Token Selector
                Button(action: onTokenSelect) {
                    HStack(spacing: 12) {
                        if let token = selectedToken {
                            // Token Icon
                            if let iconUrl = token.iconUrl, let url = URL(string: iconUrl) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Circle()
                                        .fill(tokenGradient(for: token))
                                        .overlay(
                                            Text(token.symbol.prefix(2))
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white)
                                        )
                                }
                                .frame(width: 36, height: 36)
                                .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(tokenGradient(for: token))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Text(token.symbol.prefix(2))
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(token.symbol)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(WpayinColors.text)

                                Text(token.name)
                                    .font(.system(size: 12))
                                    .foregroundColor(WpayinColors.textSecondary)
                                    .lineLimit(1)
                            }
                        } else {
                            Text("Select Token")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(WpayinColors.textSecondary)
                        }

                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(WpayinColors.textTertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(WpayinColors.background)
                    )
                }

                Spacer()

                // Amount Input
                VStack(alignment: .trailing, spacing: 4) {
                    if isInput {
                        TextField("0.0", text: $amount)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(WpayinColors.text)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    } else {
                        Text(amount.isEmpty || amount == "0.000000" ? "0.0" : amount)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(WpayinColors.textSecondary)
                    }

                    if let token = selectedToken, let amountValue = Double(amount), amountValue > 0 {
                        Text("~\((amountValue * token.price).formatted(as: settingsManager.selectedCurrency))")
                            .font(.system(size: 12))
                            .foregroundColor(WpayinColors.textTertiary)
                    }
                }
            }
        }
        .padding(20)
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

                    Spacer()

                    Text("Select Token")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(WpayinColors.text)

                    Spacer()

                    Text("")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.clear)
                }
                .padding(20)

                // Token List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(tokens) { token in
                            Button(action: {
                                onSelect(token)
                                dismiss()
                            }) {
                                HStack(spacing: 16) {
                                    // Token Icon
                                    if let iconUrl = token.iconUrl, let url = URL(string: iconUrl) {
                                        AsyncImage(url: url) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Circle()
                                                .fill(tokenGradient(for: token))
                                                .overlay(
                                                    Text(token.symbol.prefix(2))
                                                        .font(.system(size: 14, weight: .bold))
                                                        .foregroundColor(.white)
                                                )
                                        }
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                    } else {
                                        Circle()
                                            .fill(tokenGradient(for: token))
                                            .frame(width: 40, height: 40)
                                            .overlay(
                                                Text(token.symbol.prefix(2))
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(.white)
                                            )
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        let tokenPlatform = BlockchainPlatform(rawValue: token.blockchain.rawValue) ?? .ethereum
                                        HStack(spacing: 6) {
                                            Text(token.symbol)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(WpayinColors.text)
                                            
                                            if let proto = token.tokenProtocol {
                                                TokenProtocolBadge(tokenProtocol: proto, size: .small)
                                            }
                                            
                                            // Network badge
                                            Circle()
                                                .fill(tokenPlatform.color)
                                                .frame(width: 14, height: 14)
                                                .overlay(
                                                    Image(systemName: tokenPlatform.iconName)
                                                        .font(.system(size: 7, weight: .medium))
                                                        .foregroundColor(.white)
                                                )
                                            
                                            Text(tokenPlatform.name)
                                                .font(.system(size: 12))
                                                .foregroundColor(WpayinColors.textSecondary)
                                        }

                                        Text(token.name)
                                            .font(.system(size: 14))
                                            .foregroundColor(WpayinColors.textSecondary)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(String(format: "%.4f", token.balance))
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(WpayinColors.text)

                                        Text(token.totalValue.formatted(as: settingsManager.selectedCurrency))
                                            .font(.system(size: 14))
                                            .foregroundColor(WpayinColors.textSecondary)
                                    }

                                    if selectedToken?.id == token.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(WpayinColors.primary)
                                    }
                                }
                                .padding(16)
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
                                    Text(speed.rawValue)
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
            .navigationTitle("Gas Speed")
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
}

struct SlippageSettingsSheet: View {
    @Binding var slippage: Double
    @Environment(\.dismiss) private var dismiss
    @State private var customSlippage = ""

    private let presetSlippages = [0.1, 0.5, 1.0, 3.0]

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Slippage Tolerance")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(WpayinColors.text)

                Text("Your transaction will revert if the price changes unfavorably by more than this percentage")
                    .font(.system(size: 16))
                    .foregroundColor(WpayinColors.textSecondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(presetSlippages, id: \.self) { preset in
                            Button(action: {
                                slippage = preset
                            }) {
                                Text("\(String(format: "%.1f", preset))%")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(slippage == preset ? .white : WpayinColors.text)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(slippage == preset ? WpayinColors.primary : WpayinColors.surface)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }

                    HStack {
                        TextField("Custom %", text: $customSlippage)
                            .font(.system(size: 16))
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                        Button("Set") {
                            if let value = Double(customSlippage), value > 0, value <= 50 {
                                slippage = value
                            }
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(WpayinColors.primary)
                        .cornerRadius(8)
                    }
                }

                Spacer()
            }
            .padding(20)
            .background(WpayinColors.background)
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct NetworkSelectorButton: View {
    @Binding var selectedNetwork: BlockchainPlatform
    let availableNetworks: [BlockchainPlatform]
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Text("Select Network")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(WpayinColors.textSecondary)
            
            // Network Selector (styled like token selector)
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // Network icon
                    if let iconName = selectedNetwork.assetIconName {
                        Image(iconName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 36, height: 36)
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [selectedNetwork.color, selectedNetwork.color.opacity(0.7)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: selectedNetwork.iconName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedNetwork.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(WpayinColors.text)
                        
                        Text(selectedNetwork.symbol)
                            .font(.system(size: 12))
                            .foregroundColor(WpayinColors.textSecondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(WpayinColors.textTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(WpayinColors.background)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
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

                    Text("Select Network")
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
                                    // Network icon
                                    if let iconName = network.assetIconName {
                                        Image(iconName)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 40, height: 40)
                                    } else {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [network.color, network.color.opacity(0.7)]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 40, height: 40)
                                            .overlay(
                                                Image(systemName: network.iconName)
                                                    .font(.system(size: 18, weight: .medium))
                                                    .foregroundColor(.white)
                                            )
                                    }
                                    
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