// Autor Lukas Helebrandt, 2026

//
//  DepositView.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct DepositView: View {
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSymbol: String?
    @State private var selectedNetwork: BlockchainType?
    @State private var qrCodeImage: UIImage?
    @State private var addressCopied = false

    init(initialToken: Token? = nil) {
        _selectedSymbol = State(initialValue: initialToken?.symbol.uppercased())
        _selectedNetwork = State(initialValue: initialToken?.blockchain)
    }

    private var selectedToken: Token? {
        guard let selectedSymbol, let selectedNetwork else { return nil }
        return availableTokensWithNetwork.first {
            $0.symbol.uppercased() == selectedSymbol.uppercased() && $0.blockchain == selectedNetwork
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 16) {
                            Text("Deposit Funds".localized)
                                .font(.wpayinHeadline)
                                .foregroundColor(WpayinColors.text)

                            Text("Send funds to your %@ address".localized(selectedToken?.symbol ?? "Token"))
                                .font(.wpayinBody)
                                .foregroundColor(WpayinColors.textSecondary)
                        }

                        // Token Selector with Network Info
                        AssetNetworkSelector(
                            selectedSymbol: $selectedSymbol,
                            selectedNetwork: $selectedNetwork,
                            availableTokens: availableTokensWithNetwork
                        )
                        .environmentObject(walletManager)
                        .environmentObject(settingsManager)

                        if let tokenAddress = currentTokenAddress, !tokenAddress.isEmpty {
                            QRCodeView(
                                address: tokenAddress,
                                qrCodeImage: $qrCodeImage
                            )

                            AddressDisplayView(
                                address: tokenAddress,
                                copied: $addressCopied
                            )
                        } else {
                            MissingDepositAddressView()
                        }

                        // Instructions
                        InstructionsView()

                        // Warning
                        if let token = selectedToken {
                            WarningView(
                                tokenSymbol: token.symbol,
                                networkName: token.blockchain.name
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Deposit".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close".localized) {
                        dismiss()
                    }
                    .foregroundColor(WpayinColors.text)
                }
            }
        }
        .onAppear {
            ensureValidSelection()
            generateQRCode()
        }
        .onChange(of: selectedSymbol) { _ in
            ensureValidNetworkForSelectedAsset()
            generateQRCode()
        }
        .onChange(of: selectedNetwork) { _ in
            generateQRCode()
        }
        .onChange(of: walletManager.visibleSupportedTokens.map { "\($0.blockchain.rawValue):\($0.contractAddress ?? "native")" }) { _ in
            ensureValidSelection()
            generateQRCode()
        }
    }

    private var currentTokenAddress: String? {
        guard let token = selectedToken else { return nil }
        let address = walletManager.depositAddress(for: token)
        return address.isEmpty ? nil : address
    }

    private var availableTokensWithNetwork: [Token] {
        // Get all supported tokens that are on enabled networks, including zero-balance supported assets.
        let filtered = walletManager.visibleSupportedTokens.filter { token in
            let tokenBlockchainPlatform = BlockchainPlatform(rawValue: token.blockchain.rawValue) ?? .ethereum
            guard walletManager.selectedBlockchains.contains(tokenBlockchainPlatform) else {
                return false
            }
            return walletManager.availableBlockchains.contains { config in
                config.platform == tokenBlockchainPlatform && config.network == .mainnet
            } && walletManager.hasActiveAccount(for: token.blockchain)
        }
        
        // Sort by symbol first, then by blockchain
        let sorted = filtered.sorted { token1, token2 in
            if token1.symbol == token2.symbol {
                return token1.blockchain.name < token2.blockchain.name
            }
            return token1.symbol < token2.symbol
        }
        
        return sorted
    }

    private func ensureValidSelection() {
        guard !availableTokensWithNetwork.isEmpty else {
            selectedSymbol = nil
            selectedNetwork = nil
            return
        }

        let symbols = availableAssetSymbols
        if selectedSymbol == nil || !symbols.contains(selectedSymbol ?? "") {
            selectedSymbol = symbols.first
        }
        ensureValidNetworkForSelectedAsset()
    }

    private var availableAssetSymbols: [String] {
        Array(Set(availableTokensWithNetwork.map { $0.symbol.uppercased() })).sorted()
    }

    private func ensureValidNetworkForSelectedAsset() {
        guard let selectedSymbol else { return }
        let networks = availableTokensWithNetwork
            .filter { $0.symbol.uppercased() == selectedSymbol.uppercased() }
            .map { $0.blockchain }

        if selectedNetwork == nil || !networks.contains(selectedNetwork!) {
            selectedNetwork = networks.first
        }
    }

    private func generateQRCode() {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        guard let address = currentTokenAddress else {
            qrCodeImage = nil
            return
        }

        filter.message = Data(address.utf8)

        if let outputImage = filter.outputImage {
            let scaleX = 200 / outputImage.extent.size.width
            let scaleY = 200 / outputImage.extent.size.height
            let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                qrCodeImage = UIImage(cgImage: cgImage)
            }
        }
    }
}

