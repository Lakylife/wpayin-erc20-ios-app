// Autor Lukas Helebrandt, 2026

//
//  BlockchainSettingsView.swift
//  Wpayin_Wallet
//
//  Created by Claude Code
//

import SwiftUI

struct BlockchainSettingsView: View {
    @EnvironmentObject var walletManager: WalletManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Manage Networks".localized)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(WpayinColors.text)

                            Text("Enable or disable blockchain networks".localized)
                                .font(.system(size: 14))
                                .foregroundColor(WpayinColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                        // Networks List
                        VStack(spacing: 1) {
                            ForEach(walletManager.availableBlockchains.filter { $0.network == .mainnet }) { blockchain in
                                BlockchainRow(
                                    blockchain: blockchain,
                                    isEnabled: walletManager.selectedBlockchains.contains(blockchain.platform),
                                    onToggle: {
                                        walletManager.toggleBlockchain(blockchain.platform)
                                    }
                                )
                            }
                        }
                        .background(WpayinColors.surface)
                        .cornerRadius(16)
                        .padding(.horizontal, 20)

                        // Info text
                        Text("Enabling a network will fetch balances and transactions for that blockchain.".localized)
                            .font(.system(size: 13))
                            .foregroundColor(WpayinColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done".localized) {
                        dismiss()
                    }
                    .foregroundColor(WpayinColors.primary)
                }
            }
        }
    }
}

struct BlockchainRow: View {
    let blockchain: BlockchainConfig
    let isEnabled: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            PlatformIconView(platform: blockchain.platform, size: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(blockchain.platform.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(WpayinColors.text)

                if let chainId = blockchain.chainId {
                    Text("Chain ID: %@".localized("\(chainId)"))
                        .font(.system(size: 13))
                        .foregroundColor(WpayinColors.textSecondary)
                }
            }

            Spacer()

            // Toggle Switch
            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { _ in onToggle() }
            ))
            .tint(WpayinColors.primary)
        }
        .padding(16)
        .background(WpayinColors.surface)
    }

}

#Preview {
    BlockchainSettingsView()
        .environmentObject(WalletManager())
}
