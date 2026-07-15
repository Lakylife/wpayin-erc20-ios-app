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

enum WithdrawInputField: Hashable {
    case recipient
    case amount
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
    @State private var liveStandardGasPrice: GasPrice?
    @State private var liveNativeBalance: Double?
    @State private var isLoadingGasPrice = false
    @State private var submittedTransaction: Transaction?
    @State private var showsPaymentDetails = false
    @FocusState private var focusedInput: WithdrawInputField?
    private let initialPaymentRequest: PaymentRequest?

    init(
        initialToken: Token? = nil,
        initialRecipientAddress: String = "",
        initialPaymentRequest: PaymentRequest? = nil
    ) {
        self.initialPaymentRequest = initialPaymentRequest
        _selectedSymbol = State(initialValue: initialPaymentRequest?.symbol.uppercased() ?? initialToken?.symbol.uppercased())
        _selectedNetwork = State(initialValue: initialPaymentRequest?.blockchain ?? initialToken?.blockchain)
        _recipientAddress = State(initialValue: initialPaymentRequest?.address ?? initialRecipientAddress)
        _amount = State(initialValue: initialPaymentRequest?.formattedAmount ?? "")
    }

    private var selectedToken: Token? {
        guard let selectedSymbol, let selectedNetwork else { return nil }
        let matches = spendableTokens.filter {
            $0.symbol.uppercased() == selectedSymbol.uppercased() && $0.blockchain == selectedNetwork
        }
        if let requestedContract = initialPaymentRequest?.contractAddress?.lowercased() {
            return matches.first { $0.contractAddress?.lowercased() == requestedContract }
        }
        return matches.first
    }

    private var spendableTokens: [Token] {
        walletManager.visibleSupportedTokens
            .filter { $0.blockchain.isEVM || $0.blockchain == .bitcoin }
            .sorted {
            if $0.symbol == $1.symbol {
                return $0.blockchain.name < $1.blockchain.name
            }
            return $0.symbol < $1.symbol
        }
    }

    private var networksForSelectedSymbol: [Token] {
        guard let selectedSymbol else { return [] }
        return spendableTokens
            .filter { $0.symbol.uppercased() == selectedSymbol.uppercased() }
            .sorted {
                if $0.balance != $1.balance { return $0.balance > $1.balance }
                return $0.blockchain.name < $1.blockchain.name
            }
    }

    private var requiresNetworkSelection: Bool {
        networksForSelectedSymbol.count > 1
    }

    private var recipientStepNumber: Int {
        requiresNetworkSelection ? 3 : 2
    }

    private var amountStepNumber: Int {
        recipientStepNumber + 1
    }

    private var feeStepNumber: Int {
        amountStepNumber + 1
    }

    private var reviewStepNumber: Int {
        feeStepNumber + 1
    }

    private var amountValue: Double {
        Double(amount) ?? 0.0
    }

    /// Platform fee charged on top of the sent amount (EVM sends only).
    private var platformFeeValue: Double {
        guard let token = selectedToken, token.blockchain.isEVM else { return 0 }
        return (TransactionService.platformFee(for: Decimal(amountValue)) as NSDecimalNumber).doubleValue
    }

    /// The sender must cover the amount plus the platform fee.
    private var totalDebit: Double {
        amountValue + platformFeeValue
    }

    private var nativeBalance: Double {
        guard let token = selectedToken else { return 0 }
        if let liveNativeBalance { return liveNativeBalance }
        return walletManager.tokens
            .filter { $0.blockchain == token.blockchain && $0.isNative }
            .map(\.balance)
            .max() ?? 0
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
        guard initialPaymentRequest?.isExpired != true else { return false }

        if token.blockchain == .bitcoin {
            return isRecipientAddressValid &&
                   amountValue > 0 &&
                   amountValue <= token.balance
        }

        let hasGas = token.isNative
            ? totalDebit + estimatedGasFee <= token.balance
            : nativeBalance >= estimatedGasFee
        return isRecipientAddressValid &&
               amountValue > 0 &&
               totalDebit <= token.balance &&
               hasGas &&
               selectedGasPrice != nil
    }

