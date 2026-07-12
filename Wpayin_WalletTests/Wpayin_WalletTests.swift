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
