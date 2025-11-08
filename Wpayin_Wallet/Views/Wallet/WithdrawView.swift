//
//  WithdrawView.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI

enum WithdrawGasSpeed: String, CaseIterable {
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
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTokenIndex = 0
    @State private var recipientAddress = ""
    @State private var amount = ""
    @State private var showConfirmation = false
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var selectedGasSpeed: WithdrawGasSpeed = .standard
    @State private var showGasSettings = false

    private var selectedToken: Token? {
        guard !walletManager.visibleTokens.isEmpty else { return nil }
        let safeIndex = max(0, min(selectedTokenIndex, walletManager.visibleTokens.count - 1))
        return walletManager.visibleTokens[safeIndex]
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
        guard let token = selectedToken else { return "Send Funds" }
        return token.blockchain == .bitcoin ? "Send Bitcoin" : "Send Funds"
    }
    
    private var headerSubtitle: String {
        guard let token = selectedToken else { return "Send cryptocurrency to another wallet" }
        if token.blockchain == .bitcoin {
            return "Send BTC to any Bitcoin address"
        }
        return "Send cryptocurrency to another wallet"
    }
    
    private var feeDisplayText: String {
        guard let token = selectedToken else { return "Fee" }
        if token.blockchain == .bitcoin {
            return "Network Fee: \(Int(estimatedGasFee)) sat/vB"
        }
        return String(format: "Est. Gas: $%.4f", estimatedGasFee)
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
                            tokens: walletManager.visibleTokens,
                            selectedIndex: $selectedTokenIndex
                        )

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
            .navigationTitle("Withdraw")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(WpayinColors.text)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Send") {
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
        .alert("Transaction Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
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

                print("✅ Transaction sent! Hash: \(result.hash)")

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
    @Binding var selectedIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Asset")
                .font(.wpayinSubheadline)
                .foregroundColor(WpayinColors.text)

            if let currentToken = currentToken {
                Menu {
                    ForEach(Array(tokens.enumerated()), id: \.offset) { index, token in
                        Button(action: {
                            selectedIndex = index
                        }) {
                            HStack(spacing: 12) {
                                // Token Icon
                                if let iconUrl = token.iconUrl, let url = URL(string: iconUrl) {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Circle()
                                            .fill(WpayinColors.primary)
                                            .overlay(
                                                Text(token.symbol.prefix(1))
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(.white)
                                            )
                                    }
                                    .frame(width: 24, height: 24)
                                    .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(WpayinColors.primary)
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Text(token.symbol.prefix(1))
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.white)
                                        )
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(token.symbol)
                                        .font(.system(size: 14, weight: .semibold))
                                    Text(token.blockchain.name)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(String(format: "%.4f", token.balance))
                                    .font(.system(size: 14))
                            }
                        }
                    }
                } label: {
                    HStack {
                        // Token Icon
                        if let iconUrl = currentToken.iconUrl, let url = URL(string: iconUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(WpayinColors.primary)
                                    .overlay(
                                        Text(currentToken.symbol.prefix(1))
                                            .font(.wpayinCaption)
                                            .foregroundColor(.white)
                                    )
                            }
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(WpayinColors.primary)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Text(currentToken.symbol.prefix(1))
                                        .font(.wpayinCaption)
                                        .foregroundColor(.white)
                                )
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(currentToken.name)
                                    .font(.wpayinBody)
                                    .foregroundColor(WpayinColors.text)

                                Text("•")
                                    .foregroundColor(WpayinColors.textTertiary)

                                Text(currentToken.blockchain.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(WpayinColors.textTertiary)
                            }

                            Text("Balance: " + String(format: "%.4f", currentToken.balance) + " \(currentToken.symbol)")
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
                Text("No spendable assets available")
                    .font(.wpayinCaption)
                    .foregroundColor(WpayinColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(WpayinColors.surface)
                    .cornerRadius(12)
            }
        }
    }

    private var currentToken: Token? {
        guard !tokens.isEmpty else { return nil }
        let safeIndex = max(0, min(selectedIndex, tokens.count - 1))
        return tokens[safeIndex]
    }
}

struct TokenSelectionRow: View {
    let token: Token
    let isSelected: Bool
    let action: () -> Void

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

                    Text("$" + String(format: "%.2f", token.totalValue))
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
            Text("Recipient Address")
                .font(.wpayinSubheadline)
                .foregroundColor(WpayinColors.text)

            // Address input method selector
            Picker("Input Method", selection: $addressInputMethod) {
                Text("Manual Entry").tag(0)
                Text("Saved Addresses").tag(1)
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
                        Text("No saved addresses yet")
                            .font(.wpayinBody)
                            .foregroundColor(WpayinColors.textSecondary)

                        Button("Add Address") {
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
                Text("Please enter a valid Ethereum address")
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
            Text("Amount")
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
                        Text("Balance: " + String(format: "%.4f", token.balance) + " \(token.symbol)")
                            .font(.wpayinCaption)
                            .foregroundColor(WpayinColors.textSecondary)

                        Spacer()

                        Button("Max") {
                            amount = String(token.balance)
                        }
                        .font(.wpayinCaption)
                        .foregroundColor(WpayinColors.primary)
                    }

                    if amountValue > token.balance {
                        Text("Insufficient balance")
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
            Text("Transaction Summary")
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
                        Text("Network Fee")
                            .font(.wpayinBody)
                            .foregroundColor(WpayinColors.textSecondary)

                        HStack(spacing: 4) {
                            Image(systemName: gasSpeed.icon)
                                .font(.system(size: 10))
                            Text(gasSpeed.rawValue)
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
                    value: String(format: "%.4f", amount) + " \(token.symbol) + Fee",
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
            Text(title)
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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                VStack {
                    Text("QR Scanner would be implemented here")
                        .foregroundColor(WpayinColors.text)
                        .padding()

                    Text("For now, this is a placeholder")
                        .foregroundColor(WpayinColors.textSecondary)
                        .font(.wpayinCaption)
                }
            }
            .navigationTitle("Scan QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(WpayinColors.text)
                }
            }
        }
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
                        Text("Confirm Transaction")
                            .font(.wpayinHeadline)
                            .foregroundColor(WpayinColors.text)

                        Text("Please review and confirm your transaction")
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
            .navigationTitle("Confirm")
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
                    Text("Save Address")
                        .font(.wpayinHeadline)
                        .foregroundColor(WpayinColors.text)

                    Text("Give this address a name for easy access")
                        .font(.wpayinBody)
                        .foregroundColor(WpayinColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Address Name")
                        .font(.wpayinSubheadline)
                        .foregroundColor(WpayinColors.text)

                    TextField("e.g., My Friend's Wallet", text: $addressName)
                        .font(.wpayinBody)
                        .foregroundColor(WpayinColors.text)
                        .padding(16)
                        .background(WpayinColors.surface)
                        .cornerRadius(12)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Address")
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
            .navigationTitle("Save Address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(WpayinColors.text)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
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
                            Text("Network Fee")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(WpayinColors.text)

                            Text("Choose your transaction speed")
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
                                            Text(speed.rawValue)
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
                    Button("Done") {
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
    walletManager.tokens = Token.mockTokens

    return WithdrawView()
        .environmentObject(walletManager)
}
