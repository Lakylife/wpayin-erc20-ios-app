// Autor Lukas Helebrandt, 2026

import SwiftUI
import CoreImage.CIFilterBuiltins

struct PaymentRequestView: View {
    enum Expiration: String, CaseIterable, Identifiable {
        case fifteenMinutes
        case oneHour
        case oneDay
        case sevenDays
        case never

        var id: String { rawValue }

        var title: String {
            switch self {
            case .fifteenMinutes: return "15 minutes".localized
            case .oneHour: return "1 hour".localized
            case .oneDay: return "24 hours".localized
            case .sevenDays: return "7 days".localized
            case .never: return "No expiration".localized
            }
        }

        var interval: TimeInterval? {
            switch self {
            case .fifteenMinutes: return 15 * 60
            case .oneHour: return 60 * 60
            case .oneDay: return 24 * 60 * 60
            case .sevenDays: return 7 * 24 * 60 * 60
            case .never: return nil
            }
        }
    }

    let token: Token
    let address: String

    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var note = ""
    @State private var expiration: Expiration = .oneDay
    @State private var request: PaymentRequest?
    @State private var qrCodeImage: UIImage?
    @State private var showShareSheet = false
    @State private var copied = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case amount
        case note
    }

    private var parsedAmount: Decimal? {
        let normalized = amount.replacingOccurrences(of: ",", with: ".")
        guard let value = Decimal(
            string: normalized,
            locale: Locale(identifier: "en_US_POSIX")
        ), value > 0 else { return nil }
        return value
    }

    private var requestURI: String? {
        request.flatMap { PaymentRequestCodec.encode($0) }
    }

    var body: some View {
        NavigationView {
            ZStack {
                WalletFlowBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        if request == nil {
                            formContent
                        } else {
                            resultContent
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 34)
                }
                .scrollDismissesKeyboardIfAvailable()
            }
            .contentShape(Rectangle())
            .onTapGesture { focusedField = nil }
            .navigationTitle("Request payment".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        if request != nil {
                            request = nil
                            qrCodeImage = nil
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: request == nil ? "xmark" : "chevron.left")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(WpayinColors.text)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(WpayinColors.surfaceLight))
                    }
                    .accessibilityLabel(request == nil ? L10n.Action.close.localized : "Back".localized)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done".localized) { focusedField = nil }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            PaymentRequestShareSheet(activityItems: shareItems)
        }
    }

    private var formContent: some View {
        Group {
            VStack(spacing: 10) {
                TokenIconView(token: token, size: 62, showNetworkBadge: false)

                Text("Request %@".localized(token.symbol.uppercased()))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(WpayinColors.text)

                HStack(spacing: 7) {
                    NetworkIconView(blockchain: token.blockchain, size: 18)
                    Text(token.blockchain.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(WpayinColors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 2)

            requestCard(title: "Amount".localized, icon: "number") {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    TextField("0.00", text: $amount)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .amount)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(WpayinColors.text)

                    Text(token.symbol.uppercased())
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(WpayinColors.textSecondary)
                }

                Text("Leave blank to let the sender enter the amount.".localized)
                    .font(.system(size: 12))
                    .foregroundColor(WpayinColors.textSecondary)
            }

            requestCard(title: "Payment note".localized, icon: "text.alignleft") {
                TextField("What is this payment for?".localized, text: $note)
                    .focused($focusedField, equals: .note)
                    .textInputAutocapitalization(.sentences)
                    .font(.system(size: 15))
                    .foregroundColor(WpayinColors.text)
                    .onChange(of: note) { value in
                        if value.count > 120 { note = String(value.prefix(120)) }
                    }

                Text("\(note.count)/120")
                    .font(.system(size: 11))
                    .foregroundColor(WpayinColors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            requestCard(title: "Expiration".localized, icon: "clock") {
                Picker("Expiration".localized, selection: $expiration) {
                    ForEach(Expiration.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .tint(WpayinColors.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(alignment: .top, spacing: 11) {
                Image(systemName: "shield.checkered")
                    .foregroundColor(WpayinColors.primary)

                Text("A payment request cannot move funds. The sender must review and sign the transaction in their wallet.".localized)
                    .font(.system(size: 12))
                    .foregroundColor(WpayinColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(WpayinColors.primary.opacity(0.08))
            )

            WpayinButton(title: "Create payment request", style: .primary) {
                createRequest()
            }
        }
    }

    private var resultContent: some View {
        Group {
            VStack(spacing: 9) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(WpayinColors.success)

                Text("Payment request ready".localized)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(WpayinColors.text)

                if let amount = request?.formattedAmount {
                    Text("\(amount) \(token.symbol.uppercased())")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(WpayinColors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)

            paymentQRCode

            if let requestURI {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Payment link".localized)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(WpayinColors.text)

                    HStack(spacing: 10) {
                        Text(requestURI)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(WpayinColors.textSecondary)
                            .lineLimit(3)

                        Spacer(minLength: 4)

                        Button {
                            AppToast.copyToClipboard(requestURI)
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                        } label: {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(copied ? WpayinColors.success : WpayinColors.primary)
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(WpayinColors.primary.opacity(0.10)))
                        }
                        .buttonStyle(WpayinPressableStyle())
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

            if let expiresAt = request?.expiresAt {
                Label {
                    Text("Expires %@".localized(expiresAt.formatted(date: .abbreviated, time: .shortened)))
                } icon: {
                    Image(systemName: "clock")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(WpayinColors.textSecondary)
            }

            WpayinButton(title: "Share payment request", style: .primary) {
                showShareSheet = true
            }

            WpayinButton(title: "Create another request", style: .secondary) {
                request = nil
                qrCodeImage = nil
            }
        }
    }

    private func requestCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Label(title, systemImage: icon)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(WpayinColors.text)

            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(WpayinColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                )
        )
    }

    private var paymentQRCode: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
                .frame(width: 272, height: 272)
                .shadow(color: WpayinColors.primary.opacity(0.16), radius: 20, x: 0, y: 9)

            if let qrCodeImage {
                Image(uiImage: qrCodeImage)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 234, height: 234)

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
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: WpayinColors.primary))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .accessibilityLabel("Payment request QR code".localized)
    }

    private func createRequest() {
        focusedField = nil
        let createdRequest = PaymentRequest(
            address: address,
            symbol: token.symbol,
            blockchain: token.blockchain,
            contractAddress: token.contractAddress,
            tokenDecimals: token.decimals,
            amount: parsedAmount,
            note: note,
            expiresAt: expiration.interval.map { Date().addingTimeInterval($0) }
        )
        guard let uri = PaymentRequestCodec.encode(createdRequest) else { return }
        request = createdRequest
        qrCodeImage = generateQRCode(from: uri)
    }

    private func generateQRCode(from value: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(value.utf8)
        filter.correctionLevel = "H"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private var shareItems: [Any] {
        guard let request, let requestURI else { return [] }
        var lines = [
            "Payment request".localized,
            "\(request.formattedAmount.map { "\($0) " } ?? "")\(request.symbol) • \(request.blockchain.name)",
            requestURI
        ]
        if let note = request.note { lines.append("\("Note".localized): \(note)") }
        if let expiresAt = request.expiresAt {
            lines.append("Expires %@".localized(expiresAt.formatted(date: .abbreviated, time: .shortened)))
        }
        return [lines.joined(separator: "\n")]
    }
}

private struct PaymentRequestShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private extension View {
    @ViewBuilder
    func scrollDismissesKeyboardIfAvailable() -> some View {
        if #available(iOS 16.0, *) {
            scrollDismissesKeyboard(.interactively)
        } else {
            self
        }
    }
}
