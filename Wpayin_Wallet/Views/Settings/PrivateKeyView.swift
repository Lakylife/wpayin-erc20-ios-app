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
    @State private var privateKey: String?

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        if showWarning {
                            // Warning
                            VStack(spacing: 20) {
                                Image(systemName: "key.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(WpayinColors.error)

                                VStack(spacing: 12) {
                                    Text("Keep Your Private Key Safe")
                                        .font(.wpayinHeadline)
                                        .foregroundColor(WpayinColors.text)
                                        .multilineTextAlignment(.center)

                                    Text("Never share your private key with anyone. Anyone with access to your private key can steal your funds.")
                                        .font(.wpayinBody)
                                        .foregroundColor(WpayinColors.textSecondary)
                                        .multilineTextAlignment(.center)
                                }

                                WpayinButton(
                                    title: "I Understand",
                                    style: .primary
                                ) {
                                    showWarning = false
                                    loadPrivateKey()
                                }
                            }
                            .padding(.horizontal, 24)
                        } else {
                            // Private Key Display
                            VStack(spacing: 24) {
                                Text("Your Private Key")
                                    .font(.wpayinHeadline)
                                    .foregroundColor(WpayinColors.text)

                                if isRevealed {
                                    if let privateKey = privateKey {
                                        VStack(spacing: 16) {
                                            Text(privateKey)
                                                .font(.system(size: 14, design: .monospaced))
                                                .foregroundColor(WpayinColors.text)
                                                .multilineTextAlignment(.leading)
                                                .padding(20)
                                                .background(WpayinColors.surface)
                                                .cornerRadius(16)
                                                .textSelection(.enabled)

                                            WpayinButton(
                                                title: "Copy to Clipboard",
                                                style: .secondary
                                            ) {
                                                UIPasteboard.general.string = privateKey
                                            }
                                        }
                                    } else {
                                        VStack(spacing: 16) {
                                            Image(systemName: "exclamationmark.triangle")
                                                .font(.system(size: 32))
                                                .foregroundColor(WpayinColors.error)

                                            Text("Private Key Not Available")
                                                .font(.wpayinBody)
                                                .foregroundColor(WpayinColors.text)

                                            Text("This wallet was created with a recovery phrase. Private key export is not available for mnemonic-based wallets.")
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
            .navigationTitle("Private Key")
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
    }

    private func loadPrivateKey() {
        // Try to get private key from keychain (for wallets imported via private key)
        if let key = walletManager.keychain.getPrivateKey() {
            privateKey = key
            isRevealed = true
            print("✅ Loaded private key from keychain")
            return
        }

        // Try to derive private key from mnemonic (for wallets created with seed phrase)
        if let mnemonic = walletManager.keychain.getSeedPhrase() {
            do {
                let mnemonicService = MnemonicService()
                let wallet = try mnemonicService.loadWallet(from: mnemonic)

                // Get Ethereum private key (most common use case)
                let ethereumKey = wallet.getKeyForCoin(coin: .ethereum)
                privateKey = "0x" + ethereumKey.data.hexString
                isRevealed = true
                print("✅ Derived private key from mnemonic")
            } catch {
                print("❌ Failed to load wallet from mnemonic: \(error)")
                privateKey = nil
                isRevealed = true
            }
            return
        }

        // No wallet found
        print("⚠️ No private key or mnemonic found")
        privateKey = nil
        isRevealed = true
    }
}

#Preview {
    PrivateKeyView()
        .environmentObject(WalletManager())
}