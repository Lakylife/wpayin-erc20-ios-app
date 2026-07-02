// Autor Lukas Helebrandt, 2026

//
//  AppLockManager.swift
//  Wpayin_Wallet
//
//  Enforces Face ID / Touch ID app lock and the Auto Lock timeout.
//

import SwiftUI
import Combine
import LocalAuthentication

final class AppLockManager: ObservableObject {
    @Published var isLocked: Bool = false
    @Published var isAuthenticating: Bool = false
    @Published var authenticationError: String?

    private var backgroundedAt: Date?
    private let userDefaults = UserDefaults.standard

    private var biometricLockEnabled: Bool {
        userDefaults.bool(forKey: "BiometricAuthEnabled")
    }

    private var autoLockDuration: AutoLockDuration {
        if let raw = userDefaults.string(forKey: "AutoLockDuration"),
           let duration = AutoLockDuration(rawValue: raw) {
            return duration
        }
        return .after5min
    }

    /// Lock immediately on cold start when biometric protection is on.
    func lockOnLaunchIfNeeded(hasWallet: Bool) {
        if hasWallet && biometricLockEnabled {
            isLocked = true
        }
    }

    func handleScenePhaseChange(_ phase: ScenePhase, hasWallet: Bool) {
        guard hasWallet && biometricLockEnabled else { return }

        switch phase {
        case .background:
            backgroundedAt = Date()
            // Lock immediately when leaving the app — even a brief switch away
            // requires Face ID on return, and the lock screen also hides wallet
            // content in the app switcher snapshot. Auto Lock "Never" opts out.
            if autoLockDuration.seconds != nil {
                authenticationError = nil
                isLocked = true
            }
        case .active:
            backgroundedAt = nil
            // Returning to foreground while locked → prompt Face ID right away
            if isLocked {
                Task { @MainActor in
                    await self.unlockWithBiometrics()
                }
            }
        default:
            break
        }
    }

    @MainActor
    func unlockWithBiometrics() async {
        guard !isAuthenticating else { return }
        // Face ID can't be evaluated while the app is in the background
        guard UIApplication.shared.applicationState != .background else { return }
        isAuthenticating = true
        authenticationError = nil
        defer { isAuthenticating = false }

        let context = LAContext()
        var error: NSError?

        // Prefer biometrics; fall back to device passcode so the user
        // is never permanently locked out of their own wallet.
        let policy: LAPolicy = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            ? .deviceOwnerAuthenticationWithBiometrics
            : .deviceOwnerAuthentication

        do {
            let success = try await context.evaluatePolicy(
                policy,
                localizedReason: "Unlock your wallet".localized
            )
            if success {
                isLocked = false
            }
        } catch {
            authenticationError = error.localizedDescription
            Logger.log("🔒 Unlock failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Lock Screen

struct LockScreenView: View {
    @ObservedObject var lockManager: AppLockManager

    var body: some View {
        ZStack {
            WpayinColors.background.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundColor(WpayinColors.primary)

                Text("Wallet Locked".localized)
                    .font(.wpayinHeadline)
                    .foregroundColor(WpayinColors.text)

                Text("Authenticate to access your wallet".localized)
                    .font(.wpayinBody)
                    .foregroundColor(WpayinColors.textSecondary)
                    .multilineTextAlignment(.center)

                if let error = lockManager.authenticationError {
                    Text(error)
                        .font(.wpayinCaption)
                        .foregroundColor(WpayinColors.error)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                Button {
                    Task { await lockManager.unlockWithBiometrics() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "faceid")
                        Text("Unlock".localized)
                    }
                    .font(.wpayinSubheadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(WpayinColors.primary)
                    .cornerRadius(16)
                }
                .disabled(lockManager.isAuthenticating)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .task {
            // Trigger Face ID automatically when the lock screen appears.
            await lockManager.unlockWithBiometrics()
        }
    }
}