struct MissingDepositAddressView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wallet.pass")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(WpayinColors.textSecondary)

            Text("Wallet address not available".localized)
                .font(.wpayinSubheadline)
                .foregroundColor(WpayinColors.text)

            Text("Create or import a wallet for this network before receiving funds.".localized)
                .font(.wpayinBody)
                .foregroundColor(WpayinColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(WpayinColors.surface)
        .cornerRadius(12)
    }
}

struct AssetNetworkSelector: View {
    @Binding var selectedSymbol: String?
    @Binding var selectedNetwork: BlockchainType?
    let availableTokens: [Token]
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var settingsManager: SettingsManager

    private var selectedToken: Token? {
        guard let selectedSymbol, let selectedNetwork else { return nil }
        return availableTokens.first {
            $0.symbol.uppercased() == selectedSymbol.uppercased() && $0.blockchain == selectedNetwork
        }
    }

    private var assetSymbols: [String] {
        Array(Set(availableTokens.map { $0.symbol.uppercased() })).sorted()
    }

    private var networksForSelectedAsset: [Token] {
        guard let selectedSymbol else { return [] }
        return availableTokens
            .filter { $0.symbol.uppercased() == selectedSymbol.uppercased() }
            .sorted { $0.blockchain.name < $1.blockchain.name }
    }

