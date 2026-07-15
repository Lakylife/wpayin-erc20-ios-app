// Autor Lukas Helebrandt, 2026

//
//  DepositView.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct DepositView: View {
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedSymbol: String?
    @State private var selectedNetwork: BlockchainType?
    @State private var isShowingReceiveDetails: Bool
    @State private var qrCodeImage: UIImage?
    @State private var addressCopied = false
    @State private var showShareSheet = false
    @State private var showPaymentRequest = false

    init(initialToken: Token? = nil) {
        _selectedSymbol = State(initialValue: initialToken?.symbol.uppercased())
        _selectedNetwork = State(initialValue: initialToken?.blockchain)
        _isShowingReceiveDetails = State(initialValue: initialToken != nil)
    }

    private var selectedToken: Token? {
        guard let selectedSymbol, let selectedNetwork else { return nil }
        return availableTokensWithNetwork.first {
            $0.symbol.uppercased() == selectedSymbol.uppercased() && $0.blockchain == selectedNetwork
        }
    }

    private var selectedAssetTokens: [Token] {
        guard let selectedSymbol else { return [] }
        return availableTokensWithNetwork
            .filter { $0.symbol.uppercased() == selectedSymbol.uppercased() }
            .sorted { $0.blockchain.name < $1.blockchain.name }
    }

    private var isReceiveDetailsVisible: Bool {
        isShowingReceiveDetails && selectedToken != nil
    }

    var body: some View {
        NavigationView {
            ZStack {
                WalletFlowBackground()

                if isReceiveDetailsVisible, let token = selectedToken {
                    receiveDetails(for: token)
                } else {
                    selectionContent
                }
            }
            .navigationTitle(isReceiveDetailsVisible ? "Receive Crypto".localized : "Deposit".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    toolbarButton(systemName: "xmark", label: L10n.Action.close.localized) {
                        dismiss()
                    }
                }
            }
        }
        .depositSheetPresentation()
        .sheet(isPresented: $showShareSheet) {
            DepositShareSheet(activityItems: shareItems)
        }
        .sheet(isPresented: $showPaymentRequest) {
            if let token = selectedToken, let address = currentTokenAddress {
                PaymentRequestView(token: token, address: address)
            }
        }
        .onAppear {
            validateSelection()
            generateQRCode()
        }
        .onChange(of: selectedSymbol) { _ in
            validateNetworkForSelectedAsset()
            isShowingReceiveDetails = false
            generateQRCode()
        }
        .onChange(of: selectedNetwork) { _ in
            generateQRCode()
        }
        .onChange(of: walletManager.visibleSupportedTokens.map { "\($0.blockchain.rawValue):\($0.contractAddress ?? "native")" }) { _ in
            validateSelection()
            generateQRCode()
        }
    }

    private var selectionContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                DepositSelectionHeader()

                DepositAssetSelectionCard(
                    tokens: availableTokensWithNetwork,
                    selectedSymbol: $selectedSymbol,
                    selectedNetwork: $selectedNetwork
                )
                .environmentObject(settingsManager)

                if selectedSymbol != nil {
                    DepositNetworkSelectionCard(
                        tokens: selectedAssetTokens,
                        selectedNetwork: $selectedNetwork
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                WpayinButton(title: L10n.Action.continue, style: .primary) {
                    guard selectedToken != nil else { return }
                    withAnimation(.easeInOut(duration: 0.22)) {
                        isShowingReceiveDetails = true
                    }
                }
                .disabled(selectedToken == nil)
                .opacity(selectedToken == nil ? 0.45 : 1)
                .padding(.top, 2)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 32)
        }
    }

    private func receiveDetails(for token: Token) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                DepositAssetHeader(
                    token: token,
                    availableNetworks: selectedAssetTokens,
                    selectedNetwork: $selectedNetwork
                )

                if let address = currentTokenAddress, !address.isEmpty {
                    DepositQRCodeView(qrCodeImage: qrCodeImage)

                    DepositAddressView(
                        address: address,
                        copied: $addressCopied,
                        onCopy: { copyAddress(address) }
                    )

                    DepositWarningView(
                        tokenSymbol: token.symbol,
                        networkName: token.blockchain.name
                    )

                    if token.blockchain.isEVM || token.blockchain == .bitcoin {
                        WpayinButton(title: "Request payment", style: .primary) {
                            showPaymentRequest = true
                        }
                    }

                    WpayinButton(title: "Share address with sender", style: .secondary) {
                        showShareSheet = true
                    }
                } else {
                    MissingDepositAddressView()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 32)
        }
    }

    @ViewBuilder
    private func toolbarButton(
        systemName: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(WpayinColors.text)
                .frame(width: 32, height: 32)
                .background(Circle().fill(WpayinColors.surfaceLight))
        }
        .accessibilityLabel(label)
    }

    private var currentTokenAddress: String? {
        guard let token = selectedToken else { return nil }
        let address = walletManager.depositAddress(for: token)
        return address.isEmpty ? nil : address
    }

    private var availableTokensWithNetwork: [Token] {
        walletManager.visibleSupportedTokens
            .filter { token in
                let platform = BlockchainPlatform(rawValue: token.blockchain.rawValue) ?? .ethereum
                guard walletManager.selectedBlockchains.contains(platform) else { return false }
                return walletManager.availableBlockchains.contains { config in
                    config.platform == platform && config.network == .mainnet
                } && walletManager.hasActiveAccount(for: token.blockchain)
            }
            .sorted { first, second in
                if first.symbol.uppercased() == second.symbol.uppercased() {
                    return first.blockchain.name < second.blockchain.name
                }
                return first.symbol.uppercased() < second.symbol.uppercased()
            }
    }

    private func validateSelection() {
        guard let selectedSymbol else {
            selectedNetwork = nil
            isShowingReceiveDetails = false
            return
        }

        let symbolStillExists = availableTokensWithNetwork.contains {
            $0.symbol.uppercased() == selectedSymbol.uppercased()
        }
        guard symbolStillExists else {
            self.selectedSymbol = nil
            selectedNetwork = nil
            isShowingReceiveDetails = false
            return
        }

        validateNetworkForSelectedAsset()
    }

    private func validateNetworkForSelectedAsset() {
        guard let selectedSymbol else {
            selectedNetwork = nil
            return
        }

        let networks = availableTokensWithNetwork
            .filter { $0.symbol.uppercased() == selectedSymbol.uppercased() }
            .map { $0.blockchain }

        if let selectedNetwork, networks.contains(selectedNetwork) {
            return
        }

        selectedNetwork = networks.count == 1 ? networks.first : nil
    }

    private func generateQRCode() {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        guard let address = currentTokenAddress else {
            qrCodeImage = nil
            return
        }

        filter.message = Data(address.utf8)
        filter.correctionLevel = "H"

        guard let outputImage = filter.outputImage else {
            qrCodeImage = nil
            return
        }

        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            qrCodeImage = nil
            return
        }
        qrCodeImage = UIImage(cgImage: cgImage)
    }

    private func copyAddress(_ address: String) {
        AppToast.copyToClipboard(address)
        addressCopied = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            addressCopied = false
        }
    }

    private var shareItems: [Any] {
        guard let token = selectedToken, let address = currentTokenAddress else { return [] }
        let warning = "Only send %@ on %@ network to this address. Sending wrong tokens or using wrong network may result in permanent loss."
            .localized(token.symbol, token.blockchain.name)
        let message = "\(token.symbol) • \(token.blockchain.name)\n\(L10n.Bridge.receiveAddress.localized): \(address)\n\n\(warning)"
        return [message]
    }
}

