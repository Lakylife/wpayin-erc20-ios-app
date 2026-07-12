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
        case buy, sell

        var label: String {
            switch self {
            case .buy: return "Buy".localized
            case .sell: return "Sell".localized
            }
        }

        var icon: String {
            switch self {
            case .buy: return "arrow.down.circle"
            case .sell: return "arrow.up.circle"
            }
        }
    }

    @State private var mode: P2PMode = .buy

    private var availableModes: [P2PMode] { P2PMode.allCases }

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
                    case .buy:
                        P2PBuyContent()
                    case .sell:
                        P2PSellContent()
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

/// Marketplace section shown at the top of the Buy tab: what other users are
/// selling right now, with unit price, fiat estimate and posting time.
/// Tapping a listing runs the exact same on-chain verification as a pasted
/// offer — the board is discovery only and can never be trusted by itself.
private struct P2POfferBoardSection: View {
    let onSelect: (String) -> Void

    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var settingsManager: SettingsManager

    @State private var listings: [P2PListing] = []
    @State private var isLoading = false
    @State private var loadFailed = false
    @State private var ownListing: P2PListing?
    @State private var selectedPair: MarketPair?
    @State private var buyAmountText = ""

    /// One tradable pair on one network, exchange style: what you get / what
    /// you pay with.
    private struct MarketPair: Identifiable, Equatable {
        let blockchain: BlockchainType
        let buySymbol: String
        let paySymbol: String
        var id: String { "\(blockchain.rawValue)|\(buySymbol)|\(paySymbol)" }
        var title: String { "\(buySymbol) / \(paySymbol)" }
    }

    private struct PairGroup: Identifiable {
        let pair: MarketPair
        let offers: [P2PListing]
        var id: String { pair.id }
    }

    private func unitPrice(_ listing: P2PListing) -> Double {
        let sell = (listing.offer.signerAmountDecimal as NSDecimalNumber).doubleValue
        let pay = (listing.offer.senderAmountDecimal as NSDecimalNumber).doubleValue
        guard sell > 0 else { return .infinity }
        return pay / sell
    }

    /// Live listings grouped into pairs, cheapest offer deciding the order.
    private var pairGroups: [PairGroup] {
        var groups: [String: PairGroup] = [:]
        for listing in listings {
            guard let chain = listing.offer.blockchain else { continue }
            let pair = MarketPair(
                blockchain: chain,
                buySymbol: listing.offer.signerSymbol,
                paySymbol: listing.offer.senderSymbol
            )
            let existing = groups[pair.id]?.offers ?? []
            groups[pair.id] = PairGroup(pair: pair, offers: existing + [listing])
        }
        return groups.values
            .map { PairGroup(pair: $0.pair, offers: $0.offers.sorted { unitPrice($0) < unitPrice($1) }) }
            .sorted { $0.offers.count > $1.offers.count }
    }

    private var requestedAmount: Double {
        Double(buyAmountText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    /// Offers of the selected pair that can cover the requested amount,
    /// best price first. Offers fill in full, so an offer matches when the
    /// seller's amount is at least what the user asked for.
    private func matchingOffers(for pair: MarketPair) -> [P2PListing] {
        guard let group = pairGroups.first(where: { $0.pair == pair }) else { return [] }
        guard requestedAmount > 0 else { return group.offers }
        return group.offers.filter {
            ($0.offer.signerAmountDecimal as NSDecimalNumber).doubleValue >= requestedAmount
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if isLoading && listings.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(WpayinColors.primary)
                    Spacer()
                }
                .padding(.vertical, 24)
            } else if listings.isEmpty {
                emptyState
            } else if let pair = selectedPair {
                pairDetail(pair)
            } else {
                ForEach(pairGroups) { group in
                    pairRow(group)
                }
            }
        }
        .task { await load() }
        // Tapping your own listing opens its share screen instead of the
        // buy flow — the same wallet can never accept its own offer.
        .sheet(item: $ownListing) { listing in
            P2POfferShareView(offer: listing.offer) {
                ownListing = nil
                Task { await load() }
            }
        }
    }

