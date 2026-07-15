// Autor Lukas Helebrandt, 2026

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
    @State private var tokenIconUrl: String?
    @State private var tokenPrice: Double = 0
    @State private var isLoading = false
    @State private var isFetching = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var autoFetched = false
    @State private var selectedBlockchain: BlockchainPlatform = .ethereum
    @State private var showBlockchainPicker = false
    @State private var metadataFetchTask: Task<Void, Never>?

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        VStack(spacing: 16) {
                            Text("Add Token".localized)
                                .font(.wpayinHeadline)
                                .foregroundColor(WpayinColors.text)

                            Text("Add a custom token to your wallet".localized)
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

                            if isFetching {
                                HStack(spacing: 9) {
                                    ProgressView()
                                        .tint(WpayinColors.primary)

                                    Text("Fetching token details...".localized)
                                        .font(.wpayinCaption)
                                        .foregroundColor(WpayinColors.textSecondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
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
                                        Text("Reset & Enter Manually".localized)
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
                                contractAddress: contractAddress,
                                iconUrl: tokenIconUrl
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Add Token".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel".localized) {
                        dismiss()
                    }
                    .foregroundColor(WpayinColors.text)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add".localized) {
                        addToken()
                    }
                    .foregroundColor(isValidToken ? WpayinColors.primary : WpayinColors.textSecondary)
                    .disabled(!isValidToken || isLoading)
                }
            }
        }
        .alert("Error".localized, isPresented: $showError) {
            Button("OK".localized) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            if !availableEVMBlockchains.contains(selectedBlockchain),
               let first = availableEVMBlockchains.first {
                selectedBlockchain = first
            }
            scheduleMetadataFetch()
        }
        .onChange(of: contractAddress) { _ in
            if autoFetched {
                clearFetchedMetadata()
            }
            scheduleMetadataFetch()
        }
        .onChange(of: selectedBlockchain) { _ in
            clearFetchedMetadata()
            scheduleMetadataFetch()
        }
        .onDisappear {
            metadataFetchTask?.cancel()
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
            .filter {
                $0.network == .mainnet &&
                walletManager.selectedBlockchains.contains($0.platform) &&
                $0.platform.blockchainType?.isEVM == true
            }
            .map { $0.platform }
    }

    private func fetchTokenInfo() {
        guard isValidContractAddress, !isFetching else { return }

        let requestedAddress = contractAddress.lowercased()
        let requestedBlockchain = selectedBlockchain
        isFetching = true

        Task {
            do {
                // Get the config for the selected blockchain
                guard let config = walletManager.availableBlockchains.first(where: { 
                    $0.platform == requestedBlockchain && $0.network == .mainnet
                }) else {
                    throw NSError(domain: "AddToken", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network not available".localized])
                }
                
                let tokenInfo = try await APIService.shared.getTokenInfo(
                    contractAddress: requestedAddress,
                    config: config
                )

                await MainActor.run {
                    guard contractAddress.lowercased() == requestedAddress,
                          selectedBlockchain == requestedBlockchain else { return }
                    isFetching = false
                    tokenName = tokenInfo.name
                    tokenSymbol = tokenInfo.symbol
                    decimals = String(tokenInfo.decimals)
                    tokenIconUrl = tokenInfo.imageUrl
                    tokenPrice = tokenInfo.price
                    autoFetched = true
                    Logger.log("✅ Auto-fetched token: \(tokenInfo.name) (\(tokenInfo.symbol)) on \(requestedBlockchain.name)")
                }
            } catch {
                await MainActor.run {
                    guard contractAddress.lowercased() == requestedAddress,
                          selectedBlockchain == requestedBlockchain else { return }
                    isFetching = false
                    errorMessage = "Failed to fetch token information. Please enter manually.\n\nError: %@".localized(error.localizedDescription)
                    showError = true
                    Logger.log("❌ Failed to fetch token info: \(error)")
                }
            }
        }
    }

    private func resetForm() {
        metadataFetchTask?.cancel()
        clearFetchedMetadata()
    }

    private func clearFetchedMetadata() {
        tokenName = ""
        tokenSymbol = ""
        decimals = ""
        tokenIconUrl = nil
        tokenPrice = 0
        autoFetched = false
        isFetching = false
    }

    private func scheduleMetadataFetch() {
        metadataFetchTask?.cancel()
        guard isValidContractAddress else { return }

        metadataFetchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                fetchTokenInfo()
            }
        }
    }

    private func addToken() {
        guard let decimalsInt = Int(decimals) else {
            errorMessage = "Invalid decimals value".localized
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
                    throw NSError(domain: "AddToken", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network not available".localized])
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
                        let enrichedToken = Token(
                            contractAddress: token.contractAddress,
                            name: token.name,
                            symbol: token.symbol,
                            decimals: token.decimals,
                            balance: token.balance,
                            price: tokenPrice > 0 ? tokenPrice : token.price,
                            iconUrl: tokenIconUrl ?? token.iconUrl,
                            blockchain: token.blockchain,
                            isNative: token.isNative,
                            receivingAddress: token.receivingAddress
                        )
                        // Add token to wallet manager
                        walletManager.addCustomToken(enrichedToken)
                        Logger.log("✅ Token added: \(enrichedToken.name) (\(enrichedToken.symbol)) on \(selectedBlockchain.name) - Balance: \(enrichedToken.balance)")
                        dismiss()
                    } else {
                        errorMessage = "Failed to add token. Please try again.".localized
                        showError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to add token: %@".localized(error.localizedDescription)
                    showError = true
                    Logger.log("❌ Failed to add token: \(error)")
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
                Text(title.localized)
                    .font(.wpayinSubheadline)
                    .foregroundColor(WpayinColors.text)

                if isRequired {
                    Text("*")
                        .foregroundColor(WpayinColors.error)
                }

                Spacer()
            }

            TextField(placeholder.localized, text: $text)
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
    let iconUrl: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Token Preview".localized)
                .font(.wpayinSubheadline)
                .foregroundColor(WpayinColors.text)

            HStack(spacing: 16) {
                AsyncImage(url: iconUrl.flatMap(URL.init(string:))) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .scaledToFit()
                    } else {
                        Circle()
                            .fill(WpayinColors.primary)
                            .overlay(
                                Text(symbol.prefix(1))
                                    .font(.wpayinSubheadline)
                                    .foregroundColor(.white)
                            )
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())

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
                Text("Network".localized)
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
                    if let blockchainType = selectedBlockchain.blockchainType {
                        NetworkIconView(blockchain: blockchainType, size: 24)
                    } else {
                        Circle()
                            .fill(selectedBlockchain.color)
                            .frame(width: 24, height: 24)
                    }
                    
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
