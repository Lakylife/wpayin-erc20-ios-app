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
                WalletFlowBackground()

                ScrollView {
                    LazyVStack(spacing: 20) {
                        VStack(spacing: 12) {
                            Image(systemName: "arrow.down")
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

                            Text("Deposit Funds".localized)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(WpayinColors.text)

                            Text("Send funds to your %@ address".localized(selectedToken?.symbol ?? "Token"))
                                .font(.system(size: 14))
                                .foregroundColor(WpayinColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.bottom, 2)

                        AssetNetworkSelector(
                            selectedSymbol: $selectedSymbol,
                            selectedNetwork: $selectedNetwork,
                            availableTokens: availableTokensWithNetwork
                        )
                        .environmentObject(walletManager)
                        .environmentObject(settingsManager)

                        if let tokenAddress = currentTokenAddress, !tokenAddress.isEmpty {
                            VStack(spacing: 20) {
                                QRCodeView(
                                    address: tokenAddress,
                                    qrCodeImage: $qrCodeImage
                                )

                                AddressDisplayView(
                                    address: tokenAddress,
                                    copied: $addressCopied
                                )
                            }
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(WpayinColors.surface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                                            .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                                    )
                            )
                        } else {
                            MissingDepositAddressView()
                        }

                        InstructionsView()

                        if let token = selectedToken {
                            WarningView(
                                tokenSymbol: token.symbol,
                                networkName: token.blockchain.name
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Deposit".localized)
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
                    .accessibilityLabel(L10n.Action.close.localized)
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
            // Ethereum is the sensible default, not the alphabetical winner.
            selectedSymbol = symbols.contains("ETH") ? "ETH" : symbols.first
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
            selectedNetwork = networks.contains(.ethereum) ? .ethereum : networks.first
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
        .padding(20)
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

struct AssetNetworkSelector: View {
    @Binding var selectedSymbol: String?
    @Binding var selectedNetwork: BlockchainType?
    let availableTokens: [Token]
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var showAssetPicker = false
    @State private var showNetworkPicker = false

    private var selectedToken: Token? {
        guard let selectedSymbol, let selectedNetwork else { return nil }
        return availableTokens.first {
            $0.symbol.uppercased() == selectedSymbol.uppercased() && $0.blockchain == selectedNetwork
        }
    }

    private var networksForSelectedAsset: [Token] {
        guard let selectedSymbol else { return [] }
        return availableTokens
            .filter { $0.symbol.uppercased() == selectedSymbol.uppercased() }
            .sorted { $0.blockchain.name < $1.blockchain.name }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Select Asset".localized)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(WpayinColors.text)

                Spacer()

                if let token = selectedToken {
                    HStack(spacing: 8) {
                        Text("Balance: %@".localized(TokenIconHelper.formattedBalance(token.balance)))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(WpayinColors.textSecondary)
                    }
                }
            }

            Button {
                showAssetPicker = true
            } label: {
                HStack(spacing: 12) {
                    if let token = selectedToken {
                        TokenIconView(token: token, size: 40, showNetworkBadge: false)

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

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(WpayinColors.textTertiary)
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

            if !networksForSelectedAsset.isEmpty {
                Text("Select Network".localized)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(WpayinColors.textSecondary)

                Button {
                    showNetworkPicker = true
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
                tokens: availableTokens,
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



struct QRCodeView: View {
    let address: String
    @Binding var qrCodeImage: UIImage?

    var body: some View {
        VStack(spacing: 14) {
            Text("QR Code".localized)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(WpayinColors.textSecondary)

            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white)
                    .frame(width: 204, height: 204)
                    .shadow(color: WpayinColors.primary.opacity(0.14), radius: 18, x: 0, y: 8)

                if let qrImage = qrCodeImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 168, height: 168)
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
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(WpayinColors.text)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(WpayinColors.surfaceLight)
                    )

                WpayinButton(
                    title: copied ? "Copied!".localized : "Copy Address".localized,
                    style: .secondary
                ) {
                    AppToast.copyToClipboard(address)
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
        .padding(20)
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

struct InstructionStep: View {
    let number: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(WpayinColors.primary)
                .frame(width: 26, height: 26)
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
                .foregroundColor(WpayinColors.warning)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 4) {
                Text("Important".localized)
                    .font(.wpayinSubheadline)
                    .foregroundColor(WpayinColors.warning)

                Text("Only send %@ on %@ network to this address. Sending wrong tokens or using wrong network may result in permanent loss.".localized(tokenSymbol, networkName))
                    .font(.wpayinCaption)
                    .foregroundColor(WpayinColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(WpayinColors.warning.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(WpayinColors.warning.opacity(0.20), lineWidth: 1)
                )
        )
    }
}



#Preview {
    DepositView()
        .environmentObject(WalletManager())
        .environmentObject(SettingsManager())
}
