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
    @State private var selectedToken: Token?
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

                            Text("Send funds to your \(selectedToken?.symbol ?? "Token") address")
                                .font(.wpayinBody)
                                .foregroundColor(WpayinColors.textSecondary)
                        }

                        // Token Selector with Network Info
                        TokenNetworkSelector(
                            selectedToken: $selectedToken,
                            availableTokens: availableTokensWithNetwork
                        )
                        .environmentObject(walletManager)
                        .environmentObject(settingsManager)

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
            // Select first available token
            if selectedToken == nil && !availableTokensWithNetwork.isEmpty {
                selectedToken = availableTokensWithNetwork.first
            }
            generateQRCode()
        }
        .onChange(of: selectedToken?.id) { _ in
            generateQRCode()
        }
        .onChange(of: walletManager.visibleTokens.map { $0.id }) { _ in
            generateQRCode()
        }
    }

    private var currentTokenAddress: String? {
        guard let token = selectedToken else { return nil }
        
        // Convert BlockchainType to BlockchainPlatform
        let tokenBlockchainPlatform = BlockchainPlatform(rawValue: token.blockchain.rawValue) ?? .ethereum
        
        // Find the blockchain config for this token's blockchain
        let config = walletManager.availableBlockchains.first { config in
            config.platform == tokenBlockchainPlatform && config.network == .mainnet && config.isEnabled
        }
        
        guard let foundConfig = config else { return nil }

        // Get the account for this blockchain
        guard let blockchainType = foundConfig.blockchainType else { return nil }
        return walletManager.availableChainAccounts[blockchainType]?.address
    }

    private var availableTokensWithNetwork: [Token] {
        // Get all tokens that are on enabled networks
        let filtered = walletManager.visibleTokens.filter { token in
            let tokenBlockchainPlatform = BlockchainPlatform(rawValue: token.blockchain.rawValue) ?? .ethereum
            return walletManager.availableBlockchains.contains { config in
                config.platform == tokenBlockchainPlatform && config.network == .mainnet && config.isEnabled
            }
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

struct TokenNetworkSelector: View {
    @Binding var selectedToken: Token?
    let availableTokens: [Token]
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with balance
            HStack {
                Text("Select Asset & Network")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(WpayinColors.textSecondary)
                
                Spacer()
                
                if let token = selectedToken {
                    HStack(spacing: 8) {
                        Text("Balance: \(String(format: "%.4f", token.balance))")
                            .font(.system(size: 12))
                            .foregroundColor(WpayinColors.textSecondary)
                    }
                }
            }

            // Token Selector Button (styled like Swap)
            Menu {
                ForEach(availableTokens) { token in
                    Button(action: {
                        selectedToken = token
                    }) {
                        let tokenPlatform = BlockchainPlatform(rawValue: token.blockchain.rawValue) ?? .ethereum
                        HStack {
                            // Network icon
                            Circle()
                                .fill(tokenPlatform.color)
                                .frame(width: 16, height: 16)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text("\(token.symbol)")
                                        .font(.system(size: 14, weight: .medium))
                                    if let proto = token.tokenProtocol {
                                        TokenProtocolBadge(tokenProtocol: proto, size: .small)
                                    }
                                    Text("- \(token.blockchain.name)")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                                Text("\(String(format: "%.4f", token.balance)) \(token.symbol)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(token.totalValue.formatted(as: settingsManager.selectedCurrency))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    if let token = selectedToken {
                        let tokenPlatform = BlockchainPlatform(rawValue: token.blockchain.rawValue) ?? .ethereum
                        
                        // Token icon with gradient
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [tokenPlatform.color, tokenPlatform.color.opacity(0.7)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                            .overlay(
                                Text(token.symbol.prefix(2))
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(token.symbol)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(WpayinColors.text)
                                
                                // Small network badge
                                Circle()
                                    .fill(tokenPlatform.color)
                                    .frame(width: 14, height: 14)
                                    .overlay(
                                        Image(systemName: tokenPlatform.iconName)
                                            .font(.system(size: 7, weight: .medium))
                                            .foregroundColor(.white)
                                    )
                            }
                            
                            Text(token.blockchain.name)
                                .font(.system(size: 12))
                                .foregroundColor(WpayinColors.textSecondary)
                                .lineLimit(1)
                        }
                    } else {
                        Text("Select Token")
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
        }
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
    let networkName: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(WpayinColors.error)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 4) {
                Text("Important")
                    .font(.wpayinSubheadline)
                    .foregroundColor(WpayinColors.error)

                Text("Only send \(tokenSymbol) on \(networkName) network to this address. Sending wrong tokens or using wrong network may result in permanent loss.")
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
        .environmentObject({
            let walletManager = WalletManager()
            walletManager.walletAddress = "0x742d35Cc6D06b73494d45e5d2b0542f2f"
            walletManager.tokens = Token.mockTokens
            return walletManager
        }())
        .environmentObject(SettingsManager())
}
