// Autor Lukas Helebrandt, 2026

import SwiftUI
import ReownWalletKit

struct WalletConnectView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var service = WalletConnectService.shared
    @State private var uri = ""
    @State private var showScanner = false
    @FocusState private var uriFocused: Bool

    var body: some View {
        NavigationView {
            ZStack {
                WalletFlowBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        header

                        if service.isConfigured {
                            connectCard
                            sessionsSection
                            securityNotice
                        } else {
                            setupCard
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 34)
                }
            }
            .navigationTitle("WalletConnect".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(WpayinColors.text)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(WpayinColors.surfaceLight))
                    }
                    .accessibilityLabel(L10n.Action.close.localized)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done".localized) { uriFocused = false }
                }
            }
        }
        .sheet(isPresented: $showScanner) {
            WalletConnectScannerSheet { result in
                showScanner = false
                Task { await service.pair(uriString: result) }
            }
        }
        .alert("WalletConnect".localized, isPresented: errorBinding) {
            Button("OK".localized) { service.errorMessage = nil }
        } message: {
            Text(service.errorMessage ?? "")
        }
        .onAppear {
            service.configureIfNeeded()
            service.reloadSessions()
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { service.errorMessage != nil },
            set: { if !$0 { service.errorMessage = nil } }
        )
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "link.circle.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(WpayinColors.primary)
                .frame(width: 70, height: 70)
                .background(Circle().fill(WpayinColors.primary.opacity(0.12)))

            Text("Connect to dApps".localized)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(WpayinColors.text)

            Text("Scan a WalletConnect QR code or paste a connection link.".localized)
                .font(.system(size: 14))
                .foregroundColor(WpayinColors.textSecondary)
                .multilineTextAlignment(.center)

            if service.isConfigured {
                Label(
                    service.isSocketConnected ? "Relay connected".localized : "Relay reconnecting".localized,
                    systemImage: service.isSocketConnected ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath"
                )
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(service.isSocketConnected ? WpayinColors.success : WpayinColors.warning)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var connectCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New connection".localized)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(WpayinColors.text)

            TextField("wc:…", text: $uri)
                .focused($uriFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(WpayinColors.text)
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(WpayinColors.surfaceLight)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                        )
                )

            HStack(spacing: 10) {
                Button {
                    uriFocused = false
                    showScanner = true
                } label: {
                    Label("Scan QR".localized, systemImage: "qrcode.viewfinder")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(WpayinColors.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(WpayinColors.primary.opacity(0.10))
                        )
                }
                .buttonStyle(WpayinPressableStyle())

                Button {
                    uriFocused = false
                    if let clipboard = UIPasteboard.general.string {
                        uri = clipboard.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                } label: {
                    Label("Paste".localized, systemImage: "doc.on.clipboard")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(WpayinColors.text)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(WpayinColors.surfaceLight)
                        )
                }
                .buttonStyle(WpayinPressableStyle())
            }

            Button {
                uriFocused = false
                let value = uri
                Task {
                    await service.pair(uriString: value)
                    if service.errorMessage == nil { uri = "" }
                }
            } label: {
                HStack(spacing: 9) {
                    if service.isPairing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "link")
                        Text("Connect".localized)
                    }
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    uri.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || service.isPairing
                        ? AnyShapeStyle(WpayinColors.surfaceLight)
                        : AnyShapeStyle(WpayinColors.accentGradient)
                )
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(WpayinPressableStyle())
            .disabled(uri.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || service.isPairing)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(WpayinColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                )
        )
    }

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Active dApp connections".localized)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(WpayinColors.text)

                Spacer()

                Text("\(service.sessions.count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(WpayinColors.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(WpayinColors.primary.opacity(0.12)))
            }

            if service.sessions.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "link.badge.plus")
                        .font(.system(size: 26))
                        .foregroundColor(WpayinColors.textTertiary)

                    Text("No active connections".localized)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(WpayinColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 26)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(WpayinColors.surface)
                )
            } else {
                VStack(spacing: 1) {
                    ForEach(service.sessions, id: \.topic) { session in
                        WalletConnectSessionRow(session: session) {
                            Task { await service.disconnect(session) }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }

    private var securityNotice: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(WpayinColors.primary)

            Text("Connecting shares only your public address. Every signature and transaction still requires a separate confirmation. Disconnect dApps you no longer use.".localized)
                .font(.system(size: 12))
                .foregroundColor(WpayinColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(17)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(WpayinColors.primary.opacity(0.08))
        )
    }

    private var setupCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 28))
                .foregroundColor(WpayinColors.warning)

            Text("WalletConnect setup required".localized)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(WpayinColors.text)

            Text("Create a public Project ID in Reown Cloud and set WALLETCONNECT_PROJECT_ID in the app's Release build settings. No secret key belongs in the app.".localized)
                .font(.system(size: 13))
                .foregroundColor(WpayinColors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("The App Group capability must also contain group.io.noriskservis.standart.Wpayin-Wallet.".localized)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(WpayinColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(WpayinColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(WpayinColors.warning.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

private struct WalletConnectSessionRow: View {
    let session: Session
    let onDisconnect: () -> Void
    @State private var confirmDisconnect = false

    var body: some View {
        HStack(spacing: 13) {
            AsyncImage(url: session.peer.icons.first.flatMap(URL.init(string:))) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "app.fill")
                        .resizable()
                        .scaledToFit()
                        .padding(10)
                        .foregroundColor(WpayinColors.primary)
                }
            }
            .frame(width: 44, height: 44)
            .background(Circle().fill(WpayinColors.surfaceLight))
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(session.peer.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(WpayinColors.text)
                    .lineLimit(1)

                Text(URL(string: session.peer.url)?.host ?? session.peer.url)
                    .font(.system(size: 11))
                    .foregroundColor(WpayinColors.textSecondary)
                    .lineLimit(1)

                Text("Expires %@".localized(session.expiryDate.formatted(date: .abbreviated, time: .omitted)))
                    .font(.system(size: 10))
                    .foregroundColor(WpayinColors.textTertiary)
            }

            Spacer()

            Button {
                confirmDisconnect = true
            } label: {
                Image(systemName: "link.badge.minus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(WpayinColors.error)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(WpayinColors.error.opacity(0.10)))
            }
            .buttonStyle(WpayinPressableStyle())
        }
        .padding(16)
        .background(WpayinColors.surface)
        .confirmationDialog(
            "Disconnect %@?".localized(session.peer.name),
            isPresented: $confirmDisconnect,
            titleVisibility: .visible
        ) {
            Button("Disconnect".localized, role: .destructive, action: onDisconnect)
            Button("Cancel".localized, role: .cancel) {}
        }
    }
}

private struct WalletConnectScannerSheet: View {
    let onScan: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var cameraPermissionDenied = false

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                if cameraPermissionDenied {
                    VStack(spacing: 14) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 38))
                            .foregroundColor(WpayinColors.textSecondary)
                        Text("Camera access is required to scan QR codes".localized)
                            .font(.wpayinBody)
                            .foregroundColor(WpayinColors.text)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                } else {
                    QRCodeScannerRepresentable(
                        onScan: { value in
                            onScan(value)
                            dismiss()
                        },
                        onPermissionDenied: { cameraPermissionDenied = true }
                    )
                    .ignoresSafeArea()

                    RoundedRectangle(cornerRadius: 16)
                        .stroke(WpayinColors.primary, lineWidth: 3)
                        .frame(width: 240, height: 240)
                }
            }
            .navigationTitle("Scan WalletConnect QR".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel".localized) { dismiss() }
                        .foregroundColor(WpayinColors.text)
                }
            }
        }
    }
}

