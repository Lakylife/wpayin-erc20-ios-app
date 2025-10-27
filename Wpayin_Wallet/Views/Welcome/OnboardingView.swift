//
//  OnboardingView.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var walletManager: WalletManager
    @State private var currentStep = 0
    @State private var showWelcome = false

    private let totalSteps = 3

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    WpayinColors.backgroundGradientStart,
                    WpayinColors.backgroundGradientEnd
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if showWelcome {
                AppWelcomeView(onContinue: {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showWelcome = false
                    }
                })
            } else {
                VStack(spacing: 0) {
                    // Progress indicator
                    OnboardingProgressView(currentStep: currentStep, totalSteps: totalSteps)
                        .padding(.top, 60)
                        .padding(.horizontal, 20)

                    // Content
                    TabView(selection: $currentStep) {
                        OnboardingStep1View()
                            .tag(0)
                        OnboardingStep2View()
                            .tag(1)
                        OnboardingStep3View()
                            .tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    // Action buttons
                    OnboardingActionButtons(
                        currentStep: currentStep,
                        totalSteps: totalSteps,
                        onNext: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if currentStep < totalSteps - 1 {
                                    currentStep += 1
                                } else {
                                    walletManager.completeOnboarding()
                                }
                            }
                        },
                        onSkip: {
                            walletManager.completeOnboarding()
                        }
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 50)
                }
            }
        }
        .onAppear {
            showWelcome = true
        }
    }
}

struct AppWelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // App Logo
            VStack(spacing: 20) {
                WpayinLogoView(size: 120)

                VStack(spacing: 12) {
                    Text("Wpayin Wallet")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(WpayinColors.text)

                    Text("Your gateway to decentralized finance")
                        .font(.system(size: 18))
                        .foregroundColor(WpayinColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()

            // Continue button
            Button(action: onContinue) {
                HStack {
                    Text("Get Started")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            WpayinColors.primary,
                            WpayinColors.primaryDark
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 50)
        }
    }
}

struct OnboardingProgressView: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Step \(currentStep + 1) of \(totalSteps)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(WpayinColors.textSecondary)

                Spacer()
            }

            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Rectangle()
                        .fill(index <= currentStep ? WpayinColors.primary : WpayinColors.surface)
                        .frame(height: 4)
                        .cornerRadius(2)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
            }
        }
    }
}

struct OnboardingStep1View: View {
    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Icon
            Circle()
                .fill(WpayinColors.primary.opacity(0.1))
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: "lock.shield")
                        .font(.system(size: 48))
                        .foregroundColor(WpayinColors.primary)
                )

            // Content
            VStack(spacing: 20) {
                Text("Secure & Private")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(WpayinColors.text)
                    .multilineTextAlignment(.center)

                Text("Your keys, your crypto. We use industry-standard encryption to keep your assets safe. Your private keys never leave your device.")
                    .font(.system(size: 16))
                    .foregroundColor(WpayinColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }
}

struct OnboardingStep2View: View {
    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Icon
            Circle()
                .fill(WpayinColors.success.opacity(0.1))
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 48))
                        .foregroundColor(WpayinColors.success)
                )

            // Content
            VStack(spacing: 20) {
                Text("Easy Trading")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(WpayinColors.text)
                    .multilineTextAlignment(.center)

                Text("Swap tokens instantly with best rates. Access DeFi protocols, track your portfolio, and manage all your crypto in one place.")
                    .font(.system(size: 16))
                    .foregroundColor(WpayinColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }
}

struct OnboardingStep3View: View {
    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Icon
            Circle()
                .fill(WpayinColors.warning.opacity(0.1))
                .frame(width: 120, height: 120)
                .overlay(
                    Image(systemName: "globe")
                        .font(.system(size: 48))
                        .foregroundColor(WpayinColors.warning)
                )

            // Content
            VStack(spacing: 20) {
                Text("Multi-Chain Support")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(WpayinColors.text)
                    .multilineTextAlignment(.center)

                Text("Support for Ethereum, Bitcoin, Polygon, BSC, and more. Switch between networks seamlessly and manage all your assets.")
                    .font(.system(size: 16))
                    .foregroundColor(WpayinColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }
}

struct OnboardingActionButtons: View {
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Next/Get Started button
            Button(action: onNext) {
                Text(currentStep == totalSteps - 1 ? "Get Started" : "Continue")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                WpayinColors.primary,
                                WpayinColors.primaryDark
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
            }

            // Skip button (only show if not last step)
            if currentStep < totalSteps - 1 {
                Button("Skip", action: onSkip)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(WpayinColors.textSecondary)
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(WalletManager())
}