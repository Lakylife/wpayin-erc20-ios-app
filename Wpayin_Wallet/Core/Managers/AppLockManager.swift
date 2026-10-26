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

    private var backgroundedAt: TimeInterval?
    private let userDefaults: UserDefaults
    private let uptime: () -> TimeInterval
    private let requestUnlock: (@MainActor () async -> Void)?

    init(userDefaults: UserDefaults = .standard,
         uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         requestUnlock: (@MainActor () async -> Void)? = nil) {
        self.userDefaults = userDefaults
        self.uptime = uptime
        self.requestUnlock = requestUnlock
    }

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
            backgroundedAt = uptime()
            if autoLockDuration == .immediately {
                authenticationError = nil
                isLocked = true
            }
        case .active:
            if let started = backgroundedAt, let timeout = autoLockDuration.seconds,
               uptime() - started >= timeout {
                authenticationError = nil
                isLocked = true
            }
            backgroundedAt = nil
            // Returning to foreground while locked → prompt Face ID right away
            if isLocked {
                Task { @MainActor in
                    if let requestUnlock = self.requestUnlock {
                        await requestUnlock()
                    } else {
                        await self.unlockWithBiometrics()
                    }
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

        // Prefer biometrics; fall back to device passcode so the user
        // is never permanently locked out of their own wallet.
        let policy: LAPolicy = .deviceOwnerAuthentication

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

/// A fresh authorization is required for each sensitive export screen.
@MainActor
final class SecretRevealAuthorization: ObservableObject {
    @Published private(set) var isAuthenticating = false
    @Published var errorMessage: String?
    private var context: LAContext?
    private var requestID = UUID()

    func authorize(_ reveal: @escaping () -> Void) {
        guard !isAuthenticating else { return }
        let id = UUID()
        requestID = id
        let context = LAContext()
        self.context = context
        isAuthenticating = true
        errorMessage = nil
        Task { @MainActor in
            do {
                let success = try await context.evaluatePolicy(
                    .deviceOwnerAuthentication,
                    localizedReason: "Authenticate to access your wallet".localized
                )
                guard requestID == id else { return }
                isAuthenticating = false
                self.context = nil
                if success && UIApplication.shared.applicationState == .active { reveal() }
            } catch {
                guard requestID == id else { return }
                isAuthenticating = false
                self.context = nil
                errorMessage = error.localizedDescription
            }
        }
    }

    func cancel() {
        requestID = UUID()
        context?.invalidate()
        context = nil
        isAuthenticating = false
        errorMessage = nil
    }
}
