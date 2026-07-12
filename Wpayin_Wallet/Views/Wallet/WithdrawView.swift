// Autor Lukas Helebrandt, 2026

//
//  WithdrawView.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI
import AVFoundation

enum WithdrawGasSpeed: String, CaseIterable {
    case slow = "Slow"
    case standard = "Standard"
    case fast = "Fast"

    var displayName: String {
        rawValue.localized
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

    var estimatedTime: String {
        switch self {
        case .slow: return "~5 min"
        case .standard: return "~2 min"
        case .fast: return "~30 sec"
        }
    }
    
    func estimatedTimeFor(blockchain: BlockchainType) -> String {
        if blockchain == .bitcoin {
            switch self {
            case .slow: return "~60 min"
            case .standard: return "~30 min"
            case .fast: return "~10 min"
            }
        } else {
            return estimatedTime
        }
    }
}

struct WithdrawView: View {
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSymbol: String?
    @State private var selectedNetwork: BlockchainType?
    @State private var recipientAddress = ""
    @State private var amount = ""
    @State private var showConfirmation = false
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var selectedGasSpeed: WithdrawGasSpeed = .standard
    @State private var showGasSettings = false
    @State private var liveStandardGasPrice: GasPrice?
    @State private var isLoadingGasPrice = false
    @State private var submittedTransaction: Transaction?

    init(initialToken: Token? = nil, initialRecipientAddress: String = "") {
        _selectedSymbol = State(initialValue: initialToken?.symbol.uppercased())
        _selectedNetwork = State(initialValue: initialToken?.blockchain)
        _recipientAddress = State(initialValue: initialRecipientAddress)
    }

    private var selectedToken: Token? {
        guard let selectedSymbol, let selectedNetwork else { return nil }
        return spendableTokens.first {
            $0.symbol.uppercased() == selectedSymbol.uppercased() && $0.blockchain == selectedNetwork
        }
    }

    private var spendableTokens: [Token] {
        walletManager.visibleSupportedTokens.sorted {
            if $0.symbol == $1.symbol {
                return $0.blockchain.name < $1.blockchain.name
            }
            return $0.symbol < $1.symbol
        }
    }

    private var amountValue: Double {
        Double(amount) ?? 0.0
    }

    /// Platform fee charged on top of the sent amount (EVM sends only).
    private var platformFeeValue: Double {
        guard let token = selectedToken, token.blockchain != .bitcoin else { return 0 }
        return (TransactionService.platformFee(for: Decimal(amountValue)) as NSDecimalNumber).doubleValue
    }

    /// The sender must cover the amount plus the platform fee.
    private var totalDebit: Double {
        amountValue + platformFeeValue
    }

    private var nativeBalance: Double {
        guard let token = selectedToken else { return 0 }
        return walletManager.tokens.first {
            $0.blockchain == token.blockchain && $0.isNative
        }?.balance ?? 0
    }

    private var requiredGasLimit: Int {
        guard let token = selectedToken, token.blockchain != .bitcoin else { return 0 }
        let perTransaction = token.isNative ? 21_000 : 65_000
        return perTransaction * (AppConfig.platformFeeEnabled ? 2 : 1)
    }

    private var selectedGasPrice: GasPrice? {
        guard let liveStandardGasPrice else { return nil }
        return adjustedGasPrice(liveStandardGasPrice, multiplier: selectedGasSpeed.multiplier)
    }

    private var isValidTransaction: Bool {
        guard let token = selectedToken else { return false }

        // Bitcoin address validation
        if token.blockchain == .bitcoin {
            // Bitcoin addresses can start with 1, 3, or bc1
            let isBitcoinAddress = recipientAddress.hasPrefix("bc1") ||
                                  recipientAddress.hasPrefix("1") ||
                                  recipientAddress.hasPrefix("3")
            return !recipientAddress.isEmpty &&
                   isBitcoinAddress &&
                   amountValue > 0 &&
                   amountValue <= token.balance
        }

        // EVM address validation (balance must cover amount + platform fee)
        let hasGas = token.isNative
            ? totalDebit + estimatedGasFee <= token.balance
            : nativeBalance >= estimatedGasFee
        return !recipientAddress.isEmpty &&
               recipientAddress.hasPrefix("0x") &&
               recipientAddress.count == 42 &&
               amountValue > 0 &&
               totalDebit <= token.balance &&
               hasGas &&
               selectedGasPrice != nil
    }
    
    private var headerTitle: String {
        guard let token = selectedToken else { return "Send Funds".localized }
        return token.blockchain == .bitcoin ? "Send Bitcoin".localized : "Send Funds".localized
    }
    
    private var headerSubtitle: String {
        guard let token = selectedToken else { return "Send cryptocurrency to another wallet".localized }
        if token.blockchain == .bitcoin {
            return "Send BTC to any Bitcoin address".localized
        }
        return "Send cryptocurrency to another wallet".localized
    }
    
