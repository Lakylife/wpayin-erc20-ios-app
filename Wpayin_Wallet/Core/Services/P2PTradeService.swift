// Autor Lukas Helebrandt, 2026

//
//  P2PTradeService.swift
//  Wpayin_Wallet
//
//  Peer-to-peer trading between Wpayin users, settled atomically on-chain
//  through the audited AirSwap SwapERC20 contract. The seller (signer) signs
//  an EIP-712 order off-chain and shares it as a QR code / link; the buyer
//  (sender) submits it. The contract transfers both sides in one transaction —
//  either the whole trade happens or nothing does, so neither party can be
//  cheated. Both wallets are checked on-chain (balances, allowance, nonce,
//  signature, fees) before the trade is allowed.
//

import Foundation
import BigInt
import WalletCore

enum P2PTradeError: LocalizedError {
    case unsupportedNetwork
    case erc20Only
    case invalidOffer
    case offerExpired
    case offerAlreadyUsed
    case signatureMismatch
    case makerCannotCover
    case takerCannotCover
    case notEnoughGas
    case signingFailed
    case fillWouldFail

    var errorDescription: String? {
        switch self {
        case .unsupportedNetwork: return "error.p2p.unsupportedNetwork".localized
        case .erc20Only: return "error.p2p.erc20Only".localized
        case .invalidOffer: return "error.p2p.invalidOffer".localized
        case .offerExpired: return "error.p2p.offerExpired".localized
        case .offerAlreadyUsed: return "error.p2p.offerAlreadyUsed".localized
        case .signatureMismatch: return "error.p2p.signatureMismatch".localized
        case .makerCannotCover: return "error.p2p.makerCannotCover".localized
        case .takerCannotCover: return "error.p2p.takerCannotCover".localized
        case .notEnoughGas: return "error.p2p.notEnoughGas".localized
        case .signingFailed: return "error.tx.failedToSign".localized
        case .fillWouldFail: return "error.p2p.fillWouldFail".localized
        }
    }
}

/// A signed, shareable P2P trade offer (AirSwap OrderERC20 with senderWallet = 0,
/// so anyone holding the offer can fill it via swapAnySender).
struct P2POffer: Codable, Equatable {
    var version = 1
    let chainId: Int
    let nonce: String            // uint256 as decimal string
    let expiry: TimeInterval     // unix seconds

    let signerWallet: String     // seller
    let signerToken: String      // token the seller gives
    let signerAmount: String     // smallest units, decimal string
    let signerSymbol: String
    let signerDecimals: Int

    let senderToken: String      // token the seller wants
    let senderAmount: String     // smallest units, decimal string
    let senderSymbol: String
    let senderDecimals: Int

    let protocolFeeBps: Int      // AirSwap protocol fee signed into the order

    let sigV: Int                // 27/28
    let sigR: String             // 0x…
    let sigS: String             // 0x…

    var blockchain: BlockchainType? {
        BlockchainType.allCases.first { $0.chainId == chainId }
    }

    var signerAmountDecimal: Decimal {
        (Decimal(string: signerAmount) ?? 0) / swapPow(Decimal(10), signerDecimals)
    }

    var senderAmountDecimal: Decimal {
        (Decimal(string: senderAmount) ?? 0) / swapPow(Decimal(10), senderDecimals)
    }

    var isExpired: Bool {
        Date().timeIntervalSince1970 >= expiry
    }
}

/// Result of validating an offer from the buyer's point of view.
struct P2POfferCheck {
    let offer: P2POffer
    let takerPlatformFee: Decimal   // our platform fee, in sender-token units
}

final class P2PTradeService {
    static let shared = P2PTradeService()
    private init() {}

    /// AirSwap SwapERC20 v4.3 — deployed at the same address on every
    /// supported chain (verified via eth_getCode 2026-07-06). Optimism has
    /// no deployment, so it is intentionally absent.
    static let swapContracts: [BlockchainType: String] = [
        .ethereum: "0xD82E10B9A4107939e55fCCa9B53A9ede6CF2fC46",
        .bsc: "0xD82E10B9A4107939e55fCCa9B53A9ede6CF2fC46",
        .polygon: "0xD82E10B9A4107939e55fCCa9B53A9ede6CF2fC46",
        .arbitrum: "0xD82E10B9A4107939e55fCCa9B53A9ede6CF2fC46",
        .base: "0xD82E10B9A4107939e55fCCa9B53A9ede6CF2fC46",
        .avalanche: "0xD82E10B9A4107939e55fCCa9B53A9ede6CF2fC46"
    ]