    private func groupedToken(for symbol: String) -> Token? {
        let symbolTokens = availableTokens.filter { $0.symbol.uppercased() == symbol.uppercased() }
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
            // Header with balance
            HStack {
                Text("Select Asset".localized)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(WpayinColors.textSecondary)
                
                Spacer()
                
                if let token = selectedToken {
                    HStack(spacing: 8) {
                        Text("Balance: %@".localized(TokenIconHelper.formattedBalance(token.balance)))
                            .font(.system(size: 12))
                            .foregroundColor(WpayinColors.textSecondary)
                    }
                }
            }

            // Token Selector Button (styled like Swap)
            Menu {
                ForEach(assetSymbols, id: \.self) { symbol in
                    Button(action: {
                        selectedSymbol = symbol
                    }) {
                        let token = groupedToken(for: symbol)
                        HStack {
                            if let token {
                                TokenIconView(token: token, size: 20, showNetworkBadge: false)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(token?.name ?? symbol)
                                    .font(.system(size: 14, weight: .medium))
                                    .lineLimit(1)
                                Text("\(TokenIconHelper.formattedBalance(token?.balance ?? 0)) \(symbol)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if let token {
                                Text(token.totalValue.formatted(as: settingsManager.selectedCurrency))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    if let token = selectedToken {
                        TokenIconView(token: token, size: 36, showNetworkBadge: false)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(token.symbol)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(WpayinColors.text)
                                    .lineLimit(1)

                                Text(token.name)
                                    .font(.system(size: 12))
                                    .foregroundColor(WpayinColors.textTertiary)
                                    .lineLimit(1)
                            }
                            
                            Text(TokenIconHelper.formattedBalanceWithSymbol(token.balance, symbol: token.symbol))
                                .font(.system(size: 12))
                                .foregroundColor(WpayinColors.textSecondary)
                                .lineLimit(1)
                        }
                    } else {
                        Text("Select Token".localized)
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

            if !networksForSelectedAsset.isEmpty {
                Text("Select Network".localized)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(WpayinColors.textSecondary)

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
                    HStack(spacing: 12) {
                        if let token = selectedToken {
                            NetworkIconView(blockchain: token.blockchain, size: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(token.blockchain.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(WpayinColors.text)
                                Text(TokenIconHelper.formattedBalanceWithSymbol(token.balance, symbol: token.symbol))
                                    .font(.system(size: 12))
                                    .foregroundColor(WpayinColors.textSecondary)
                            }
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
            }
        }
    }
}



struct QRCodeView: View {
    let address: String
    @Binding var qrCodeImage: UIImage?

    var body: some View {
        VStack(spacing: 16) {
            Text("QR Code".localized)
                .font(.wpayinSubheadline)
                .foregroundColor(WpayinColors.text)

            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .frame(width: 220, height: 220)

                if let qrImage = qrCodeImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 180, height: 180)
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: WpayinColors.primary))
                }
            }
        }
    }
}

struct AddressDisplayView: View {
    let address: String
    @Binding var copied: Bool

    var body: some View {
        VStack(spacing: 12) {
            Text("Wallet Address".localized)
                .font(.wpayinSubheadline)
                .foregroundColor(WpayinColors.text)

            VStack(spacing: 12) {
                Text(address)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(WpayinColors.text)
                    .multilineTextAlignment(.center)
                    .padding(16)
                    .background(WpayinColors.surface)
                    .cornerRadius(12)

                WpayinButton(
                    title: copied ? "Copied!".localized : "Copy Address".localized,
                    style: .secondary
                ) {
                    UIPasteboard.general.string = address
                    copied = true

                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copied = false
                    }
                }
            }
        }
    }
}

struct InstructionsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How to Deposit".localized)
                .font(.wpayinSubheadline)
                .foregroundColor(WpayinColors.text)

            VStack(alignment: .leading, spacing: 12) {
                InstructionStep(
                    number: "1",
                    text: "Copy the wallet address above or scan the QR code"
                )

                InstructionStep(
                    number: "2",
                    text: "Send funds from your exchange or other wallet to this address"
                )

                InstructionStep(
                    number: "3",
                    text: "Wait for the transaction to be confirmed on the blockchain"
                )

                InstructionStep(
                    number: "4",
                    text: "Your funds will appear in your wallet shortly"
                )
            }
        }
    }
}

struct InstructionStep: View {
    let number: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.wpayinBody)
                .foregroundColor(WpayinColors.primary)
                .frame(width: 24, height: 24)
                .background(WpayinColors.primary.opacity(0.2))
                .clipShape(Circle())

            Text(text.localized)
                .font(.wpayinBody)
                .foregroundColor(WpayinColors.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct WarningView: View {
    let tokenSymbol: String
    let networkName: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(WpayinColors.error)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 4) {
                Text("Important".localized)
                    .font(.wpayinSubheadline)
                    .foregroundColor(WpayinColors.error)

                Text("Only send %@ on %@ network to this address. Sending wrong tokens or using wrong network may result in permanent loss.".localized(tokenSymbol, networkName))
                    .font(.wpayinCaption)
                    .foregroundColor(WpayinColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(16)
        .background(WpayinColors.surface)
        .cornerRadius(12)
    }
}



#Preview {
    DepositView()
        .environmentObject(WalletManager())
        .environmentObject(SettingsManager())
}