    private var header: some View {
        HStack {
            if let pair = selectedPair {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        selectedPair = nil
                        buyAmountText = ""
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .bold))
                        Text(pair.title)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(WpayinColors.text)
                }
                .buttonStyle(PlainButtonStyle())

                NetworkIconView(blockchain: pair.blockchain, size: 16)
            } else {
                Text("Markets".localized)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(WpayinColors.text)
            }

            Spacer()

            Button {
                Task { await load() }
            } label: {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(WpayinColors.primary)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(WpayinColors.primary)
                }
            }
            .disabled(isLoading)
            .buttonStyle(PlainButtonStyle())
        }
    }

    /// One market row: pair, network, best price and market depth.
    private func pairRow(_ group: PairGroup) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { selectedPair = group.pair }
        } label: {
            HStack(spacing: 12) {
                NetworkIconView(blockchain: group.pair.blockchain, size: 34)

                VStack(alignment: .leading, spacing: 4) {
                    Text(group.pair.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(WpayinColors.text)

                    if let best = group.offers.first {
                        Text("From %@".localized("\(formatBoardAmount(Decimal(unitPrice(best)))) \(group.pair.paySymbol)"))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(WpayinColors.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }

                Spacer(minLength: 8)

                Text("Offers: %@".localized("\(group.offers.count)"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(WpayinColors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(WpayinColors.surfaceLight))

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

    /// Pair detail: how much the user wants to buy + offers that cover it,
    /// cheapest first, ready to tap-buy.
    @ViewBuilder
    private func pairDetail(_ pair: MarketPair) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How much %@ do you want to buy?".localized(pair.buySymbol))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(WpayinColors.textSecondary)

            HStack(spacing: 10) {
                TextField("0.0", text: $buyAmountText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(WpayinColors.text)

                Text(pair.buySymbol)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(WpayinColors.textSecondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: WpayinRadius.medium, style: .continuous)
                    .fill(WpayinColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: WpayinRadius.medium, style: .continuous)
                            .stroke(WpayinColors.primary.opacity(0.32), lineWidth: 1)
                    )
            )

            Text("Offers are filled in full — you always buy the seller's whole amount.".localized)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(WpayinColors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }

        let offers = matchingOffers(for: pair)
        if offers.isEmpty {
            Text("No offer covers this amount right now. Lower it or check back later.".localized)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(WpayinColors.textSecondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.vertical, 20)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: WpayinRadius.medium, style: .continuous)
                        .fill(WpayinColors.surface)
                )
        } else {
            ForEach(offers) { listing in
                listingRow(listing, isBestPrice: listing.id == offers.first?.id && offers.count > 1)
            }
        }
    }

    private func listingRow(_ listing: P2PListing, isBestPrice: Bool) -> some View {
        P2PListingRow(
            listing: listing,
            isBestPrice: isBestPrice,
            onTap: { onSelect(listing.payload) },
            onOwnOffer: { ownListing = listing },
            onReport: {
                Task {
                    try? await P2PMarketService.shared.report(listing)
                    await MainActor.run {
                        AppToast.show("Offer reported".localized, icon: "exclamationmark.shield")
                    }
                }
            },
            onBlock: {
                P2PMarketService.shared.block(wallet: listing.offer.signerWallet)
                listings.removeAll { $0.offer.signerWallet.caseInsensitiveCompare(listing.offer.signerWallet) == .orderedSame }
                AppToast.show("Seller blocked".localized, icon: "hand.raised.fill")
            }
        )
    }

    private func formatBoardAmount(_ value: Decimal) -> String {
        let doubleValue = (value as NSDecimalNumber).doubleValue
        return String(format: doubleValue >= 1 ? "%.2f" : "%.4f", doubleValue)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: loadFailed ? "wifi.slash" : "tray")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(WpayinColors.textSecondary)

            Text(loadFailed ? "Offer board unavailable".localized : "No public offers right now".localized)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(WpayinColors.text)

            Text(loadFailed
                 ? "error.p2p.boardUnavailable".localized
                 : "Be the first — create an offer and publish it to the board.".localized)
                .font(.wpayinCaption)
                .foregroundColor(WpayinColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .background(
            RoundedRectangle(cornerRadius: WpayinRadius.medium, style: .continuous)
                .fill(WpayinColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: WpayinRadius.medium, style: .continuous)
                        .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                )
        )
    }

    private func load() async {
        if listings.isEmpty {
            listings = P2PMarketService.shared.cachedListings()
        }
        isLoading = true
        do {
            let fetched = try await P2PMarketService.shared.fetchListings()
            await MainActor.run {
                // Newest first — freshest prices at the top.
                listings = fetched.sorted { $0.createdAt > $1.createdAt }
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
}

/// One marketplace listing from the buyer's perspective: what you get, what
/// you pay, the unit price with a fiat estimate, and when it was posted.
private struct P2PListingRow: View {
    let listing: P2PListing
    var isBestPrice: Bool = false
    let onTap: () -> Void
    let onOwnOffer: () -> Void
    let onReport: () -> Void
    let onBlock: () -> Void

    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var settingsManager: SettingsManager

    private var offer: P2POffer { listing.offer }

    /// The user's own listing — it can't be accepted from the same wallet.
    private var isOwnOffer: Bool {
        guard let blockchain = offer.blockchain,
              let myAddress = walletManager.availableChainAccounts[blockchain]?.address else {
            return false
        }
        return myAddress.caseInsensitiveCompare(offer.signerWallet) == .orderedSame
    }

    /// Price of 1 unit of the sold token, in the payment token.
    private var unitPrice: Double? {
        let sellAmount = (offer.signerAmountDecimal as NSDecimalNumber).doubleValue
        let payAmount = (offer.senderAmountDecimal as NSDecimalNumber).doubleValue
        guard sellAmount > 0, payAmount > 0 else { return nil }
        return payAmount / sellAmount
    }

    /// Fiat estimate of the full payment side, from live market prices.
    private var paymentFiatValue: Double? {
        guard let blockchain = offer.blockchain,
              let price = walletManager.currentUSDPrice(for: offer.senderSymbol, blockchain: blockchain),
              price > 0 else { return nil }
        return (offer.senderAmountDecimal as NSDecimalNumber).doubleValue * price
    }

    private var postedText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: settingsManager.selectedLanguage.rawValue)
        formatter.unitsStyle = .short
        return formatter.localizedString(for: listing.createdAt, relativeTo: Date())
    }

    var body: some View {
        Button {
            if isOwnOffer {
                onOwnOffer()
            } else {
                onTap()
            }
        } label: {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    if let network = offer.blockchain {
                        NetworkIconView(blockchain: network, size: 34)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Buy %@ for %@".localized(
                            "\(formatAmount(offer.signerAmountDecimal)) \(offer.signerSymbol)",
                            "\(formatAmount(offer.senderAmountDecimal)) \(offer.senderSymbol)"
                        ))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(WpayinColors.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)

                        HStack(spacing: 6) {
                            if let unitPrice {
                                Text("1 \(offer.signerSymbol) ≈ \(formatAmount(Decimal(unitPrice))) \(offer.senderSymbol)")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(WpayinColors.textSecondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }

                            if let paymentFiatValue {
                                Text("(≈ \(paymentFiatValue.formatted(as: settingsManager.selectedCurrency)))")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(WpayinColors.textTertiary)
                                    .lineLimit(1)
                            }
                        }
                    }

                    Spacer(minLength: 8)

                    if isOwnOffer {
                        Text("Your offer".localized)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(WpayinColors.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(WpayinColors.primary.opacity(0.12)))
                    } else {
                        if isBestPrice {
                            Text("Best price".localized)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(WpayinColors.success)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(WpayinColors.success.opacity(0.12)))
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(WpayinColors.textTertiary)
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(WpayinColors.textTertiary)

                    Text("Posted %@".localized(postedText))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(WpayinColors.textTertiary)

                    Text("· \("Expires".localized) \(Date(timeIntervalSince1970: offer.expiry).formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(WpayinColors.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Spacer()

                    Text("\(offer.signerWallet.prefix(6))…\(offer.signerWallet.suffix(4))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(WpayinColors.textTertiary)
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
        .buttonStyle(WpayinPressableStyle())
        .contextMenu {
            if !isOwnOffer {
                Button(action: onReport) {
                    Label("Report Offer".localized, systemImage: "exclamationmark.shield")
                }
                Button(role: .destructive, action: onBlock) {
                    Label("Block Seller".localized, systemImage: "hand.raised.fill")
                }
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
    @State private var usesMarketPrice = true
    @State private var suggestedReceiveAmount = ""

    @State private var showSellPicker = false
    @State private var showReceivePicker = false
    @State private var isCreating = false
    @State private var creationPhase: P2POfferCreationPhase = .checking
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
                P2POfferShareView(
                    offer: offer
                ) {
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
                if receiveToken?.blockchain != token.blockchain
                    || receiveToken.flatMap(effectiveAddress) == effectiveAddress(token) {
                    selectDefaultReceiveToken()
                }
                loadProtocolFee(for: token.blockchain)
                applyMarketPrice()
            }
        }
        .sheet(isPresented: $showReceivePicker) {
            TokenPickerView(tokens: receivableTokens, selectedToken: receiveToken) { token in
                receiveToken = token
                usesMarketPrice = true
                applyMarketPrice()
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
            if receiveToken == nil { selectDefaultReceiveToken() }
            reloadOffers()
            applyMarketPrice()
        }
        .onChange(of: sellAmount) { _ in applyMarketPrice() }
        .onChange(of: sellToken?.id) { _ in applyMarketPrice() }
        .onChange(of: receiveToken?.id) { _ in applyMarketPrice() }
        .onChange(of: receiveAmount) { newValue in
            if newValue != suggestedReceiveAmount { usesMarketPrice = false }
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
            onTokenSelect: { showSellPicker = true },
            onMax: { applyMaxSellAmount() }
        )

        ModernTokenSelector(
            title: "You receive".localized,
            selectedToken: receiveToken,
            amount: $receiveAmount,
            isInput: true,
            onTokenSelect: { showReceivePicker = true },
            showsMax: false
        )

        marketPriceRow

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
                Text(isCreating ? creationPhaseTitle : "Create Offer".localized)
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

    private var creationPhaseTitle: String {
        switch creationPhase {
        case .checking: return "Checking offer...".localized
        case .wrapping: return "Preparing tokens...".localized
        case .approving: return "Approving token...".localized
        case .signing: return "Signing offer...".localized
        }
    }

    private var marketPriceRow: some View {
        HStack(spacing: 8) {
            Image(systemName: usesMarketPrice ? "chart.line.uptrend.xyaxis" : "slider.horizontal.3")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(WpayinColors.primary)

            Text(usesMarketPrice
                 ? "Live market price — you can edit the amount above".localized
                 : "Custom price set by you".localized)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(WpayinColors.textSecondary)

            Spacer(minLength: 6)

            if !usesMarketPrice, !suggestedReceiveAmount.isEmpty {
                Button("Use market".localized) {
                    usesMarketPrice = true
                    receiveAmount = suggestedReceiveAmount
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(WpayinColors.primary)
            }
        }
        .padding(.horizontal, 4)
    }

    private func applyMarketPrice() {
        guard let sellToken, let receiveToken,
              sellValue > 0,
              sellToken.price > 0,
              receiveToken.price > 0 else {
            suggestedReceiveAmount = ""
            if usesMarketPrice { receiveAmount = "" }
            return
        }

        let marketAmount = sellValue * sellToken.price / receiveToken.price
        var formatted = String(format: marketAmount >= 1 ? "%.2f" : "%.6f", marketAmount)
        while formatted.contains("."), formatted.last == "0" { formatted.removeLast() }
        if formatted.last == "." { formatted.removeLast() }
        suggestedReceiveAmount = formatted
        if usesMarketPrice { receiveAmount = formatted }
    }

    private func selectDefaultReceiveToken() {
        receiveToken = receivableTokens.first {
            $0.symbol.caseInsensitiveCompare("USDT") == .orderedSame
        } ?? receivableTokens.first {
            $0.symbol.caseInsensitiveCompare("USDC") == .orderedSame
        } ?? receivableTokens.first
        usesMarketPrice = true
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

    /// MAX = highest sell amount whose amount + protocol fee still fits the
    /// balance; natives also keep back the 0.002 wrap gas reserve
    /// (mirrors P2PTradeService.wrapNativeShortfall).
    private func applyMaxSellAmount() {
        guard let token = sellToken else { return }
        if let bps = protocolFeeBps {
            sellAmount = maxSellAmount(for: token, feeBps: bps)
        } else {
            Task {
                let bps = try? await P2PTradeService.shared.fetchProtocolFeeBps(blockchain: token.blockchain)
                await MainActor.run {
                    protocolFeeBps = bps
                    sellAmount = maxSellAmount(for: token, feeBps: bps ?? 0)
                }
            }
        }
    }

    private func maxSellAmount(for token: Token, feeBps: Int) -> String {
        var available = token.balance
        if token.isNative { available -= 0.002 }
        let maxSell = available / (1 + Double(feeBps) / 10_000)
        // Floor to 8 decimals minus one unit so double rounding can never
        // push amount + fee back over the balance.
        let floored = ((maxSell * 100_000_000).rounded(.down) - 1) / 100_000_000
        guard floored > 0 else { return "" }
        var result = String(format: "%.8f", floored)
        while result.contains("."), result.last == "0" { result.removeLast() }
        if result.last == "." { result.removeLast() }
        return result
    }

    private func createOffer() {
        guard let sellToken, let receiveToken,
              sellValue > 0, receiveValue > 0 else { return }
        isCreating = true

        Task {
            // Creating an offer can wrap natives and approve tokens on-chain.
            guard await settingsManager.authorizeSpending(reason: "auth.confirmPayment".localized) else {
                await MainActor.run { isCreating = false }
                return
            }
            do {
                let offer = try await P2PTradeService.shared.createOffer(
                    sellToken: sellToken,
                    sellAmount: Decimal(sellValue),
                    receiveToken: receiveToken,
                    receiveAmount: Decimal(receiveValue),
                    validFor: validHours * 3600,
                    onPhase: { creationPhase = $0 }
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

                Button("Done".localized, action: onDone)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(WpayinColors.textSecondary)

                Spacer(minLength: 24)
            }
            .padding(20)
        }
        .onAppear {
            generateQR()
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

            Button {
                pasteFromClipboard()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Paste offer code".localized)
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(WpayinColors.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(WpayinColors.primary.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .stroke(WpayinColors.primary.opacity(0.5), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(WpayinPressableStyle())

            if isValidating {
                HStack(spacing: 9) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(WpayinColors.primary)
                    Text("Verifying offer...".localized)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(WpayinColors.textSecondary)
                }
                .padding(.top, 2)
            }
        }
        .onChange(of: payloadText) { newValue in
            autoValidate(newValue)
        }
    }

    private func pasteFromClipboard() {
        guard let clipboard = UIPasteboard.general.string?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !clipboard.isEmpty else {
            errorMessage = "error.p2p.invalidOffer".localized
            showError = true
            return
        }
        payloadText = clipboard
        // onChange fires validation only for decodable payloads — surface
        // the error directly when the clipboard holds something else.
        if P2PTradeService.shared.decode(clipboard) == nil {
            errorMessage = "error.p2p.invalidOffer".localized
            showError = true
        }
    }

    /// Kick off verification automatically once the text is a complete,
    /// decodable offer payload — no separate "Verify" step needed.
    private func autoValidate(_ text: String) {
        guard !isValidating, check == nil,
              P2PTradeService.shared.decode(text) != nil else { return }
        validate()
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

            // Why neither side can cheat: atomic settlement + pre-flight dry run.
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(WpayinColors.primary)
                        .frame(width: 18)

                    Text("Settlement is atomic — both sides receive their tokens in one transaction, or nothing happens.".localized)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(WpayinColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(WpayinColors.primary)
                        .frame(width: 18)

                    Text("The offer is re-verified and simulated on-chain right before you confirm — if the seller can no longer cover it, the trade stops and you pay nothing.".localized)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(WpayinColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: WpayinRadius.medium, style: .continuous)
                    .fill(WpayinColors.primary.opacity(0.08))
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
            guard await settingsManager.authorizeSpending(reason: "auth.confirmPayment".localized) else {
                await MainActor.run { isAccepting = false }
                return
            }
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
