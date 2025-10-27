//
//  BrowserView.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI

struct BrowserView: View {
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var searchText = ""

    var body: some View {
        ZStack {
            // Background gradient matching mockup
            LinearGradient(
                gradient: Gradient(colors: [
                    WpayinColors.backgroundGradientStart,
                    WpayinColors.backgroundGradientEnd
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(.all)

            VStack(spacing: 0) {
                // Modern Header
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 50)

                    HStack {
                        Text("Browser")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(WpayinColors.text)

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    // Search Bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(WpayinColors.textSecondary)

                        TextField("Search DApps...", text: $searchText)
                            .font(.wpayinBody)
                            .foregroundColor(WpayinColors.text)

                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(WpayinColors.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(WpayinColors.surface)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            WpayinColors.headerBackground,
                            Color.clear
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Popular DApps Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Popular DApps")
                                .font(.wpayinHeadline)
                                .foregroundColor(WpayinColors.text)
                                .padding(.horizontal, 20)

                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 16) {
                                DAppCard(name: "Uniswap", icon: "arrow.swap", color: .pink)
                                DAppCard(name: "Aave", icon: "chart.bar.fill", color: .purple)
                                DAppCard(name: "Compound", icon: "dollarsign.circle.fill", color: .green)
                                DAppCard(name: "OpenSea", icon: "cube.fill", color: .blue)
                                DAppCard(name: "1inch", icon: "arrow.triangle.swap", color: .red)
                                DAppCard(name: "Curve", icon: "chart.line.uptrend.xyaxis", color: .cyan)
                            }
                            .padding(.horizontal, 20)
                        }

                        // Bottom padding for tab bar
                        Spacer()
                            .frame(height: 100)
                    }
                    .padding(.top, 20)
                }
            }
        }
    }
}

struct DAppCard: View {
    let name: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
            }

            Text(name)
                .font(.wpayinCaption)
                .foregroundColor(WpayinColors.text)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(WpayinColors.surface)
        .cornerRadius(16)
    }
}

#Preview {
    BrowserView()
        .environmentObject(WalletManager())
        .environmentObject(SettingsManager())
}
