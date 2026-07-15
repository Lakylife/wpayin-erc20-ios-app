// Autor Lukas Helebrandt, 2026

//
//  SettingsView.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI
import LocalAuthentication

private enum AppVersionInfo {
    static let version = Bundle.main.object(
        forInfoDictionaryKey: "CFBundleShortVersionString"
    ) as? String ?? "—"

    static let build = Bundle.main.object(
        forInfoDictionaryKey: "CFBundleVersion"
    ) as? String ?? "—"

    static var localizedVersion: String {
        "\("Version".localized) \(version)"
    }

    static var versionWithBuild: String {
        "\(version) (Build \(build))"
    }
}

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
    @State private var showTimeZoneSelection = false
    @State private var showAutoLockSelection = false
    @State private var showNetworkManagement = false
    @State private var showHelpCenter = false
    @State private var showExportWalletCompliance = false
    @State private var showContactSupport = false
    @State private var showAppearanceSettings = false
    @State private var showWalletConnect = false

    var body: some View {
        ZStack {
            // Background gradient matching design specification
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
                HStack {
                    Text(L10n.Settings.title.localized)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(WpayinColors.text)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            WpayinColors.primary.opacity(0.12),
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
                                action: { showExportWalletCompliance = true }
                            )
                        }

                        // Security Section
                        SettingsSection(title: L10n.Settings.security.localized) {
                            BiometricSettingsRow(settingsManager: settingsManager)

                            SettingsRow(
                                icon: "lock.fill",
                                title: "Auto-Lock",
                                subtitle: settingsManager.autoLockDuration.displayName.localized,
                                action: { showAutoLockSelection = true }
                            )
                        }

                        // Preferences Section
                        SettingsSection(title: L10n.Settings.preferences.localized) {
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

                            SettingsRow(
                                icon: "clock.badge.checkmark",
                                title: "Time Zone",
                                subtitle: settingsManager.timeZoneSummary,
                                action: { showTimeZoneSelection = true }
                            )

                            SettingsRow(
                                icon: "paintbrush.fill",
                                title: "Appearance",
                                subtitle: settingsManager.selectedColorTheme.displayName,
                                action: { showAppearanceSettings = true }
                            )

                            NotificationSettingsRow(settingsManager: settingsManager)
                        }

                        // Network Management Section
                        SettingsSection(title: L10n.Networks.title.localized) {
                            SettingsRow(
                                icon: "network",
                                title: L10n.Settings.manageNetworks.localized,
                                subtitle: L10n.Networks.networkCount.localized(walletManager.selectedBlockchains.count),
                                action: { showNetworkManagement = true }
                            )

                            SettingsRow(
                                icon: "link",
                                title: "WalletConnect",
                                subtitle: "Connect to dApps and manage active sessions".localized,
                                action: { showWalletConnect = true }
                            )
                        }

                        // Support Section
                        SettingsSection(title: L10n.Settings.support.localized) {
                            SettingsRow(
                                icon: "questionmark.circle.fill",
                                title: L10n.Settings.helpCenter.localized,
                                subtitle: "Get help and support",
                                action: { showHelpCenter = true }
                            )

                            SettingsRow(
                                icon: "envelope.fill",
                                title: L10n.Settings.contactUs.localized,
                                subtitle: "Send feedback",
                                action: {
                                    if !settingsManager.openContactUs() {
                                        showContactSupport = true
                                    }
                                }
                            )

                            SettingsRow(
                                icon: "info.circle.fill",
                                title: L10n.Settings.about.localized,
                                subtitle: "App version and info",
                                action: { showAbout = true }
                            )
                        }

                        // Danger Zone
                        SettingsSection(title: L10n.Settings.dangerZone.localized) {
                            SettingsRow(
                                icon: "trash.fill",
                                title: L10n.Settings.deleteWallet.localized,
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

                            Text(AppVersionInfo.localizedVersion)
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
        .sheet(isPresented: $showTimeZoneSelection) {
            TimeZoneSelectionView()
                .environmentObject(settingsManager)
        }
        .sheet(isPresented: $showAutoLockSelection) {
            AutoLockSelectionView()
                .environmentObject(settingsManager)
        }
        .sheet(isPresented: $showAppearanceSettings) {
            AppearanceSettingsView()
                .environmentObject(settingsManager)
        }
        .sheet(isPresented: $showNetworkManagement) {
            NetworkManagementView()
                .environmentObject(walletManager)
                .environmentObject(networkManager)
        }
        .sheet(isPresented: $showWalletConnect) {
            WalletConnectView()
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
        .sheet(isPresented: $showHelpCenter) {
            HelpCenterView()
        }
        .sheet(isPresented: $showContactSupport) {
            ContactSupportView()
        }
        .sheet(isPresented: $showExportWalletCompliance) {
            ExportWalletComplianceView {
                showExportWalletCompliance = false
                showRecoveryPhrase = true
            }
        }
        .alert(L10n.Settings.deleteWallet.localized, isPresented: $showDeleteWalletAlert) {
            Button("Cancel".localized, role: .cancel) { }
            Button("Delete".localized, role: .destructive) {
                walletManager.deleteWallet()
            }
        } message: {
            Text("This action cannot be undone. Make sure you have backed up your recovery phrase.".localized)
        }
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
            Text(title.localized)
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
                    Text(title.localized)
                        .font(.wpayinBody)
                        .foregroundColor(titleColor)

                    Text(subtitle.localized)
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
                        .allowsHitTesting(false)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxWidth: .infinity)
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

            Toggle("", isOn: Binding(
                get: { settingsManager.biometricAuthEnabled },
                set: { newValue in
                    if newValue {
                        settingsManager.updateBiometricAuth(true)
                    } else {
                        // Switching the lock off must pass the lock first.
                        Task { await settingsManager.disableBiometricAuthAfterVerification() }
                    }
                }
            ))
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
        return settingsManager.biometricAuthEnabled
            ? "Required to unlock and sign transactions"
            : "Protect wallet access and transaction signing"
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
                Text(L10n.Settings.notifications.localized)
                    .font(.wpayinBody)
                    .foregroundColor(WpayinColors.text)

                Text("Transaction alerts and updates".localized)
                    .font(.wpayinCaption)
                    .foregroundColor(WpayinColors.textSecondary)
            }

            Spacer()

            Toggle(
                "",
                isOn: Binding(
                    get: { settingsManager.notificationsEnabled },
                    set: { settingsManager.setNotificationsEnabled($0) }
                )
            )
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
                            Image("WpayinLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 84, height: 84)
                                .clipShape(RoundedRectangle(cornerRadius: 18))

                            VStack(spacing: 8) {
                                Text("Wpayin Wallet")
                                    .font(.wpayinTitle)
                                    .foregroundColor(WpayinColors.text)

                                Text(AppVersionInfo.localizedVersion)
                                    .font(.wpayinSubheadline)
                                    .foregroundColor(WpayinColors.textSecondary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 20) {
                            AboutSection(
                                title: "About",
                                content: "Wpayin Wallet is a secure, decentralized wallet for managing your cryptocurrency assets. Built with privacy and security as our top priorities. Your private keys never leave your device."
                            )

                            AboutSection(
                                title: "Version",
                                content: AppVersionInfo.versionWithBuild
                            )

                            NavigationLink {
                                VersionHistoryView()
                            } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(WpayinColors.primary.opacity(0.14))
                                            .frame(width: 46, height: 46)

                                        Image(systemName: "sparkles")
                                            .font(.system(size: 19, weight: .semibold))
                                            .foregroundColor(WpayinColors.primary)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("What's New & Version History".localized)
                                            .font(.wpayinSubheadline)
                                            .foregroundColor(WpayinColors.text)

                                        Text("See changes in this and earlier releases".localized)
                                            .font(.wpayinCaption)
                                            .foregroundColor(WpayinColors.textSecondary)
                                    }

                                    Spacer(minLength: 8)

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(WpayinColors.textTertiary)
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(WpayinColors.surface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 40)
                }
            }
            .navigationTitle(L10n.Settings.about.localized)
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
    }
}

