// Autor Lukas Helebrandt, 2026

//
//  AppearanceSettingsView.swift
//  Wpayin_Wallet
//
//  App color theme + asset list display style.
//

import SwiftUI

struct AppearanceSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        // App color theme
                        VStack(alignment: .leading, spacing: 14) {
                            Text("App Color".localized)
                                .font(.wpayinHeadline)
                                .foregroundColor(WpayinColors.text)

                            VStack(spacing: 1) {
                                ForEach(AppColorTheme.allCases) { theme in
                                    ColorThemeRow(
                                        theme: theme,
                                        isSelected: settingsManager.selectedColorTheme == theme
                                    ) {
                                        settingsManager.updateColorTheme(theme)
                                    }
                                }
                            }
                            .background(WpayinColors.surface)
                            .cornerRadius(16)
                        }

                        // Asset list style
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Asset List Style".localized)
                                .font(.wpayinHeadline)
                                .foregroundColor(WpayinColors.text)

                            Text("Choose how Your Assets are displayed on the Home screen".localized)
                                .font(.wpayinCaption)
                                .foregroundColor(WpayinColors.textSecondary)

                            VStack(spacing: 1) {
                                ForEach(AssetListStyle.allCases) { style in
                                    AssetStyleRow(
                                        style: style,
                                        isSelected: settingsManager.assetListStyle == style
                                    ) {
                                        settingsManager.updateAssetListStyle(style)
                                    }
                                }
                            }
                            .background(WpayinColors.surface)
                            .cornerRadius(16)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Appearance".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.Action.done.localized) {
                        dismiss()
                    }
                    .foregroundColor(WpayinColors.text)
                }
            }
        }
    }
}

private struct ColorThemeRow: View {
    let theme: AppColorTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [theme.primary, theme.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )

                Text(theme.displayName.localized)
                    .font(.wpayinBody)
                    .foregroundColor(WpayinColors.text)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.primary)
                }
            }
            .padding(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct AssetStyleRow: View {
    let style: AssetListStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: style.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(WpayinColors.primary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(style.displayName.localized)
                        .font(.wpayinBody)
                        .foregroundColor(WpayinColors.text)

                    if style == .cards {
                        Text("Default".localized)
                            .font(.wpayinCaption)
                            .foregroundColor(WpayinColors.textSecondary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(WpayinColors.primary)
                }
            }
            .padding(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    AppearanceSettingsView()
        .environmentObject(SettingsManager())
}
