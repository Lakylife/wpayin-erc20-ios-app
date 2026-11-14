// Autor Lukas Helebrandt, 2026

//
//  QuintiumSettingsView.swift
//  Wpayin_Wallet
//
//  Network, node and explorer of the Quintium chain.
//

import SwiftUI

struct QuintiumSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var network: QuintiumNetwork = QuintiumSettings.network
    @State private var rpcUrl: String = QuintiumSettings.rpcUrl(for: QuintiumSettings.network)
    @State private var explorerUrl: String = QuintiumSettings.customExplorerUrl(for: QuintiumSettings.network) ?? ""
    @State private var checkState: CheckState = .idle
    @State private var savedMessage: String?

    private enum CheckState: Equatable {
        case idle
        case checking
        case ok(block: Int)
        case failed(String)
    }

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        header
                        networkPicker
                        nodeFields
                        parameters
                        saveButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Quinvium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done".localized) { dismiss() }
                        .foregroundColor(WpayinColors.primary)
                }
            }
            .onChange(of: network) { newValue in
                rpcUrl = QuintiumSettings.rpcUrl(for: newValue)
                explorerUrl = QuintiumSettings.customExplorerUrl(for: newValue) ?? ""
                checkState = .idle
                savedMessage = nil
            }
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(spacing: 12) {
            QuintiumIconMark(size: 72)
                .padding(.top, 20)
            Text("Quinvium (QU)")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(WpayinColors.text)
            Text("Our own Proof-of-Work blockchain, compatible with Ethereum. Your Quinvium address is the same as your Ethereum address.".localized)
                .font(.system(size: 14))
                .foregroundColor(WpayinColors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var networkPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Network".localized)
            Picker("Network".localized, selection: $network) {
                ForEach(QuintiumNetwork.allCases) { item in
                    Text(item.isTestnet ? "Testnet".localized : "Mainnet".localized).tag(item)
                }
            }
            .pickerStyle(.segmented)

            if network == .mainnet && !network.isLaunched {
                note(
                    icon: "clock",
                    text: "Mainnet starts on 1 January 2027. Until then use the testnet.".localized,
                    color: WpayinColors.warning
                )
            }
        }
    }

    private var nodeFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Node".localized)

            field(
                title: "RPC URL".localized,
                text: $rpcUrl,
                placeholder: "https://rpc.example.com"
            )
            if QuintiumSettings.isUnencryptedPublicURL(rpcUrl) {
                note(
                    icon: "lock.open",
                    text: "This connection is not encrypted (http). Anyone on the way can read or change the data. Use https if your node supports it.".localized,
                    color: WpayinColors.warning
                )
            }
            Text("Address of a Quinvium node with JSON-RPC (default port %@). There is no public node yet, so enter your own.".localized("\(network.defaultRpcPort)"))
                .font(.system(size: 12))
                .foregroundColor(WpayinColors.textTertiary)
            Text("At home use the local address, for example http://192.168.1.20:%@. Away from home use the public address of your connection, for example http://203.0.113.7:%@. The Quinvium app shows both under Network → Connect to another computer.".localized("\(network.defaultRpcPort)", "\(network.defaultRpcPort)"))
                .font(.system(size: 12))
                .foregroundColor(WpayinColors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            field(
                title: "Block Explorer URL".localized,
                text: $explorerUrl,
                placeholder: QuintiumSettings.explorerOrigin(of: rpcUrl) ?? "Automatic".localized
            )
            Text("Leave empty for automatic: the explorer built into the node, on the same address as RPC.".localized)
                .font(.system(size: 12))
                .foregroundColor(WpayinColors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: checkNode) {
                HStack(spacing: 8) {
                    if checkState == .checking {
                        ProgressView().tint(WpayinColors.primary)
                    } else {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                    }
                    Text("Test connection".localized)
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(WpayinColors.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12).fill(WpayinColors.surface))
            }
            .disabled(checkState == .checking)

            switch checkState {
            case .ok(let block):
                note(
                    icon: "checkmark.circle.fill",
                    text: "Connected. Chain ID %@, block %@.".localized("\(network.chainId)", "\(block)"),
                    color: WpayinColors.success
                )
            case .failed(let message):
                note(icon: "exclamationmark.triangle.fill", text: message, color: WpayinColors.error)
            default:
                EmptyView()
            }
        }
    }

    private var parameters: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Network parameters".localized)
            VStack(spacing: 1) {
                parameterRow("Chain ID".localized, "\(network.chainId)")
                parameterRow("Currency".localized, "\(network.symbol), 18 " + "decimals".localized)
                parameterRow("Block time".localized, "15 s")
                parameterRow("Address path".localized, "m/44'/60'/0'/0")
            }
            .background(WpayinColors.surface)
            .cornerRadius(12)
        }
    }

    private var saveButton: some View {
        VStack(spacing: 10) {
            Button(action: save) {
                Text("Save".localized)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(WpayinColors.primary))
            }
            if let savedMessage {
                Text(savedMessage)
                    .font(.system(size: 13))
                    .foregroundColor(WpayinColors.success)
            }
        }
    }

    // MARK: Actions

    private func checkNode() {
        let url = rpcUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let selected = network
        checkState = .checking
        Task {
            do {
                let status = try await QuintiumNodeClient.check(rpcUrl: url, network: selected)
                await MainActor.run { checkState = .ok(block: status.blockNumber) }
            } catch {
                await MainActor.run { checkState = .failed(error.localizedDescription) }
            }
        }
    }

    private func save() {
        let rpc = rpcUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let explorer = explorerUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if !rpc.isEmpty && !QuintiumSettings.isValidURL(rpc) {
            checkState = .failed(QuintiumNodeClient.NodeError.invalidURL.localizedDescription)
            return
        }
        QuintiumSettings.setRpcUrl(rpc, for: network)
        QuintiumSettings.setExplorerUrl(explorer, for: network)
        if QuintiumSettings.network != network {
            QuintiumSettings.network = network
        }
        savedMessage = "Saved".localized
    }

    // MARK: Building blocks

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(WpayinColors.text)
    }

    private func field(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(WpayinColors.textSecondary)
            TextField(placeholder, text: text)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .font(.system(size: 15, design: .monospaced))
                .foregroundColor(WpayinColors.text)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(WpayinColors.surface))
        }
    }

    private func parameterRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(WpayinColors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(WpayinColors.text)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func note(icon: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
            Text(text)
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundColor(color)
    }
}

/// Shown in Bridge and P2P while those features have no Quintium contracts yet,
/// so Quintium is visible there without pretending a route exists.
struct QuintiumUnavailableNote: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            QuintiumIconMark(size: 22)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(WpayinColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(WpayinColors.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(QuintiumIconMark.gold.opacity(0.35), lineWidth: 1))
    }
}
