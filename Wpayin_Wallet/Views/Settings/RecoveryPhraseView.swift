//
//  RecoveryPhraseView.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI

struct RecoveryPhraseView: View {
    @EnvironmentObject var walletManager: WalletManager
    @Environment(\.dismiss) private var dismiss
    @State private var isRevealed = false
    @State private var showWarning = true
    @State private var recoveryPhrase: String?
    @State private var copied = false

    private var mnemonicWords: [String] {
        guard let phrase = recoveryPhrase else { return [] }
        return phrase.components(separatedBy: " ")
    }

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
                                    Text("Keep Your Recovery Phrase Safe")
                                        .font(.wpayinHeadline)
                                        .foregroundColor(WpayinColors.text)
                                        .multilineTextAlignment(.center)

                                    Text("Never share your recovery phrase with anyone. Anyone with access to your recovery phrase can steal your funds.")
                                        .font(.wpayinBody)
                                        .foregroundColor(WpayinColors.textSecondary)
                                        .multilineTextAlignment(.center)
                                }

                                WpayinButton(
                                    title: "I Understand",
                                    style: .primary
                                ) {
                                    showWarning = false
                                    loadRecoveryPhrase()
                                }
                            }
                            .padding(.horizontal, 24)
                        } else {
                            // Recovery Phrase Display
                            if recoveryPhrase != nil {
                                VStack(spacing: 24) {
                                    VStack(spacing: 16) {
                                        Text("Your Recovery Phrase")
                                            .font(.wpayinHeadline)
                                            .foregroundColor(WpayinColors.text)

                                        Text("Write down these 12 words in the exact order shown. This phrase is the only way to recover your wallet.")
                                            .font(.wpayinBody)
                                            .foregroundColor(WpayinColors.textSecondary)
                                            .multilineTextAlignment(.center)
                                    }

                                    // Warning Box
                                    HStack(spacing: 12) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(WpayinColors.error)
                                            .font(.system(size: 20))

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Keep it secure!")
                                                .font(.wpayinSubheadline)
                                                .foregroundColor(WpayinColors.error)

                                            Text("Never share your recovery phrase with anyone. Store it in a safe place.")
                                                .font(.wpayinCaption)
                                                .foregroundColor(WpayinColors.textSecondary)
                                        }

                                        Spacer()
                                    }
                                    .padding(16)
                                    .background(WpayinColors.surface)
                                    .cornerRadius(12)

                                    // Mnemonic Display
                                    VStack(spacing: 16) {
                                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                                            ForEach(Array(mnemonicWords.enumerated()), id: \.offset) { index, word in
                                                HStack {
                                                    Text("\(index + 1).")
                                                        .font(.wpayinCaption)
                                                        .foregroundColor(WpayinColors.textSecondary)
                                                        .frame(width: 20, alignment: .leading)

                                                    Text(word)
                                                        .font(.wpayinBody)
                                                        .foregroundColor(WpayinColors.text)

                                                    Spacer()
                                                }
                                                .padding(.vertical, 12)
                                                .padding(.horizontal, 16)
                                                .background(WpayinColors.surfaceLight)
                                                .cornerRadius(8)
                                                .blur(radius: isRevealed ? 0 : 4)
                                            }
                                        }

                                        // Reveal/Hide Button
                                        WpayinButton(
                                            title: isRevealed ? "Hide" : "Tap to Reveal",
                                            style: .secondary
                                        ) {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                isRevealed.toggle()
                                            }
                                        }
                                    }
                                    .padding(20)
                                    .background(WpayinColors.surface)
                                    .cornerRadius(16)

                                    // Copy Button
                                    WpayinButton(
                                        title: copied ? "Copied!" : "Copy to Clipboard",
                                        style: .tertiary
                                    ) {
                                        copyToClipboard()
                                    }
                                    .disabled(!isRevealed)
                                }
                                .padding(.horizontal, 24)
                            } else {
                                // No recovery phrase available
                                VStack(spacing: 16) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.system(size: 32))
                                        .foregroundColor(WpayinColors.error)

                                    Text("Recovery Phrase Not Available")
                                        .font(.wpayinBody)
                                        .foregroundColor(WpayinColors.text)

                                    Text("This wallet was imported using a private key. Recovery phrase is only available for wallets created with a seed phrase.")
                                        .font(.wpayinCaption)
                                        .foregroundColor(WpayinColors.textSecondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 32)
                            }
                        }
                    }
                    .padding(.top, 40)
                }
            }
            .navigationTitle("Recovery Phrase")
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

    private func loadRecoveryPhrase() {
        if let mnemonic = walletManager.keychain.getSeedPhrase() {
            recoveryPhrase = mnemonic
            print("✅ Loaded recovery phrase from keychain")
        } else {
            print("⚠️ No recovery phrase found - wallet might be imported via private key")
            recoveryPhrase = nil
        }
    }

    private func copyToClipboard() {
        guard let phrase = recoveryPhrase else { return }
        UIPasteboard.general.string = phrase
        copied = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copied = false
        }
    }
}

#Preview {
    RecoveryPhraseView()
        .environmentObject(WalletManager())
}
