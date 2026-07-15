//
//  Wpayin_WalletTests.swift
//  Wpayin_WalletTests
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import Testing
import Foundation
@testable import Wpayin_Wallet

@MainActor
struct Wpayin_WalletTests {

    @Test func recognizesCanonicalETHWETHPair() {
        let eth = token(address: nil, symbol: "ETH", isNative: true)
        let weth = token(
            address: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
            symbol: "WETH",
            isNative: false
        )

        #expect(SwapService.shared.nativeWrapDirection(fromToken: eth, toToken: weth) == .wrap)
        #expect(SwapService.shared.nativeWrapDirection(fromToken: weth, toToken: eth) == .unwrap)
    }

    @Test func rejectsTokenThatOnlyUsesWETHSymbol() {
        let eth = token(address: nil, symbol: "ETH", isNative: true)
        let fakeWeth = token(
            address: "0x0000000000000000000000000000000000000001",
            symbol: "WETH",
            isNative: false
        )

        #expect(SwapService.shared.nativeWrapDirection(fromToken: eth, toToken: fakeWeth) == nil)
    }

    @Test func platformFeeRecipientIsFixed() {
        #expect(AppConfig.platformFeeRecipient == "0xB6edEd26638bCE6d32b217ae661e32899B9CA6a2")
        #expect(AppConfig.platformFeeBps == 25)
        #expect(AppConfig.platformFeeEnabled)
    }

    @Test func p2pOfferCodeRoundTripsThroughShareText() throws {
        let offer = P2POffer(
            chainId: 1,
            nonce: "123456789",
            expiry: Date().addingTimeInterval(3600).timeIntervalSince1970,
            signerWallet: "0xb6eded26638bce6d32b217ae661e32899b9ca6a2",
            signerToken: "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
            signerAmount: "2000000000000000",
            signerSymbol: "WETH",
            signerDecimals: 18,
            senderToken: "0xdac17f958d2ee523a2206206994597c13d831ec7",
            senderAmount: "3500000",
            senderSymbol: "USDT",
            senderDecimals: 6,
            protocolFeeBps: 7,
            sigV: 27,
            sigR: "0x" + String(repeating: "11", count: 32),
            sigS: "0x" + String(repeating: "22", count: 32)
        )

        let code = try #require(P2PTradeService.shared.encode(offer))
        #expect(P2PTradeService.shared.decode(code) == offer)
        #expect(P2PTradeService.shared.decode("Wpayin private offer:\n\(code)\nOpen in Wpayin") == offer)
    }

    @Test func erc20PaymentRequestUsesEIP681AndRoundTrips() throws {
        let request = PaymentRequest(
            address: "0x1111111111111111111111111111111111111111",
            symbol: "USDC",
            blockchain: .base,
            contractAddress: "0x2222222222222222222222222222222222222222",
            tokenDecimals: 6,
            amount: Decimal(string: "12.5"),
            note: "Invoice 42",
            expiresAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        let uri = try #require(PaymentRequestCodec.encode(request))
        #expect(uri.hasPrefix("ethereum:0x2222222222222222222222222222222222222222@8453/transfer"))

        let decoded = try #require(PaymentRequestCodec.decode(uri))
        #expect(decoded.address == request.address)
        #expect(decoded.symbol == request.symbol)
        #expect(decoded.blockchain == .base)
        #expect(decoded.contractAddress == request.contractAddress)
        #expect(decoded.tokenDecimals == 6)
        #expect(decoded.amount == request.amount)
        #expect(decoded.note == request.note)
        #expect(decoded.expiresAt == request.expiresAt)
    }

    @Test func bitcoinPaymentRequestUsesBIP21AndRoundTrips() throws {
        let request = PaymentRequest(
            address: "bc1qexampleaddress",
            symbol: "BTC",
            blockchain: .bitcoin,
            contractAddress: nil,
            tokenDecimals: 8,
            amount: Decimal(string: "0.00125"),
            note: "Coffee",
            expiresAt: nil
        )

        let uri = try #require(PaymentRequestCodec.encode(request))
        #expect(uri.hasPrefix("bitcoin:bc1qexampleaddress"))

        let decoded = try #require(PaymentRequestCodec.decode(uri))
        #expect(decoded.address == request.address)
        #expect(decoded.blockchain == .bitcoin)
        #expect(decoded.amount == request.amount)
        #expect(decoded.note == request.note)
    }

    @Test func nonEVMRequestUsesSafeWpayinPayload() throws {
        let request = PaymentRequest(
            address: "solanaPublicAddress",
            symbol: "SOL",
            blockchain: .solana,
            contractAddress: nil,
            tokenDecimals: 9,
            amount: nil,
            note: nil,
            expiresAt: nil
        )

        let uri = try #require(PaymentRequestCodec.encode(request))
        #expect(uri.hasPrefix("WPAYIN-PAY:"))
        let decoded = try #require(PaymentRequestCodec.decode("Pay me with Wpayin:\n\(uri)"))
        #expect(decoded.address == request.address)
        #expect(decoded.blockchain == .solana)
        #expect(decoded.amount == nil)
    }

    private func token(address: String?, symbol: String, isNative: Bool) -> Token {
        Token(
            contractAddress: address,
            name: symbol,
            symbol: symbol,
            decimals: 18,
            balance: 1,
            price: 1,
            iconUrl: nil,
            blockchain: .ethereum,
            isNative: isNative
        )
    }

}
