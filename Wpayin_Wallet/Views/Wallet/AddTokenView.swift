//
//  AddTokenView.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI

struct AddTokenView: View {
    @EnvironmentObject var walletManager: WalletManager
    @Environment(\.dismiss) private var dismiss
    @State private var contractAddress = ""
    @State private var tokenSymbol = ""
    @State private var tokenName = ""
    @State private var decimals = ""
    @State private var isLoading = false
    @State private var isFetching = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var autoFetched = false
    @State private var selectedBlockchain: BlockchainPlatform = .ethereum
    @State private var showBlockchainPicker = false

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        VStack(spacing: 16) {
                            Text("Add Token")
                                .font(.wpayinHeadline)
                                .foregroundColor(WpayinColors.text)

                            Text("Add a custom token to your wallet")
                                .font(.wpayinBody)
                                .foregroundColor(WpayinColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }

                        VStack(spacing: 20) {
                            // Blockchain Selector
                            BlockchainSelectorField(
                                selectedBlockchain: $selectedBlockchain,
                                availableBlockchains: availableEVMBlockchains
                            )
                            
                            TokenInputField(
                                title: "Contract Address",
                                placeholder: "0x...",
                                text: $contractAddress,
                                isRequired: true
                            )

                            // Auto-fetch button
                            if isValidContractAddress && !autoFetched {
                                WpayinButton(
                                    title: isFetching ? "Fetching..." : "Auto-Fetch Token Info",
                                    style: .secondary
                                ) {
                                    fetchTokenInfo()
                                }
                                .disabled(isFetching)
                            }

                            TokenInputField(
                                title: "Token Symbol",
                                placeholder: "e.g., USDC",
                                text: $tokenSymbol,
                                isRequired: true
                            )
                            .disabled(autoFetched)

                            TokenInputField(
                                title: "Token Name",
                                placeholder: "e.g., USD Coin",
                                text: $tokenName,
                                isRequired: true
                            )
                            .disabled(autoFetched)

                            TokenInputField(
                                title: "Decimals",
                                placeholder: "e.g., 18",
                                text: $decimals,
                                isRequired: true,
                                keyboardType: .numberPad
                            )
                            .disabled(autoFetched)

                            // Show reset button if auto-fetched
                            if autoFetched {
                                Button(action: resetForm) {
                                    HStack {
                                        Image(systemName: "arrow.counterclockwise")
                                        Text("Reset & Enter Manually")
                                    }
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(WpayinColors.textSecondary)
                                }
                            }
                        }

                        if isValidToken {
                            TokenPreview(
                                symbol: tokenSymbol,
                                name: tokenName,
                                contractAddress: contractAddress
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Add Token")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(WpayinColors.text)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addToken()
                    }
                    .foregroundColor(isValidToken ? WpayinColors.primary : WpayinColors.textSecondary)
                    .disabled(!isValidToken || isLoading)
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private var isValidContractAddress: Bool {
        !contractAddress.isEmpty &&
        contractAddress.hasPrefix("0x") &&
        contractAddress.count == 42
    }

    private var isValidToken: Bool {
        isValidContractAddress &&
        !tokenSymbol.isEmpty &&
        !tokenName.isEmpty &&
        !decimals.isEmpty &&
        Int(decimals) != nil
    }
    
    private var availableEVMBlockchains: [BlockchainPlatform] {
        walletManager.availableBlockchains
            .filter { $0.network == .mainnet && $0.isEnabled && $0.platform.blockchainType?.isEVM == true }
            .map { $0.platform }
    }

    private func fetchTokenInfo() {
        guard isValidContractAddress else { return }

        isFetching = true

        Task {
            do {
                // Get the config for the selected blockchain
                guard let config = walletManager.availableBlockchains.first(where: { 
                    $0.platform == selectedBlockchain && $0.network == .mainnet 
                }) else {
                    throw NSError(domain: "AddToken", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network not available"])
                }
                
                let tokenInfo = try await APIService.shared.getTokenInfo(contractAddress: contractAddress, config: config)

                await MainActor.run {
                    isFetching = false
                    tokenName = tokenInfo.name
                    tokenSymbol = tokenInfo.symbol
                    decimals = String(tokenInfo.decimals)
                    autoFetched = true
                    print("✅ Auto-fetched token: \(tokenInfo.name) (\(tokenInfo.symbol)) on \(selectedBlockchain.name)")
                }
            } catch {
                await MainActor.run {
                    isFetching = false
                    errorMessage = "Failed to fetch token information. Please enter manually.\n\nError: \(error.localizedDescription)"
                    showError = true
                    print("❌ Failed to fetch token info: \(error)")
                }
            }
        }
    }

    private func resetForm() {
        tokenName = ""
        tokenSymbol = ""
        decimals = ""
        autoFetched = false
    }

    private func addToken() {
        guard let decimalsInt = Int(decimals) else {
            errorMessage = "Invalid decimals value"
            showError = true
            return
        }

        isLoading = true

        Task {
            do {
                // Get the config for the selected blockchain
                guard let config = walletManager.availableBlockchains.first(where: { 
                    $0.platform == selectedBlockchain && $0.network == .mainnet 
                }) else {
                    throw NSError(domain: "AddToken", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network not available"])
                }
                
                // Get token balance first
                let tokenWithBalance = try await APIService.shared.getERC20TokenBalance(
                    address: walletManager.walletAddress,
                    contractAddress: contractAddress,
                    config: config,
                    name: tokenName,
                    symbol: tokenSymbol,
                    decimals: decimalsInt
                )

                await MainActor.run {
                    isLoading = false

                    if let token = tokenWithBalance {
                        // Add token to wallet manager
                        walletManager.addCustomToken(token)
                        print("✅ Token added: \(token.name) (\(token.symbol)) on \(selectedBlockchain.name) - Balance: \(token.balance)")
                        dismiss()
                    } else {
                        errorMessage = "Failed to add token. Please try again."
                        showError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to add token: \(error.localizedDescription)"
                    showError = true
                    print("❌ Failed to add token: \(error)")
                }
            }
        }
    }
}

struct TokenInputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let isRequired: Bool
    let keyboardType: UIKeyboardType

    init(title: String, placeholder: String, text: Binding<String>, isRequired: Bool = false, keyboardType: UIKeyboardType = .default) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.isRequired = isRequired
        self.keyboardType = keyboardType
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.wpayinSubheadline)
                    .foregroundColor(WpayinColors.text)

                if isRequired {
                    Text("*")
                        .foregroundColor(WpayinColors.error)
                }

                Spacer()
            }

            TextField(placeholder, text: $text)
                .font(.wpayinBody)
                .foregroundColor(WpayinColors.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboardType)
                .padding(16)
                .background(WpayinColors.surface)
                .cornerRadius(12)
        }
    }
}

