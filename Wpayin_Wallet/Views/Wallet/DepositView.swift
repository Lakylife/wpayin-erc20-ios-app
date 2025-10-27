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
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAsset = 0
    @State private var selectedBlockchain: BlockchainPlatform = .ethereum
    @State private var qrCodeImage: UIImage?
    @State private var addressCopied = false

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 16) {
                            Text("Deposit Funds")
                                .font(.wpayinHeadline)
                                .foregroundColor(WpayinColors.text)

                            Text("Send funds to your \(selectedAssetSymbol) address")
                                .font(.wpayinBody)
                                .foregroundColor(WpayinColors.textSecondary)
                        }

                        // Asset Selector
                        AssetSelector(
                            assets: availableAssets,
                            selectedIndex: $selectedAsset
                        )

                        // Blockchain Selector for selected asset
                        if !availableBlockchainsForAsset.isEmpty {
                            BlockchainSelectorView(
                                blockchains: availableBlockchainsForAsset,
                                selectedBlockchain: $selectedBlockchain
                            )
                        }

                        if let tokenAddress = currentTokenAddress {
                            QRCodeView(
                                address: tokenAddress,
                                qrCodeImage: $qrCodeImage
                            )

                            AddressDisplayView(
                                address: tokenAddress,
                                copied: $addressCopied
                            )
                        } else {
                            Text("No deposit address available for the selected asset.")
                                .font(.wpayinBody)
                                .foregroundColor(WpayinColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding()
                                .background(WpayinColors.surface)
                                .cornerRadius(12)
                        }

                        // Instructions
                        InstructionsView()

                        // Warning
                        WarningView(tokenSymbol: selectedAssetSymbol)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Deposit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(WpayinColors.text)
                }
            }
        }
        .onAppear {
            generateQRCode()
        }
        .onChange(of: selectedAsset) { _ in
            generateQRCode()
        }
        .onChange(of: selectedBlockchain) { _ in
            generateQRCode()
        }
        .onChange(of: walletManager.tokens.map { $0.id }) { _ in
            generateQRCode()
        }
    }

    private var currentTokenAddress: String? {
        // Find the blockchain config for the selected blockchain platform
        guard let config = walletManager.availableBlockchains.first(where: { config in
            config.platform == selectedBlockchain && config.network == .mainnet && config.isEnabled
        }) else { return nil }

        // Get the account for this blockchain
        guard let blockchainType = config.blockchainType else { return nil }
        return walletManager.availableChainAccounts[blockchainType]?.address
    }

    private var availableAssets: [String] {
        Array(Set(walletManager.groupedTokens.map { $0.symbol })).sorted()
    }

    private var selectedAssetSymbol: String {
        guard !availableAssets.isEmpty else { return "Token" }
        let validIndex = min(selectedAsset, availableAssets.count - 1)
        return availableAssets[validIndex]
    }

    private var availableBlockchainsForAsset: [BlockchainPlatform] {
        let symbol = selectedAssetSymbol
        switch symbol.uppercased() {
        case "ETH":
            return [.ethereum, .arbitrum, .optimism, .base]
        case "BTC":
            return [.bitcoin]
        case "MATIC":
            return [.polygon]
        case "BNB":
            return [.bsc]
        default:
            return [.ethereum]
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

struct AssetSelector: View {
    let assets: [String]
    @Binding var selectedIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Asset")
                .font(.wpayinSubheadline)
                .foregroundColor(WpayinColors.text)

            if !assets.isEmpty {
                let currentAsset = assets[min(selectedIndex, assets.count - 1)]
                Menu {
                    ForEach(Array(assets.enumerated()), id: \.offset) { index, asset in
                        Button(action: {
                            selectedIndex = index
                        }) {
                            Text(asset)
                        }
                    }
                } label: {
                    HStack {
                        Circle()
                            .fill(WpayinColors.primary)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text(currentAsset.prefix(1))
                                    .font(.wpayinCaption)
                                    .foregroundColor(.white)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(getAssetName(currentAsset))
                                .font(.wpayinBody)
                                .foregroundColor(WpayinColors.text)

                            Text(currentAsset)
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
                Text("No assets available")
                    .font(.wpayinCaption)
                    .foregroundColor(WpayinColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(WpayinColors.surface)
                    .cornerRadius(12)
            }
        }
    }

    private func getAssetName(_ symbol: String) -> String {
        switch symbol.uppercased() {
        case "ETH":
            return "Ethereum"
        case "BTC":
            return "Bitcoin"
        case "MATIC":
            return "Polygon"
        case "BNB":
            return "BNB Chain"
        case "AVAX":
            return "Avalanche"
        default:
            return symbol
        }
    }
}

struct TokenSelectorItem: View {
    let token: Token
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .fill(isSelected ? WpayinColors.primary : WpayinColors.surfaceLight)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(token.symbol.prefix(1))
                            .font(.wpayinBody)
                            .foregroundColor(isSelected ? .white : WpayinColors.text)
                    )

                Text(token.symbol)
                    .font(.wpayinBody)
                    .foregroundColor(isSelected ? WpayinColors.primary : WpayinColors.text)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? WpayinColors.primary.opacity(0.1) : WpayinColors.surface)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? WpayinColors.primary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct QRCodeView: View {
    let address: String
    @Binding var qrCodeImage: UIImage?

    var body: some View {
        VStack(spacing: 16) {
            Text("QR Code")
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
            Text("Wallet Address")
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
                    title: copied ? "Copied!" : "Copy Address",
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
            Text("How to Deposit")
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

            Text(text)
                .font(.wpayinBody)
                .foregroundColor(WpayinColors.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct WarningView: View {
    let tokenSymbol: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(WpayinColors.error)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 4) {
                Text("Important")
                    .font(.wpayinSubheadline)
                    .foregroundColor(WpayinColors.error)

                Text("Only send \(tokenSymbol) on its native network to this address. Sending other cryptocurrencies may result in permanent loss.")
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

struct BlockchainSelectorView: View {
    let blockchains: [BlockchainPlatform]
    @Binding var selectedBlockchain: BlockchainPlatform

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Blockchain")
                .font(.wpayinSubheadline)
                .foregroundColor(WpayinColors.text)

            if !blockchains.isEmpty {
                Menu {
                    ForEach(blockchains, id: \.self) { blockchain in
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
                            .frame(width: 20, height: 20)
                            .overlay(
                                Image(systemName: selectedBlockchain.iconName)
                                    .font(.system(size: 10, weight: .medium))
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
}

#Preview {
    DepositView()
        .environmentObject({
            let walletManager = WalletManager()
            walletManager.walletAddress = "0x742d35Cc6D06b73494d45e5d2b0542f2f"
            return walletManager
        }())
}
