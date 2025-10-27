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
                            Text("Manage Networks")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(WpayinColors.text)

                            Text("Enable or disable blockchain networks")
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
                        Text("Enabling a network will fetch balances and transactions for that blockchain.")
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
                    Button("Done") {
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
            // Blockchain Icon
            Circle()
                .fill(blockchainColor)
                .frame(width: 44, height: 44)
                .overlay(
                    Text(blockchain.platform.icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(blockchain.platform.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(WpayinColors.text)

                if let chainId = blockchain.chainId {
                    Text("Chain ID: \(chainId)")
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

    private var blockchainColor: Color {
        switch blockchain.platform {
        case .ethereum:
            return Color.blue
        case .bitcoin:
            return Color.orange
        case .polygon:
            return Color.purple
        case .bsc:
            return Color.yellow
        case .arbitrum:
            return Color.cyan
        case .optimism:
            return Color.red
        case .avalanche:
            return Color.pink
        default:
            return WpayinColors.primary
        }
    }
}

extension BlockchainPlatform {
    var icon: String {
        switch self {
        case .ethereum:
            return "Ξ"
        case .bitcoin:
            return "₿"
        case .polygon:
            return "◬"
        case .bsc:
            return "B"
        case .arbitrum:
            return "A"
        case .optimism:
            return "O"
        case .avalanche:
            return "Λ"
        default:
            return String(name.prefix(1))
        }
    }
}

#Preview {
    BlockchainSettingsView()
        .environmentObject(WalletManager())
}