    static var supportedBlockchains: Set<BlockchainType> { Set(swapContracts.keys) }

    /// Canonical wrapped-native tokens. Selling or paying with the native coin
    /// is supported by auto-wrapping the needed amount into these (deposit()
    /// is a 1:1 wrap, so the user's value is unchanged).
    static let wrappedNative: [BlockchainType: (address: String, symbol: String)] = [
        .ethereum: ("0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", "WETH"),
        .arbitrum: ("0x82aF49447D8a07e3bd95BD0d56f35241523fBab1", "WETH"),
        .base: ("0x4200000000000000000000000000000000000006", "WETH"),
        .polygon: ("0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270", "WMATIC"),
        .bsc: ("0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c", "WBNB"),
        .avalanche: ("0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7", "WAVAX")
    ]

    private let payloadPrefix = "WPAYIN-P2P:"

    // EIP-712 — must exactly match SwapERC20.sol (name SWAP_ERC20, version 4.3)
    private let domainTypeHash = Data(hexString: "8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f")!
    private let domainNameHash = Data(hexString: "53be2722d46649832d0712cbda538f9399a2de2a00cf45739b4874b2169e004c")!   // keccak("SWAP_ERC20")
    private let domainVersionHash = Data(hexString: "1a4a38b58898b90facc89350d9c72c929053b43bc088c91ec178f60fc1f34678")! // keccak("4.3")
    private let orderTypeHash = Data(hexString: "c0c0b55c946f3a31595c7c56c2fcfb240731b0e424d96f05eea86f1997ebf0d8")!

    // MARK: - Offer creation (seller)

