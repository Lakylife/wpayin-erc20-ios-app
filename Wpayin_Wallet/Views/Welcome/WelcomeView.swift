//
//  WelcomeView.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var walletManager: WalletManager
    @State private var showCreateWallet = false
    @State private var showImportWallet = false

    var body: some View {
        ZStack {
            WpayinColors.background.ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Logo and Title
                VStack(spacing: 24) {
                    WpayinLogoView(size: 80)

                    VStack(spacing: 8) {
                        Text("Wpayin Wallet")
                            .font(.wpayinTitle)
                            .foregroundColor(WpayinColors.text)

                        Text("Secure, Simple, Decentralized")
                            .font(.wpayinSubheadline)
                            .foregroundColor(WpayinColors.textSecondary)
                    }
                }

                Spacer()

                // Action Buttons
                VStack(spacing: 16) {
                    WpayinButton(
                        title: "Create New Wallet",
                        style: .primary
                    ) {
                        showCreateWallet = true
                    }

                    WpayinButton(
                        title: "Import Existing Wallet",
                        style: .secondary
                    ) {
                        showImportWallet = true
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
            }
        }
        .sheet(isPresented: $showCreateWallet) {
            CreateWalletFlow()
                .environmentObject(walletManager)
        }
        .sheet(isPresented: $showImportWallet) {
            ImportWalletView()
                .environmentObject(walletManager)
        }
    }
}

#Preview {
    WelcomeView()
        .environmentObject(WalletManager())
}