private struct DepositSelectionHeader: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(WpayinColors.primary)
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(WpayinColors.primary.opacity(0.14))
                        .overlay(
                            Circle()
                                .stroke(WpayinColors.primary.opacity(0.18), lineWidth: 1)
                        )
                )

            Text("Receive Crypto".localized)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(WpayinColors.text)

            Text("Select Asset & Network".localized)
                .font(.system(size: 14))
                .foregroundColor(WpayinColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 2)
    }
}

private struct DepositAssetSelectionCard: View {
    let tokens: [Token]
    @Binding var selectedSymbol: String?
    @Binding var selectedNetwork: BlockchainType?
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var showAssetPicker = false

    private var representativeToken: Token? {
        guard let selectedSymbol else { return nil }
        return tokens.first { $0.symbol.uppercased() == selectedSymbol.uppercased() }
    }

    private var totalBalance: Double {
        guard let selectedSymbol else { return 0 }
        return tokens
            .filter { $0.symbol.uppercased() == selectedSymbol.uppercased() }
            .reduce(0) { $0 + $1.balance }
    }

    var body: some View {
        DepositSelectionCard(title: "Select Asset".localized, isComplete: selectedSymbol != nil) {
            Button {
                showAssetPicker = true
            } label: {
                HStack(spacing: 13) {
                    if let token = representativeToken {
                        TokenIconView(token: token, size: 38, showNetworkBadge: false)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(token.symbol.uppercased())
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(WpayinColors.text)

                            Text(TokenIconHelper.formattedBalanceWithSymbol(
                                totalBalance,
                                symbol: token.symbol,
                                decimals: 4
                            ))
                            .font(.system(size: 12))
                            .foregroundColor(WpayinColors.textSecondary)
                        }
                    } else {
                        Image(systemName: "coloncurrencysign.circle.fill")
                            .font(.system(size: 21))
                            .foregroundColor(WpayinColors.primary)
                            .frame(width: 38, height: 38)

                        Text(L10n.Tokens.selectToken.localized)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(WpayinColors.text)
                    }

                    Spacer()

                    Image(systemName: selectedSymbol == nil ? "chevron.right" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(WpayinColors.textTertiary)
                }
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(WpayinPressableStyle())
        }
        .sheet(isPresented: $showAssetPicker) {
            AssetPickerSheet(tokens: tokens, selectedSymbol: selectedSymbol) { symbol in
                selectedNetwork = nil
                selectedSymbol = symbol

                let matchingTokens = tokens.filter {
                    $0.symbol.uppercased() == symbol.uppercased()
                }
                if matchingTokens.count == 1 {
                    selectedNetwork = matchingTokens.first?.blockchain
                }
            }
            .environmentObject(settingsManager)
        }
    }
}

private struct DepositNetworkSelectionCard: View {
    let tokens: [Token]
    @Binding var selectedNetwork: BlockchainType?
    @State private var showNetworkPicker = false