    /// Create and sign a sell offer. Verifies the seller can cover the amount
    /// plus the AirSwap protocol fee, and grants the swap contract an
    /// allowance when needed (one approve transaction).
    func createOffer(
        sellToken: Token,
        sellAmount: Decimal,
        receiveToken: Token,
        receiveAmount: Decimal,
        validFor: TimeInterval
    ) async throws -> P2POffer {
        let blockchain = sellToken.blockchain
        guard let contract = Self.swapContracts[blockchain],
              let chainId = blockchain.chainId,
              receiveToken.blockchain == blockchain else {
            throw P2PTradeError.unsupportedNetwork
        }

        guard let privateKey = try SwapService.shared.getPrivateKey(for: blockchain) else {
            throw TransactionError.noPrivateKey
        }
        let signerWallet = try SwapService.shared.deriveAddress(from: privateKey, blockchain: blockchain)

        // Native coins are sold as their canonical wrapped ERC-20 (1:1)
        var effectiveSellToken = sellToken
        if sellToken.isNative {
            guard let wrapped = Self.wrappedNative[blockchain] else { throw P2PTradeError.erc20Only }
            effectiveSellToken = Token(
                contractAddress: wrapped.address,
                name: wrapped.symbol,
                symbol: wrapped.symbol,
                decimals: 18,
                balance: sellToken.balance,
                price: sellToken.price,
                iconUrl: sellToken.iconUrl,
                blockchain: blockchain,
                isNative: false
            )
        }
        guard let sellAddress = effectiveSellToken.contractAddress else { throw P2PTradeError.erc20Only }

        // The receive side may also be the native coin — the buyer will pay
        // its wrapped form (auto-wrapped on their side when accepting).
        var effectiveReceiveToken = receiveToken
        if receiveToken.isNative {
            guard let wrapped = Self.wrappedNative[blockchain] else { throw P2PTradeError.erc20Only }
            effectiveReceiveToken = Token(
                contractAddress: wrapped.address,
                name: wrapped.symbol,
                symbol: wrapped.symbol,
                decimals: 18,
                balance: 0,
                price: receiveToken.price,
                iconUrl: receiveToken.iconUrl,
                blockchain: blockchain,
                isNative: false
            )
        }
        guard let receiveAddress = effectiveReceiveToken.contractAddress,
              receiveAddress.lowercased() != sellAddress.lowercased() else {
            throw P2PTradeError.invalidOffer
        }

        // The protocol fee is part of the signed order hash — read the live value.
        let protocolFeeBps = try await fetchProtocolFeeBps(blockchain: blockchain)

        let signerUnits = units(from: sellAmount, decimals: effectiveSellToken.decimals)
        let senderUnits = units(from: receiveAmount, decimals: effectiveReceiveToken.decimals)
        guard signerUnits > 0, senderUnits > 0 else { throw P2PTradeError.invalidOffer }

        // Seller must hold amount + protocol fee; wrap the shortfall when
        // selling the native coin.
        let requiredUnits = signerUnits + signerUnits * BigUInt(protocolFeeBps) / BigUInt(10_000)
        if sellToken.isNative {
            try await wrapNativeShortfall(
                requiredUnits: requiredUnits,
                wrappedAddress: sellAddress,
                owner: signerWallet,
                blockchain: blockchain,
                privateKey: privateKey
            )
        }
        let sellerBalance = try await erc20Balance(of: signerWallet, token: sellAddress, blockchain: blockchain)
        guard sellerBalance >= requiredUnits else { throw P2PTradeError.makerCannotCover }

        // Allowance for amount + fee (approve when missing)
        let requiredDecimal = sellAmount * (1 + Decimal(protocolFeeBps) / 10_000)
        try await SwapService.shared.checkAndApproveToken(
            token: effectiveSellToken,
            owner: signerWallet,
            spender: contract,
            amount: requiredDecimal,
            blockchain: blockchain,
            privateKey: privateKey
        )

        let nonce = BigUInt(UInt64.random(in: 1...UInt64.max))
        let expiry = Date().timeIntervalSince1970 + validFor

        let digest = orderDigest(
            chainId: chainId,
            contract: contract,
            nonce: nonce,
            expiry: BigUInt(UInt64(expiry)),
            signerWallet: signerWallet,
            signerToken: sellAddress,
            signerAmount: signerUnits,
            protocolFee: BigUInt(protocolFeeBps),
            senderWallet: "0x0000000000000000000000000000000000000000", // anyone may fill
            senderToken: receiveAddress,
            senderAmount: senderUnits
        )

        guard let key = PrivateKey(data: privateKey),
              let signature = key.sign(digest: digest, curve: .secp256k1) else {
            throw P2PTradeError.signingFailed
        }

        return P2POffer(
            chainId: chainId,
            nonce: nonce.description,
            expiry: expiry,
            signerWallet: signerWallet,
            signerToken: sellAddress,
            signerAmount: signerUnits.description,
            signerSymbol: effectiveSellToken.symbol,
            signerDecimals: effectiveSellToken.decimals,
            senderToken: receiveAddress,
            senderAmount: senderUnits.description,
            senderSymbol: effectiveReceiveToken.symbol,
            senderDecimals: effectiveReceiveToken.decimals,
            protocolFeeBps: protocolFeeBps,
            sigV: Int(signature[64]) + 27,
            sigR: "0x" + signature[0..<32].hexString,
            sigS: "0x" + signature[32..<64].hexString
        )
    }

    // MARK: - Offer validation (buyer)

