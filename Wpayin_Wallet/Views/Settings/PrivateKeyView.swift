// Autor Lukas Helebrandt, 2026

//
//  PrivateKeyView.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI
import WalletCore

struct PrivateKeyView: View {
    @EnvironmentObject var walletManager: WalletManager
    @Environment(\.dismiss) private var dismiss
    @State private var isRevealed = false
    @State private var showWarning = true
    @State private var privateKeys: [ExportedPrivateKey] = []
    @State private var micaAccepted = false

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        if showWarning {
                            // Warning
                            VStack(spacing: 24) {
                                Image(systemName: "exclamationmark.shield.fill")
                                    .font(.system(size: 64))
                                    .foregroundColor(WpayinColors.error)

                                VStack(spacing: 12) {
                                    Text(L10n.Security.legalNotice.localized)
                                        .font(.wpayinHeadline)
                                        .foregroundColor(WpayinColors.text)
                                        .multilineTextAlignment(.center)

                                    Text(L10n.Security.warning.localized)
                                        .font(.wpayinBody)
                                        .foregroundColor(WpayinColors.textSecondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.bottom, 10)

                                // MiCA Acceptance Checkbox
                                Button(action: {
                                    withAnimation(.spring()) {
                                        micaAccepted.toggle()
                                    }
                                }) {
                                    HStack(alignment: .top, spacing: 14) {
                                        Image(systemName: micaAccepted ? "checkmark.square.fill" : "square")
                                            .font(.system(size: 24))
                                            .foregroundColor(micaAccepted ? WpayinColors.primary : WpayinColors.textSecondary)
                                        
                                        Text(L10n.Security.micaAgreement.localized)
                                            .font(.wpayinCaption)
                                            .foregroundColor(WpayinColors.textSecondary)
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .padding(16)
                                    .background(WpayinColors.surface)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(micaAccepted ? WpayinColors.primary.opacity(0.5) : Color.clear, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())

                                HoldToRevealButton(
                                    title: L10n.Action.understand.localized,
                                    style: .primary,
                                    isEnabled: micaAccepted
                                ) {
                                    showWarning = false
                                    loadPrivateKey()
                                }
                                .opacity(micaAccepted ? 1.0 : 0.5)
                            }
                            .padding(.horizontal, 24)
                        } else {
                            // Private Key Display
                            VStack(spacing: 24) {
                                Text(L10n.Security.yourKey.localized)
                                    .font(.wpayinHeadline)
                                    .foregroundColor(WpayinColors.text)

                                if isRevealed {
                                    if !privateKeys.isEmpty {
                                        VStack(spacing: 16) {
                                            ForEach(privateKeys) { exportedKey in
                                                VStack(alignment: .leading, spacing: 12) {
                                                    HStack(spacing: 10) {
                                                        NetworkIconView(blockchain: exportedKey.blockchain, size: 28)

                                                        VStack(alignment: .leading, spacing: 2) {
                                                            Text(exportedKey.blockchain.name)
                                                                .font(.system(size: 15, weight: .semibold))
                                                                .foregroundColor(WpayinColors.text)

                                                            Text(exportedKey.address)
                                                                .font(.system(size: 11, design: .monospaced))
                                                                .foregroundColor(WpayinColors.textSecondary)
                                                                .lineLimit(1)
                                                                .truncationMode(.middle)
                                                        }

                                                        Spacer()
                                                    }

                                                    Text(exportedKey.privateKey)
                                                        .font(.system(size: 13, design: .monospaced))
                                                        .foregroundColor(WpayinColors.text)
                                                        .multilineTextAlignment(.leading)
                                                        .padding(14)
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                        .background(WpayinColors.background)
                                                        .cornerRadius(12)
                                                        .textSelection(.enabled)

                                                    WpayinButton(
                                                        title: L10n.Action.copy.localized,
                                                        style: .secondary
                                                    ) {
                                                        AppToast.copyToClipboard(exportedKey.privateKey)
                                                    }
                                                }
                                                .padding(16)
                                                .background(WpayinColors.surface)
                                                .cornerRadius(16)
                                            }
                                        }
                                    } else {
                                        VStack(spacing: 16) {
                                            Image(systemName: "exclamationmark.triangle")
                                                .font(.system(size: 32))
                                                .foregroundColor(WpayinColors.error)

                                            Text(L10n.Security.notAvailable.localized)
                                                .font(.wpayinBody)
                                                .foregroundColor(WpayinColors.text)

                                            Text(L10n.Security.mnemonicWarning.localized)
                                                .font(.wpayinCaption)
                                                .foregroundColor(WpayinColors.textSecondary)
                                                .multilineTextAlignment(.center)
                                        }
                                        .padding(.vertical, 32)
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                    .padding(.top, 40)
                }
            }
            .navigationTitle(L10n.Settings.showPrivateKey.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.Action.close.localized) {
                        dismiss()
                    }
                    .foregroundColor(WpayinColors.text)
                }
            }
        }
    }

    private func loadPrivateKey() {
        // Try to get private key from keychain (for wallets imported via private key)
        if let key = walletManager.keychain.getPrivateKey() {
            privateKeys = [
                ExportedPrivateKey(
                    blockchain: .ethereum,
                    address: walletManager.walletAddress,
                    privateKey: key
                )
            ]
            isRevealed = true
            Logger.log("✅ Loaded private key from keychain")
            return
        }

        // Try to derive private key from mnemonic (for wallets created with seed phrase)
        if let mnemonic = walletManager.keychain.getSeedPhrase() {
            do {
                let mnemonicService = MnemonicService()
                let wallet = try mnemonicService.loadWallet(from: mnemonic)

                privateKeys = exportPrivateKeys(from: wallet)
                isRevealed = true
                Logger.log("✅ Derived \(privateKeys.count) private keys from mnemonic")
            } catch {
                Logger.log("❌ Failed to load wallet from mnemonic: \(error)")
                privateKeys = []
                isRevealed = true
            }
            return
        }

        // No wallet found
        Logger.log("⚠️ No private key or mnemonic found")
        privateKeys = []
        isRevealed = true
    }

    private func exportPrivateKeys(from wallet: HDWallet) -> [ExportedPrivateKey] {
        let supportedBlockchains = walletManager.availableBlockchains
            .filter { $0.network == .mainnet }
            .compactMap { $0.blockchainType }
            .filter { blockchain in
                blockchain.isEVM || blockchain == .bitcoin || blockchain == .solana
            }

        let uniqueBlockchains = Array(Set(supportedBlockchains)).sorted {
            privateKeySortPriority($0) < privateKeySortPriority($1)
        }

        return uniqueBlockchains.compactMap { blockchain in
            guard let coinType = blockchain.coinType else { return nil }
            let key = wallet.getKeyForCoin(coin: coinType)
            let address = walletManager.availableChainAccounts[blockchain]?.address
                ?? coinType.deriveAddress(privateKey: key).description

            return ExportedPrivateKey(
                blockchain: blockchain,
                address: address,
                privateKey: "0x" + key.data.hexString
            )
        }
    }

    private func privateKeySortPriority(_ blockchain: BlockchainType) -> Int {
        switch blockchain {
        case .ethereum: return 0
        case .bitcoin: return 1
        case .solana: return 2
        case .polygon: return 3
        case .bsc: return 4
        case .arbitrum: return 5
        case .optimism: return 6
        case .base: return 7
        case .avalanche: return 8
        default: return 99
        }
    }
}

private struct ExportedPrivateKey: Identifiable {
    let id = UUID()
    let blockchain: BlockchainType
    let address: String
    let privateKey: String
}

// MARK: - Hold To Reveal Button

struct HoldToRevealButton: View {
    let title: String
    let style: WpayinButton.ButtonStyle
    var isEnabled: Bool = true
    let onComplete: () -> Void
    