struct AboutSection: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.localized)
                .font(.wpayinSubheadline)
                .foregroundColor(WpayinColors.text)

            Text(content.localized)
                .font(.wpayinBody)
                .foregroundColor(WpayinColors.textSecondary)
        }
    }
}

struct ContactSupportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    private let supportEmail = "support@wpayin.com"

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 52))
                        .foregroundColor(WpayinColors.primary)

                    VStack(spacing: 8) {
                        Text("Contact Us".localized)
                            .font(.wpayinHeadline)
                            .foregroundColor(WpayinColors.text)

                        Text("No email app is configured on this device. You can copy the support address below.".localized)
                            .font(.wpayinBody)
                            .foregroundColor(WpayinColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    Text(supportEmail)
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundColor(WpayinColors.text)
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(WpayinColors.surface)
                        .cornerRadius(12)

                    WpayinButton(title: copied ? "Copied!" : "Copy Address", style: .primary) {
                        AppToast.copyToClipboard(supportEmail)
                        copied = true
                    }

                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("Contact Us".localized)
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
    }
}

struct ExportWalletComplianceView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var acceptedResponsibility = false
    @State private var acceptedNoRecovery = false
    let onContinue: () -> Void

    private var isEUOrEEARegion: Bool {
        let euAndEEA: Set<String> = [
            "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "GR",
            "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL", "PL", "PT", "RO", "SK",
            "SI", "ES", "SE", "IS", "LI", "NO"
        ]
        return Locale.current.regionCode.map { euAndEEA.contains($0) } ?? false
    }

    private var canContinue: Bool {
        acceptedResponsibility && acceptedNoRecovery
    }

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Export Wallet".localized)
                                .font(.wpayinTitle)
                                .foregroundColor(WpayinColors.text)

                            Text("Export wallet legal notice".localized)
                                .font(.wpayinBody)
                                .foregroundColor(WpayinColors.textSecondary)
                        }

                        ExportNoticeBlock(
                            icon: "exclamationmark.triangle.fill",
                            title: "Self-custody responsibility",
                            message: "Exporting your recovery phrase or private key gives full control over your crypto assets. Anyone with access can move your funds permanently."
                        )

                        ExportNoticeBlock(
                            icon: "lock.slash.fill",
                            title: "No recovery by Wpayin",
                            message: "Wpayin is a non-custodial wallet. We cannot reset, recover, freeze, reverse, or restore funds if your exported secret is lost, stolen, or shared."
                        )

                        if isEUOrEEARegion {
                            ExportNoticeBlock(
                                icon: "building.columns.fill",
                                title: "MiCA and EU notice",
                                message: "For users in the EU or EEA, crypto-assets may be volatile and transfers are generally irreversible. Under self-custody, you remain solely responsible for safeguarding wallet secrets and verifying transaction details."
                            )
                        }

                        VStack(spacing: 12) {
                            ExportAcknowledgementRow(
                                isOn: $acceptedResponsibility,
                                text: "I understand that exported wallet secrets can transfer full control of my assets."
                            )

                            ExportAcknowledgementRow(
                                isOn: $acceptedNoRecovery,
                                text: "I understand that Wpayin cannot recover funds or wallet access if I lose or share this information."
                            )
                        }

                        WpayinButton(title: "Continue to Export", style: canContinue ? .primary : .secondary) {
                            guard canContinue else { return }
                            onContinue()
                        }
                        .opacity(canContinue ? 1.0 : 0.45)
                        .disabled(!canContinue)
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Export Wallet".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel".localized) {
                        dismiss()
                    }
                    .foregroundColor(WpayinColors.text)
                }
            }
        }
    }
}

struct ExportNoticeBlock: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(WpayinColors.primary)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 6) {
                Text(title.localized)
                    .font(.wpayinSubheadline)
                    .foregroundColor(WpayinColors.text)

                Text(message.localized)
                    .font(.wpayinBody)
                    .foregroundColor(WpayinColors.textSecondary)
            }
        }
        .padding(16)
        .background(WpayinColors.surface)
        .cornerRadius(12)
    }
}

struct ExportAcknowledgementRow: View {
    @Binding var isOn: Bool
    let text: String

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22))
                    .foregroundColor(isOn ? WpayinColors.primary : WpayinColors.textSecondary)

                Text(text.localized)
                    .font(.wpayinBody)
                    .foregroundColor(WpayinColors.text)
                    .multilineTextAlignment(.leading)

                Spacer()
            }
            .padding(16)
            .background(WpayinColors.surface)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SettingsView()
        .environmentObject(WalletManager())
        .environmentObject(SettingsManager())
        .environmentObject(NetworkConfigManager())
}
