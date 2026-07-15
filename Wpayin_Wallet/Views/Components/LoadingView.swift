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
    @State private var logoPulsing = false
    @State private var orbitRotation: Double = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LaunchBackground()

                VStack(spacing: 0) {
                    Spacer(minLength: geometry.safeAreaInsets.top + 28)

                    VStack(spacing: 28) {
                        LaunchBrandMark(
                            isPulsing: logoPulsing,
                            orbitRotation: orbitRotation
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
                        .padding(.bottom, max(geometry.safeAreaInsets.bottom, 20) + 22)
                        .offset(y: contentVisible ? 0 : 16)
                        .opacity(contentVisible ? 1 : 0)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Preparing your wallet".localized)
        .onAppear {
            withAnimation(.spring(response: 0.75, dampingFraction: 0.86)) {
                contentVisible = true
            }

            guard !reduceMotion else { return }

            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                logoPulsing = true
            }
            withAnimation(.linear(duration: 1.7).repeatForever(autoreverses: false)) {
                orbitRotation = 360
            }
        }
    }
}

private struct LaunchBackground: View {
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

            Circle()
                .fill(WpayinColors.primary.opacity(0.11))
                .frame(width: 300, height: 300)
                .blur(radius: 100)
                .offset(x: -95, y: -240)

            Circle()
                .fill(WpayinColors.accent.opacity(0.06))
                .frame(width: 250, height: 250)
                .blur(radius: 105)
                .offset(x: 110, y: 285)

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
    let isPulsing: Bool
    let orbitRotation: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            WpayinColors.primary.opacity(isPulsing ? 0.13 : 0.07),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 92
                    )
                )
                .frame(width: 190, height: 190)
                .scaleEffect(isPulsing ? 1.035 : 0.98)

            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
                .frame(width: 154, height: 154)

            Circle()
                .trim(from: 0.03, to: 0.27)
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.clear,
                            WpayinColors.primary,
                            Color.white.opacity(0.9),
                            WpayinColors.accent,
                            Color.clear
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .frame(width: 154, height: 154)
                .rotationEffect(.degrees(orbitRotation))
                .shadow(color: WpayinColors.primary.opacity(0.65), radius: 6)

            Circle()
                .fill(Color.white)
                .frame(width: 6, height: 6)
                .shadow(color: WpayinColors.primary, radius: 7)
                .offset(y: -77)
                .rotationEffect(.degrees(orbitRotation + 97))

            Image("WpayinLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 104, height: 104)
                .scaleEffect(isPulsing ? 1.015 : 1)
        }
        .frame(width: 190, height: 190)
    }
}

private struct LaunchStatusPanel: View {
    let reduceMotion: Bool

    var body: some View {
        VStack(spacing: 12) {
            LaunchProgressBar(reduceMotion: reduceMotion)
                .frame(width: 112, height: 3)

            Text("Preparing your wallet".localized)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(WpayinColors.textSecondary)
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
            withAnimation(.easeInOut(duration: 0.95).repeatForever(autoreverses: false)) {
                progress = 1.04
            }
        }
    }
}

#Preview {
    LoadingView()
}
