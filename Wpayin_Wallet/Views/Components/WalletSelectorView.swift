//
//  WalletSelectorView.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI

struct WalletSelectorView: View {
    @EnvironmentObject var walletManager: WalletManager
    @Environment(\.dismiss) private var dismiss
    @State private var showCreateWallet = false
    @State private var showImportWallet = false
    @State private var showCreateAccount = false
    @State private var isCreatingAccount = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    HStack {
                        Text("Select Wallet")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(WpayinColors.text)

                        Spacer()

                        Button("Done") {
                            dismiss()
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(WpayinColors.primary)
                    }

                    Text("Choose which wallet to use or add a new one")
                        .font(.system(size: 16))
                        .foregroundColor(WpayinColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 24)

                // Wallet List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // All wallets from multiChainWallets - ONLY ONE CAN BE ACTIVE
                        ForEach(walletManager.multiChainWallets) { wallet in
                            WalletCard(
                                wallet: wallet,
                                isActive: wallet.id == walletManager.activeWallet?.id,
                                onSelect: {
                                    selectWallet(wallet)
                                }
                            )
                        }

                        // Show empty state if no wallets
                        if walletManager.multiChainWallets.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "wallet.pass")
                                    .font(.system(size: 48))
                                    .foregroundColor(WpayinColors.textTertiary)

                                Text("No Wallets")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(WpayinColors.text)

                                Text("Create or import a wallet to get started")
                                    .font(.system(size: 16))
                                    .foregroundColor(WpayinColors.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 60)
                        }

                        // Add wallet buttons
                        VStack(spacing: 12) {
                            // Create Account button (MetaMask style) - only show if we have a seed phrase
                            if walletManager.keychain.hasSeedPhrase() {
                                AddWalletButton(
                                    icon: "person.badge.plus.fill",
                                    title: "Create Account",
                                    subtitle: "Add a new account from your recovery phrase",
                                    action: { showCreateAccount = true }
                                )
                            }

                            AddWalletButton(
                                icon: "plus.circle.fill",
                                title: "Create New Wallet",
                                subtitle: "Generate a new wallet with recovery phrase",
                                action: { showCreateWallet = true }
                            )

                            AddWalletButton(
                                icon: "square.and.arrow.down.fill",
                                title: "Import Wallet",
                                subtitle: "Import using recovery phrase or private key",
                                action: { showImportWallet = true }
                            )
                        }
                        .padding(.top, 12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        WpayinColors.backgroundGradientStart,
                        WpayinColors.backgroundGradientEnd
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
        .sheet(isPresented: $showCreateWallet) {
            CreateWalletFlow()
                .environmentObject(walletManager)
        }
        .sheet(isPresented: $showImportWallet) {
            ImportWalletView()
                .environmentObject(walletManager)
        }
        .sheet(isPresented: $showCreateAccount) {
            CreateAccountView(isCreating: $isCreatingAccount, onCreate: { accountName in
                Task {
                    let success = await walletManager.createNewAccount(name: accountName)
                    if success {
                        showCreateAccount = false
                        dismiss()
                    }
                }
            })
        }
    }

    private func selectWallet(_ wallet: MultiChainWallet) {
        walletManager.setActiveWallet(wallet)
        dismiss()
    }
}

struct WalletCard: View {
    let wallet: MultiChainWallet
    let isActive: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                // Wallet Avatar
                WpayinLogoView(size: 48, colors: walletColors(for: wallet.name))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(wallet.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(WpayinColors.text)

                        if isActive {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(WpayinColors.success)
                                    .frame(width: 8, height: 8)

                                Text("ACTIVE")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(WpayinColors.success)
                                    .textCase(.uppercase)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(WpayinColors.success.opacity(0.15))
                            )
                        }
                    }

                    if let primaryAddress = getPrimaryAddress(for: wallet) {
                        Text(formatAddress(primaryAddress))
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(WpayinColors.textSecondary)
                    }

                    Text("$0.00") // TODO: Calculate wallet balance
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(WpayinColors.text)
                }

                Spacer()

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(WpayinColors.success)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 24))
                        .foregroundColor(WpayinColors.textTertiary)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(WpayinColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isActive ? WpayinColors.success.opacity(0.3) : WpayinColors.surfaceBorder, lineWidth: isActive ? 2 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func walletColors(for name: String) -> [Color] {
        let hash = abs(name.hashValue)
        let colorSets = [
            [Color.blue, Color.purple],
            [Color.green, Color.teal],
            [Color.orange, Color.red],
            [Color.purple, Color.pink],
            [Color.teal, Color.blue],
            [WpayinColors.primary, WpayinColors.primaryDark]
        ]
        return colorSets[hash % colorSets.count]
    }

    private func getPrimaryAddress(for wallet: MultiChainWallet) -> String? {
        // Priority: Ethereum > first EVM chain > any chain
        if let ethAccount = wallet.accounts.first(where: { $0.blockchainConfig.platform == .ethereum }) {
            return ethAccount.address
        } else if let evmAccount = wallet.accounts.first(where: { $0.blockchainConfig.platform.blockchainType?.isEVM == true }) {
            return evmAccount.address
        } else {
            return wallet.accounts.first?.address
        }
    }

    private func formatAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        return "\(address.prefix(6))...\(address.suffix(4))"
    }
}

struct AddWalletButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Circle()
                    .fill(WpayinColors.primary.opacity(0.1))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 24))
                            .foregroundColor(WpayinColors.primary)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(WpayinColors.text)

                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(WpayinColors.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(WpayinColors.textTertiary)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(WpayinColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Create Account View (MetaMask Style)

struct CreateAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isCreating: Bool
    let onCreate: (String?) -> Void

    @State private var accountName: String = ""
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Circle()
                            .fill(WpayinColors.primary.opacity(0.1))
                            .frame(width: 64, height: 64)
                            .overlay(
                                Image(systemName: "person.badge.plus.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(WpayinColors.primary)
                            )

                        Text("Create Account")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(WpayinColors.text)

                        Text("Add a new account from your existing recovery phrase")
                            .font(.system(size: 16))
                            .foregroundColor(WpayinColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .padding(.top, 40)

                    // Account Name Input
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Account Name (Optional)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(WpayinColors.textSecondary)

                        TextField("e.g., Trading Account", text: $accountName)
                            .font(.system(size: 16))
                            .foregroundColor(WpayinColors.text)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(WpayinColors.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isNameFieldFocused ? WpayinColors.primary : WpayinColors.surfaceBorder, lineWidth: isNameFieldFocused ? 2 : 1)
                            )
                            .focused($isNameFieldFocused)

                        Text("If left empty, the account will be named \"Account 2\", \"Account 3\", etc.")
                            .font(.system(size: 13))
                            .foregroundColor(WpayinColors.textTertiary)
                    }
                    .padding(.horizontal, 20)

                    Spacer()

                    // Create Button
                    VStack(spacing: 12) {
                        Button(action: {
                            isCreating = true
                            onCreate(accountName.isEmpty ? nil : accountName)
                        }) {
                            HStack {
                                if isCreating {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Create Account")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(WpayinColors.primary)
                            )
                        }
                        .disabled(isCreating)

                        Button("Cancel") {
                            dismiss()
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(WpayinColors.textSecondary)
                        .padding(.vertical, 12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    WalletSelectorView()
        .environmentObject(WalletManager())
}