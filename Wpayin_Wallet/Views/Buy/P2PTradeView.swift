// Autor Lukas Helebrandt, 2026

//
//  P2PTradeView.swift
//  Wpayin_Wallet
//
//  Peer-to-peer trading between Wpayin users. The seller signs an offer and
//  shares it as a QR code; the buyer scans it, the app verifies both sides
//  on-chain (balances, allowance, signature, fees) and settlement is atomic
//  via the AirSwap SwapERC20 contract — see P2PTradeService.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct P2PTradeView: View {
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss

    private enum P2PMode: CaseIterable {
        case browse, sell, buy

        var label: String {
            switch self {
            case .browse: return "Offers".localized
            case .sell: return "Sell".localized
            case .buy: return "Buy".localized
            }
        }

        var icon: String {
            switch self {
            case .browse: return "list.bullet.rectangle"
            case .sell: return "arrow.up.circle"
            case .buy: return "arrow.down.circle"
            }
        }
    }

    @State private var mode: P2PMode = AppConfig.p2pOfferBoardEnabled ? .browse : .sell
    @State private var buyPayload: String?

    private var availableModes: [P2PMode] {
        AppConfig.p2pOfferBoardEnabled ? P2PMode.allCases : [.sell, .buy]
    }

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    modePicker
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 14)

                    switch mode {
                    case .browse:
                        P2PMarketContent { payload in
                            buyPayload = payload
                            withAnimation(.easeOut(duration: 0.2)) { mode = .buy }
                        }
                    case .sell:
                        P2PSellContent()
                    case .buy:
                        P2PBuyContent(initialPayload: buyPayload)
                            .id(buyPayload)   // re-validate when a new listing is opened
                    }
                }
            }
            .navigationTitle("P2P Exchange".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.Action.cancel.localized) { dismiss() }
                        .foregroundColor(WpayinColors.text)
                }
            }
        }
    }

    private var modePicker: some View {
        HStack(spacing: 4) {
            ForEach(availableModes, id: \.self) { item in
                modeButton(item)
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(WpayinColors.surface)
                .overlay(Capsule().stroke(WpayinColors.surfaceBorder, lineWidth: 1))
        )
    }

    private func modeButton(_ item: P2PMode) -> some View {
        let isSelected = mode == item
        return Button {
            withAnimation(.easeOut(duration: 0.2)) { mode = item }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: item.icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(item.label)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(isSelected ? .white : WpayinColors.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(
                Capsule()
                    .fill(isSelected ? AnyShapeStyle(WpayinColors.accentGradient) : AnyShapeStyle(Color.clear))
            )
        }
        .buttonStyle(WpayinPressableStyle())
    }
}

// MARK: - Public offer board (discovery — trust comes from on-chain validation)

private struct P2PMarketContent: View {
    let onSelect: (String) -> Void

    @State private var listings: [P2PListing] = []
    @State private var isLoading = false
    @State private var loadFailed = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                if isLoading && listings.isEmpty {
                    ProgressView()
                        .tint(WpayinColors.primary)
                        .padding(.top, 60)
                } else if listings.isEmpty {
                    emptyState
                } else {
                    ForEach(listings) { listing in
                        listingRow(listing)
                    }
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 20)
        }
        .refreshable { await load() }
        .task { await load() }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: loadFailed ? "icloud.slash" : "tray")
                .font(.system(size: 30, weight: .medium))
                .foregroundColor(WpayinColors.primary)
                .frame(width: 72, height: 72)
                .background(Circle().fill(WpayinColors.primary.opacity(0.12)))

            Text(loadFailed ? "Offer board unavailable".localized : "No public offers right now".localized)
                .font(.wpayinHeadline)
                .foregroundColor(WpayinColors.text)

            Text(loadFailed
                 ? "error.p2p.iCloudUnavailable".localized
                 : "Be the first — create an offer and publish it to the board.".localized)
                .font(.wpayinBody)
                .foregroundColor(WpayinColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: WpayinRadius.card, style: .continuous)
                .fill(WpayinColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: WpayinRadius.card, style: .continuous)
                        .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                )
        )
        .padding(.top, 8)
    }

    private func listingRow(_ listing: P2PListing) -> some View {
        let offer = listing.offer
        return Button {
            onSelect(listing.payload)
        } label: {
            HStack(spacing: 12) {
                if let network = offer.blockchain {
                    NetworkIconView(blockchain: network, size: 34)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("\(formatAmount(offer.signerAmountDecimal)) \(offer.signerSymbol) → \(formatAmount(offer.senderAmountDecimal)) \(offer.senderSymbol)")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(WpayinColors.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    HStack(spacing: 6) {
                        Text("\(offer.signerWallet.prefix(6))…\(offer.signerWallet.suffix(4))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(WpayinColors.textSecondary)

                        Text("· \("Expires".localized) \(Date(timeIntervalSince1970: offer.expiry).formatted(date: .abbreviated, time: .shortened))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(WpayinColors.textTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(WpayinColors.textTertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: WpayinRadius.medium, style: .continuous)
                    .fill(WpayinColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: WpayinRadius.medium, style: .continuous)
                            .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(WpayinPressableStyle())
    }

    private func load() async {
        isLoading = true
        do {
            let fetched = try await P2PMarketService.shared.fetchListings()
            await MainActor.run {
                listings = fetched
                loadFailed = false
                isLoading = false
            }
        } catch {
            Logger.log("⚠️ P2P board fetch failed: \(error.localizedDescription)")
            await MainActor.run {
                loadFailed = true
                isLoading = false
            }
        }
    }

    private func formatAmount(_ value: Decimal) -> String {
        let doubleValue = (value as NSDecimalNumber).doubleValue
        return String(format: doubleValue >= 1 ? "%.2f" : "%.4f", doubleValue)
    }
}

// MARK: - Sell (create offer)

private struct P2PSellContent: View {
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var settingsManager: SettingsManager

    @State private var sellToken: Token?
    @State private var receiveToken: Token?
    @State private var sellAmount = ""
    @State private var receiveAmount = ""
    @State private var validHours: Double = 24

    @State private var showSellPicker = false
    @State private var showReceivePicker = false
    @State private var isCreating = false
    @State private var createdOffer: P2POffer?
    @State private var protocolFeeBps: Int?

    @State private var myOffers: [P2POffer] = []
    @State private var completedNonces: Set<String> = []
    @State private var cancellingNonce: String?

    @State private var showError = false
    @State private var errorMessage = ""

    private let expiryOptions: [(label: String, hours: Double)] = [
        ("1 h", 1), ("6 h", 6), ("24 h", 24), ("72 h", 72)
    ]

    /// Contract the token settles as on-chain — native coins settle as their
    /// canonical wrapped ERC-20 (auto-wrapped 1:1 by P2PTradeService).
    private func effectiveAddress(_ token: Token) -> String? {
        if token.isNative {
            return P2PTradeService.wrappedNative[token.blockchain]?.address.lowercased()
        }
        return token.contractAddress?.lowercased()
    }

    /// Tokens the user can sell — ERC-20s and wrappable natives with balance.
    private var sellableTokens: [Token] {
        walletManager.visibleSupportedTokens.filter {
            $0.balance > 0 &&
            P2PTradeService.supportedBlockchains.contains($0.blockchain) &&
            effectiveAddress($0) != nil
        }
    }

    private var receivableTokens: [Token] {
        guard let sellToken, let sellAddress = effectiveAddress(sellToken) else { return [] }
        return walletManager.visibleSupportedTokens.filter {
            $0.blockchain == sellToken.blockchain &&
            effectiveAddress($0) != nil &&
            effectiveAddress($0) != sellAddress
        }
    }

    /// Wrap note shown when either side is a native coin.
    private var wrapNotice: String? {
        for token in [sellToken, receiveToken] {
            if let token, token.isNative,
               let wrapped = P2PTradeService.wrappedNative[token.blockchain] {
                return "%@ is wrapped to %@ automatically (1:1) — the value is identical.".localized(
                    token.symbol, wrapped.symbol
                )
            }
        }
        return nil
    }

    private var sellValue: Double { Double(sellAmount) ?? 0 }
    private var receiveValue: Double { Double(receiveAmount) ?? 0 }

    private var protocolFeeAmount: Double {
        guard let bps = protocolFeeBps else { return 0 }
        return sellValue * Double(bps) / 10_000
    }

    private var isValid: Bool {
        guard let token = sellToken, receiveToken != nil else { return false }
        return sellValue > 0 && receiveValue > 0 &&
               sellValue + protocolFeeAmount <= token.balance
    }

    var body: some View {
        Group {
            if let offer = createdOffer {
                P2POfferShareView(offer: offer) {
                    createdOffer = nil
                    sellAmount = ""
                    receiveAmount = ""
                    reloadOffers()
                }
            } else {
                form
            }
        }
    }

    private var form: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                if sellableTokens.isEmpty {
                    noSellableTokensCard
                } else {
                    sellForm
                }

                if !myOffers.isEmpty {
                    myOffersSection
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 20)
        }
        .sheet(isPresented: $showSellPicker) {
            TokenPickerView(tokens: sellableTokens, selectedToken: sellToken) { token in
                sellToken = token
                if receiveToken?.blockchain != token.blockchain { receiveToken = nil }
                loadProtocolFee(for: token.blockchain)
            }
        }
        .sheet(isPresented: $showReceivePicker) {
            TokenPickerView(tokens: receivableTokens, selectedToken: receiveToken) { token in
                receiveToken = token
            }
        }
        .alert("P2P Trade Failed".localized, isPresented: $showError) {
            Button("OK".localized) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            if sellToken == nil {
                sellToken = sellableTokens.first
                if let token = sellToken { loadProtocolFee(for: token.blockchain) }
            }
            reloadOffers()
        }
    }

    /// Explains why the picker is empty instead of showing a blank sheet —
    /// P2P settles ERC-20↔ERC-20, so the user needs at least one ERC-20 token.
    private var noSellableTokensCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "circle.grid.2x2")
                .font(.system(size: 30, weight: .medium))
                .foregroundColor(WpayinColors.primary)
                .frame(width: 72, height: 72)
                .background(Circle().fill(WpayinColors.primary.opacity(0.12)))

            Text("No tokens to sell".localized)
                .font(.wpayinHeadline)
                .foregroundColor(WpayinColors.text)

            Text("You don't hold any tradable tokens on a supported network yet. Deposit or buy some crypto first, then come back.".localized)
            .font(.wpayinBody)
            .foregroundColor(WpayinColors.textSecondary)
            .multilineTextAlignment(.center)
            .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 36)
        .background(
            RoundedRectangle(cornerRadius: WpayinRadius.card, style: .continuous)
                .fill(WpayinColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: WpayinRadius.card, style: .continuous)
                        .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                )
        )
        .padding(.top, 8)
    }

    @ViewBuilder
    private var sellForm: some View {
        ModernTokenSelector(
            title: "You sell".localized,
            selectedToken: sellToken,
            amount: $sellAmount,
            isInput: true,
            onTokenSelect: { showSellPicker = true }
        )

        ModernTokenSelector(
            title: "You receive".localized,
            selectedToken: receiveToken,
            amount: $receiveAmount,
            isInput: true,
            onTokenSelect: { showReceivePicker = true }
        )

        expiryRow

        infoCard

        if !isValid, sellValue > 0, let token = sellToken,
           sellValue + protocolFeeAmount > token.balance {
            Text("error.p2p.makerCannotCover".localized)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(WpayinColors.error)
        }

        Button(action: createOffer) {
            HStack(spacing: 9) {
                if isCreating { ProgressView().tint(.white) }
                Text(isCreating ? "Creating offer...".localized : "Create Offer".localized)
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundColor(isValid ? .white : WpayinColors.textTertiary)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(isValid
                          ? AnyShapeStyle(WpayinColors.accentGradient)
                          : AnyShapeStyle(WpayinColors.surfaceLight))
            )
        }
        .disabled(!isValid || isCreating)
        .buttonStyle(WpayinPressableStyle())
    }

    // MARK: - My offers

    private var myOffersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Active offers".localized)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(WpayinColors.text)
                .padding(.top, 8)

            ForEach(myOffers, id: \.nonce) { offer in
                myOfferRow(offer)
            }
        }
    }

    private func offerStatus(_ offer: P2POffer) -> (label: String, color: Color) {
        if completedNonces.contains(offer.nonce) {
            return ("Completed".localized, WpayinColors.success)
        }
        if offer.isExpired {
            return ("Expired".localized, WpayinColors.textTertiary)
        }
        return ("Active".localized, WpayinColors.primary)
    }

    private func myOfferRow(_ offer: P2POffer) -> some View {
        let status = offerStatus(offer)
        let isDone = completedNonces.contains(offer.nonce) || offer.isExpired

        return VStack(spacing: 12) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(formatOfferAmount(offer.signerAmountDecimal)) \(offer.signerSymbol) → \(formatOfferAmount(offer.senderAmountDecimal)) \(offer.senderSymbol)")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(WpayinColors.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    HStack(spacing: 6) {
                        if let network = offer.blockchain {
                            NetworkIconView(blockchain: network, size: 13)
                        }

                        Text("\("Expires".localized): \(Date(timeIntervalSince1970: offer.expiry).formatted(date: .abbreviated, time: .shortened))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(WpayinColors.textSecondary)
                    }
                }

                Spacer()

                Text(status.label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(status.color)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(status.color.opacity(0.12)))
            }

            HStack(spacing: 10) {
                if !isDone {
                    Button {
                        createdOffer = offer
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Share Offer".localized)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(WpayinColors.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: WpayinRadius.small, style: .continuous)
                                .fill(WpayinColors.primary.opacity(0.12))
                        )
                    }
                    .buttonStyle(WpayinPressableStyle())

                    Button {
                        cancelOffer(offer)
                    } label: {
                        HStack(spacing: 6) {
                            if cancellingNonce == offer.nonce {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .tint(WpayinColors.error)
                            } else {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            Text("Cancel Offer".localized)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(WpayinColors.error)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: WpayinRadius.small, style: .continuous)
                                .fill(WpayinColors.error.opacity(0.1))
                        )
                    }
                    .buttonStyle(WpayinPressableStyle())
                    .disabled(cancellingNonce != nil)
                } else {
                    Button {
                        P2PTradeService.shared.removeOffer(offer)
                        reloadOffers()
                    } label: {
                        Text("Remove".localized)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(WpayinColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(
                                RoundedRectangle(cornerRadius: WpayinRadius.small, style: .continuous)
                                    .fill(WpayinColors.surfaceLight)
                            )
                    }
                    .buttonStyle(WpayinPressableStyle())
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: WpayinRadius.medium, style: .continuous)
                .fill(WpayinColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: WpayinRadius.medium, style: .continuous)
                        .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                )
        )
    }

    private func reloadOffers() {
        myOffers = P2PTradeService.shared.savedOffers().sorted { $0.expiry > $1.expiry }

        // Refresh on-chain status — a used nonce means filled (or cancelled elsewhere)
        Task {
            var used: Set<String> = []
            for offer in myOffers where !offer.isExpired {
                if let isUsed = try? await P2PTradeService.shared.isOfferUsed(offer), isUsed {
                    used.insert(offer.nonce)
                }
            }
            await MainActor.run { completedNonces = used }
        }
    }

    private func cancelOffer(_ offer: P2POffer) {
        cancellingNonce = offer.nonce

        Task {
            do {
                let txHash = try await P2PTradeService.shared.cancelOffer(offer)
                Logger.log("✅ P2P offer cancelled: \(txHash)")
                await P2PMarketService.shared.removeListing(for: offer)
                await MainActor.run {
                    cancellingNonce = nil
                    P2PTradeService.shared.removeOffer(offer)
                    reloadOffers()
                    AppToast.show("Offer cancelled".localized, icon: "xmark.circle")
                }
            } catch {
                Logger.log("❌ P2P offer cancellation failed: \(error.localizedDescription)")
                await MainActor.run {
                    cancellingNonce = nil
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func formatOfferAmount(_ value: Decimal) -> String {
        let doubleValue = (value as NSDecimalNumber).doubleValue
        return String(format: doubleValue >= 1 ? "%.2f" : "%.4f", doubleValue)
    }

    private var expiryRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Offer valid for".localized)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(WpayinColors.textSecondary)

            HStack(spacing: 10) {
                ForEach(expiryOptions, id: \.hours) { option in
                    let isSelected = validHours == option.hours
                    Button {
                        validHours = option.hours
                    } label: {
                        Text(option.label)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(isSelected ? WpayinColors.primary : WpayinColors.text)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: WpayinRadius.small, style: .continuous)
                                    .fill(isSelected ? WpayinColors.primary.opacity(0.12) : WpayinColors.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: WpayinRadius.small, style: .continuous)
                                    .stroke(isSelected ? WpayinColors.primary : WpayinColors.surfaceBorder,
                                            lineWidth: isSelected ? 1.5 : 1)
                            )
                    }
                    .buttonStyle(WpayinPressableStyle())
                }
            }
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            infoRow(icon: "lock.shield.fill",
                    text: "Settlement is atomic — both sides receive their tokens in one transaction, or nothing happens.".localized)

            if let wrapNotice {
                infoRow(icon: "arrow.triangle.2.circlepath", text: wrapNotice)
            }

            if let bps = protocolFeeBps, let token = sellToken {
                infoRow(icon: "percent",
                        text: "Protocol fee %@: %@ %@".localized(
                            String(format: "(%.2f%%)", Double(bps) / 100),
                            String(format: "%.6f", protocolFeeAmount),
                            token.symbol
                        ))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: WpayinRadius.medium, style: .continuous)
                .fill(WpayinColors.primary.opacity(0.08))
        )
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(WpayinColors.primary)
                .frame(width: 18)

            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(WpayinColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func loadProtocolFee(for blockchain: BlockchainType) {
        Task {
            let fee = try? await P2PTradeService.shared.fetchProtocolFeeBps(blockchain: blockchain)
            await MainActor.run { protocolFeeBps = fee }
        }
    }

    private func createOffer() {
        guard let sellToken, let receiveToken,
              sellValue > 0, receiveValue > 0 else { return }
        isCreating = true

        Task {
            do {
                let offer = try await P2PTradeService.shared.createOffer(
                    sellToken: sellToken,
                    sellAmount: Decimal(sellValue),
                    receiveToken: receiveToken,
                    receiveAmount: Decimal(receiveValue),
                    validFor: validHours * 3600
                )
                await MainActor.run {
                    isCreating = false
                    P2PTradeService.shared.saveOffer(offer)
                    createdOffer = offer
                }
            } catch {
                Logger.log("❌ P2P offer creation failed: \(error.localizedDescription)")
                await MainActor.run {
                    isCreating = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Offer share screen (QR + share sheet)

private struct P2POfferShareView: View {
    let offer: P2POffer
    let onDone: () -> Void

    @State private var qrImage: UIImage?
    @State private var isPublishing = false
    @State private var isPublished = false
    @State private var publishError: String?
    @State private var showPublishError = false

    private var payload: String {
        P2PTradeService.shared.encode(offer) ?? ""
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                Text("Share this offer with the buyer".localized)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(WpayinColors.textSecondary)
                    .multilineTextAlignment(.center)

                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white)
                        .frame(width: 240, height: 240)
                        .shadow(color: WpayinColors.primary.opacity(0.14), radius: 18, y: 8)

                    if let qrImage {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 204, height: 204)
                    } else {
                        ProgressView()
                    }
                }

                VStack(spacing: 0) {
                    SwapDetailRow(
                        label: "You sell".localized,
                        value: "\(formatAmount(offer.signerAmountDecimal)) \(offer.signerSymbol)"
                    )
                    SwapDetailRow(
                        label: "You receive".localized,
                        value: "\(formatAmount(offer.senderAmountDecimal)) \(offer.senderSymbol)",
                        highlightsValue: true
                    )
                    SwapDetailRow(
                        label: "Expires".localized,
                        value: Date(timeIntervalSince1970: offer.expiry)
                            .formatted(date: .abbreviated, time: .shortened)
                    )
                }
                .background(
                    RoundedRectangle(cornerRadius: WpayinRadius.card, style: .continuous)
                        .fill(WpayinColors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: WpayinRadius.card, style: .continuous)
                                .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                        )
                )

                if #available(iOS 16.0, *) {
                    ShareLink(item: payload) {
                        shareLabel
                    }
                    .buttonStyle(WpayinPressableStyle())
                } else {
                    Button {
                        AppToast.copyToClipboard(payload)
                    } label: {
                        shareLabel
                    }
                    .buttonStyle(WpayinPressableStyle())
                }

                // Publish to the public board so anyone in the app can find it
                if AppConfig.p2pOfferBoardEnabled {
                    publishButton
                }

                Button("Done".localized, action: onDone)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(WpayinColors.textSecondary)

                Spacer(minLength: 24)
            }
            .padding(20)
        }
        .onAppear(perform: generateQR)
        .alert("P2P Trade Failed".localized, isPresented: $showPublishError) {
            Button("OK".localized) { }
        } message: {
            Text(publishError ?? "")
        }
    }

    private var publishButton: some View {
                Button(action: publish) {
                    HStack(spacing: 8) {
                        if isPublishing {
                            ProgressView()
                                .tint(WpayinColors.primary)
                        } else {
                            Image(systemName: isPublished ? "checkmark.circle.fill" : "megaphone.fill")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        Text(isPublished ? "Published to the board".localized : "Publish to Offer Board".localized)
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(isPublished ? WpayinColors.success : WpayinColors.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill((isPublished ? WpayinColors.success : WpayinColors.primary).opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .stroke((isPublished ? WpayinColors.success : WpayinColors.primary).opacity(0.5), lineWidth: 1)
                            )
                    )
                }
                .disabled(isPublishing || isPublished)
                .buttonStyle(WpayinPressableStyle())
    }

    private func publish() {
        isPublishing = true
        Task {
            do {
                try await P2PMarketService.shared.publish(offer)
                await MainActor.run {
                    isPublishing = false
                    isPublished = true
                }
            } catch {
                await MainActor.run {
                    isPublishing = false
                    publishError = error.localizedDescription
                    showPublishError = true
                }
            }
        }
    }

    private var shareLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 15, weight: .semibold))
            Text("Share Offer".localized)
                .font(.system(size: 17, weight: .bold))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(WpayinColors.accentGradient)
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
    }

    private func generateQR() {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        if let output = filter.outputImage {
            let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
            if let cgImage = context.createCGImage(scaled, from: scaled.extent) {
                qrImage = UIImage(cgImage: cgImage)
            }
        }
    }

    private func formatAmount(_ value: Decimal) -> String {
        let doubleValue = (value as NSDecimalNumber).doubleValue
        return String(format: doubleValue >= 1 ? "%.4f" : "%.6f", doubleValue)
    }
}