    @State private var progress: CGFloat = 0
    @State private var isPressing = false
    @State private var timer: Timer?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 16)
                    .fill(WpayinColors.surface)
                
                // Progress Fill
                RoundedRectangle(cornerRadius: 16)
                    .fill(WpayinColors.primary.opacity(0.3))
                    .frame(width: progress * geometry.size.width)
                
                // Border
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isPressing ? WpayinColors.primary : WpayinColors.surfaceBorder, lineWidth: 2)
                
                // Text
                Text(title.localized)
                    .font(.wpayinHeadline)
                    .foregroundColor(isEnabled ? WpayinColors.text : WpayinColors.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 56)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard isEnabled else { return }
                    if !isPressing {
                        startPressing()
                    }
                }
                .onEnded { _ in
                    stopPressing()
                }
        )
        .animation(.linear(duration: 0.1), value: progress)
    }
    
    private func startPressing() {
        isPressing = true
        progress = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            if progress < 1.0 {
                progress += 0.01
            } else {
                stopPressing()
                onComplete()
            }
        }
    }
    
    private func stopPressing() {
        isPressing = false
        timer?.invalidate()
        timer = nil
        if progress < 1.0 {
            withAnimation(.easeOut) {
                progress = 0
            }
        }
    }
}

#Preview {
    PrivateKeyView()
        .environmentObject(WalletManager())
}
