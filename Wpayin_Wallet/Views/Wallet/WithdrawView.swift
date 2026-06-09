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
        
        // EVM address validation
        return !recipientAddress.isEmpty &&
               recipientAddress.hasPrefix("0x") &&
               recipientAddress.count == 42 &&
               amountValue > 0 &&
               amountValue <= token.balance
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

        // Base gas fee by network (in native tokens)
        let baseGas: Double
        switch token.blockchain {
        case .ethereum:
            baseGas = 0.002
        case .arbitrum, .optimism:
            baseGas = 0.0003
        case .polygon:
            baseGas = 0.0001
        case .bsc:
            baseGas = 0.0002
        default:
            baseGas = 0.001
        }

        return baseGas * selectedGasSpeed.multiplier
    }

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 16) {
                            Text(headerTitle)
                                .font(.wpayinHeadline)
                                .foregroundColor(WpayinColors.text)

                            Text(headerSubtitle)
                                .font(.wpayinBody)
                                .foregroundColor(WpayinColors.textSecondary)
                        }

                        // Token Selection
                        TokenSelectionView(
                            tokens: spendableTokens,
                            selectedSymbol: $selectedSymbol,
                            selectedNetwork: $selectedNetwork
                        )
                        .environmentObject(settingsManager)

                        // Recipient Address
                        RecipientAddressView(address: $recipientAddress)
                            .environmentObject(walletManager)

                        // Amount Input
                        AmountInputView(
                            amount: $amount,
                            selectedToken: selectedToken
                        )

                        // Transaction Summary
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
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Withdraw".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel".localized) {
                        dismiss()
                    }
                    .foregroundColor(WpayinColors.text)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Send".localized) {
                        showConfirmation = true
                    }
                    .foregroundColor(isValidTransaction ? WpayinColors.primary : WpayinColors.textSecondary)
                    .disabled(!isValidTransaction)
                }
            }
        }
        .sheet(isPresented: $showConfirmation) {
            TransactionConfirmationView(
                token: selectedToken!,
                amount: amountValue,
                recipient: recipientAddress,
                gasSpeed: selectedGasSpeed,
                estimatedGas: estimatedGasFee,
                onConfirm: {
                    processTransaction()
                }
            )
        }
        .sheet(isPresented: $showGasSettings) {
            WithdrawGasSettingsSheet(
                selectedSpeed: $selectedGasSpeed, 
                estimatedGas: estimatedGasFee,
                selectedToken: selectedToken
            )
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
    }

    private func ensureValidSelection() {
        guard !spendableTokens.isEmpty else {
            selectedSymbol = nil
            selectedNetwork = nil
            return
        }

        let symbols = Array(Set(spendableTokens.map { $0.symbol.uppercased() })).sorted()
        if selectedSymbol == nil || !symbols.contains(selectedSymbol ?? "") {
            selectedSymbol = symbols.first
        }
        ensureValidNetworkForSelectedAsset()
    }

    private func ensureValidNetworkForSelectedAsset() {
        guard let selectedSymbol else { return }
        let networks = spendableTokens
            .filter { $0.symbol.uppercased() == selectedSymbol.uppercased() }
            .map { $0.blockchain }
        if selectedNetwork == nil || !networks.contains(selectedNetwork!) {
            selectedNetwork = networks.first
        }
    }

    private func processTransaction() {
        isProcessing = true

        Task {
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
                        customGasPrice: nil, // Use automatic gas price
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
                        customGasPrice: nil, // Use automatic gas price
                        gasLimit: 65000
                    )
                }

                Logger.log("✅ Transaction sent! Hash: \(result.hash)")

                await MainActor.run {
                    isProcessing = false
                    // Refresh wallet data to show updated balance
                    Task {
                        await walletManager.refreshWalletData()
                    }
                    dismiss()
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
}

struct TokenSelectionView: View {
    let tokens: [Token]
    @Binding var selectedSymbol: String?
    @Binding var selectedNetwork: BlockchainType?
    @EnvironmentObject var settingsManager: SettingsManager

    private var currentToken: Token? {
        guard let selectedSymbol, let selectedNetwork else { return nil }
        return tokens.first {
            $0.symbol.uppercased() == selectedSymbol.uppercased() && $0.blockchain == selectedNetwork
        }
    }

    private var assetSymbols: [String] {
        Array(Set(tokens.map { $0.symbol.uppercased() })).sorted()
    }

    private var networksForSelectedAsset: [Token] {
        guard let selectedSymbol else { return [] }
        return tokens
            .filter { $0.symbol.uppercased() == selectedSymbol.uppercased() }
            .sorted { $0.blockchain.name < $1.blockchain.name }
    }

