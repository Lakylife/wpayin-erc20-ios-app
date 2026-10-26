// Autor Lukas Helebrandt, 2026

//
//  BuyView.swift
//  Wpayin_Wallet
//
//  P2P-only entry point: Wpayin is a non-custodial interface — trades settle
//  wallet-to-wallet through an on-chain atomic swap contract. No fiat
//  on-ramp, no funds ever held by the app.
//

import SwiftUI

struct BuyView: View {
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var showP2PTrade = false

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 54))
                                .foregroundColor(WpayinColors.primary)

                            Text("P2P Exchange".localized)
                                .font(.wpayinTitle)
                                .foregroundColor(WpayinColors.text)

                            Text("Trade tokens directly with another Wpayin user. Both sides settle wallet-to-wallet in a single on-chain transaction — no intermediary ever holds your funds.".localized)
                                .font(.wpayinBody)
                                .foregroundColor(WpayinColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.top, 20)

                        // Primary action
                        Button {
                            showP2PTrade = true
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 46, height: 46)
                                    .background(Circle().fill(Color.white.opacity(0.14)))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Start P2P Trade".localized)
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)

                                    Text("Trade directly with another Wpayin user".localized)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color.white.opacity(0.75))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color.white.opacity(0.7))
                            }
                            .padding(18)
                            .background(
                                RoundedRectangle(cornerRadius: WpayinRadius.card, style: .continuous)
                                    .fill(WpayinColors.accentGradient)
                                    .shadow(color: WpayinColors.primary.opacity(0.25), radius: 16, y: 8)
                            )
                        }
                        .buttonStyle(WpayinPressableStyle())
                        .padding(.horizontal)

                        // How it works
                        VStack(alignment: .leading, spacing: 16) {
                            Text("How it works".localized)
                                .font(.wpayinHeadline)
                                .foregroundColor(WpayinColors.text)

                            P2PHowItWorksRow(
                                index: 1,
                                icon: "doc.text",
                                title: "Create or accept an offer".localized,
                                subtitle: "Agree with your counterparty on the tokens and amounts to exchange.".localized
                            )

                            P2PHowItWorksRow(
                                index: 2,
                                icon: "signature",
                                title: "Review and sign".localized,
                                subtitle: "Each side authorizes the trade from their own wallet — keys never leave the device.".localized
                            )

                            P2PHowItWorksRow(
                                index: 3,
                                icon: "link",
                                title: "Atomic on-chain settlement".localized,
                                subtitle: "A smart contract exchanges both tokens in one transaction — either both transfer or neither does.".localized
                            )
                        }
                        .padding(18)
                        .background(
                            RoundedRectangle(cornerRadius: WpayinRadius.card, style: .continuous)
                                .fill(WpayinColors.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: WpayinRadius.card, style: .continuous)
                                        .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                                )
                        )
                        .padding(.horizontal)

                        // Non-custodial note
                        HStack(spacing: 10) {
                            Image(systemName: "lock.shield")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(WpayinColors.success)

                            Text("Wpayin never holds your funds and does not process fiat payments.".localized)
                                .font(.wpayinCaption)
                                .foregroundColor(WpayinColors.textSecondary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.horizontal, 28)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("P2P Exchange".localized)
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showP2PTrade) {
            P2PTradeView()
                .environmentObject(walletManager)
                .environmentObject(settingsManager)
        }
    }
}

private struct P2PHowItWorksRow: View {
    let index: Int
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(WpayinColors.primary)
                .frame(width: 36, height: 36)
                .background(Circle().fill(WpayinColors.primary.opacity(0.12)))

            VStack(alignment: .leading, spacing: 4) {
                Text("\(index). \(title)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(WpayinColors.text)

                Text(subtitle)
                    .font(.wpayinCaption)
                    .foregroundColor(WpayinColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    BuyView()
        .environmentObject(WalletManager())
        .environmentObject(SettingsManager())
}
