// Autor Lukas Helebrandt, 2026

//
//  MainTabView.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            // Background matching design specification
            WpayinColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Main content area - takes up available space
                ZStack {
                    switch selectedTab {
                    case 0:
                        WalletView()
                            .environmentObject(walletManager)
                            .environmentObject(settingsManager)
                    case 1:
                        SwapView()
                            .environmentObject(walletManager)
                            .environmentObject(settingsManager)
                    case 2:
                        ActivityView()
                            .environmentObject(walletManager)
                            .environmentObject(settingsManager)
                    case 3:
                        SettingsView()
                            .environmentObject(walletManager)
                            .environmentObject(settingsManager)
                    default:
                        WalletView()
                            .environmentObject(walletManager)
                            .environmentObject(settingsManager)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(settingsManager.refreshID) // Force redraw on settings change (language, etc.)

                ModernBottomNavigation(selectedTab: $selectedTab)
            }
        }
    }
}

struct ModernBottomNavigation: View {
    @Binding var selectedTab: Int

    // 4 tabs - Home, Swap, Activity, Settings
    private var tabItems: [(icon: String, title: String, index: Int)] {
        [
            (icon: "house.fill", title: L10n.Wallet.home.localized, index: 0),
            (icon: "arrow.left.arrow.right", title: L10n.Wallet.swap.localized, index: 1),
            (icon: "doc.text.fill", title: L10n.Wallet.activity.localized, index: 2),
            (icon: "gearshape.fill", title: L10n.Wallet.settings.localized, index: 3)
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(tabItems, id: \.index) { item in
                    ModernNavItem(
                        icon: item.icon,
                        title: item.title,
                        isSelected: selectedTab == item.index,
                        onTap: { selectedTab = item.index }
                    )
                }
            }
            .padding(6)
            .background(
                Capsule()
                    .fill(WpayinColors.navBackground)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(WpayinColors.navBorder, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 8)
            )
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .background(
            LinearGradient(
                colors: [
                    Color.clear,
                    WpayinColors.background.opacity(0.82)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
                .ignoresSafeArea()
        )
    }
}

struct ModernNavItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? WpayinColors.text : WpayinColors.textTertiary)
                    .frame(width: 34, height: 24)

                Text(title.localized)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? WpayinColors.text : WpayinColors.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .background(
                Capsule()
                    .fill(isSelected ? WpayinColors.primary.opacity(0.18) : Color.clear)
            )
            .overlay(alignment: .top) {
                if isSelected {
                    Capsule()
                        .fill(WpayinColors.primary)
                        .frame(width: 18, height: 3)
                        .offset(y: -2)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}


#Preview {
    return MainTabView()
        .environmentObject(WalletManager())
        .environmentObject(SettingsManager())
}
