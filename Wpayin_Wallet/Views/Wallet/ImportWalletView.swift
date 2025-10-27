//
//  ImportWalletView.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI

struct ImportWalletView: View {
    @EnvironmentObject var walletManager: WalletManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var mnemonicText = ""
    @State private var privateKeyText = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isImporting = false

    private let tabs = ["Recovery Phrase", "Private Key"]

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Tab Selector
                    TabSelector(selectedTab: $selectedTab, tabs: tabs)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)

                    ScrollView {
                        VStack(spacing: 32) {
                            VStack(spacing: 16) {
                                Text("Import Your Wallet")
                                    .font(.wpayinHeadline)
                                    .foregroundColor(WpayinColors.text)

                                Text(selectedTab == 0 ?
                                    "Enter your 12-word recovery phrase to restore your wallet." :
                                    "Enter your private key to import your wallet.")
                                    .font(.wpayinBody)
                                    .foregroundColor(WpayinColors.textSecondary)
                                    .multilineTextAlignment(.center)
                            }

                            if selectedTab == 0 {
                                MnemonicInput(text: $mnemonicText)
                            } else {
                                PrivateKeyInput(text: $privateKeyText)
                            }

                            // Security Notice
                            SecurityNotice()
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 40)
                    }

                    Spacer()

                    // Import Button
                    VStack(spacing: 12) {
                        WpayinButton(
                            title: isImporting ? "Importing..." : "Import Wallet",
                            style: .primary
                        ) {
                            importWallet()
                        }
                        .disabled(!canImport || isImporting)

                        WpayinButton(
                            title: "Cancel",
                            style: .tertiary
                        ) {
                            dismiss()
                        }
                        .disabled(isImporting)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Import Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(WpayinColors.text)
                    .disabled(isImporting)
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private var canImport: Bool {
        if selectedTab == 0 {
            let cleaned = mnemonicText
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            return walletManager.validateMnemonic(cleaned)
        } else {
            let key = privateKeyText.trimmingCharacters(in: .whitespacesAndNewlines)
            return walletManager.validatePrivateKey(key)
        }
    }

    private func importWallet() {
        isImporting = true

        Task {
            let success: Bool
            if selectedTab == 0 {
                success = await importWithMnemonic()
            } else {
                success = await importWithPrivateKey()
            }

            await MainActor.run {
                isImporting = false
                if success {
                    dismiss()
                } else {
                    errorMessage = "Failed to import wallet. Please check your input and try again."
                    showError = true
                }
            }
        }
    }

    private func importWithMnemonic() async -> Bool {
        let cleanedMnemonic = mnemonicText.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return walletManager.importWalletWithMnemonic(cleanedMnemonic)
    }

    private func importWithPrivateKey() async -> Bool {
        let cleanedPrivateKey = privateKeyText.trimmingCharacters(in: .whitespacesAndNewlines)
        return walletManager.importWallet(privateKey: cleanedPrivateKey)
    }
}

struct TabSelector: View {
    @Binding var selectedTab: Int
    let tabs: [String]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                Button(action: {
                    selectedTab = index
                }) {
                    VStack(spacing: 8) {
                        Text(tab)
                            .font(.wpayinBody)
                            .foregroundColor(selectedTab == index ? WpayinColors.primary : WpayinColors.textSecondary)

                        Rectangle()
                            .fill(selectedTab == index ? WpayinColors.primary : Color.clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedTab)
    }
}

struct MnemonicInput: View {
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recovery Phrase")
                .font(.wpayinSubheadline)
                .foregroundColor(WpayinColors.text)

            TextField("Enter your 12-word recovery phrase...", text: $text)
                .font(.wpayinBody)
                .foregroundColor(WpayinColors.text)
                .padding(16)
                .background(WpayinColors.surface)
                .cornerRadius(12)
                .lineLimit(4)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Text("Separate each word with a space")
                .font(.wpayinCaption)
                .foregroundColor(WpayinColors.textSecondary)
        }
    }
}

struct PrivateKeyInput: View {
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Private Key")
                .font(.wpayinSubheadline)
                .foregroundColor(WpayinColors.text)

            TextField("Enter your private key...", text: $text)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(WpayinColors.text)
                .padding(16)
                .background(WpayinColors.surface)
                .cornerRadius(12)
                .lineLimit(3)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Text("64 character hexadecimal string (with or without 0x prefix)")
                .font(.wpayinCaption)
                .foregroundColor(WpayinColors.textSecondary)
        }
    }
}

struct SecurityNotice: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "shield.fill")
                .foregroundColor(WpayinColors.primary)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: 4) {
                Text("Your Security")
                    .font(.wpayinSubheadline)
                    .foregroundColor(WpayinColors.text)

                Text("Your private information is encrypted and stored securely on your device only.")
                    .font(.wpayinCaption)
                    .foregroundColor(WpayinColors.textSecondary)
            }

            Spacer()
        }
        .padding(16)
        .background(WpayinColors.surface)
        .cornerRadius(12)
    }
}

#Preview {
    ImportWalletView()
        .environmentObject(WalletManager())
}
