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

                // HTML-Style Bottom Navigation (Fixed to bottom, no rounded container)
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
        // HTML CSS: position: fixed; bottom: 0; padding: 12px 8px;
        // background: rgba(10, 10, 10, 0.95); backdrop-filter: blur(20px);
        // border-top: 1px solid rgba(255, 255, 255, 0.05);
        HStack(spacing: 0) {
            ForEach(tabItems, id: \.index) { item in
                ModernNavItem(
                    icon: item.icon,
                    title: item.title,
                    isSelected: selectedTab == item.index,
                    onTap: { selectedTab = item.index }
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(
            // Match HTML: rgba(10, 10, 10, 0.95) with blur
            Color(red: 10/255, green: 10/255, blue: 10/255)
                .opacity(0.95)
                .background(.ultraThinMaterial)
                .overlay(
                    // Border-top only
                    VStack {
                        Rectangle()
                            .fill(Color.white.opacity(0.05))
                            .frame(height: 1)
                        Spacer()
                    }
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
            // HTML: Each nav-item has border-radius: 12px when active
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(isSelected ? WpayinColors.primary : WpayinColors.textTertiary)
                    .frame(width: 24, height: 24)

                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? WpayinColors.text : WpayinColors.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.white.opacity(0.1) : Color.clear)
            )
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