    /// Full safety check before the buyer accepts: known contract, expiry,
    /// unused nonce, valid signature, seller still funded and approved, and
    /// buyer able to cover the price incl. our platform fee and gas.
    func validateOffer(_ offer: P2POffer) async throws -> P2POfferCheck {
        guard let blockchain = offer.blockchain,
              let contract = Self.swapContracts[blockchain],
              let chainId = blockchain.chainId, chainId == offer.chainId else {
            throw P2PTradeError.unsupportedNetwork
        }
        guard let signerUnits = BigUInt(offer.signerAmount),
              let senderUnits = BigUInt(offer.senderAmount),
              signerUnits > 0, senderUnits > 0,
              offer.signerToken.hasPrefix("0x"), offer.signerToken.count == 42,
              offer.senderToken.hasPrefix("0x"), offer.senderToken.count == 42,
              offer.signerWallet.hasPrefix("0x"), offer.signerWallet.count == 42,
              let nonce = BigUInt(offer.nonce) else {
            throw P2PTradeError.invalidOffer
        }
        guard !offer.isExpired else { throw P2PTradeError.offerExpired }

        // Protocol fee in the order hash must match the live contract value
        let liveFee = try await fetchProtocolFeeBps(blockchain: blockchain)
        guard liveFee == offer.protocolFeeBps else { throw P2PTradeError.invalidOffer }

        // Nonce must be unused — nonceUsed(address,uint256) 0x1647795e
        var nonceCall = Data(hexString: "1647795e")!
        nonceCall.append(abiAddress(offer.signerWallet))
        nonceCall.append(abiUInt(nonce))
        let nonceResult = try await SwapService.shared.ethCall(to: contract, data: nonceCall, blockchain: blockchain)
        guard BigUInt(nonceResult) == 0 else { throw P2PTradeError.offerAlreadyUsed }

        // Signature must recover to the seller's wallet
        let digest = orderDigest(
            chainId: chainId,
            contract: contract,
            nonce: nonce,
            expiry: BigUInt(UInt64(offer.expiry)),
            signerWallet: offer.signerWallet,
            signerToken: offer.signerToken,
            signerAmount: signerUnits,
            protocolFee: BigUInt(offer.protocolFeeBps),
            senderWallet: "0x0000000000000000000000000000000000000000",
            senderToken: offer.senderToken,
            senderAmount: senderUnits
        )
        guard let r = Data(hexString: String(offer.sigR.dropFirst(2))),
              let s = Data(hexString: String(offer.sigS.dropFirst(2))),
              offer.sigV == 27 || offer.sigV == 28 else {
            throw P2PTradeError.invalidOffer
        }
        var recoverable = Data()
        recoverable.append(r)
        recoverable.append(s)
        recoverable.append(UInt8(offer.sigV - 27))
        guard let publicKey = PublicKey.recover(signature: recoverable, message: digest),
              AnyAddress(publicKey: publicKey, coin: .ethereum).description.lowercased()
                == offer.signerWallet.lowercased() else {
            throw P2PTradeError.signatureMismatch
        }

        // Seller must still hold and approve amount + protocol fee
        let requiredMaker = signerUnits + signerUnits * BigUInt(offer.protocolFeeBps) / BigUInt(10_000)
        let makerBalance = try await erc20Balance(of: offer.signerWallet, token: offer.signerToken, blockchain: blockchain)
        let makerAllowance = try await erc20Allowance(
            owner: offer.signerWallet, spender: contract,
            token: offer.signerToken, blockchain: blockchain
        )
        guard makerBalance >= requiredMaker, makerAllowance >= requiredMaker else {
            throw P2PTradeError.makerCannotCover
        }

        // Buyer must cover price + our platform fee, and have gas
        guard let takerKey = try SwapService.shared.getPrivateKey(for: blockchain) else {
            throw TransactionError.noPrivateKey
        }
        let takerWallet = try SwapService.shared.deriveAddress(from: takerKey, blockchain: blockchain)
        guard takerWallet.lowercased() != offer.signerWallet.lowercased() else {
            throw P2PTradeError.invalidOffer
        }

        let platformFee = TransactionService.platformFee(for: offer.senderAmountDecimal)
        let platformFeeUnits = units(from: platformFee, decimals: offer.senderDecimals)
        let requiredTaker = senderUnits + platformFeeUnits
        var takerBalance = try await erc20Balance(of: takerWallet, token: offer.senderToken, blockchain: blockchain)

        // Paying with the wrapped native? The native coin counts too — the
        // shortfall gets auto-wrapped 1:1 when accepting (gas is checked below).
        if takerBalance < requiredTaker, isWrappedNative(offer.senderToken, blockchain: blockchain) {
            let nativeHex = try await SwapService.shared.rpcRequest(
                method: "eth_getBalance", params: [takerWallet, "latest"], blockchain: blockchain
            )
            if let native = hexQuantity(nativeHex) {
                // Keep a gas reserve out of the spendable native amount
                let reserve = BigUInt(2) * BigUInt(10).power(15) // 0.002 native
                takerBalance += native > reserve ? native - reserve : 0
            }
        }
        guard takerBalance >= requiredTaker else { throw P2PTradeError.takerCannotCover }

        // Rough gas check: approve + swap ≈ 400k units of the native coin
        let gasPriceHex = try await SwapService.shared.rpcRequest(method: "eth_gasPrice", params: [], blockchain: blockchain)
        let balanceHex = try await SwapService.shared.rpcRequest(method: "eth_getBalance", params: [takerWallet, "latest"], blockchain: blockchain)
        if let gasPrice = hexQuantity(gasPriceHex), let nativeBalance = hexQuantity(balanceHex) {
            guard nativeBalance >= gasPrice * BigUInt(400_000) else { throw P2PTradeError.notEnoughGas }
        }

        return P2POfferCheck(offer: offer, takerPlatformFee: platformFee)
    }