struct TokenPreview: View {
    let symbol: String
    let name: String
    let contractAddress: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Token Preview")
                .font(.wpayinSubheadline)
                .foregroundColor(WpayinColors.text)

            HStack(spacing: 16) {
                Circle()
                    .fill(WpayinColors.primary)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(symbol.prefix(1))
                            .font(.wpayinSubheadline)
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.wpayinBody)
                        .foregroundColor(WpayinColors.text)

                    Text(symbol)
                        .font(.wpayinCaption)
                        .foregroundColor(WpayinColors.textSecondary)

                    Text("\(contractAddress.prefix(10))...\(contractAddress.suffix(4))")
                        .font(.wpayinSmall)
                        .foregroundColor(WpayinColors.textSecondary)
                }

                Spacer()
            }
            .padding(16)
            .background(WpayinColors.surface)
            .cornerRadius(12)
        }
    }
}

struct BlockchainSelectorField: View {
    @Binding var selectedBlockchain: BlockchainPlatform
    let availableBlockchains: [BlockchainPlatform]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Network")
                    .font(.wpayinSubheadline)
                    .foregroundColor(WpayinColors.text)
                
                Text("*")
                    .foregroundColor(WpayinColors.error)
                
                Spacer()
            }
            
            Menu {
                ForEach(availableBlockchains, id: \.self) { blockchain in
                    Button(action: {
                        selectedBlockchain = blockchain
                    }) {
                        HStack {
                            Circle()
                                .fill(blockchain.color)
                                .frame(width: 12, height: 12)
                            Text(blockchain.name)
                            if blockchain == selectedBlockchain {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Circle()
                        .fill(selectedBlockchain.color)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: selectedBlockchain.iconName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                        )
                    
                    Text(selectedBlockchain.name)
                        .font(.wpayinBody)
                        .foregroundColor(WpayinColors.text)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(WpayinColors.textSecondary)
                }
                .padding(16)
                .background(WpayinColors.surface)
                .cornerRadius(12)
            }
        }
    }
}

#Preview {
    AddTokenView()
        .environmentObject(WalletManager())
}
