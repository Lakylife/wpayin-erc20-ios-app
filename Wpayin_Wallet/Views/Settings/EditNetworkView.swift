//
//  EditNetworkView.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI

struct EditNetworkView: View {
    @EnvironmentObject var networkManager: NetworkConfigManager
    @Environment(\.dismiss) private var dismiss

    let network: NetworkConfig
    @State private var editedNetwork: NetworkConfig
    @State private var showSaveAlert = false

    init(network: NetworkConfig) {
        self.network = network
        _editedNetwork = State(initialValue: network)
    }

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Network Icon
                        Circle()
                            .fill(editedNetwork.color)
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text(editedNetwork.iconSymbol)
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .padding(.top, 20)

                        // Form Fields
                        VStack(spacing: 16) {
                            FormField(
                                title: "Network Name",
                                value: $editedNetwork.name,
                                placeholder: "e.g., Ethereum Mainnet",
                                isEditable: editedNetwork.isCustom
                            )

                            FormField(
                                title: "Chain ID",
                                value: Binding(
                                    get: { String(editedNetwork.chainId) },
                                    set: { editedNetwork.chainId = Int($0) ?? editedNetwork.chainId }
                                ),
                                placeholder: "1",
                                keyboardType: .numberPad,
                                isEditable: editedNetwork.isCustom
                            )

                            FormField(
                                title: "RPC URL",
                                value: $editedNetwork.rpcUrl,
                                placeholder: "https://...",
                                keyboardType: .URL
                            )

                            FormField(
                                title: "Currency Symbol",
                                value: $editedNetwork.symbol,
                                placeholder: "ETH",
                                isEditable: editedNetwork.isCustom
                            )

                            FormField(
                                title: "Block Explorer URL",
                                value: $editedNetwork.blockExplorerUrl,
                                placeholder: "https://etherscan.io",
                                keyboardType: .URL
                            )

                            // Testnet Toggle (only for custom networks)
                            if editedNetwork.isCustom {
                                HStack {
                                    Text("Testnet")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(WpayinColors.text)

                                    Spacer()

                                    Toggle("", isOn: $editedNetwork.isTestnet)
                                        .tint(WpayinColors.primary)
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(WpayinColors.surface)
                                )
                            }
                        }
                        .padding(.horizontal, 20)

                        // Save Button
                        Button(action: saveNetwork) {
                            Text("Save Changes")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(WpayinColors.primary)
                                )
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Edit Network")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(WpayinColors.text)
                }
            }
            .alert("Network Updated", isPresented: $showSaveAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Network configuration has been saved successfully.")
            }
        }
    }

    private func saveNetwork() {
        networkManager.updateNetwork(editedNetwork)
        showSaveAlert = true
    }
}

struct AddNetworkView: View {
    @EnvironmentObject var networkManager: NetworkConfigManager
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var chainId = ""
    @State private var rpcUrl = ""
    @State private var symbol = ""
    @State private var blockExplorerUrl = ""
    @State private var isTestnet = false
    @State private var showSuccessAlert = false

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Icon Placeholder
                        Circle()
                            .fill(WpayinColors.primary.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "network")
                                    .font(.system(size: 36))
                                    .foregroundColor(WpayinColors.primary)
                            )
                            .padding(.top, 20)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Add Custom Network")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(WpayinColors.text)

                            Text("Add a custom EVM-compatible network to your wallet")
                                .font(.system(size: 14))
                                .foregroundColor(WpayinColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)

                        // Form Fields
                        VStack(spacing: 16) {
                            FormField(
                                title: "Network Name",
                                value: $name,
                                placeholder: "e.g., My Custom Network"
                            )

                            FormField(
                                title: "Chain ID",
                                value: $chainId,
                                placeholder: "1",
                                keyboardType: .numberPad
                            )

                            FormField(
                                title: "RPC URL",
                                value: $rpcUrl,
                                placeholder: "https://rpc.example.com",
                                keyboardType: .URL
                            )

                            FormField(
                                title: "Currency Symbol",
                                value: $symbol,
                                placeholder: "ETH"
                            )

                            FormField(
                                title: "Block Explorer URL",
                                value: $blockExplorerUrl,
                                placeholder: "https://explorer.example.com",
                                keyboardType: .URL
                            )

                            // Testnet Toggle
                            HStack {
                                Text("Testnet")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(WpayinColors.text)

                                Spacer()

                                Toggle("", isOn: $isTestnet)
                                    .tint(WpayinColors.primary)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(WpayinColors.surface)
                            )
                        }
                        .padding(.horizontal, 20)

                        // Add Button
                        Button(action: addNetwork) {
                            Text("Add Network")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(isFormValid ? WpayinColors.primary : WpayinColors.textTertiary)
                                )
                        }
                        .disabled(!isFormValid)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Add Network")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(WpayinColors.text)
                }
            }
            .alert("Network Added", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("\(name) has been added successfully.")
            }
        }
    }

    private var isFormValid: Bool {
        !name.isEmpty &&
        !chainId.isEmpty &&
        Int(chainId) != nil &&
        !rpcUrl.isEmpty &&
        rpcUrl.hasPrefix("http") &&
        !symbol.isEmpty
    }

    private func addNetwork() {
        guard isFormValid, let chainIdInt = Int(chainId) else { return }

        let newNetwork = NetworkConfig(
            name: name,
            chainId: chainIdInt,
            rpcUrl: rpcUrl,
            symbol: symbol,
            blockExplorerUrl: blockExplorerUrl.isEmpty ? "" : blockExplorerUrl,
            isTestnet: isTestnet,
            isCustom: true,
            blockchain: .ethereum // Default to ethereum type for custom networks
        )

        networkManager.addCustomNetwork(newNetwork)
        showSuccessAlert = true
    }
}

struct FormField: View {
    let title: String
    @Binding var value: String
    let placeholder: String
    var keyboardType: UIKeyboardType = .default
    var isEditable: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(WpayinColors.textSecondary)

            if isEditable {
                TextField(placeholder, text: $value)
                    .font(.system(size: 16))
                    .foregroundColor(WpayinColors.text)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(WpayinColors.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                            )
                    )
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            } else {
                Text(value)
                    .font(.system(size: 16))
                    .foregroundColor(WpayinColors.textSecondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(WpayinColors.surface.opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(WpayinColors.surfaceBorder.opacity(0.5), lineWidth: 1)
                            )
                    )
            }
        }
    }
}

//#Preview {
//    EditNetworkView(network: NetworkConfig.defaultNetworks[0])
//        .environmentObject(NetworkConfigManager())
//}