    // MARK: - Offer acceptance (buyer)

    /// Approve the payment token when needed, then submit swapAnySender.
    /// The offer is re-validated against fresh on-chain state and the exact
    /// fill is dry-run via eth_call first, so a seller who moved their funds
    /// or revoked approval in the meantime costs the buyer nothing — the
    /// trade is aborted before any gas is spent. Settlement itself is atomic
    /// inside the contract. Returns the tx hash.
    func acceptOffer(_ offer: P2POffer) async throws -> String {
        guard let blockchain = offer.blockchain,
              let contract = Self.swapContracts[blockchain],
              let signerUnits = BigUInt(offer.signerAmount),
              let senderUnits = BigUInt(offer.senderAmount),
              let nonce = BigUInt(offer.nonce) else {
            throw P2PTradeError.invalidOffer
        }

        // Re-check everything now — verification may have happened minutes ago
        _ = try await validateOffer(offer)

        guard let privateKey = try SwapService.shared.getPrivateKey(for: blockchain) else {
            throw TransactionError.noPrivateKey
        }
        let takerWallet = try SwapService.shared.deriveAddress(from: privateKey, blockchain: blockchain)

        // Paying with the wrapped native — wrap the shortfall first (1:1)
        let platformFeeForWrap = TransactionService.platformFee(for: offer.senderAmountDecimal)
        let neededUnits = senderUnits + units(from: platformFeeForWrap, decimals: offer.senderDecimals)
        if isWrappedNative(offer.senderToken, blockchain: blockchain) {
            try await wrapNativeShortfall(
                requiredUnits: neededUnits,
                wrappedAddress: offer.senderToken,
                owner: takerWallet,
                blockchain: blockchain,
                privateKey: privateKey
            )
        }

        // Allowance for the payment token
        let currentAllowance = try await erc20Allowance(
            owner: takerWallet, spender: contract,
            token: offer.senderToken, blockchain: blockchain
        )
        if currentAllowance < senderUnits {
            let paymentToken = Token(
                contractAddress: offer.senderToken,
                name: offer.senderSymbol,
                symbol: offer.senderSymbol,
                decimals: offer.senderDecimals,
                balance: 0,
                price: 0,
                iconUrl: nil,
                blockchain: blockchain,
                isNative: false
            )
            try await SwapService.shared.checkAndApproveToken(
                token: paymentToken,
                owner: takerWallet,
                spender: contract,
                amount: offer.senderAmountDecimal,
                blockchain: blockchain,
                privateKey: privateKey
            )
            // The dry-run below reads mined state, so wait for the approve
            try await waitForAllowance(
                atLeast: senderUnits, owner: takerWallet, spender: contract,
                token: offer.senderToken, blockchain: blockchain
            )
        }

        // swapAnySender(recipient,nonce,expiry,signerWallet,signerToken,signerAmount,senderToken,senderAmount,v,r,s)
        var callData = Data(hexString: functionSelector(
            "swapAnySender(address,uint256,uint256,address,address,uint256,address,uint256,uint8,bytes32,bytes32)"
        ))!
        callData.append(abiAddress(takerWallet))
        callData.append(abiUInt(nonce))
        callData.append(abiUInt(BigUInt(UInt64(offer.expiry))))
        callData.append(abiAddress(offer.signerWallet))
        callData.append(abiAddress(offer.signerToken))
        callData.append(abiUInt(signerUnits))
        callData.append(abiAddress(offer.senderToken))
        callData.append(abiUInt(senderUnits))
        callData.append(abiUInt(BigUInt(offer.sigV)))
        callData.append(Data(hexString: String(offer.sigR.dropFirst(2)))!)
        callData.append(Data(hexString: String(offer.sigS.dropFirst(2)))!)

        // Dry-run the exact fill — a revert here costs nothing
        do {
            _ = try await SwapService.shared.rpcRequest(
                method: "eth_call",
                params: [
                    ["from": takerWallet, "to": contract, "data": "0x" + callData.hexString],
                    "latest"
                ],
                blockchain: blockchain
            )
        } catch {
            Logger.log("🛑 P2P fill simulation reverted: \(error.localizedDescription)")
            throw P2PTradeError.fillWouldFail
        }

        let txHash = try await SwapService.shared.sendRawTransaction(
            from: takerWallet,
            to: contract,
            value: BigUInt(0),
            data: callData,
            gasLimit: BigUInt(300_000),
            blockchain: blockchain,
            privateKey: privateKey
        )

        // Our platform fee — separate transfer, never blocks the trade itself
        let platformFee = TransactionService.platformFee(for: offer.senderAmountDecimal)
        if platformFee > 0 {
            let feeUnits = units(from: platformFee, decimals: offer.senderDecimals)
            if feeUnits > 0 {
                var feeData = Data(hexString: "a9059cbb")! // transfer(address,uint256)
                feeData.append(abiAddress(AppConfig.platformFeeRecipient))
                feeData.append(abiUInt(feeUnits))
                do {
                    let feeTx = try await SwapService.shared.sendRawTransaction(
                        from: takerWallet,
                        to: offer.senderToken,
                        value: BigUInt(0),
                        data: feeData,
                        gasLimit: BigUInt(65_000),
                        blockchain: blockchain,
                        privateKey: privateKey
                    )
                    Logger.log("💸 P2P platform fee broadcast: \(feeTx)")
                } catch {
                    Logger.log("⚠️ P2P platform fee failed (trade unaffected): \(error.localizedDescription)")
                }
            }
        }

        return txHash
    }