    private var isRecipientAddressValid: Bool {
        guard let network = selectedNetwork else { return false }
        let value = recipientAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        if network == .bitcoin {
            return (value.lowercased().hasPrefix("bc1") && value.count >= 14)
                || ((value.hasPrefix("1") || value.hasPrefix("3")) && (26...35).contains(value.count))
        }

        return network.isEVM
            && value.hasPrefix("0x")
            && value.count == 42
            && value.dropFirst(2).allSatisfy { $0.isHexDigit }
    }

    private var isAmountReady: Bool {
        guard let token = selectedToken, amountValue > 0 else { return false }
        if token.blockchain == .bitcoin {
            return amountValue <= token.balance
        }
        return totalDebit <= token.balance
    }

    private var canShowReview: Bool {
        isValidTransaction
    }

    private var isPaymentDetailsVisible: Bool {
        showsPaymentDetails && isRecipientAddressValid
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
                        HStack(spacing: 14) {
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

                            VStack(alignment: .leading, spacing: 4) {
                                Text(headerTitle)
                                    .font(.system(size: 23, weight: .bold, design: .rounded))
                                    .foregroundColor(WpayinColors.text)

                                Text(headerSubtitle)
                                    .font(.system(size: 13))
                                    .foregroundColor(WpayinColors.textSecondary)
                                    .lineLimit(2)
                            }

                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if let paymentRequest = initialPaymentRequest {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: paymentRequest.isExpired ? "clock.badge.exclamationmark" : "doc.text.fill")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(paymentRequest.isExpired ? WpayinColors.error : WpayinColors.primary)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(paymentRequest.isExpired ? "Payment request expired".localized : "Payment request".localized)
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(paymentRequest.isExpired ? WpayinColors.error : WpayinColors.text)

                                    if let note = paymentRequest.note {
                                        Text(note)
                                            .font(.system(size: 13))
                                            .foregroundColor(WpayinColors.textSecondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }

                                    if let expiresAt = paymentRequest.expiresAt {
                                        Text("Expires %@".localized(expiresAt.formatted(date: .abbreviated, time: .shortened)))
                                            .font(.system(size: 11))
                                            .foregroundColor(WpayinColors.textTertiary)
                                    }
                                }

                                Spacer(minLength: 0)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(
                                        paymentRequest.isExpired
                                            ? WpayinColors.error.opacity(0.08)
                                            : WpayinColors.primary.opacity(0.08)
                                    )
                            )
                        }

