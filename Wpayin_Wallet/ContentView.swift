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
    @StateObject private var walletConnectService = WalletConnectService.shared
    @State private var isShowingLaunchExperience = true
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
                if walletManager.isInitializing || isShowingLaunchExperience {
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
        .environment(\.timeZone, settingsManager.resolvedTimeZone)
        .sheet(item: $walletConnectService.pendingProposal) { proposal in
            WalletConnectProposalApprovalView(item: proposal)
        }
        .sheet(item: $walletConnectService.pendingRequest) { request in
            WalletConnectRequestApprovalView(item: request)
                .environmentObject(settingsManager)
        }
        .alert("WalletConnect".localized, isPresented: walletConnectErrorBinding) {
            Button("OK".localized) { walletConnectService.errorMessage = nil }
        } message: {
            Text(walletConnectService.errorMessage ?? "")
        }
        .task {
            let launchStartedAt = Date()
            lockManager.lockOnLaunchIfNeeded(hasWallet: walletManager.keychain.hasSeedPhrase() || walletManager.keychain.hasPrivateKey())
            await walletManager.checkExistingWallet()
            walletConnectService.configureIfNeeded()

            // Keep the branded launch experience visible long enough to feel
            // intentional, even when the cached wallet restores instantly.
            let minimumLaunchDuration: TimeInterval = 0.9
            let remaining = minimumLaunchDuration - Date().timeIntervalSince(launchStartedAt)
            if remaining > 0 {
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }
            withAnimation(.easeOut(duration: 0.3)) {
                isShowingLaunchExperience = false
            }

            // Start automatic price updates when wallet is ready
            if walletManager.hasWallet {
                walletManager.startPriceUpdates()
            }
        }
        .onChange(of: scenePhase) { newPhase in
            lockManager.handleScenePhaseChange(newPhase, hasWallet: walletManager.hasWallet)
        }
        .onOpenURL { url in
            walletConnectService.handleDeepLink(url)
        }
        .onDisappear {
            walletManager.stopPriceUpdates()
        }
    }

    private var walletConnectErrorBinding: Binding<Bool> {
        Binding(
            get: { walletConnectService.errorMessage != nil },
            set: { if !$0 { walletConnectService.errorMessage = nil } }
        )
    }
}

#Preview {
    ContentView()
}