    // MARK: - Offer cancellation (seller)

    /// Mark the offer's nonce as used on-chain so nobody can fill it anymore.
    /// This is the honest way for the seller to withdraw an offer.
    func cancelOffer(_ offer: P2POffer) async throws -> String {
        guard let blockchain = offer.blockchain,
              let contract = Self.swapContracts[blockchain],
              let nonce = BigUInt(offer.nonce) else {
            throw P2PTradeError.invalidOffer
        }
        guard let privateKey = try SwapService.shared.getPrivateKey(for: blockchain) else {
            throw TransactionError.noPrivateKey
        }
        let wallet = try SwapService.shared.deriveAddress(from: privateKey, blockchain: blockchain)
        guard wallet.lowercased() == offer.signerWallet.lowercased() else {
            throw P2PTradeError.invalidOffer
        }

        // cancel(uint256[]) — 0x2e340823
        var callData = Data(hexString: "2e340823")!
        callData.append(abiUInt(BigUInt(32))) // array offset
        callData.append(abiUInt(BigUInt(1)))  // length
        callData.append(abiUInt(nonce))

        return try await SwapService.shared.sendRawTransaction(
            from: wallet,
            to: contract,
            value: BigUInt(0),
            data: callData,
            gasLimit: BigUInt(80_000),
            blockchain: blockchain,
            privateKey: privateKey
        )
    }

