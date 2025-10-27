//
//  ContentView.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var walletManager = WalletManager()
    @StateObject private var settingsManager = SettingsManager()
    @StateObject private var networkManager = NetworkConfigManager()

    init() {
        // Setup settings listener after both managers are initialized
        let wallet = WalletManager()
        let settings = SettingsManager()
        wallet.setupSettingsListener(settings)

        _walletManager = StateObject(wrappedValue: wallet)
        _settingsManager = StateObject(wrappedValue: settings)
        _networkManager = StateObject(wrappedValue: NetworkConfigManager())
    }

    var body: some View {
        Group {
            if walletManager.isInitializing {
                LoadingView()
            } else if !walletManager.hasCompletedOnboarding {
                OnboardingView()
                    .environmentObject(walletManager)
                    .environmentObject(settingsManager)
                    .environmentObject(networkManager)
            } else if walletManager.hasWallet {
                MainTabView()
                    .environmentObject(walletManager)
                    .environmentObject(settingsManager)
                    .environmentObject(networkManager)
            } else {
                WelcomeView()
                    .environmentObject(walletManager)
                    .environmentObject(settingsManager)
                    .environmentObject(networkManager)
            }
        }
        .id(settingsManager.refreshID) // Force refresh when currency or language changes
        .preferredColorScheme(.dark)
        .task {
            await walletManager.checkExistingWallet()

            // Start automatic price updates when wallet is ready
            if walletManager.hasWallet {
                walletManager.startPriceUpdates()
            }
        }
        .onDisappear {
            walletManager.stopPriceUpdates()
        }
    }
}

#Preview {
    ContentView()
}