    private var selectedToken: Token? {
        guard let selectedNetwork else { return nil }
        return tokens.first { $0.blockchain == selectedNetwork }
    }

    var body: some View {
        DepositSelectionCard(
            title: L10n.Swap.selectNetwork.localized,
            isComplete: selectedToken != nil
        ) {
            Button {
                showNetworkPicker = true
            } label: {
                HStack(spacing: 13) {
                    if let token = selectedToken {
                        NetworkIconView(blockchain: token.blockchain, size: 36)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(token.blockchain.name)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(WpayinColors.text)

                            if let tokenProtocol = token.tokenProtocol, !tokenProtocol.shortName.isEmpty {
                                Text(tokenProtocol.shortName)
                                    .font(.system(size: 12))
                                    .foregroundColor(WpayinColors.textSecondary)
                            }
                        }
                    } else {
                        Image(systemName: "network")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(WpayinColors.primary)
                            .frame(width: 36, height: 36)

                        Text(L10n.Swap.selectNetwork.localized)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(WpayinColors.text)
                    }

                    Spacer()

                    Image(systemName: selectedToken == nil ? "chevron.right" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(WpayinColors.textTertiary)
                }
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(WpayinPressableStyle())
        }
        .sheet(isPresented: $showNetworkPicker) {
            NetworkPickerSheet(
                tokens: tokens,
                selectedNetwork: selectedNetwork
            ) { network in
                selectedNetwork = network
            }
        }
    }
}

private struct DepositSelectionCard<Content: View>: View {
    let title: String
    let isComplete: Bool
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(WpayinColors.text)