struct WalletConnectProposalApprovalView: View {
    let item: WalletConnectPendingProposal
    @ObservedObject private var service = WalletConnectService.shared
    @State private var isProcessing = false

    private var isDangerous: Bool { service.isDangerous(item.context) }

    var body: some View {
        NavigationView {
            ZStack {
                WalletFlowBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        AsyncImage(url: item.proposal.proposer.icons.first.flatMap(URL.init(string:))) { phase in
                            if case .success(let image) = phase {
                                image.resizable().scaledToFill()
                            } else {
                                Image(systemName: "app.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .padding(16)
                                    .foregroundColor(WpayinColors.primary)
                            }
                        }
                        .frame(width: 72, height: 72)
                        .background(Circle().fill(WpayinColors.surface))
                        .clipShape(Circle())

                        VStack(spacing: 5) {
                            Text(item.proposal.proposer.name)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(WpayinColors.text)

                            Text(item.context?.origin ?? item.proposal.proposer.url)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(WpayinColors.textSecondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }

                        verificationBanner

                        approvalCard(
                            title: "Requested networks".localized,
                            icon: "network",
                            values: service.requestedChainNames(for: item.proposal)
                        )

                        approvalCard(
                            title: "Requested permissions".localized,
                            icon: "signature",
                            values: service.requestedMethodNames(for: item.proposal)
                        )

                        HStack(alignment: .top, spacing: 11) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(WpayinColors.primary)
                            Text("Connecting shares your public address. It does not allow the dApp to move funds without another confirmation.".localized)
                                .font(.system(size: 12))
                                .foregroundColor(WpayinColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(WpayinColors.primary.opacity(0.08))
                        )

                        if !isDangerous {
                            WpayinButton(title: isProcessing ? "Connecting…" : "Approve connection", style: .primary) {
                                isProcessing = true
                                Task {
                                    await service.approve(item)
                                    isProcessing = false
                                }
                            }
                        }

                        WpayinButton(title: "Reject", style: isDangerous ? .destructive : .secondary) {
                            isProcessing = true
                            Task {
                                await service.reject(item)
                                isProcessing = false
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 34)
                }
            }
            .navigationTitle("Connection request".localized)
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
    }

    private var verificationBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: isDangerous ? "exclamationmark.octagon.fill" : "checkmark.shield.fill")
            Text(service.validationLabel(item.context))
                .font(.system(size: 13, weight: .bold))
            Spacer()
        }
        .foregroundColor(isDangerous ? WpayinColors.error : (item.context?.validation == .valid ? WpayinColors.success : WpayinColors.warning))
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill((isDangerous ? WpayinColors.error : WpayinColors.warning).opacity(0.09))
        )
    }

    private func approvalCard(title: String, icon: String, values: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(WpayinColors.text)

            if values.isEmpty {
                Text("None supported".localized)
                    .foregroundColor(WpayinColors.error)
            } else {
                ForEach(values, id: \.self) { value in
                    Label(value, systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(WpayinColors.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

struct WalletConnectRequestApprovalView: View {
    let item: WalletConnectPendingRequest
    @EnvironmentObject private var settingsManager: SettingsManager
    @ObservedObject private var service = WalletConnectService.shared
    @State private var isProcessing = false

    private var isDangerous: Bool { service.isDangerous(item.context) }
    private var transaction: WalletConnectTransactionSummary? {
        service.transactionSummary(for: item.request)
    }

    var body: some View {
        NavigationView {
            ZStack {
                WalletFlowBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        Image(systemName: requestIcon)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(WpayinColors.primary)
                            .frame(width: 64, height: 64)
                            .background(Circle().fill(WpayinColors.primary.opacity(0.12)))

                        VStack(spacing: 5) {
                            Text(requestTitle)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(WpayinColors.text)

                            Text(item.peer?.name ?? item.context?.origin ?? "Connected dApp".localized)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(WpayinColors.textSecondary)
                        }

                        HStack(spacing: 10) {
                            Image(systemName: isDangerous ? "exclamationmark.octagon.fill" : "shield.checkered")
                            Text(service.validationLabel(item.context))
                            Spacer()
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(isDangerous ? WpayinColors.error : WpayinColors.warning)
                        .padding(15)
                        .background(
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .fill((isDangerous ? WpayinColors.error : WpayinColors.warning).opacity(0.09))
                        )

                        if let transaction {
                            transactionCard(transaction)
                        } else {
                            signingCard
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Raw request".localized)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(WpayinColors.text)

                            Text(service.prettyParameters(for: item.request))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(WpayinColors.textSecondary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(WpayinColors.surface)
                        )

                        if !isDangerous {
                            WpayinButton(title: isProcessing ? "Processing…" : "Approve and sign", style: .primary) {
                                isProcessing = true
                                Task {
                                    await service.approve(item, settingsManager: settingsManager)
                                    isProcessing = false
                                }
                            }
                        }

                        WpayinButton(title: "Reject", style: isDangerous ? .destructive : .secondary) {
                            isProcessing = true
                            Task {
                                await service.reject(item)
                                isProcessing = false
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 34)
                }
            }
            .navigationTitle("Signature request".localized)
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
    }

    private var requestTitle: String {
        switch item.request.method {
        case "personal_sign": return "Sign message".localized
        case "eth_signTypedData", "eth_signTypedData_v3", "eth_signTypedData_v4": return "Sign typed data".localized
        case "eth_sendTransaction": return "Send transaction".localized
        default: return item.request.method
        }
    }

    private var requestIcon: String {
        item.request.method == "eth_sendTransaction" ? "arrow.up.right.circle.fill" : "signature"
    }

    private var signingCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            Label(item.request.chainId.absoluteString, systemImage: "network")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(WpayinColors.text)

            Text("A signature can authorize actions in a smart contract. Verify the domain and read the request before signing.".localized)
                .font(.system(size: 12))
                .foregroundColor(WpayinColors.warning)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(WpayinColors.warning.opacity(0.08))
        )
    }

    private func transactionCard(_ transaction: WalletConnectTransactionSummary) -> some View {
        VStack(spacing: 12) {
            requestRow("Network".localized, transaction.network)
            requestRow("To".localized, transaction.to, monospaced: true)
            if let amount = transaction.amount {
                requestRow("Amount".localized, "\(PaymentRequestCodec.decimalString(amount)) \(transaction.symbol)")
            }
            if let data = transaction.data, data != "0x", !data.isEmpty {
                requestRow("Contract data".localized, "\(max(0, (data.count - 2) / 2)) bytes")
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

    private func requestRow(_ title: String, _ value: String, monospaced: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(WpayinColors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: monospaced ? .monospaced : .rounded))
                .foregroundColor(WpayinColors.text)
                .multilineTextAlignment(.trailing)
                .lineLimit(monospaced ? 2 : 1)
        }
    }
}
