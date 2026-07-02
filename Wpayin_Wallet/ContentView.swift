// Autor Lukas Helebrandt, 2026

//
//  ContentView.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var walletManager: WalletManager
    @StateObject private var settingsManager: SettingsManager
    @StateObject private var networkManager = NetworkConfigManager()
    @StateObject private var lockManager = AppLockManager()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Setup settings listener after both managers are initialized
        let wallet = WalletManager()
        let settings = SettingsManager()
        wallet.setupSettingsListener(settings)

        _walletManager = StateObject(wrappedValue: wallet)
        _settingsManager = StateObject(wrappedValue: settings)
    }

    var body: some View {
        ZStack {
            Group {
                if walletManager.isInitializing {
                    LoadingView()
                        .transition(.opacity)
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
            .animation(.easeOut(duration: 0.3), value: walletManager.isInitializing)

            if lockManager.isLocked {
                LockScreenView(lockManager: lockManager)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .preferredColorScheme(.dark)
        .environment(\.locale, Locale(identifier: settingsManager.selectedLanguage.rawValue))
        .task {
            lockManager.lockOnLaunchIfNeeded(hasWallet: walletManager.keychain.hasSeedPhrase() || walletManager.keychain.hasPrivateKey())
            await walletManager.checkExistingWallet()

            // Start automatic price updates when wallet is ready
            if walletManager.hasWallet {
                walletManager.startPriceUpdates()
            }
        }
        .onChange(of: scenePhase) { newPhase in
            lockManager.handleScenePhaseChange(newPhase, hasWallet: walletManager.hasWallet)
        }
        .onDisappear {
            walletManager.stopPriceUpdates()
        }
    }
}

#Preview {
    ContentView()
}