    /// Whether the offer's nonce is already used on-chain (filled or cancelled).
    func isOfferUsed(_ offer: P2POffer) async throws -> Bool {
        guard let blockchain = offer.blockchain,
              let contract = Self.swapContracts[blockchain],
              let nonce = BigUInt(offer.nonce) else {
            throw P2PTradeError.invalidOffer
        }
        var call = Data(hexString: "1647795e")! // nonceUsed(address,uint256)
        call.append(abiAddress(offer.signerWallet))
        call.append(abiUInt(nonce))
        let result = try await SwapService.shared.ethCall(to: contract, data: call, blockchain: blockchain)
        return BigUInt(result) != 0
    }

    // MARK: - My offers (local persistence for the seller)

    private let savedOffersKey = "P2PActiveOffers"

    func savedOffers() -> [P2POffer] {
        guard let data = UserDefaults.standard.data(forKey: savedOffersKey),
              let offers = try? JSONDecoder().decode([P2POffer].self, from: data) else {
            return []
        }
        // Drop offers that expired more than a week ago
        let cutoff = Date().timeIntervalSince1970 - 7 * 86_400
        return offers.filter { $0.expiry > cutoff }
    }

    func saveOffer(_ offer: P2POffer) {
        var offers = savedOffers().filter { $0.nonce != offer.nonce }
        offers.append(offer)
        persist(offers)
    }

    func removeOffer(_ offer: P2POffer) {
        persist(savedOffers().filter { $0.nonce != offer.nonce })
    }

    private func persist(_ offers: [P2POffer]) {
        if let data = try? JSONEncoder().encode(offers) {
            UserDefaults.standard.set(data, forKey: savedOffersKey)
        }
    }

    private func isWrappedNative(_ address: String, blockchain: BlockchainType) -> Bool {
        Self.wrappedNative[blockchain]?.address.lowercased() == address.lowercased()
    }

    /// Wrap just enough of the native coin (deposit(), 1:1) so the wrapped
    /// balance reaches `requiredUnits`; waits until the wrap is mined.
    private func wrapNativeShortfall(
        requiredUnits: BigUInt,
        wrappedAddress: String,
        owner: String,
        blockchain: BlockchainType,
        privateKey: Data
    ) async throws {
        let wrappedBalance = try await erc20Balance(of: owner, token: wrappedAddress, blockchain: blockchain)
        guard wrappedBalance < requiredUnits else { return }
        let shortfall = requiredUnits - wrappedBalance

        // Native balance must cover the shortfall plus a gas reserve
        let nativeHex = try await SwapService.shared.rpcRequest(
            method: "eth_getBalance", params: [owner, "latest"], blockchain: blockchain
        )
        let reserve = BigUInt(2) * BigUInt(10).power(15) // 0.002 native for gas
        guard let native = hexQuantity(nativeHex), native >= shortfall + reserve else {
            throw P2PTradeError.takerCannotCover
        }

        Logger.log("🎁 Wrapping \(shortfall) native units into \(wrappedAddress)")
        _ = try await SwapService.shared.sendRawTransaction(
            from: owner,
            to: wrappedAddress,
            value: shortfall,
            data: Data(hexString: "d0e30db0")!, // deposit()
            gasLimit: BigUInt(60_000),
            blockchain: blockchain,
            privateKey: privateKey
        )

        // Wait until the wrap is mined so follow-up checks see the balance
        for _ in 0..<15 {
            try await Task.sleep(nanoseconds: 3_000_000_000)
            if let balance = try? await erc20Balance(of: owner, token: wrappedAddress, blockchain: blockchain),
               balance >= requiredUnits {
                return
            }
        }
        Logger.log("🛑 Native wrap not mined in time")
        throw P2PTradeError.fillWouldFail
    }

    /// Poll the payment-token allowance until the approve transaction lands.
    private func waitForAllowance(
        atLeast required: BigUInt,
        owner: String,
        spender: String,
        token: String,
        blockchain: BlockchainType
    ) async throws {
        for _ in 0..<15 {
            try await Task.sleep(nanoseconds: 3_000_000_000)
            if let allowance = try? await erc20Allowance(
                owner: owner, spender: spender, token: token, blockchain: blockchain
            ), allowance >= required {
                return
            }
        }
        Logger.log("🛑 P2P approve not mined in time")
        throw P2PTradeError.fillWouldFail
    }

    // MARK: - Payload encoding (QR / share)

