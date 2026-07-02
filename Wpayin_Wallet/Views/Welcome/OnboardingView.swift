// Autor Lukas Helebrandt, 2026

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
    @State private var showWelcome = true

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
    }
}

struct AppWelcomeView: View {
    let onContinue: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false
    @State private var isFloating = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image("Intro - Background")
                    .resizable()
                    .scaledToFill()
                    .opacity(0.48)
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.12),
                        Color.clear,
                        Color.black.opacity(0.72)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: geometry.safeAreaInsets.top + 36)

                    VStack(spacing: 28) {
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            WpayinColors.primary.opacity(0.3),
                                            Color.clear
                                        ],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 100
                                    )
                                )
                                .frame(width: 210, height: 210)
                                .blur(radius: 8)
                                .scaleEffect(isFloating ? 1.08 : 0.96)

                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .fill(Color.black.opacity(0.68))
                                .frame(width: 126, height: 126)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.2),
                                                    WpayinColors.primary.opacity(0.55),
                                                    Color.white.opacity(0.04)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                                .shadow(color: WpayinColors.primary.opacity(0.3), radius: 24)

                            Image("WpayinLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 88, height: 88)
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }
                        .frame(width: 220, height: 220)
                        .offset(y: isFloating ? -6 : 4)

                        VStack(spacing: 12) {
                            Text("Wpayin Wallet")
                                .font(.wpayinBrand)
                                .foregroundColor(WpayinColors.text)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)

                            Text(L10n.Onboarding.welcome.localized)
                                .font(.system(size: 17, weight: .medium, design: .rounded))
                                .foregroundColor(WpayinColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .padding(.horizontal, 28)
                        }
                    }
                    .opacity(isVisible ? 1 : 0)
                    .scaleEffect(isVisible ? 1 : 0.92)

                    Spacer()

                    Button(action: onContinue) {
                        HStack(spacing: 10) {
                            Text(L10n.Action.getStarted.localized)
                                .font(.system(size: 17, weight: .semibold, design: .rounded))

                            Image(systemName: "arrow.right")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(
                            LinearGradient(
                                colors: [
                                    WpayinColors.primary,
                                    WpayinColors.primaryDark
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                        .shadow(color: WpayinColors.primary.opacity(0.28), radius: 18, y: 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 20)
                    .padding(.bottom, max(geometry.safeAreaInsets.bottom, 20) + 24)
                    .opacity(isVisible ? 1 : 0)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                isVisible = true
            }

            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                isFloating = true
            }
        }
    }
}

struct OnboardingProgressView: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(L10n.Onboarding.step.localized(currentStep + 1, totalSteps))
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
                Text(L10n.Onboarding.secureTitle.localized)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(WpayinColors.text)
                    .multilineTextAlignment(.center)

                Text(L10n.Onboarding.secureDesc.localized)
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
                Text(L10n.Onboarding.tradingTitle.localized)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(WpayinColors.text)
                    .multilineTextAlignment(.center)

                Text(L10n.Onboarding.tradingDesc.localized)
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
                Text(L10n.Onboarding.multiChainTitle.localized)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(WpayinColors.text)
                    .multilineTextAlignment(.center)

                Text(L10n.Onboarding.multiChainDesc.localized)
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
                Text(currentStep == totalSteps - 1 ? L10n.Action.getStarted.localized : L10n.Action.continue.localized)
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
                Button(L10n.Action.skip.localized, action: onSkip)
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