                        if isPaymentDetailsVisible, let token = selectedToken {
                            AmountInputView(
                                stepNumber: amountStepNumber,
                                amount: $amount,
                                selectedToken: token,
                                reservedNetworkFee: token.isNative ? estimatedGasFee : 0,
                                focusedInput: $focusedInput
                            )

                            WithdrawFeeSelectionView(
                                stepNumber: feeStepNumber,
                                selectedSpeed: $selectedGasSpeed,
                                estimatedGas: estimatedGasFee,
                                token: token,
                                gweiText: selectedGweiText,
                                isLoading: isLoadingGasPrice,
                                focusedInput: $focusedInput,
                                availableNativeBalance: nativeBalance,
                                hasSufficientBalance: token.blockchain == .bitcoin
                                    || (token.isNative
                                        ? totalDebit + estimatedGasFee <= token.balance
                                        : nativeBalance >= estimatedGasFee)
                            )

                            if canShowReview {
                                WithdrawReviewStep(
                                    stepNumber: reviewStepNumber,
                                    token: token,
                                    amount: amountValue,
                                    recipient: recipientAddress,
                                    gasSpeed: selectedGasSpeed,
                                    estimatedGas: estimatedGasFee,
                                    platformFee: platformFeeValue
                                )
                            }
                        } else {
                            WithdrawAssetSelectionView(
                                stepNumber: 1,
                                tokens: spendableTokens,
                                selectedSymbol: $selectedSymbol,
                                selectedNetwork: $selectedNetwork
                            )
                            .environmentObject(settingsManager)

                            if requiresNetworkSelection {
                                WithdrawNetworkSelectionView(
                                    stepNumber: 2,
                                    tokens: networksForSelectedSymbol,
                                    selectedNetwork: $selectedNetwork
                                )
                            }

                            if let token = selectedToken {
                                RecipientAddressView(
                                    stepNumber: recipientStepNumber,
                                    address: $recipientAddress,
                                    selectedNetwork: token.blockchain,
                                    isAddressValid: isRecipientAddressValid,
                                    focusedInput: $focusedInput
                                )
                                .environmentObject(walletManager)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                    .animation(.easeInOut(duration: 0.22), value: requiresNetworkSelection)
                    .animation(.easeInOut(duration: 0.22), value: isRecipientAddressValid)
                    .animation(.easeInOut(duration: 0.22), value: isAmountReady)
                    .animation(.easeInOut(duration: 0.22), value: canShowReview)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { _ in focusedInput = nil }
                )
            }
            .contentShape(Rectangle())
            .onTapGesture {
                focusedInput = nil
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

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()

                    Button("Done".localized) {
                        focusedInput = nil
                    }
                    .font(.system(size: 15, weight: .semibold))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isPaymentDetailsVisible ? "Edit recipient".localized : "Continue".localized) {
                        focusedInput = nil
                        withAnimation(.easeInOut(duration: 0.22)) {
                            showsPaymentDetails.toggle()
                        }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(WpayinColors.primary)
                    .opacity(isRecipientAddressValid ? 1 : 0)
                    .disabled(!isRecipientAddressValid)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    focusedInput = nil
                    showConfirmation = true
                } label: {
                    HStack(spacing: 10) {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Review and sign".localized)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))

                            Image(systemName: "arrow.right")
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
            if let token = selectedToken {
                TransactionConfirmationView(
                    token: token,
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
            showsPaymentDetails = isRecipientAddressValid
            if initialPaymentRequest?.isExpired == true {
                errorMessage = "This payment request has expired. Ask the recipient to create a new one.".localized
                showError = true
            }
        }
        .onChange(of: walletManager.visibleSupportedTokens.map { "\($0.blockchain.rawValue):\($0.contractAddress ?? "native")" }) { _ in
            ensureValidSelection()
        }
        .onChange(of: selectedSymbol) { _ in
            focusedInput = nil
            showsPaymentDetails = false
            ensureValidNetworkForSelectedAsset()
        }
        .onChange(of: selectedNetwork) { _ in
            focusedInput = nil
            showsPaymentDetails = false
            liveStandardGasPrice = nil
            liveNativeBalance = nil
        }
        .onChange(of: recipientAddress) { _ in
            guard isRecipientAddressValid else {
                showsPaymentDetails = false
                return
            }
            focusedInput = nil
            withAnimation(.easeInOut(duration: 0.22)) {
                showsPaymentDetails = true
            }
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
        if let selectedSymbol, !symbols.contains(selectedSymbol.uppercased()) {
            self.selectedSymbol = nil
            selectedNetwork = nil
        }
        ensureValidNetworkForSelectedAsset()
    }

    private func ensureValidNetworkForSelectedAsset() {
        guard let selectedSymbol else {
            selectedNetwork = nil
            return
        }
        let matchingTokens = spendableTokens
            .filter { $0.symbol.uppercased() == selectedSymbol.uppercased() }
        guard !matchingTokens.isEmpty else {
            selectedNetwork = nil
            return
        }

        if let selectedNetwork,
           matchingTokens.contains(where: { $0.blockchain == selectedNetwork }) {
            if initialPaymentRequest?.blockchain == selectedNetwork {
                return
            }
            if matchingTokens.contains(where: { $0.blockchain == selectedNetwork && $0.balance > 0 }) {
                return
            }
        }

        // Select the network that actually owns this asset balance. When the
        // token exists on several chains, prefer the largest funded balance.
        selectedNetwork = matchingTokens
            .filter { $0.balance > 0 }
            .max(by: { $0.balance < $1.balance })?
            .blockchain
            ?? (matchingTokens.count == 1 ? matchingTokens.first?.blockchain : nil)
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
            liveNativeBalance = nil
            return
        }
        isLoadingGasPrice = true
        defer { isLoadingGasPrice = false }

        let gasPriceTask = Task {
            try await GasPriceService.shared.getGasPrice(for: token.blockchain).recommended
        }
        let nativeBalanceTask = Task {
            try await SwapService.shared.fetchNativeBalance(blockchain: token.blockchain)
        }

        do { liveStandardGasPrice = try await gasPriceTask.value } catch {
            liveStandardGasPrice = nil
            Logger.log("Failed to load send gas price: \(error.localizedDescription)")
        }
        do {
            let balance = try await nativeBalanceTask.value
            liveNativeBalance = NSDecimalNumber(decimal: balance).doubleValue
        } catch {
            liveNativeBalance = nil
            Logger.log("Failed to load live native balance: \(error.localizedDescription)")
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

struct WithdrawStepCard<Content: View>: View {
    let stepNumber: Int
    let title: String
    let isComplete: Bool
    let showsStepNumber: Bool
    private let content: Content

    init(
        stepNumber: Int,
        title: String,
        isComplete: Bool = false,
        showsStepNumber: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.stepNumber = stepNumber
        self.title = title
        self.isComplete = isComplete
        self.showsStepNumber = showsStepNumber
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 11) {
                if showsStepNumber {
                    ZStack {
                        Circle()
                            .fill(isComplete ? WpayinColors.success.opacity(0.16) : WpayinColors.primary.opacity(0.14))

                        if isComplete {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(WpayinColors.success)
                        } else {
                            Text("\(stepNumber)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(WpayinColors.primary)
                        }
                    }
                    .frame(width: 30, height: 30)
                }

                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(WpayinColors.text)

                Spacer()
            }

            content
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(WpayinColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            isComplete ? WpayinColors.success.opacity(0.16) : WpayinColors.surfaceBorder,
                            lineWidth: 1
                        )
                )
        )
    }
}

struct WithdrawAssetSelectionView: View {
    let stepNumber: Int
    let tokens: [Token]
    @Binding var selectedSymbol: String?
    @Binding var selectedNetwork: BlockchainType?
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var showAssetPicker = false

    private var selectedAssetTokens: [Token] {
        guard let selectedSymbol else { return [] }
        return tokens.filter { $0.symbol.uppercased() == selectedSymbol.uppercased() }
    }

    private var representativeToken: Token? {
        if let selectedNetwork,
           let exactToken = selectedAssetTokens.first(where: { $0.blockchain == selectedNetwork }) {
            return exactToken
        }
        return selectedAssetTokens.first
    }

    private var totalBalance: Double {
        selectedAssetTokens.reduce(0) { $0 + $1.balance }
    }

    private var displayedBalance: Double {
        if let selectedNetwork,
           let exactToken = selectedAssetTokens.first(where: { $0.blockchain == selectedNetwork }) {
            return exactToken.balance
        }
        return totalBalance
    }

    var body: some View {
        WithdrawStepCard(
            stepNumber: stepNumber,
            title: "Select Asset".localized,
            isComplete: representativeToken != nil
        ) {
            Button {
                showAssetPicker = true
            } label: {
                HStack(spacing: 13) {
                    if let token = representativeToken {
                        TokenIconView(token: token, size: 36, showNetworkBadge: false)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(token.symbol.uppercased())
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(WpayinColors.text)

                            Text("Balance: %@".localized(
                                TokenIconHelper.formattedBalanceWithSymbol(
                                    displayedBalance,
                                    symbol: token.symbol,
                                    decimals: 4
                                )
                            ))
                            .font(.system(size: 12))
                            .foregroundColor(WpayinColors.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(WpayinColors.textTertiary)
                    } else {
                        Image(systemName: "coloncurrencysign.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(WpayinColors.primary)
                            .frame(width: 36, height: 36)

                        Text(L10n.Tokens.selectToken.localized)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(WpayinColors.text)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(WpayinColors.textTertiary)
                    }
                }
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(WpayinPressableStyle())
        }
        .sheet(isPresented: $showAssetPicker) {
            AssetPickerSheet(
                tokens: tokens,
                selectedSymbol: selectedSymbol
            ) { symbol in
                if selectedSymbol?.uppercased() != symbol.uppercased() {
                    selectedNetwork = nil
                }
                selectedSymbol = symbol
                let matchingTokens = tokens.filter { $0.symbol.uppercased() == symbol.uppercased() }
                selectedNetwork = matchingTokens
                    .filter { $0.balance > 0 }
                    .max(by: { $0.balance < $1.balance })?
                    .blockchain
                    ?? (matchingTokens.count == 1 ? matchingTokens.first?.blockchain : nil)
            }
            .environmentObject(settingsManager)
        }
    }
}

struct WithdrawNetworkSelectionView: View {
    let stepNumber: Int
    let tokens: [Token]
    @Binding var selectedNetwork: BlockchainType?
    @State private var showNetworkPicker = false

    private var selectedToken: Token? {
        guard let selectedNetwork else { return nil }
        return tokens.first { $0.blockchain == selectedNetwork }
    }

    var body: some View {
        WithdrawStepCard(
            stepNumber: stepNumber,
            title: L10n.Swap.selectNetwork.localized,
            isComplete: selectedToken != nil
        ) {
            Button {
                showNetworkPicker = true
            } label: {
                HStack(spacing: 13) {
                    if let token = selectedToken {
                        NetworkIconView(blockchain: token.blockchain, size: 34)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(token.blockchain.name)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(WpayinColors.text)

                            Text(TokenIconHelper.formattedBalanceWithSymbol(
                                token.balance,
                                symbol: token.symbol,
                                decimals: 4
                            ))
                            .font(.system(size: 12))
                            .foregroundColor(WpayinColors.textSecondary)
                        }
                    } else {
                        Image(systemName: "network")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(WpayinColors.primary)
                            .frame(width: 34, height: 34)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(L10n.Swap.selectNetwork.localized)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(WpayinColors.text)

                            Text(L10n.Networks.available.localized(tokens.count))
                                .font(.system(size: 12))
                                .foregroundColor(WpayinColors.textSecondary)
                        }
                    }

                    Spacer()

                    Image(systemName: selectedToken == nil ? "chevron.right" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(WpayinColors.textTertiary)
                }
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(WpayinPressableStyle())
        }
        .sheet(isPresented: $showNetworkPicker) {
            NetworkPickerSheet(
                tokens: tokens,
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
    let stepNumber: Int
    @Binding var address: String
    let selectedNetwork: BlockchainType
    let isAddressValid: Bool
    let focusedInput: FocusState<WithdrawInputField?>.Binding
    @State private var showScanner = false
    @State private var showSavedAddresses = false
    @State private var showAddAddressSheet = false
    @State private var newAddressName = ""

    var body: some View {
        WithdrawStepCard(
            stepNumber: stepNumber,
            title: "Recipient Address".localized,
            isComplete: isAddressValid
        ) {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    HStack(spacing: 9) {
                        TextField(addressPlaceholder, text: $address)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(WpayinColors.text)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused(focusedInput, equals: .recipient)

                        if !address.isEmpty {
                            Image(systemName: isAddressValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(isAddressValid ? WpayinColors.success : WpayinColors.error)
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(WpayinColors.surfaceLight)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .stroke(
                                        address.isEmpty
                                            ? WpayinColors.surfaceBorder
                                            : (isAddressValid ? WpayinColors.success.opacity(0.35) : WpayinColors.error.opacity(0.45)),
                                        lineWidth: 1
                                    )
                            )
                    )

                    Button {
                        focusedInput.wrappedValue = nil
                        showScanner = true
                    } label: {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(WpayinColors.primary)
                            .frame(width: 52, height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .fill(WpayinColors.primary.opacity(0.12))
                            )
                    }
                    .buttonStyle(WpayinPressableStyle())
                }

                HStack(spacing: 10) {
                    Button {
                        focusedInput.wrappedValue = nil
                        showSavedAddresses = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "person.crop.circle.fill.badge.checkmark")
                                .font(.system(size: 15, weight: .semibold))

                            Text("Saved Addresses".localized)
                                .font(.system(size: 13, weight: .semibold))

                            if !walletManager.savedAddresses.isEmpty {
                                Text("\(walletManager.savedAddresses.count)")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(WpayinColors.primary.opacity(0.16)))
                            }
                        }
                        .foregroundColor(WpayinColors.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(WpayinColors.primary.opacity(0.09))
                        )
                    }
                    .buttonStyle(WpayinPressableStyle())

                    if isAddressValid {
                        Button {
                            showAddAddressSheet = true
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .bold))

                                Text("Save Address".localized)
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(WpayinColors.success)
                            .padding(.horizontal, 12)
                            .frame(height: 42)
                            .background(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(WpayinColors.success.opacity(0.09))
                            )
                        }
                        .buttonStyle(WpayinPressableStyle())
                    }
                }

                if !address.isEmpty && !isAddressValid {
                    HStack(spacing: 7) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))

                        Text("Please enter a valid wallet address".localized)
                            .font(.system(size: 12))
                    }
                    .foregroundColor(WpayinColors.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .sheet(isPresented: $showScanner) {
            QRScannerView(scannedAddress: $address)
        }
        .sheet(isPresented: $showSavedAddresses) {
            SavedAddressPickerSheet(
                addresses: walletManager.savedAddresses,
                selectedAddress: address,
                network: selectedNetwork
            ) { savedAddress in
                address = savedAddress.address
                focusedInput.wrappedValue = nil
            }
        }
        .sheet(isPresented: $showAddAddressSheet) {
            AddAddressSheet(
                address: address,
                addressName: $newAddressName
            ) {
                if !newAddressName.isEmpty && isAddressValid {
                    walletManager.addSavedAddress(name: newAddressName, address: address)
                    newAddressName = ""
                    showAddAddressSheet = false
                }
            }
        }
    }

    private var addressPlaceholder: String {
        selectedNetwork == .bitcoin ? "bc1…" : "0x…"
    }
}

struct AmountInputView: View {
    let stepNumber: Int
    @Binding var amount: String
    let selectedToken: Token
    let reservedNetworkFee: Double
    let focusedInput: FocusState<WithdrawInputField?>.Binding

    private var amountValue: Double {
        Double(amount) ?? 0.0
    }

    private var platformFeeValue: Double {
        guard selectedToken.blockchain.isEVM else { return 0 }
        return (TransactionService.platformFee(for: Decimal(amountValue)) as NSDecimalNumber).doubleValue
    }

    /// Max sendable so that amount + platform fee still fits in the balance.
    private var maxSendable: Double {
        let availableAfterGas = max(0, selectedToken.balance - reservedNetworkFee)
        guard selectedToken.blockchain.isEVM, AppConfig.platformFeeEnabled else { return availableAfterGas }
        let rate = (AppConfig.platformFeeRate as NSDecimalNumber).doubleValue
        return availableAfterGas / (1 + rate)
    }

    var body: some View {
        WithdrawStepCard(
            stepNumber: stepNumber,
            title: "Amount".localized,
            isComplete: amountValue > 0
                && amountValue + platformFeeValue + reservedNetworkFee <= selectedToken.balance,
            showsStepNumber: false
        ) {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    TextField("0.0", text: $amount)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(WpayinColors.text)
                        .keyboardType(.decimalPad)
                        .focused(focusedInput, equals: .amount)
                        .padding(.vertical, 18)
                        .padding(.horizontal, 16)

                    Text(selectedToken.symbol)
                        .font(.wpayinHeadline)
                        .foregroundColor(WpayinColors.textSecondary)
                        .padding(.trailing, 8)
                }
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(WpayinColors.surfaceLight)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                        )
                )

                HStack {
                    Text("Balance: %@".localized(String(format: "%.4f %@", selectedToken.balance, selectedToken.symbol)))
                        .font(.wpayinCaption)
                        .foregroundColor(WpayinColors.textSecondary)

                    Spacer()

                    Button("Max".localized) {
                        amount = formattedMaximum(maxSendable, decimals: selectedToken.decimals)
                        focusedInput.wrappedValue = nil
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(WpayinColors.primary)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(WpayinColors.primary.opacity(0.12)))
                    .buttonStyle(WpayinPressableStyle())
                }

                if platformFeeValue > 0, amountValue > 0 {
                    Text("Platform fee %@: %@ %@".localized(
                        String(format: "(%.2f%%)", Double(AppConfig.platformFeeBps) / 100),
                        String(format: "%.6f", platformFeeValue),
                        selectedToken.symbol
                    ))
                    .font(.wpayinCaption)
                    .foregroundColor(WpayinColors.textSecondary)
                }

                if amountValue + platformFeeValue + reservedNetworkFee > selectedToken.balance {
                    Text("Insufficient balance".localized)
                        .font(.wpayinCaption)
                        .foregroundColor(WpayinColors.error)
                }
            }
        }
    }

