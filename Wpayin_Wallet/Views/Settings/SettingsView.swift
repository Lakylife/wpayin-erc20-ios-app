//
//  SettingsView.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI
import LocalAuthentication

struct SettingsView: View {
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var networkManager: NetworkConfigManager
    @State private var showDeleteWalletAlert = false
    @State private var showPrivateKey = false
    @State private var showRecoveryPhrase = false
    @State private var showAbout = false
    @State private var showCurrencySelection = false
    @State private var showLanguageSelection = false
    @State private var showAutoLockSelection = false
    @State private var showNetworkManagement = false

    var body: some View {
        ZStack {
            // Background gradient matching mockup
            LinearGradient(
                gradient: Gradient(colors: [
                    WpayinColors.backgroundGradientStart,
                    WpayinColors.backgroundGradientEnd
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(.all)

            VStack(spacing: 0) {
                // Modern Header
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 50)

                    HStack {
                        Text(L10n.Settings.title.localized)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(WpayinColors.text)

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            WpayinColors.headerBackground,
                            Color.clear
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Wallet Section
                        SettingsSection(title: "Wallet") {
                            SettingsRow(
                                icon: "key.fill",
                                title: "Show Private Key",
                                subtitle: "View your wallet private key",
                                action: { showPrivateKey = true }
                            )

                            SettingsRow(
                                icon: "square.and.arrow.up",
                                title: "Export Wallet",
                                subtitle: "Backup your wallet data",
                                action: { exportWallet() }
                            )
                        }

                        // Security Section
                        SettingsSection(title: L10n.Settings.security.localized) {
                            BiometricSettingsRow(settingsManager: settingsManager)

                            SettingsRow(
                                icon: "lock.fill",
                                title: "Auto-Lock",
                                subtitle: settingsManager.autoLockDuration.displayName,
                                action: { showAutoLockSelection = true }
                            )
                        }

                        // Preferences Section
                        SettingsSection(title: "Preferences") {
                            SettingsRow(
                                icon: "dollarsign.circle.fill",
                                title: L10n.Settings.currency.localized,
                                subtitle: "\(settingsManager.selectedCurrency.symbol) \(settingsManager.selectedCurrency.rawValue)",
                                action: { showCurrencySelection = true }
                            )

                            SettingsRow(
                                icon: "globe",
                                title: L10n.Settings.language.localized,
                                subtitle: "\(settingsManager.selectedLanguage.flag) \(settingsManager.selectedLanguage.name)",
                                action: { showLanguageSelection = true }
                            )

                            NotificationSettingsRow(settingsManager: settingsManager)
                        }

                        // Network Management Section
                        SettingsSection(title: "Networks") {
                            SettingsRow(
                                icon: "network",
                                title: "Manage Networks",
                                subtitle: "\(walletManager.selectedBlockchains.count) networks enabled",
                                action: { showNetworkManagement = true }
                            )
                        }

                        // Support Section
                        SettingsSection(title: "Support") {
                            SettingsRow(
                                icon: "questionmark.circle.fill",
                                title: "Help Center",
                                subtitle: "Get help and support",
                                action: { settingsManager.openHelpCenter() }
                            )

                            SettingsRow(
                                icon: "envelope.fill",
                                title: "Contact Us",
                                subtitle: "Send feedback",
                                action: { settingsManager.openContactUs() }
                            )

                            SettingsRow(
                                icon: "info.circle.fill",
                                title: L10n.Settings.about.localized,
                                subtitle: "App version and info",
                                action: { showAbout = true }
                            )
                        }

                        // Danger Zone
                        SettingsSection(title: "Danger Zone") {
                            SettingsRow(
                                icon: "trash.fill",
                                title: "Delete Wallet",
                                subtitle: "Permanently delete this wallet",
                                titleColor: WpayinColors.error,
                                action: { showDeleteWalletAlert = true }
                            )
                        }

                        // Version Info
                        VStack(spacing: 8) {
                            Text("Wpayin Wallet")
                                .font(.wpayinCaption)
                                .foregroundColor(WpayinColors.textSecondary)

                            Text("Version 1.1.0")
                                .font(.wpayinSmall)
                                .foregroundColor(WpayinColors.textSecondary)
                        }
                        .padding(.top, 20)

                        // Bottom padding for tab bar
                        Spacer()
                            .frame(height: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
        }
        .sheet(isPresented: $showPrivateKey) {
            PrivateKeyView()
                .environmentObject(walletManager)
        }
        .sheet(isPresented: $showRecoveryPhrase) {
            RecoveryPhraseView()
                .environmentObject(walletManager)
        }
        .sheet(isPresented: $showCurrencySelection) {
            CurrencySelectionView()
                .environmentObject(settingsManager)
        }
        .sheet(isPresented: $showLanguageSelection) {
            LanguageSelectionView()
                .environmentObject(settingsManager)
        }
        .sheet(isPresented: $showAutoLockSelection) {
            AutoLockSelectionView()
                .environmentObject(settingsManager)
        }
        .sheet(isPresented: $showNetworkManagement) {
            BlockchainSettingsView()
                .environmentObject(walletManager)
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
        .alert("Delete Wallet", isPresented: $showDeleteWalletAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                walletManager.deleteWallet()
            }
        } message: {
            Text("This action cannot be undone. Make sure you have backed up your recovery phrase.")
        }
    }

    private func exportWallet() {
        showRecoveryPhrase = true
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.wpayinHeadline)
                .foregroundColor(WpayinColors.text)

            VStack(spacing: 1) {
                content
            }
            .background(WpayinColors.surface)
            .cornerRadius(16)
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let titleColor: Color
    let hasToggle: Bool
    let action: (() -> Void)?

    @State private var toggleValue = false

    init(
        icon: String,
        title: String,
        subtitle: String,
        titleColor: Color = WpayinColors.text,
        hasToggle: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.titleColor = titleColor
        self.hasToggle = hasToggle
        self.action = action
    }

    var body: some View {
        Button(action: {
            if hasToggle {
                toggleValue.toggle()
            } else {
                action?()
            }
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(WpayinColors.primary)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.wpayinBody)
                        .foregroundColor(titleColor)

                    Text(subtitle)
                        .font(.wpayinCaption)
                        .foregroundColor(WpayinColors.textSecondary)
                }

                Spacer()

                if hasToggle {
                    Toggle("", isOn: $toggleValue)
                        .labelsHidden()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(WpayinColors.textSecondary)
                }
            }
            .padding(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct BiometricSettingsRow: View {
    @ObservedObject var settingsManager: SettingsManager

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: biometricIconName)
                .font(.system(size: 20))
                .foregroundColor(WpayinColors.primary)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(biometricTitle)
                    .font(.wpayinBody)
                    .foregroundColor(WpayinColors.text)

                Text(biometricSubtitle)
                    .font(.wpayinCaption)
                    .foregroundColor(WpayinColors.textSecondary)
            }

            Spacer()

            Toggle("", isOn: $settingsManager.biometricAuthEnabled)
                .labelsHidden()
                .disabled(!settingsManager.isBiometricAvailable)
        }
        .padding(16)
        .opacity(settingsManager.isBiometricAvailable ? 1.0 : 0.5)
    }

    private var biometricIconName: String {
        switch settingsManager.biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        default:
            return "faceid"
        }
    }

    private var biometricTitle: String {
        switch settingsManager.biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        default:
            return "Biometric Authentication"
        }
    }

    private var biometricSubtitle: String {
        if !settingsManager.isBiometricAvailable {
            return "Not available on this device"
        }
        return "Use biometry to unlock wallet"
    }
}

struct NotificationSettingsRow: View {
    @ObservedObject var settingsManager: SettingsManager

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "bell.fill")
                .font(.system(size: 20))
                .foregroundColor(WpayinColors.primary)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text("Notifications")
                    .font(.wpayinBody)
                    .foregroundColor(WpayinColors.text)