// MARK: - Buy (redeem offer)

private struct P2PBuyContent: View {
    var initialPayload: String? = nil

    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var settingsManager: SettingsManager

    @State private var payloadText = ""
    @State private var showScanner = false
    @State private var isValidating = false
    @State private var check: P2POfferCheck?
    @State private var isAccepting = false

    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var successMessage = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                if let check {
                    offerSummary(check)
                } else {
                    inputCard
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 20)
        }
        .sheet(isPresented: $showScanner) {
            P2PScannerSheet { value in
                payloadText = value
                validate()
            }
        }
        .alert("P2P Trade Failed".localized, isPresented: $showError) {
            Button("OK".localized) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Trade Completed".localized, isPresented: $showSuccess) {
            Button("OK".localized) { }
        } message: {
            Text(successMessage)
        }
        .onAppear {
            if let initialPayload, check == nil, payloadText.isEmpty {
                payloadText = initialPayload
                validate()
            }
        }
    }

    private var inputCard: some View {
        VStack(spacing: 16) {
            Text("Scan or paste an offer from the seller".localized)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(WpayinColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            Button {
                showScanner = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Scan QR Code".localized)
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(WpayinColors.accentGradient)
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            }
            .buttonStyle(WpayinPressableStyle())

            HStack {
                Rectangle().fill(WpayinColors.surfaceBorder).frame(height: 1)
                Text("or".localized)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(WpayinColors.textTertiary)
                Rectangle().fill(WpayinColors.surfaceBorder).frame(height: 1)
            }

            VStack(spacing: 12) {
                TextField("Paste offer code".localized, text: $payloadText)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(WpayinColors.text)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: WpayinRadius.medium, style: .continuous)
                            .fill(WpayinColors.surfaceLight)
                            .overlay(
                                RoundedRectangle(cornerRadius: WpayinRadius.medium, style: .continuous)
                                    .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                            )
                    )
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Button {
                    validate()
                } label: {
                    HStack(spacing: 9) {
                        if isValidating { ProgressView().tint(.white) }
                        Text(isValidating ? "Verifying offer...".localized : "Verify Offer".localized)
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(payloadText.isEmpty ? WpayinColors.textTertiary : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(payloadText.isEmpty
                                  ? AnyShapeStyle(WpayinColors.surfaceLight)
                                  : AnyShapeStyle(WpayinColors.accentGradient))
                    )
                }
                .disabled(payloadText.isEmpty || isValidating)
                .buttonStyle(WpayinPressableStyle())
            }
        }
    }

    private func offerSummary(_ check: P2POfferCheck) -> some View {
        let offer = check.offer
        return VStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(WpayinColors.success)

                Text("Offer verified on-chain".localized)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(WpayinColors.success)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(Capsule().fill(WpayinColors.success.opacity(0.12)))

            VStack(spacing: 0) {
                SwapDetailRow(
                    label: "You pay".localized,
                    value: "\(formatAmount(offer.senderAmountDecimal)) \(offer.senderSymbol)"
                )
                SwapDetailRow(
                    label: "You receive".localized,
                    value: "\(formatAmount(offer.signerAmountDecimal)) \(offer.signerSymbol)",
                    highlightsValue: true
                )
                if let network = offer.blockchain {
                    SwapDetailRow(label: "Network".localized, value: network.name)
                }
                SwapDetailRow(
                    label: "Seller".localized,
                    value: "\(offer.signerWallet.prefix(6))…\(offer.signerWallet.suffix(4))"
                )
                if check.takerPlatformFee > 0 {
                    SwapDetailRow(
                        label: "Platform fee".localized,
                        value: "\(formatAmount(check.takerPlatformFee)) \(offer.senderSymbol)"
                    )
                }
                SwapDetailRow(
                    label: "Expires".localized,
                    value: Date(timeIntervalSince1970: offer.expiry)
                        .formatted(date: .abbreviated, time: .shortened)
                )
            }
            .background(
                RoundedRectangle(cornerRadius: WpayinRadius.card, style: .continuous)
                    .fill(WpayinColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: WpayinRadius.card, style: .continuous)
                            .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                    )
            )

            Button {
                accept()
            } label: {
                HStack(spacing: 9) {
                    if isAccepting { ProgressView().tint(.white) }
                    Text(isAccepting ? "Completing trade...".localized : "Confirm Trade".localized)
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(WpayinColors.accentGradient)
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            }
            .disabled(isAccepting)
            .buttonStyle(WpayinPressableStyle())

            Button("Cancel".localized) {
                self.check = nil
                payloadText = ""
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(WpayinColors.textSecondary)
        }
        .padding(.top, 8)
    }

    private func validate() {
        guard let offer = P2PTradeService.shared.decode(payloadText) else {
            errorMessage = "error.p2p.invalidOffer".localized
            showError = true
            return
        }
        isValidating = true

        Task {
            do {
                let result = try await P2PTradeService.shared.validateOffer(offer)
                await MainActor.run {
                    isValidating = false
                    check = result
                }
            } catch {
                Logger.log("❌ P2P offer validation failed: \(error.localizedDescription)")
                await MainActor.run {
                    isValidating = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func accept() {
        guard let check else { return }
        isAccepting = true

        Task {
            do {
                let txHash = try await P2PTradeService.shared.acceptOffer(check.offer)
                Logger.log("✅ P2P trade submitted! TX: \(txHash)")
                await MainActor.run {
                    isAccepting = false
                    self.check = nil
                    payloadText = ""
                    successMessage = "Transaction: %@".localized(txHash)
                    showSuccess = true

                    Task { await walletManager.refreshWalletData() }
                }
            } catch {
                Logger.log("❌ P2P trade failed: \(error.localizedDescription)")
                await MainActor.run {
                    isAccepting = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func formatAmount(_ value: Decimal) -> String {
        let doubleValue = (value as NSDecimalNumber).doubleValue
        return String(format: doubleValue >= 1 ? "%.4f" : "%.6f", doubleValue)
    }
}

// MARK: - Raw QR scanner (offer payloads must not go through address parsing)

private struct P2PScannerSheet: View {
    let onScan: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var permissionDenied = false

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                if permissionDenied {
                    Text("Camera access is required to scan QR codes".localized)
                        .font(.wpayinBody)
                        .foregroundColor(WpayinColors.text)
                        .multilineTextAlignment(.center)
                        .padding(24)
                } else {
                    QRCodeScannerRepresentable(
                        onScan: { value in
                            onScan(value)
                            dismiss()
                        },
                        onPermissionDenied: { permissionDenied = true }
                    )
                    .ignoresSafeArea()

                    VStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(WpayinColors.primary, lineWidth: 3)
                            .frame(width: 240, height: 240)
                        Spacer()
                    }
                }
            }
            .navigationTitle("Scan QR Code".localized)
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