    private func formattedMaximum(_ value: Double, decimals: Int) -> String {
        let precision = min(max(decimals, 0), 12)
        var result = String(format: "%.*f", precision, max(0, value))
        while result.contains(".") && result.last == "0" { result.removeLast() }
        if result.last == "." { result.removeLast() }
        return result
    }
}

struct WithdrawFeeSelectionView: View {
    let stepNumber: Int
    @Binding var selectedSpeed: WithdrawGasSpeed
    let estimatedGas: Double
    let token: Token
    let gweiText: String
    let isLoading: Bool
    let focusedInput: FocusState<WithdrawInputField?>.Binding
    let availableNativeBalance: Double
    let hasSufficientBalance: Bool

    var body: some View {
        WithdrawStepCard(
            stepNumber: stepNumber,
            title: "Network Fee".localized,
            isComplete: token.blockchain == .bitcoin || (!isLoading && estimatedGas > 0),
            showsStepNumber: false
        ) {
            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    ForEach(WithdrawGasSpeed.allCases, id: \.self) { speed in
                        Button {
                            focusedInput.wrappedValue = nil
                            selectedSpeed = speed
                        } label: {
                            VStack(spacing: 7) {
                                Image(systemName: speed.icon)
                                    .font(.system(size: 17, weight: .semibold))

                                Text(speed.displayName)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)

                                Text(speed.estimatedTimeFor(blockchain: token.blockchain))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(
                                        selectedSpeed == speed
                                            ? WpayinColors.text.opacity(0.72)
                                            : WpayinColors.textTertiary
                                    )
                                    .lineLimit(1)
                            }
                            .foregroundColor(selectedSpeed == speed ? WpayinColors.text : WpayinColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 88)
                            .background(
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .fill(
                                        selectedSpeed == speed
                                            ? WpayinColors.primary.opacity(0.16)
                                            : WpayinColors.surfaceLight
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                                            .stroke(
                                                selectedSpeed == speed
                                                    ? WpayinColors.primary.opacity(0.7)
                                                    : WpayinColors.surfaceBorder,
                                                lineWidth: 1
                                            )
                                    )
                                )
                        }
                        .buttonStyle(WpayinPressableStyle())
                    }
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(selectedSpeed.displayName)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(WpayinColors.text)

                        if token.blockchain != .bitcoin {
                            Text(gweiText)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(WpayinColors.textTertiary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    if isLoading {
                        ProgressView()
                            .tint(WpayinColors.primary)
                    } else {
                        Text(selectedFeeText)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(WpayinColors.primary)
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(WpayinColors.surfaceLight)
                )

                if !isLoading && !hasSufficientBalance {
                    HStack(spacing: 7) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))

                        Text(insufficientFeeMessage)
                            .font(.system(size: 12))
                    }
                    .foregroundColor(WpayinColors.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var selectedFeeText: String {
        if token.blockchain == .bitcoin {
            return "\(Int(estimatedGas)) sat/vB"
        }
        guard estimatedGas > 0 else { return "—" }
        return "~\(String(format: "%.6f", estimatedGas)) \(token.blockchain.nativeToken)"
    }

    private var insufficientFeeMessage: String {
        let nativeSymbol = token.blockchain.nativeToken
        if token.isNative {
            return "Amount plus the network fee exceeds the available %@ balance.".localized(nativeSymbol)
        }
        return "Sending %@ on %@ requires %@ for the network fee. Required: ~%@ %@ · Available: %@ %@".localized(
            token.symbol,
            token.blockchain.name,
            nativeSymbol,
            formattedNative(estimatedGas),
            nativeSymbol,
            formattedNative(availableNativeBalance),
            nativeSymbol
        )
    }

    private func formattedNative(_ value: Double) -> String {
        guard value > 0 else { return "0" }
        return String(format: value < 0.0001 ? "%.8f" : "%.6f", value)
    }
}

struct WithdrawReviewStep: View {
    let stepNumber: Int
    let token: Token
    let amount: Double
    let recipient: String
    let gasSpeed: WithdrawGasSpeed
    let estimatedGas: Double
    let platformFee: Double

    var body: some View {
        WithdrawStepCard(
            stepNumber: stepNumber,
            title: "Transaction Summary".localized,
            isComplete: true,
            showsStepNumber: false
        ) {
            VStack(spacing: 13) {
                SummaryRow(
                    title: "Amount",
                    value: "\(formatted(amount)) \(token.symbol)"
                )

                SummaryRow(
                    title: L10n.Swap.selectNetwork.localized,
                    value: token.blockchain.name
                )

                SummaryRow(
                    title: "To",
                    value: shortRecipient
                )

                SummaryRow(
                    title: "Network Fee".localized,
                    value: feeText
                )

                if platformFee > 0 {
                    SummaryRow(
                        title: "\("Platform fee".localized) \(String(format: "(%.2f%%)", Double(AppConfig.platformFeeBps) / 100))",
                        value: "\(formatted(platformFee)) \(token.symbol)"
                    )
                }

                Divider()
                    .background(WpayinColors.surfaceBorder)

                SummaryRow(
                    title: "Total",
                    value: "\(formatted(amount + platformFee)) \(token.symbol) + \("Fee".localized)",
                    isTotal: true
                )
            }
        }
    }

    private var shortRecipient: String {
        guard recipient.count > 13 else { return recipient }
        return "\(recipient.prefix(7))…\(recipient.suffix(6))"
    }

    private var feeText: String {
        if token.blockchain == .bitcoin {
            return "\(gasSpeed.displayName) · \(Int(estimatedGas)) sat/vB"
        }
        return "\(gasSpeed.displayName) · ~\(String(format: "%.6f", estimatedGas)) \(token.blockchain.nativeToken)"
    }

    private func formatted(_ value: Double) -> String {
        let precision = value >= 1 ? 6 : 8
        var result = String(format: "%.*f", precision, value)
        while result.contains("."), result.last == "0" { result.removeLast() }
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
    var onPaymentRequest: ((PaymentRequest) -> Void)? = nil
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
                            if let paymentRequest = PaymentRequestCodec.decode(value) {
                                scannedAddress = paymentRequest.address
                                if let onPaymentRequest {
                                    onPaymentRequest(paymentRequest)
                                } else {
                                    onScan?(paymentRequest.address)
                                }
                                dismiss()
                                return
                            }
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

struct SavedAddressPickerSheet: View {
    let addresses: [SavedAddress]
    let selectedAddress: String
    let network: BlockchainType
    let onSelect: (SavedAddress) -> Void

    @Environment(\.dismiss) private var dismiss

    private var compatibleAddresses: [SavedAddress] {
        addresses.filter { isCompatible($0.address) }
    }

    var body: some View {
        NavigationView {
            ZStack {
                WalletFlowBackground()

                if compatibleAddresses.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundColor(WpayinColors.textTertiary)

                        Text("No saved addresses yet".localized)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(WpayinColors.text)

                        Text(network.name)
                            .font(.system(size: 13))
                            .foregroundColor(WpayinColors.textSecondary)
                    }
                    .padding(24)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            ForEach(compatibleAddresses) { savedAddress in
                                SavedAddressRow(
                                    savedAddress: savedAddress,
                                    isSelected: savedAddress.address.caseInsensitiveCompare(selectedAddress) == .orderedSame
                                ) {
                                    onSelect(savedAddress)
                                    dismiss()
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("Saved Addresses".localized)
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

    private func isCompatible(_ address: String) -> Bool {
        let value = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if network == .bitcoin {
            return (value.lowercased().hasPrefix("bc1") && value.count >= 14)
                || ((value.hasPrefix("1") || value.hasPrefix("3")) && (26...35).contains(value.count))
        }

        return network.isEVM
            && value.hasPrefix("0x")
            && value.count == 42
            && value.dropFirst(2).allSatisfy { $0.isHexDigit }
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