                Text("Transaction alerts and updates")
                    .font(.wpayinCaption)
                    .foregroundColor(WpayinColors.textSecondary)
            }

            Spacer()

            Toggle("", isOn: $settingsManager.notificationsEnabled)
                .labelsHidden()
        }
        .padding(16)
    }
}


struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        VStack(spacing: 20) {
                            Image(systemName: "wallet.pass.fill")
                                .font(.system(size: 64))
                                .foregroundColor(WpayinColors.primary)

                            VStack(spacing: 8) {
                                Text("Wpayin Wallet")
                                    .font(.wpayinTitle)
                                    .foregroundColor(WpayinColors.text)

                                Text("Version 1.1.0")
                                    .font(.wpayinSubheadline)
                                    .foregroundColor(WpayinColors.textSecondary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 20) {
                            AboutSection(
                                title: "About",
                                content: "Wpayin Wallet is a secure, decentralized wallet for managing your cryptocurrency assets. Built with privacy and security as our top priorities."
                            )

                            AboutSection(
                                title: "Features",
                                content: "• Secure wallet creation and import\\n• ERC-20 token support\\n• DeFi integrations\\n• Swap functionality\\n• Transaction history\\n• Biometric authentication"
                            )

                            AboutSection(
                                title: "Privacy",
                                content: "Your private keys never leave your device. We don't track your transactions or store your personal data."
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 40)
                }
            }
            .navigationTitle("About")
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
}

struct AboutSection: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.wpayinSubheadline)
                .foregroundColor(WpayinColors.text)

            Text(content)
                .font(.wpayinBody)
                .foregroundColor(WpayinColors.textSecondary)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(WalletManager())
        .environmentObject(SettingsManager())
        .environmentObject(NetworkConfigManager())
}