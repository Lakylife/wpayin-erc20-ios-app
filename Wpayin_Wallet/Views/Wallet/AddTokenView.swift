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

                            Text("Add a custom ERC-20 token to your wallet")
                                .font(.wpayinBody)
                                .foregroundColor(WpayinColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }

                        VStack(spacing: 20) {
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

    private func fetchTokenInfo() {
        guard isValidContractAddress else { return }

        isFetching = true

        Task {
            do {
                let tokenInfo = try await APIService.shared.getTokenInfo(contractAddress: contractAddress)

                await MainActor.run {
                    isFetching = false
                    tokenName = tokenInfo.name
                    tokenSymbol = tokenInfo.symbol
                    decimals = String(tokenInfo.decimals)
                    autoFetched = true
                    print("✅ Auto-fetched token: \(tokenInfo.name) (\(tokenInfo.symbol))")
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
                // Get token balance first
                let ethereumConfig = BlockchainConfig.defaultConfigs.first(where: { $0.platform == .ethereum })!
                let tokenWithBalance = try await APIService.shared.getERC20TokenBalance(
                    address: walletManager.walletAddress,
                    contractAddress: contractAddress,
                    config: ethereumConfig,
                    name: tokenName,
                    symbol: tokenSymbol,
                    decimals: decimalsInt
                )

                await MainActor.run {
                    isLoading = false

                    if let token = tokenWithBalance {
                        // Add token to wallet manager
                        walletManager.addCustomToken(token)
                        print("✅ Token added: \(token.name) (\(token.symbol)) - Balance: \(token.balance)")
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

#Preview {
    AddTokenView()
        .environmentObject(WalletManager())
}
