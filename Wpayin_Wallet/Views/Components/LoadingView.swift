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
    @State private var isVisible = false
    @State private var orbitRotation: Double = 0
    @State private var pulseLogo = false
    @State private var moveBackground = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LaunchBackground(isMoving: moveBackground)

                VStack(spacing: 0) {
                    Spacer(minLength: geometry.safeAreaInsets.top + 40)

                    VStack(spacing: 34) {
                        LaunchLogo(
                            rotation: orbitRotation,
                            isPulsing: pulseLogo
                        )

                        VStack(spacing: 10) {
                            Text("Wpayin")
                                .font(.wpayinBrand)
                                .foregroundColor(WpayinColors.text)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            Text(L10n.Welcome.subtitle.localized)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(WpayinColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .padding(.horizontal, 32)
                        }
                    }
                    .scaleEffect(isVisible ? 1 : 0.9)
                    .opacity(isVisible ? 1 : 0)

                    Spacer()

                    VStack(spacing: 14) {
                        Text(L10n.Wallet.syncing.localized)
                            .font(.wpayinSmall)
                            .foregroundColor(WpayinColors.textSecondary)

                        LaunchProgressView(reduceMotion: reduceMotion)
                            .frame(height: 4)
                            .padding(.horizontal, 56)
                    }
                    .opacity(isVisible ? 1 : 0)
                    .padding(.bottom, max(geometry.safeAreaInsets.bottom, 24) + 26)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) {
                isVisible = true
            }

            guard !reduceMotion else { return }

            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                orbitRotation = 360
            }

            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                pulseLogo = true
            }

            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                moveBackground = true
            }
        }
    }
}

private struct LaunchBackground: View {
    let isMoving: Bool

    var body: some View {
        ZStack {
            Color.black

            Image("Intro - Background")
                .resizable()
                .scaledToFill()
                .opacity(0.42)
                .scaleEffect(isMoving ? 1.06 : 1)
                .offset(x: isMoving ? -12 : 8, y: isMoving ? 8 : -8)

            RadialGradient(
                colors: [
                    WpayinColors.primary.opacity(0.18),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 260
            )

            LinearGradient(
                colors: [
                    Color.black.opacity(0.18),
                    Color.clear,
                    Color.black.opacity(0.58)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

private struct LaunchLogo: View {
    let rotation: Double
    let isPulsing: Bool

    static let orbitCoins: [BlockchainType] = [
        .bitcoin, .ethereum, .solana, .bsc, .arbitrum, .base
    ]

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            WpayinColors.primary.opacity(isPulsing ? 0.34 : 0.22),
                            WpayinColors.primary.opacity(0.06),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 112
                    )
                )
                .frame(width: 230, height: 230)
                .blur(radius: 8)
                .scaleEffect(isPulsing ? 1.08 : 0.96)

            Circle()
                .stroke(
                    WpayinColors.surfaceBorder,
                    style: StrokeStyle(lineWidth: 1, dash: [3, 9])
                )
                .frame(width: 210, height: 210)
                .rotationEffect(.degrees(-rotation * 0.65))

            // Top coins riding the dashed orbit (counter-rotated to stay upright)
            ZStack {
                ForEach(Array(Self.orbitCoins.enumerated()), id: \.offset) { index, coin in
                    let angle = Double(index) / Double(Self.orbitCoins.count) * 360
                    NetworkIconView(blockchain: coin, size: 26)
                        .shadow(color: Color.black.opacity(0.5), radius: 4, y: 2)
                        .rotationEffect(.degrees(rotation * 0.65 - angle))
                        .offset(y: -105)
                        .rotationEffect(.degrees(angle))
                }
            }
            .rotationEffect(.degrees(-rotation * 0.65))

            ZStack(alignment: .top) {
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color.clear,
                                WpayinColors.primary.opacity(0.15),
                                WpayinColors.primary,
                                Color.white.opacity(0.75),
                                Color.clear
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .frame(width: 176, height: 176)

                Circle()
                    .fill(WpayinColors.primary)
                    .frame(width: 8, height: 8)
                    .shadow(color: WpayinColors.primary, radius: 7)
                    .offset(y: -4)
            }
            .rotationEffect(.degrees(rotation))

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.black.opacity(0.72))
                .frame(width: 118, height: 118)
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.18),
                                    WpayinColors.primary.opacity(0.55),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: WpayinColors.primary.opacity(0.32), radius: 24)

            Image("WpayinLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 82, height: 82)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .frame(width: 240, height: 240)
    }
}

private struct LaunchProgressView: View {
    let reduceMotion: Bool
    @State private var progress: CGFloat = -0.35

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(WpayinColors.surfaceLight)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                WpayinColors.primary.opacity(0.35),
                                WpayinColors.primary,
                                Color.white.opacity(0.85)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * 0.34)
                    .offset(x: geometry.size.width * progress)
                    .shadow(color: WpayinColors.primary.opacity(0.55), radius: 6)
            }
            .clipShape(Capsule())
        }
        .onAppear {
            guard !reduceMotion else {
                progress = 0.33
                return
            }

            withAnimation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true)) {
                progress = 1.01
            }
        }
    }
}

#Preview {
    LoadingView()
}