    private var feeDisplayText: String {
        guard let token = selectedToken else { return "Fee".localized }
        if token.blockchain == .bitcoin {
            return "Network Fee: %@ sat/vB".localized("\(Int(estimatedGasFee))")
        }
        return "Est. Gas: %@".localized(estimatedGasFee.formatted(as: settingsManager.selectedCurrency))
    }

    private var estimatedGasFee: Double {
        guard let token = selectedToken else { return 0 }

        // Bitcoin uses satoshis/byte, others use ETH/native token amount
        if token.blockchain == .bitcoin {
            // Return fee rate in satoshis/byte
            switch selectedGasSpeed {
            case .slow:
                return 10  // ~1 hour
            case .standard:
                return 20  // ~30 minutes
            case .fast:
                return 40  // ~10-15 minutes
            }
        }

        guard let selectedGasPrice else { return 0 }
        let weiPerGas: Int
        switch selectedGasPrice {
        case .legacy(let gasPrice): weiPerGas = gasPrice
        case .eip1559(let maxFeePerGas, _): weiPerGas = maxFeePerGas
        }
        return Double(requiredGasLimit) * Double(weiPerGas) / 1_000_000_000_000_000_000
    }

    private var selectedGweiText: String {
        guard let selectedGasPrice else { return isLoadingGasPrice ? "…" : "—" }
        switch selectedGasPrice {
        case .legacy(let gasPrice):
            return String(format: "%.2f Gwei", Double(gasPrice) / 1_000_000_000)
        case .eip1559(let maxFeePerGas, let priorityFee):
            return String(format: "%.2f Gwei · %.2f priority",
                          Double(maxFeePerGas) / 1_000_000_000,
                          Double(priorityFee) / 1_000_000_000)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                WalletFlowBackground()

                ScrollView {
                    LazyVStack(spacing: 20) {
                        VStack(spacing: 12) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(WpayinColors.primary)
                                .frame(width: 50, height: 50)
                                .background(
                                    Circle()
                                        .fill(WpayinColors.primary.opacity(0.14))
                                        .overlay(
                                            Circle()
                                                .stroke(WpayinColors.primary.opacity(0.18), lineWidth: 1)
                                        )
                                )

                            Text(headerTitle)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(WpayinColors.text)

                            Text(headerSubtitle)
                                .font(.system(size: 14))
                                .foregroundColor(WpayinColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }

                        TokenSelectionView(
                            tokens: spendableTokens,
                            selectedSymbol: $selectedSymbol,
                            selectedNetwork: $selectedNetwork
                        )
                        .environmentObject(settingsManager)

                        RecipientAddressView(address: $recipientAddress)
                            .environmentObject(walletManager)

                        AmountInputView(
                            amount: $amount,
                            selectedToken: selectedToken,
                            reservedNetworkFee: selectedToken?.isNative == true ? estimatedGasFee : 0
                        )

                        if isValidTransaction {
                            TransactionSummaryView(
                                token: selectedToken!,
                                amount: amountValue,
                                recipient: recipientAddress,
                                gasSpeed: $selectedGasSpeed,
                                estimatedGas: estimatedGasFee,
                                onGasSettingsTapped: {
                                    showGasSettings = true
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Withdraw".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(WpayinColors.text)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(WpayinColors.surfaceLight))
                    }
                    .accessibilityLabel(L10n.Action.cancel.localized)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    showConfirmation = true
                } label: {
                    HStack(spacing: 10) {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(L10n.Action.send.localized)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))

                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        Group {
                            if isValidTransaction && !isProcessing {
                                WpayinColors.accentGradient
                            } else {
                                LinearGradient(
                                    colors: [WpayinColors.surfaceLight, WpayinColors.surfaceLight],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            }
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(WpayinPressableStyle())
                .disabled(!isValidTransaction || isProcessing)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(WpayinColors.background.opacity(0.96))
            }
        }
        .sheet(isPresented: $showConfirmation) {
            TransactionConfirmationView(
                token: selectedToken!,
                amount: amountValue,
                recipient: recipientAddress,
                gasSpeed: $selectedGasSpeed,
                estimatedGas: estimatedGasFee,
                gweiText: selectedGweiText,
                onConfirm: {
                    processTransaction()
                }
            )
        }
        .sheet(isPresented: $showGasSettings) {
            WithdrawGasSettingsSheet(
                selectedSpeed: $selectedGasSpeed, 
                estimatedGas: estimatedGasFee,
                selectedToken: selectedToken,
                gweiText: selectedGweiText
            )
        }
        .sheet(item: $submittedTransaction) { transaction in
            TransactionDetailView(transaction: transaction)
                .environmentObject(walletManager)
                .environmentObject(settingsManager)
        }
        .alert("Transaction Error".localized, isPresented: $showError) {
            Button("OK".localized) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            ensureValidSelection()
        }
        .onChange(of: walletManager.visibleSupportedTokens.map { "\($0.blockchain.rawValue):\($0.contractAddress ?? "native")" }) { _ in
            ensureValidSelection()
        }
        .onChange(of: selectedSymbol) { _ in
            ensureValidNetworkForSelectedAsset()
        }
        .task(id: selectedToken.map { "\($0.blockchain.rawValue):\($0.contractAddress ?? "native")" }) {
            await refreshGasPrice()
        }
    }

    private func ensureValidSelection() {
        guard !spendableTokens.isEmpty else {
            selectedSymbol = nil
            selectedNetwork = nil
            return
        }

        let symbols = Array(Set(spendableTokens.map { $0.symbol.uppercased() })).sorted()
        if selectedSymbol == nil || !symbols.contains(selectedSymbol ?? "") {
            // Ethereum is the sensible default, not the alphabetical winner.
            selectedSymbol = symbols.contains("ETH") ? "ETH" : symbols.first
        }
        ensureValidNetworkForSelectedAsset()
    }

    private func ensureValidNetworkForSelectedAsset() {
        guard let selectedSymbol else { return }
        let networks = spendableTokens
            .filter { $0.symbol.uppercased() == selectedSymbol.uppercased() }
            .map { $0.blockchain }
        if selectedNetwork == nil || !networks.contains(selectedNetwork!) {
            selectedNetwork = networks.contains(.ethereum) ? .ethereum : networks.first
        }
    }

    private func processTransaction() {
        isProcessing = true

        Task {
            guard await settingsManager.authorizeSpending(reason: "auth.confirmPayment".localized) else {
                await MainActor.run { isProcessing = false }
                return
            }
            do {
                guard let token = selectedToken else {
                    throw TransactionError.failedToCreateTransaction
                }

                // Send transaction using TransactionService
                let result: TransactionResult
                
                // Check if it's Bitcoin
                if token.blockchain == .bitcoin {
                    // Bitcoin transaction
                    result = try await BitcoinService.shared.sendTransaction(
                        to: recipientAddress,
                        amount: Decimal(amountValue),
                        feeRate: estimatedGasFee > 0 ? Int(estimatedGasFee) : nil  // satoshis/byte
                    )
                } else if token.isNative {
                    // Send native token (ETH, BNB, MATIC, etc.)
                    result = try await TransactionService.shared.sendEvmNativeToken(
                        to: recipientAddress,
                        amount: Decimal(amountValue),
                        blockchain: token.blockchain,
                        customGasPrice: selectedGasPrice,
                        gasPriceMultiplier: 1,
                        gasLimit: 21000
                    )
                } else {
                    // Send ERC-20 token
                    result = try await TransactionService.shared.sendErc20Token(
                        tokenAddress: token.contractAddress ?? "",
                        to: recipientAddress,
                        amount: Decimal(amountValue),
                        decimals: token.decimals,
                        blockchain: token.blockchain,
                        customGasPrice: selectedGasPrice,
                        gasPriceMultiplier: 1,
                        gasLimit: 65000
                    )
                }

                Logger.log("✅ Transaction sent! Hash: \(result.hash)")

                await MainActor.run {
                    isProcessing = false
                    let explorerURL = URL(string: NetworkManager.shared.getExplorerUrl(
                        for: token.blockchain,
                        txHash: result.hash
                    ))
                    let pendingTransaction = Transaction(
                        hash: result.hash,
                        from: result.from,
                        to: result.to,
                        amount: amountValue,
                        token: token.symbol,
                        type: .send,
                        status: .pending,
                        timestamp: Date(),
                        gasUsed: Double(result.gasUsed ?? "") ?? 0,
                        gasFee: estimatedGasFee,
                        explorerUrl: explorerURL,
                        blockchain: token.blockchain
                    )
                    walletManager.registerLocalTransaction(pendingTransaction)
                    if token.blockchain != .bitcoin {
                        walletManager.applyOptimisticSend(
                            token: token,
                            tokenDebit: amountValue + platformFeeValue,
                            nativeGasDebit: estimatedGasFee
                        )
                    }
                    submittedTransaction = pendingTransaction
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    @MainActor
    private func refreshGasPrice() async {
        guard let token = selectedToken, token.blockchain != .bitcoin else {
            liveStandardGasPrice = nil
            return
        }
        isLoadingGasPrice = true
        defer { isLoadingGasPrice = false }
        do {
            liveStandardGasPrice = try await GasPriceService.shared
                .getGasPrice(for: token.blockchain).recommended
        } catch {
            liveStandardGasPrice = nil
            Logger.log("Failed to load send gas price: \(error.localizedDescription)")
        }
    }

    private func adjustedGasPrice(_ price: GasPrice, multiplier: Double) -> GasPrice {
        switch price {
        case .legacy(let gasPrice):
            return .legacy(gasPrice: max(1, Int(Double(gasPrice) * multiplier)))
        case .eip1559(let maxFeePerGas, let priorityFee):
            return .eip1559(
                maxFeePerGas: max(1, Int(Double(maxFeePerGas) * multiplier)),
                maxPriorityFeePerGas: max(1, Int(Double(priorityFee) * multiplier))
            )
        }
    }
}

struct TokenSelectionView: View {
    let tokens: [Token]
    @Binding var selectedSymbol: String?
    @Binding var selectedNetwork: BlockchainType?
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var showAssetPicker = false
    @State private var showNetworkPicker = false

    private var currentToken: Token? {
        guard let selectedSymbol, let selectedNetwork else { return nil }
        return tokens.first {
            $0.symbol.uppercased() == selectedSymbol.uppercased() && $0.blockchain == selectedNetwork
        }
    }

    private var networksForSelectedAsset: [Token] {
        guard let selectedSymbol else { return [] }
        return tokens
            .filter { $0.symbol.uppercased() == selectedSymbol.uppercased() }
            .sorted { $0.blockchain.name < $1.blockchain.name }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Select Asset".localized)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(WpayinColors.text)

            if let currentToken = currentToken {
                Button {
                    showAssetPicker = true
                } label: {
                    HStack {
                        TokenIconView(token: currentToken, size: 40, showNetworkBadge: false)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(currentToken.symbol)
                                .font(.wpayinBody)
                                .foregroundColor(WpayinColors.text)
                                .lineLimit(1)

                            Text(currentToken.name)
                                .font(.wpayinCaption)
                                .foregroundColor(WpayinColors.textTertiary)
                                .lineLimit(1)

                            Text("Balance: %@".localized(TokenIconHelper.formattedBalanceWithSymbol(currentToken.balance, symbol: currentToken.symbol)))
                                .font(.wpayinCaption)
                                .foregroundColor(WpayinColors.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(WpayinColors.textSecondary)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(WpayinColors.surfaceLight)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(WpayinPressableStyle())

                Text("Select Network".localized)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(WpayinColors.textSecondary)
                    .padding(.top, 4)

                Button {
                    showNetworkPicker = true
                } label: {
                    HStack {
                        NetworkIconView(blockchain: currentToken.blockchain, size: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(currentToken.blockchain.name)
                                .font(.wpayinBody)
                                .foregroundColor(WpayinColors.text)

                            Text(TokenIconHelper.formattedBalanceWithSymbol(currentToken.balance, symbol: currentToken.symbol))
                                .font(.wpayinCaption)
                                .foregroundColor(WpayinColors.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(WpayinColors.textSecondary)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(WpayinColors.surfaceLight)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(WpayinPressableStyle())
            } else {
                Text("No spendable assets available".localized)
                    .font(.wpayinCaption)
                    .foregroundColor(WpayinColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(WpayinColors.surface)
                    .cornerRadius(12)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(WpayinColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                )
        )
        .sheet(isPresented: $showAssetPicker) {
            AssetPickerSheet(
                tokens: tokens,
                selectedSymbol: selectedSymbol
            ) { symbol in
                selectedSymbol = symbol
            }
            .environmentObject(settingsManager)
        }
        .sheet(isPresented: $showNetworkPicker) {
            NetworkPickerSheet(
                tokens: networksForSelectedAsset,
                selectedNetwork: selectedNetwork
            ) { network in
                selectedNetwork = network
            }
        }
    }
}

struct TokenSelectionRow: View {
    let token: Token
    let isSelected: Bool
    let action: () -> Void
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Circle()
                    .fill(WpayinColors.primary)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(token.symbol.prefix(1))
                            .font(.wpayinSubheadline)
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(token.name)
                        .font(.wpayinBody)
                        .foregroundColor(WpayinColors.text)

                    Text(token.symbol)
                        .font(.wpayinCaption)
                        .foregroundColor(WpayinColors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.4f", token.balance))
                        .font(.wpayinBody)
                        .foregroundColor(WpayinColors.text)

                    Text(token.totalValue.formatted(as: settingsManager.selectedCurrency))
                        .font(.wpayinCaption)
                        .foregroundColor(WpayinColors.textSecondary)
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? WpayinColors.primary : WpayinColors.textSecondary)
            }
            .padding(16)
            .background(isSelected ? WpayinColors.primary.opacity(0.1) : WpayinColors.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? WpayinColors.primary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RecipientAddressView: View {
    @EnvironmentObject var walletManager: WalletManager
    @Binding var address: String
    @State private var showScanner = false
    @State private var showSavedAddresses = false
    @State private var showAddAddressSheet = false
    @State private var newAddressName = ""
    @State private var addressInputMethod = 0 // 0: manual, 1: saved

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recipient Address".localized)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(WpayinColors.text)

            // Address input method selector
            Picker("Input Method".localized, selection: $addressInputMethod) {
                Text("Manual Entry".localized).tag(0)
                Text("Saved Addresses".localized).tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.bottom, 8)

            if addressInputMethod == 0 {
                // Manual address entry
                HStack(spacing: 12) {
                    TextField("0x...", text: $address)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(WpayinColors.text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(16)
                        .background(WpayinColors.surfaceLight)
                        .cornerRadius(14)

                    Button(action: {
                        showScanner = true
                    }) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 20))
                            .foregroundColor(WpayinColors.primary)
                            .frame(width: 48, height: 48)
                            .background(WpayinColors.surfaceLight)
                            .cornerRadius(14)
                    }

                    Button(action: {
                        showAddAddressSheet = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 20))
                            .foregroundColor(WpayinColors.success)
                            .frame(width: 48, height: 48)
                            .background(WpayinColors.surfaceLight)
                            .cornerRadius(14)
                    }
                    .disabled(address.isEmpty || !isValidAddress(address))
                }
            } else {
                // Saved addresses selection
                if walletManager.savedAddresses.isEmpty {
                    VStack(spacing: 16) {
                        Text("No saved addresses yet".localized)
                            .font(.wpayinBody)
                            .foregroundColor(WpayinColors.textSecondary)

                        Button("Add Address".localized) {
                            addressInputMethod = 0
                        }
                        .foregroundColor(WpayinColors.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(walletManager.savedAddresses) { savedAddress in
                                SavedAddressRow(
                                    savedAddress: savedAddress,
                                    isSelected: address == savedAddress.address
                                ) {
                                    address = savedAddress.address
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
            }

            if !address.isEmpty && !isValidAddress(address) {
                Text("Please enter a valid wallet address".localized)
                    .font(.wpayinCaption)
                    .foregroundColor(WpayinColors.error)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(WpayinColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                )
        )
        .sheet(isPresented: $showScanner) {
            QRScannerView(scannedAddress: $address)
        }
        .sheet(isPresented: $showAddAddressSheet) {
            AddAddressSheet(
                address: address,
                addressName: $newAddressName
            ) {
                if !newAddressName.isEmpty && isValidAddress(address) {
                    walletManager.addSavedAddress(name: newAddressName, address: address)
                    newAddressName = ""
                    showAddAddressSheet = false
                }
            }
        }
    }

    private func isValidAddress(_ address: String) -> Bool {
        // EVM
        if address.hasPrefix("0x") && address.count == 42 { return true }
        // Bitcoin (legacy, P2SH, bech32)
        if (address.hasPrefix("bc1") && address.count >= 14)
            || ((address.hasPrefix("1") || address.hasPrefix("3")) && (26...35).contains(address.count)) {
            return true
        }
        return false
    }
}

struct AmountInputView: View {
    @Binding var amount: String
    let selectedToken: Token?
    let reservedNetworkFee: Double

    private var amountValue: Double {
        Double(amount) ?? 0.0
    }

    private var platformFeeValue: Double {
        guard let token = selectedToken, token.blockchain != .bitcoin else { return 0 }
        return (TransactionService.platformFee(for: Decimal(amountValue)) as NSDecimalNumber).doubleValue
    }

    /// Max sendable so that amount + platform fee still fits in the balance.
    private var maxSendable: Double {
        guard let token = selectedToken else { return 0 }
        let availableAfterGas = max(0, token.balance - reservedNetworkFee)
        guard token.blockchain != .bitcoin, AppConfig.platformFeeEnabled else { return availableAfterGas }
        let rate = (AppConfig.platformFeeRate as NSDecimalNumber).doubleValue
        return availableAfterGas / (1 + rate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Amount".localized)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(WpayinColors.text)

            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    TextField("0.0", text: $amount)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(WpayinColors.text)
                        .keyboardType(.decimalPad)
                        .padding(.vertical, 18)
                        .padding(.horizontal, 16)

                    if let token = selectedToken {
                        Text(token.symbol)
                            .font(.wpayinHeadline)
                            .foregroundColor(WpayinColors.textSecondary)
                            .padding(.trailing, 8)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(WpayinColors.surfaceLight)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                        )
                )

                if let token = selectedToken {
                    HStack {
                        Text("Balance: %@".localized(String(format: "%.4f %@", token.balance, token.symbol)))
                            .font(.wpayinCaption)
                            .foregroundColor(WpayinColors.textSecondary)

                        Spacer()

                        Button("Max".localized) {
                            amount = formattedMaximum(maxSendable, decimals: token.decimals)
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(WpayinColors.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(WpayinColors.primary.opacity(0.12)))
                    }

                    if platformFeeValue > 0, amountValue > 0 {
                        Text("Platform fee %@: %@ %@".localized(
                            String(format: "(%.2f%%)", Double(AppConfig.platformFeeBps) / 100),
                            String(format: "%.6f", platformFeeValue),
                            token.symbol
                        ))
                        .font(.wpayinCaption)
                        .foregroundColor(WpayinColors.textSecondary)
                    }

                    if amountValue + platformFeeValue + reservedNetworkFee > token.balance {
                        Text("Insufficient balance".localized)
                            .font(.wpayinCaption)
                            .foregroundColor(WpayinColors.error)
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(WpayinColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                )
        )
    }

    private func formattedMaximum(_ value: Double, decimals: Int) -> String {
        let precision = min(max(decimals, 0), 12)
        var result = String(format: "%.*f", precision, max(0, value))
        while result.contains(".") && result.last == "0" { result.removeLast() }
        if result.last == "." { result.removeLast() }
        return result
    }
}

struct TransactionSummaryView: View {
    let token: Token
    let amount: Double
    let recipient: String
    @Binding var gasSpeed: WithdrawGasSpeed
    let estimatedGas: Double
    let onGasSettingsTapped: () -> Void

    private var feeValue: String {
        if token.blockchain == .bitcoin {
            return "\(Int(estimatedGas)) sat/vB"
        }
        return "~\(String(format: "%.6f", estimatedGas)) \(token.blockchain.nativeToken)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Transaction Summary".localized)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(WpayinColors.text)

            VStack(spacing: 12) {
                SummaryRow(
                    title: "Amount",
                    value: String(format: "%.4f", amount) + " \(token.symbol)"
                )

                SummaryRow(
                    title: "To",
                    value: "\(recipient.prefix(6))...\(recipient.suffix(4))"
                )

                // Gas Fee with Selection Button
                Button(action: onGasSettingsTapped) {
                    HStack {
                        Text("Network Fee".localized)
                            .font(.wpayinBody)
                            .foregroundColor(WpayinColors.textSecondary)

                        HStack(spacing: 4) {
                            Image(systemName: gasSpeed.icon)
                                .font(.system(size: 10))
                            Text(gasSpeed.displayName)
                                .font(.system(size: 12))
                        }
                        .foregroundColor(WpayinColors.primary)

                        Spacer()

                        Text(feeValue)
                            .font(.wpayinBody)
                            .foregroundColor(WpayinColors.text)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(WpayinColors.textTertiary)
                    }
                }
                .buttonStyle(PlainButtonStyle())

                Divider()
                    .background(WpayinColors.surfaceLight)

                SummaryRow(
                    title: "Total",
                    value: "%@ + %@".localized(String(format: "%.4f %@", amount, token.symbol), "Fee".localized),
                    isTotal: true
                )
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(WpayinColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                )
        )
    }
}

struct SummaryRow: View {
    let title: String
    let value: String
    let isTotal: Bool

    init(title: String, value: String, isTotal: Bool = false) {
        self.title = title
        self.value = value
        self.isTotal = isTotal
    }

    var body: some View {
        HStack {
            Text(title.localized)
                .font(isTotal ? .wpayinSubheadline : .wpayinBody)
                .foregroundColor(WpayinColors.textSecondary)

            Spacer()

            Text(value)
                .font(isTotal ? .wpayinSubheadline : .wpayinBody)
                .foregroundColor(WpayinColors.text)
        }
    }
}

struct QRScannerView: View {
    @Binding var scannedAddress: String
    var onScan: ((String) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var cameraPermissionDenied = false

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                if cameraPermissionDenied {
                    VStack(spacing: 16) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 40))
                            .foregroundColor(WpayinColors.textSecondary)

                        Text("Camera access is required to scan QR codes".localized)
                            .font(.wpayinBody)
                            .foregroundColor(WpayinColors.text)
                            .multilineTextAlignment(.center)

                        Text("Enable camera access in iOS Settings and try again.".localized)
                            .font(.wpayinCaption)
                            .foregroundColor(WpayinColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                } else {
                    QRCodeScannerRepresentable(
                        onScan: { value in
                            let address = QRCodePayloadParser.extractAddress(from: value)
                            scannedAddress = address
                            onScan?(address)
                            dismiss()
                        },
                        onPermissionDenied: {
                            cameraPermissionDenied = true
                        }
                    )
                    .ignoresSafeArea()

                    VStack {
                        Spacer()

                        RoundedRectangle(cornerRadius: 16)
                            .stroke(WpayinColors.primary, lineWidth: 3)
                            .frame(width: 240, height: 240)

                        Spacer()

                        Text("Point the camera at a wallet QR code".localized)
                            .font(.wpayinBody)
                            .foregroundColor(WpayinColors.text)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.65))
                            )
                            .padding(.bottom, 36)
                    }
                }
            }
            .navigationTitle("Scan QR Code".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel".localized) {
                        dismiss()
                    }
                    .foregroundColor(WpayinColors.text)
                }
            }
        }
    }
}

struct QRCodeScannerRepresentable: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    let onPermissionDenied: () -> Void

    func makeUIViewController(context: Context) -> QRCodeScannerViewController {
        let controller = QRCodeScannerViewController()
        controller.onScan = onScan
        controller.onPermissionDenied = onPermissionDenied
        return controller
    }

    func updateUIViewController(_ uiViewController: QRCodeScannerViewController, context: Context) {
        uiViewController.onScan = onScan
        uiViewController.onPermissionDenied = onPermissionDenied
    }
}

final class QRCodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?
    var onPermissionDenied: (() -> Void)?

    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScannedCode = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureCameraAccess()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hasScannedCode = false
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.stopRunning()
            }
        }
    }

    private func configureCameraAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    granted ? self?.configureCaptureSession() : self?.onPermissionDenied?()
                }
            }
        default:
            onPermissionDenied?()
        }
    }

    private func configureCaptureSession() {
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
              captureSession.canAddInput(videoInput) else {
            onPermissionDenied?()
            return
        }

        captureSession.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()
        guard captureSession.canAddOutput(metadataOutput) else {
            onPermissionDenied?()
            return
        }

        captureSession.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        metadataOutput.metadataObjectTypes = [.qr]

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer

        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !hasScannedCode,
              let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = metadataObject.stringValue else {
            return
        }

        hasScannedCode = true
        captureSession.stopRunning()
        onScan?(stringValue)
    }
}

enum QRCodePayloadParser {
    static func extractAddress(from value: String) -> String {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if let queryAddress = queryValue(named: "address", in: trimmedValue) {
            return queryAddress
        }

        if let evmAddress = firstMatch(in: trimmedValue, pattern: #"0x[a-fA-F0-9]{40}"#) {
            return evmAddress
        }

        var candidate = trimmedValue
        if let colonIndex = candidate.firstIndex(of: ":") {
            candidate = String(candidate[candidate.index(after: colonIndex)...])
        }
        if let questionIndex = candidate.firstIndex(of: "?") {
            candidate = String(candidate[..<questionIndex])
        }
        if let atIndex = candidate.lastIndex(of: "@") {
            candidate = String(candidate[..<atIndex])
        }

        return candidate.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func queryValue(named name: String, in value: String) -> String? {
        guard let components = URLComponents(string: value),
              let queryItems = components.queryItems else {
            return nil
        }

        return queryItems.first { $0.name.lowercased() == name.lowercased() }?.value
    }

    private static func firstMatch(in value: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = regex.firstMatch(in: value, range: range),
              let matchRange = Range(match.range, in: value) else {
            return nil
        }
        return String(value[matchRange])
    }
}

struct TransactionConfirmationView: View {
    let token: Token
    let amount: Double
    let recipient: String
    @Binding var gasSpeed: WithdrawGasSpeed
    let estimatedGas: Double
    let gweiText: String
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showGasSettings = false

    var body: some View {
        NavigationView {
            ZStack {
                WalletFlowBackground()

                VStack(spacing: 20) {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(WpayinColors.primary)
                            .frame(width: 56, height: 56)
                            .background(Circle().fill(WpayinColors.primary.opacity(0.14)))

                        Text("Confirm Transaction".localized)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(WpayinColors.text)

                        Text("Please review and confirm your transaction".localized)
                            .font(.system(size: 14))
                            .foregroundColor(WpayinColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    TransactionSummaryView(
                        token: token,
                        amount: amount,
                        recipient: recipient,
                        gasSpeed: $gasSpeed,
                        estimatedGas: estimatedGas,
                        onGasSettingsTapped: {
                            showGasSettings = true
                        }
                    )

                    Spacer()

                    VStack(spacing: 12) {
                        WpayinButton(
                            title: "Confirm & Send",
                            style: .primary
                        ) {
                            onConfirm()
                            dismiss()
                        }

                        WpayinButton(
                            title: "Cancel",
                            style: .tertiary
                        ) {
                            dismiss()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 20)
            }
            .navigationTitle("Confirm".localized)
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showGasSettings) {
            WithdrawGasSettingsSheet(
                selectedSpeed: $gasSpeed,
                estimatedGas: estimatedGas,
                selectedToken: token,
                gweiText: gweiText
            )
        }
    }
}

struct SavedAddressRow: View {
    let savedAddress: SavedAddress
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .fill(WpayinColors.primary)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(savedAddress.name.prefix(1))
                            .font(.wpayinCaption)
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(savedAddress.name)
                        .font(.wpayinBody)
                        .foregroundColor(WpayinColors.text)

                    Text("\(savedAddress.address.prefix(10))...\(savedAddress.address.suffix(4))")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(WpayinColors.textSecondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? WpayinColors.primary : WpayinColors.textSecondary)
            }
            .padding(12)
            .background(isSelected ? WpayinColors.primary.opacity(0.1) : WpayinColors.surface)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AddAddressSheet: View {
    let address: String
    @Binding var addressName: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("Save Address".localized)
                        .font(.wpayinHeadline)
                        .foregroundColor(WpayinColors.text)

                    Text("Give this address a name for easy access".localized)
                        .font(.wpayinBody)
                        .foregroundColor(WpayinColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Address Name".localized)
                        .font(.wpayinSubheadline)
                        .foregroundColor(WpayinColors.text)

                    TextField("e.g., My Friend's Wallet".localized, text: $addressName)
                        .font(.wpayinBody)
                        .foregroundColor(WpayinColors.text)
                        .padding(16)
                        .background(WpayinColors.surface)
                        .cornerRadius(12)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Address".localized)
                        .font(.wpayinSubheadline)
                        .foregroundColor(WpayinColors.text)

                    Text(address)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(WpayinColors.textSecondary)
                        .padding(16)
                        .background(WpayinColors.surfaceLight)
                        .cornerRadius(12)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .background(WpayinColors.background.ignoresSafeArea())
            .navigationTitle("Save Address".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel".localized) {
                        dismiss()
                    }
                    .foregroundColor(WpayinColors.text)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save".localized) {
                        onSave()
                    }
                    .foregroundColor(addressName.isEmpty ? WpayinColors.textSecondary : WpayinColors.primary)
                    .disabled(addressName.isEmpty)
                }
            }
        }
    }
}

// MARK: - Gas Settings Sheet

struct WithdrawGasSettingsSheet: View {
    @Binding var selectedSpeed: WithdrawGasSpeed
    let estimatedGas: Double
    let selectedToken: Token?
    let gweiText: String
    @Environment(\.dismiss) private var dismiss

    private func feeText(for speed: WithdrawGasSpeed) -> String {
        guard let selectedToken else { return "" }
        if selectedToken.blockchain == .bitcoin {
            let rate: Int
            switch speed {
            case .slow: rate = 10
            case .standard: rate = 20
            case .fast: rate = 40
            }
            return "\(rate) sat/vB"
        }

        let standardFee = estimatedGas / selectedSpeed.multiplier
        return "~\(String(format: "%.6f", standardFee * speed.multiplier)) \(selectedToken.blockchain.nativeToken)"
    }

    var body: some View {
        NavigationView {
            ZStack {
                WalletFlowBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 8) {
                            Text("Network Fee".localized)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(WpayinColors.text)

                            Text("Choose your transaction speed".localized)
                                .font(.wpayinBody)
                                .foregroundColor(WpayinColors.textSecondary)

                            if selectedToken?.blockchain != .bitcoin {
                                Text(gweiText)
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundColor(WpayinColors.primary)
                            }
                        }
                        .padding(.top, 20)

                        // Gas Speed Options
                        VStack(spacing: 12) {
                            ForEach(WithdrawGasSpeed.allCases, id: \.self) { speed in
                                Button(action: {
                                    selectedSpeed = speed
                                    dismiss()
                                }) {
                                    HStack(spacing: 16) {
                                        // Icon
                                        Image(systemName: speed.icon)
                                            .font(.system(size: 24))
                                            .foregroundColor(selectedSpeed == speed ? WpayinColors.primary : WpayinColors.textSecondary)
                                            .frame(width: 44, height: 44)
                                            .background(
                                                Circle()
                                                    .fill(selectedSpeed == speed ? WpayinColors.primary.opacity(0.15) : WpayinColors.surface)
                                            )

                                        // Speed Info
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(speed.displayName)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(WpayinColors.text)

                                            Text(speed.estimatedTimeFor(blockchain: selectedToken?.blockchain ?? .ethereum))
                                                .font(.system(size: 14))
                                                .foregroundColor(WpayinColors.textSecondary)

                                            Text(feeText(for: speed))
                                                .font(.system(size: 14))
                                                .foregroundColor(WpayinColors.textSecondary)
                                        }

                                        Spacer()

                                        // Checkmark
                                        if selectedSpeed == speed {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(WpayinColors.primary)
                                        }
                                    }
                                    .padding(16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(selectedSpeed == speed ? WpayinColors.primary.opacity(0.05) : WpayinColors.surface)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(selectedSpeed == speed ? WpayinColors.primary : Color.clear, lineWidth: 2)
                                            )
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done".localized) {
                        dismiss()
                    }
                    .foregroundColor(WpayinColors.primary)
                }
            }
        }
    }
}

#Preview {
    let walletManager = WalletManager()
    return WithdrawView()
        .environmentObject(walletManager)
        .environmentObject(SettingsManager())
}
