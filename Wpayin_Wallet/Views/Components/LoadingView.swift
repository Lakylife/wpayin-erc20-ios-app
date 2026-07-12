// Autor Lukas Helebrandt, 2026

//
//  LoadingView.swift
//  Wpayin_Wallet
//
//  Branded launch experience shown while the wallet state is restored.
//

import SwiftUI

struct LoadingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var contentVisible = false
    @State private var orbitRotation: Double = 0
    @State private var logoPulsing = false
    @State private var backgroundMoving = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LaunchBackground(isMoving: backgroundMoving)

                VStack(spacing: 0) {
                    Spacer(minLength: geometry.safeAreaInsets.top + 28)

                    VStack(spacing: 28) {
                        LaunchBrandMark(
                            rotation: orbitRotation,
                            isPulsing: logoPulsing
                        )

                        VStack(spacing: 9) {
                            Text("Wpayin")
                                .font(.wpayinBrand)
                                .tracking(0.4)
                                .foregroundColor(WpayinColors.text)

                            Text(L10n.Welcome.subtitle.localized)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(WpayinColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .padding(.horizontal, 36)
                        }
                    }
                    .scaleEffect(contentVisible ? 1 : 0.92)
                    .opacity(contentVisible ? 1 : 0)

                    Spacer()

                    LaunchStatusPanel(reduceMotion: reduceMotion)
                        .padding(.horizontal, 28)
                        .padding(.bottom, max(geometry.safeAreaInsets.bottom, 20) + 22)
                        .offset(y: contentVisible ? 0 : 16)
                        .opacity(contentVisible ? 1 : 0)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.Wallet.syncing.localized)
        .onAppear {
            withAnimation(.spring(response: 0.75, dampingFraction: 0.86)) {
                contentVisible = true
            }

            guard !reduceMotion else { return }

            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                orbitRotation = 360
            }
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                logoPulsing = true
            }
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
                backgroundMoving = true
            }
        }
    }
}

private struct LaunchBackground: View {
    let isMoving: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.035, green: 0.04, blue: 0.075),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image("Intro - Background")
                .resizable()
                .scaledToFill()
                .opacity(0.2)
                .scaleEffect(isMoving ? 1.055 : 1.015)
                .offset(x: isMoving ? -10 : 8, y: isMoving ? 8 : -8)

            Circle()
                .fill(WpayinColors.primary.opacity(0.16))
                .frame(width: 330, height: 330)
                .blur(radius: 86)
                .offset(x: isMoving ? -115 : -80, y: isMoving ? -245 : -205)

            Circle()
                .fill(WpayinColors.accent.opacity(0.1))
                .frame(width: 280, height: 280)
                .blur(radius: 92)
                .offset(x: isMoving ? 135 : 95, y: isMoving ? 280 : 240)

            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.16),
                    Color.black.opacity(0.62)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

private struct LaunchBrandMark: View {
    let rotation: Double
    let isPulsing: Bool

    var body: some View {
        ZStack {
            // One restrained glow is cheaper to render than several animated
            // material/blur layers and keeps the existing Wpayin palette.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            WpayinColors.primary.opacity(isPulsing ? 0.24 : 0.14),
                            WpayinColors.accent.opacity(0.045),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 108
                    )
                )
                .frame(width: 220, height: 220)
                .scaleEffect(isPulsing ? 1.04 : 0.98)

            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.clear,
                            WpayinColors.primary.opacity(0.22),
                            WpayinColors.primary,
                            Color.white.opacity(0.7),
                            WpayinColors.accent.opacity(0.5),
                            Color.clear
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 2.4, lineCap: .round)
                )
                .frame(width: 194, height: 194)
                .rotationEffect(.degrees(rotation * 0.65))

            Circle()
                .stroke(
                    Color.white.opacity(0.1),
                    style: StrokeStyle(lineWidth: 1, dash: [1, 10], dashPhase: rotation / 12)
                )
                .frame(width: 168, height: 168)

            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index == 1 ? WpayinColors.accent : WpayinColors.primary)
                    .frame(width: index == 1 ? 7 : 9, height: index == 1 ? 7 : 9)
                    .overlay(Circle().stroke(Color.white.opacity(0.55), lineWidth: 1))
                    .shadow(color: WpayinColors.primary.opacity(0.5), radius: 6)
                    .offset(y: -97)
                    .rotationEffect(.degrees(Double(index) * 120 + rotation * 0.18))
            }

            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color.black.opacity(0.76))
                .frame(width: 128, height: 128)
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.34),
                                    WpayinColors.primary.opacity(0.72),
                                    WpayinColors.accent.opacity(0.28)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )
                .shadow(color: WpayinColors.primary.opacity(0.22), radius: 22)
                .shadow(color: Color.black.opacity(0.48), radius: 10, y: 7)

            Image("WpayinLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
        }
        .frame(width: 224, height: 224)
    }
}

private struct LaunchStatusPanel: View {
    let reduceMotion: Bool

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(WpayinColors.primary.opacity(0.14))
                        .frame(width: 38, height: 38)

                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(WpayinColors.primary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.Wallet.syncing.localized)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(WpayinColors.text)

                    Text(L10n.Welcome.subtitle.localized)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(WpayinColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                LoadingDots(reduceMotion: reduceMotion)
            }

            LaunchProgressBar(reduceMotion: reduceMotion)
                .frame(height: 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.045))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.28), radius: 24, y: 12)
    }
}

private struct LoadingDots: View {
    let reduceMotion: Bool
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(WpayinColors.primary)
                    .frame(width: 6, height: 6)
                    .scaleEffect(isAnimating ? 1 : 0.68)
                    .opacity(isAnimating ? 1 : 0.32)
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeInOut(duration: 0.62)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.18),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = !reduceMotion
        }
    }
}

private struct LaunchProgressBar: View {
    let reduceMotion: Bool
    @State private var progress: CGFloat = -0.4

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.07))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                WpayinColors.primary.opacity(0.2),
                                WpayinColors.primary,
                                Color.white.opacity(0.9),
                                WpayinColors.accent
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * 0.38)
                    .offset(x: geometry.size.width * progress)
                    .shadow(color: WpayinColors.primary.opacity(0.55), radius: 5)
            }
            .clipShape(Capsule())
        }
        .onAppear {
            guard !reduceMotion else {
                progress = 0.31
                return
            }
            withAnimation(.easeInOut(duration: 1.45).repeatForever(autoreverses: false)) {
                progress = 1.04
            }
        }
    }
}

#Preview {
    LoadingView()
}