                Spacer()

                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(WpayinColors.success)
                }
            }

            content
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(WpayinColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                )
        )
    }
}

private struct DepositAssetHeader: View {
    let token: Token
    let availableNetworks: [Token]
    @Binding var selectedNetwork: BlockchainType?
    @State private var showNetworkPicker = false

    var body: some View {
        VStack(spacing: 10) {
            TokenIconView(token: token, size: 64, showNetworkBadge: false)

            Text(token.symbol.uppercased())
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(WpayinColors.text)

            Button {
                showNetworkPicker = true
            } label: {
                HStack(spacing: 7) {
                    NetworkIconView(blockchain: token.blockchain, size: 18)

                    Text(token.blockchain.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(WpayinColors.textSecondary)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(WpayinColors.textTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(WpayinColors.surface)
                        .overlay(
                            Capsule()
                                .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(WpayinPressableStyle())
            .accessibilityLabel(L10n.Swap.selectNetwork.localized)

            Text("Send funds to your %@ address".localized(token.symbol))
                .font(.system(size: 14))
                .foregroundColor(WpayinColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 2)
        .sheet(isPresented: $showNetworkPicker) {
            NetworkPickerSheet(
                tokens: availableNetworks,
                selectedNetwork: selectedNetwork
            ) { network in
                selectedNetwork = network
            }
        }
    }
}

private struct DepositQRCodeView: View {
    let qrCodeImage: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
                .frame(width: 248, height: 248)
                .shadow(color: WpayinColors.primary.opacity(0.15), radius: 20, x: 0, y: 9)

            if let qrCodeImage {
                Image(uiImage: qrCodeImage)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 210, height: 210)

                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.white)
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image("WpayinLogo")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(.black)
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 2)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: WpayinColors.primary))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .accessibilityLabel("QR Code".localized)
    }
}

private struct DepositAddressView: View {
    let address: String
    @Binding var copied: Bool
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.Bridge.receiveAddress.localized)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(WpayinColors.text)

            HStack(spacing: 12) {
                Text(address)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(WpayinColors.text)
                    .lineLimit(2)
                    .textSelection(.enabled)

                Spacer(minLength: 4)

                Button(action: onCopy) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(copied ? WpayinColors.success : WpayinColors.primary)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(WpayinColors.primary.opacity(0.10)))
                }
                .buttonStyle(WpayinPressableStyle())
                .accessibilityLabel(copied ? "Copied!".localized : L10n.Action.copy.localized)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(WpayinColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                )
        )
    }
}

private struct MissingDepositAddressView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wallet.pass")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(WpayinColors.textSecondary)

            Text("Wallet address not available".localized)
                .font(.wpayinSubheadline)
                .foregroundColor(WpayinColors.text)

            Text("Create or import a wallet for this network before receiving funds.".localized)
                .font(.wpayinBody)
                .foregroundColor(WpayinColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(WpayinColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                )
        )
    }
}

private struct DepositWarningView: View {
    let tokenSymbol: String
    let networkName: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(WpayinColors.warning)
                .font(.system(size: 19))

            VStack(alignment: .leading, spacing: 4) {
                Text("Important".localized)
                    .font(.wpayinSubheadline)
                    .foregroundColor(WpayinColors.warning)

                Text("Only send %@ on %@ network to this address. Sending wrong tokens or using wrong network may result in permanent loss."
                    .localized(tokenSymbol, networkName))
                    .font(.wpayinCaption)
                    .foregroundColor(WpayinColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(WpayinColors.warning.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(WpayinColors.warning.opacity(0.20), lineWidth: 1)
                )
        )
    }
}

private struct DepositShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private extension View {
    @ViewBuilder
    func depositSheetPresentation() -> some View {
        if #available(iOS 16.4, *) {
            self
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(28)
        } else if #available(iOS 16.0, *) {
            self
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        } else {
            self
        }
    }
}

#Preview {
    DepositView()
        .environmentObject(WalletManager())
        .environmentObject(SettingsManager())
}