    private func groupedToken(for symbol: String) -> Token? {
        let symbolTokens = tokens.filter { $0.symbol.uppercased() == symbol.uppercased() }
        guard let first = symbolTokens.first else { return nil }
        let totalBalance = symbolTokens.reduce(0) { $0 + $1.balance }
        let bestPrice = symbolTokens.map { $0.price }.filter { $0 > 0 }.max() ?? 0

        return Token(
            contractAddress: first.contractAddress,
            name: first.name,
            symbol: first.symbol,
            decimals: first.decimals,
            balance: totalBalance,
            price: bestPrice,
            iconUrl: first.iconUrl,
            blockchain: first.blockchain,
            isNative: first.isNative,
            receivingAddress: first.receivingAddress
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Asset".localized)
                .font(.wpayinSubheadline)
                .foregroundColor(WpayinColors.text)

            if let currentToken = currentToken {
                Menu {
                    ForEach(assetSymbols, id: \.self) { symbol in
                        Button(action: {
                            selectedSymbol = symbol
                        }) {
                            let token = groupedToken(for: symbol)
                            HStack(spacing: 12) {
                                if let token {
                                    TokenIconView(token: token, size: 24, showNetworkBadge: false)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(token?.name ?? symbol)
                                        .font(.system(size: 14, weight: .semibold))
                                        .lineLimit(1)
                                    Text("\(TokenIconHelper.formattedBalance(token?.balance ?? 0)) \(symbol)")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(token?.totalValue.formatted(as: settingsManager.selectedCurrency) ?? "")
                                    .font(.system(size: 14))
                            }
                        }
                    }
                } label: {
                    HStack {
                        TokenIconView(token: currentToken, size: 32, showNetworkBadge: false)

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
                    .padding(16)
                    .background(WpayinColors.surface)
                    .cornerRadius(12)
                }

                Text("Select Network".localized)
                    .font(.wpayinSubheadline)
                    .foregroundColor(WpayinColors.text)
                    .padding(.top, 4)

                Menu {
                    ForEach(networksForSelectedAsset) { token in
                        Button(action: {
                            selectedNetwork = token.blockchain
                        }) {
                            HStack {
                                NetworkIconView(blockchain: token.blockchain, size: 20)
                                Text(token.blockchain.name)
                                Spacer()
                                Text(TokenIconHelper.formattedBalance(token.balance))
                            }
                        }
                    }
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
                    .padding(16)
                    .background(WpayinColors.surface)
                    .cornerRadius(12)
                }
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
                .font(.wpayinSubheadline)
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
                        .background(WpayinColors.surface)
                        .cornerRadius(12)

                    Button(action: {
                        showScanner = true
                    }) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 20))
                            .foregroundColor(WpayinColors.primary)
                            .frame(width: 48, height: 48)
                            .background(WpayinColors.surface)
                            .cornerRadius(12)
                    }

                    Button(action: {
                        showAddAddressSheet = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 20))
                            .foregroundColor(WpayinColors.success)
                            .frame(width: 48, height: 48)
                            .background(WpayinColors.surface)
                            .cornerRadius(12)
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
                Text("Please enter a valid Ethereum address".localized)
                    .font(.wpayinCaption)
                    .foregroundColor(WpayinColors.error)
            }
        }
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
        return address.hasPrefix("0x") && address.count == 42
    }
}

struct AmountInputView: View {
    @Binding var amount: String
    let selectedToken: Token?

    private var amountValue: Double {
        Double(amount) ?? 0.0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Amount".localized)
                .font(.wpayinSubheadline)
                .foregroundColor(WpayinColors.text)

            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    TextField("0.0", text: $amount)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(WpayinColors.text)
                        .keyboardType(.decimalPad)
                        .padding(20)
                        .background(WpayinColors.surface)
                        .cornerRadius(12)

                    if let token = selectedToken {
                        Text(token.symbol)
                            .font(.wpayinHeadline)
                            .foregroundColor(WpayinColors.textSecondary)
                            .padding(.trailing, 8)
                    }
                }

                if let token = selectedToken {
                    HStack {
                        Text("Balance: %@".localized(String(format: "%.4f %@", token.balance, token.symbol)))
                            .font(.wpayinCaption)
                            .foregroundColor(WpayinColors.textSecondary)

                        Spacer()

                        Button("Max".localized) {
                            amount = String(token.balance)
                        }
                        .font(.wpayinCaption)
                        .foregroundColor(WpayinColors.primary)
                    }

                    if amountValue > token.balance {
                        Text("Insufficient balance".localized)
                            .font(.wpayinCaption)
                            .foregroundColor(WpayinColors.error)
                    }
                }
            }
        }
    }
}

struct TransactionSummaryView: View {
    let token: Token
    let amount: Double
    let recipient: String
    @Binding var gasSpeed: WithdrawGasSpeed
    let estimatedGas: Double
    let onGasSettingsTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Transaction Summary".localized)
                .font(.wpayinSubheadline)
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

                        Text("~" + String(format: "%.6f", estimatedGas) + " ETH")
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
            .padding(16)
            .background(WpayinColors.surface)
            .cornerRadius(12)
        }
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
    let gasSpeed: WithdrawGasSpeed
    let estimatedGas: Double
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                VStack(spacing: 32) {
                    VStack(spacing: 16) {
                        Text("Confirm Transaction".localized)
                            .font(.wpayinHeadline)
                            .foregroundColor(WpayinColors.text)

                        Text("Please review and confirm your transaction".localized)
                            .font(.wpayinBody)
                            .foregroundColor(WpayinColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    TransactionSummaryView(
                        token: token,
                        amount: amount,
                        recipient: recipient,
                        gasSpeed: .constant(gasSpeed),
                        estimatedGas: estimatedGas,
                        onGasSettingsTapped: { }
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
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
            }
            .navigationTitle("Confirm".localized)
            .navigationBarTitleDisplayMode(.inline)
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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

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

                                            if selectedToken?.blockchain != .bitcoin {
                                                Text("~\(String(format: "%.6f", estimatedGas * speed.multiplier)) ETH")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(WpayinColors.textSecondary)
                                            }
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
