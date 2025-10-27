//
//  LoadingView.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI

struct LoadingView: View {
    @State private var rotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var opacity: Double = 0.0

    var body: some View {
        ZStack {
            // Background - solid black for modern look
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo with multiple animation layers
                ZStack {
                    // Outer rotating ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    WpayinColors.primary.opacity(0.6),
                                    WpayinColors.primary.opacity(0.1),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(rotation))

                    // Middle pulsing ring
                    Circle()
                        .stroke(
                            WpayinColors.primary.opacity(0.3),
                            lineWidth: 1
                        )
                        .frame(width: 120, height: 120)
                        .scaleEffect(pulseScale)

                    // Logo container with glow
                    ZStack {
                        // Glow effect
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        WpayinColors.primary.opacity(0.3),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 50
                                )
                            )
                            .frame(width: 100, height: 100)
                            .blur(radius: 10)

                        // Logo image
                        Image("WpayinLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .cornerRadius(16)
                            .shadow(color: WpayinColors.primary.opacity(0.5), radius: 20, x: 0, y: 0)
                    }
                }
                .opacity(opacity)

                Spacer()

                // Modern loading dots
                ModernLoadingDots()
                    .padding(.bottom, 60)
                    .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.6)) {
                opacity = 1.0
            }

            // Rotating ring animation
            withAnimation(
                Animation.linear(duration: 3.0)
                    .repeatForever(autoreverses: false)
            ) {
                rotation = 360
            }

            // Pulsing animation
            withAnimation(
                Animation.easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
            ) {
                pulseScale = 1.1
            }
        }
    }
}

struct ModernLoadingDots: View {
    @State private var currentDot = 0
    let dotCount = 3

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<dotCount, id: \.self) { index in
                Circle()
                    .fill(WpayinColors.primary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(currentDot == index ? 1.3 : 1.0)
                    .opacity(currentDot == index ? 1.0 : 0.3)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: false),
                        value: currentDot
                    )
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                withAnimation {
                    currentDot = (currentDot + 1) % dotCount
                }
            }
        }
    }
}

#Preview {
    LoadingView()
}