    func encode(_ offer: P2POffer) -> String? {
        guard let data = try? JSONEncoder().encode(offer) else { return nil }
        return payloadPrefix + data.base64EncodedString()
    }

    func decode(_ payload: String) -> P2POffer? {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(payloadPrefix),
              let data = Data(base64Encoded: String(trimmed.dropFirst(payloadPrefix.count))),
              let offer = try? JSONDecoder().decode(P2POffer.self, from: data) else {
            return nil
        }
        return offer
    }

    // MARK: - On-chain reads

    func fetchProtocolFeeBps(blockchain: BlockchainType) async throws -> Int {
        guard let contract = Self.swapContracts[blockchain] else {
            throw P2PTradeError.unsupportedNetwork
        }
        let result = try await SwapService.shared.ethCall(
            to: contract,
            data: Data(hexString: "b0e21e8a")!, // protocolFee()
            blockchain: blockchain
        )
        return Int(BigUInt(result))
    }

    private func erc20Balance(of owner: String, token: String, blockchain: BlockchainType) async throws -> BigUInt {
        var call = Data(hexString: "70a08231")! // balanceOf(address)
        call.append(abiAddress(owner))
        let result = try await SwapService.shared.ethCall(to: token, data: call, blockchain: blockchain)
        return BigUInt(result)
    }

    private func erc20Allowance(owner: String, spender: String, token: String, blockchain: BlockchainType) async throws -> BigUInt {
        var call = Data(hexString: "dd62ed3e")! // allowance(address,address)
        call.append(abiAddress(owner))
        call.append(abiAddress(spender))
        let result = try await SwapService.shared.ethCall(to: token, data: call, blockchain: blockchain)
        return BigUInt(result)
    }

    // MARK: - EIP-712

    /// keccak256(0x1901 ‖ domainSeparator ‖ structHash) per EIP-712.
    private func orderDigest(
        chainId: Int,
        contract: String,
        nonce: BigUInt,
        expiry: BigUInt,
        signerWallet: String,
        signerToken: String,
        signerAmount: BigUInt,
        protocolFee: BigUInt,
        senderWallet: String,
        senderToken: String,
        senderAmount: BigUInt
    ) -> Data {
        var domain = Data()
        domain.append(domainTypeHash)
        domain.append(domainNameHash)
        domain.append(domainVersionHash)
        domain.append(abiUInt(BigUInt(chainId)))
        domain.append(abiAddress(contract))
        let domainSeparator = Hash.keccak256(data: domain)

        var order = Data()
        order.append(orderTypeHash)
        order.append(abiUInt(nonce))
        order.append(abiUInt(expiry))
        order.append(abiAddress(signerWallet))
        order.append(abiAddress(signerToken))
        order.append(abiUInt(signerAmount))
        order.append(abiUInt(protocolFee))
        order.append(abiAddress(senderWallet))
        order.append(abiAddress(senderToken))
        order.append(abiUInt(senderAmount))
        let structHash = Hash.keccak256(data: order)

        var message = Data([0x19, 0x01])
        message.append(domainSeparator)
        message.append(structHash)
        return Hash.keccak256(data: message)
    }

    // MARK: - Small helpers

    private func units(from amount: Decimal, decimals: Int) -> BigUInt {
        BigUInt((amount * swapPow(Decimal(10), decimals)).swapRounded().description) ?? BigUInt(0)
    }

    private func functionSelector(_ signature: String) -> String {
        Hash.keccak256(data: Data(signature.utf8)).prefix(4).hexString
    }

    private func abiUInt(_ value: BigUInt) -> Data {
        let raw = value.serialize()
        var result = Data(repeating: 0, count: max(0, 32 - raw.count))
        result.append(raw)
        return result
    }

    private func abiAddress(_ address: String) -> Data {
        let raw = Data(hexString: String(address.dropFirst(2))) ?? Data()
        var result = Data(repeating: 0, count: max(0, 32 - raw.count))
        result.append(raw)
        return result
    }

    private func hexQuantity(_ value: Any) -> BigUInt? {
        guard let hex = value as? String else { return nil }
        let stripped = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        return BigUInt(stripped, radix: 16)
    }
}
