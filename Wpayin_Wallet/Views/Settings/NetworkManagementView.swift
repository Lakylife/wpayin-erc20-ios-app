//
//  NetworkManagementView.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI

struct NetworkManagementView: View {
    @EnvironmentObject var networkManager: NetworkConfigManager
    @Environment(\.dismiss) private var dismiss
    @State private var showAddNetwork = false
    @State private var selectedNetwork: NetworkConfig?

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

                            Text("Configure RPC endpoints and add custom networks")
                                .font(.system(size: 14))
                                .foregroundColor(WpayinColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                        // Default Networks Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Default Networks")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(WpayinColors.text)
                                .padding(.horizontal, 20)

                            VStack(spacing: 1) {
                                ForEach(networkManager.networks.filter { !$0.isCustom }) { network in
                                    NetworkRow(network: network) {
                                        selectedNetwork = network
                                    }
                                }
                            }
                            .background(WpayinColors.surface)
                            .cornerRadius(16)
                            .padding(.horizontal, 20)
                        }

                        // Custom Networks Section
                        if networkManager.networks.contains(where: { $0.isCustom }) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Custom Networks")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(WpayinColors.text)
                                    .padding(.horizontal, 20)

                                VStack(spacing: 1) {
                                    ForEach(networkManager.networks.filter { $0.isCustom }) { network in
                                        NetworkRow(network: network, isDeletable: true) {
                                            selectedNetwork = network
                                        } onDelete: {
                                            networkManager.deleteNetwork(network)
                                        }
                                    }
                                }
                                .background(WpayinColors.surface)
                                .cornerRadius(16)
                                .padding(.horizontal, 20)
                            }
                        }

                        // Add Custom Network Button
                        Button(action: { showAddNetwork = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                                Text("Add Custom Network")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(WpayinColors.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(WpayinColors.surface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(WpayinColors.primary.opacity(0.3), lineWidth: 1.5)
                                    )
                            )
                        }
                        .padding(.horizontal, 20)
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
            .sheet(isPresented: $showAddNetwork) {
                AddNetworkView()
                    .environmentObject(networkManager)
            }
            .sheet(item: $selectedNetwork) { network in
                EditNetworkView(network: network)
                    .environmentObject(networkManager)
            }
        }
    }
}

struct NetworkRow: View {
    let network: NetworkConfig
    var isDeletable: Bool = false
    let onTap: () -> Void
    var onDelete: (() -> Void)? = nil

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Network Icon
                Circle()
                    .fill(network.color)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(network.iconSymbol)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(network.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(WpayinColors.text)

                        if network.isTestnet {
                            Text("TESTNET")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.orange.opacity(0.1))
                                )
                        }

                        if network.isCustom {
                            Text("CUSTOM")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(WpayinColors.primary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(WpayinColors.primary.opacity(0.1))
                                )
                        }
                    }

                    Text("Chain ID: \(network.chainId)")
                        .font(.system(size: 13))
                        .foregroundColor(WpayinColors.textSecondary)

                    Text(network.rpcUrl)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(WpayinColors.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                if isDeletable, let deleteAction = onDelete {
                    Button(action: deleteAction) {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundColor(.red)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(Color.red.opacity(0.1))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(WpayinColors.textTertiary)
                }
            }
            .padding(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

//#Preview {
//    NetworkManagementView()
//        .environmentObject(NetworkConfigManager())
//}
