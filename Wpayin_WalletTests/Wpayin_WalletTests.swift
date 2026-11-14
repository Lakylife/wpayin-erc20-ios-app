//
//  Wpayin_WalletTests.swift
//  Wpayin_WalletTests
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import Testing
import Foundation
import SwiftUI
@testable import Wpayin_Wallet

@MainActor
struct Wpayin_WalletTests {

    @Test func autoLockHonorsConfiguredTimeout() throws {
        let suite = "AppLockTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "BiometricAuthEnabled")
        defaults.set(AutoLockDuration.after5min.rawValue, forKey: "AutoLockDuration")
        var now: TimeInterval = 100
        let manager = AppLockManager(userDefaults: defaults, uptime: { now }, requestUnlock: {})
        manager.handleScenePhaseChange(.background, hasWallet: true)
        #expect(!manager.isLocked)
        now += 299
        manager.handleScenePhaseChange(.active, hasWallet: true)
        #expect(!manager.isLocked)
        manager.handleScenePhaseChange(.background, hasWallet: true)
        now += 300
        manager.handleScenePhaseChange(.active, hasWallet: true)
        #expect(manager.isLocked)
    }

    @Test func autoLockNeverAndImmediateRemainDistinct() throws {
        let suite = "AppLockTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "BiometricAuthEnabled")
        defaults.set(AutoLockDuration.never.rawValue, forKey: "AutoLockDuration")
        var now: TimeInterval = 0
        let manager = AppLockManager(userDefaults: defaults, uptime: { now }, requestUnlock: {})
        manager.handleScenePhaseChange(.background, hasWallet: true)
        now = 100_000
        manager.handleScenePhaseChange(.active, hasWallet: true)
        #expect(!manager.isLocked)
        defaults.set(AutoLockDuration.immediately.rawValue, forKey: "AutoLockDuration")
        manager.handleScenePhaseChange(.background, hasWallet: true)
        #expect(manager.isLocked)
    }

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

    @Test func quintiumUsesItsOwnChainIdsAndNeverAnEthereumNode() {
        #expect(QuintiumNetwork.mainnet.chainId == 52401)
        #expect(QuintiumNetwork.testnet.chainId == 52402)
        #expect(QuintiumNetwork.mainnet.symbol == "QU")
        #expect(QuintiumNetwork.testnet.symbol == "tQU")

        let network = QuintiumSettings.network
        #expect(BlockchainType.quintium.chainId == network.chainId)
        // Without a configured node the RPC stays empty instead of falling back to Ethereum.
        #expect(BlockchainType.quintium.rpcUrl == QuintiumSettings.rpcUrl)
        #expect(!BlockchainType.quintium.rpcUrl.contains("ethereum"))
        #expect(!QuintiumSettings.isValidURL(""))
        #expect(!QuintiumSettings.isValidURL("rpc.example.com"))
        #expect(QuintiumSettings.isValidURL("https://rpc.example.com"))
    }

    @Test func plainHttpIsBlockedExceptForTheQuintiumNode() {
        #expect(!PlainHTTPGuard.isBlocked(URL(string: "https://api.coingecko.com/api/v3/ping")))
        #expect(PlainHTTPGuard.isBlocked(URL(string: "http://api.example.org/prices")))
        #expect(!PlainHTTPGuard.isBlocked(URL(string: "http://192.168.1.20:8546")))
        #expect(!PlainHTTPGuard.isBlocked(URL(string: "http://127.0.0.1:8546")))
        #expect(PlainHTTPGuard.isBlocked(URL(string: "http://198.51.100.77:8546")))
        PlainHTTPGuard.allow(host: "198.51.100.77")
        #expect(!PlainHTTPGuard.isBlocked(URL(string: "http://198.51.100.77:8546")))
    }

    @Test func tokenRegistryCallDataIsBuiltFromTheAddress() {
        #expect(QuintiumNodeClient.listedCallData(token: "0x60FD058c896B7E039363F07485016116f915ae02") // gitleaks:allow (ABI call data, not a key)
                == "0x6413823000000000000000000000000060fd058c896b7e039363f07485016116f915ae02")
        #expect(QuintiumNodeClient.listedCallData(token: "0x1234") == nil)
        #expect(QuintiumNetwork.mainnet.tokenRegistryAddress == nil)
    }

    @Test func quintiumWarnsOnlyForPlainHttpToPublicHosts() {
        #expect(QuintiumSettings.isUnencryptedPublicURL("http://203.0.113.7:8546"))
        #expect(QuintiumSettings.isUnencryptedPublicURL("http://node.example.com:8546"))
        #expect(QuintiumSettings.isUnencryptedPublicURL("http://172.32.0.1:8546"))
        #expect(!QuintiumSettings.isUnencryptedPublicURL("https://203.0.113.7:8546"))
        #expect(!QuintiumSettings.isUnencryptedPublicURL("http://192.168.1.20:8546"))
        #expect(!QuintiumSettings.isUnencryptedPublicURL("http://10.0.0.5:8546"))
        #expect(!QuintiumSettings.isUnencryptedPublicURL("http://172.16.4.2:8546"))
        #expect(!QuintiumSettings.isUnencryptedPublicURL("http://127.0.0.1:8546"))
        #expect(!QuintiumSettings.isUnencryptedPublicURL("http://localhost:8546"))
        #expect(!QuintiumSettings.isUnencryptedPublicURL("http://mynode.local:8546"))
        #expect(!QuintiumSettings.isUnencryptedPublicURL("http://[fd12::1]:8546"))
        #expect(!QuintiumSettings.isUnencryptedPublicURL(""))
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

    @Test func quintiumP2PConfigFollowsNetwork() {
        let testnetContracts = P2PTradeService.swapContracts(quintium: .testnet)
        #expect(testnetContracts[.quintium] == "0x60FD058c896B7E039363F07485016116f915ae02")
        let testnetWrapped = P2PTradeService.wrappedNative(quintium: .testnet)[.quintium]
        #expect(testnetWrapped?.address == "0xae0000000000000000000000000000000000000a")
        #expect(testnetWrapped?.symbol == "WQU")

        #expect(P2PTradeService.swapContracts(quintium: .mainnet)[.quintium] == nil)
        #expect(P2PTradeService.wrappedNative(quintium: .mainnet)[.quintium] == nil)
        // Other chains are unaffected by the Quintium network
        #expect(P2PTradeService.swapContracts(quintium: .mainnet)[.ethereum] == "0xD82E10B9A4107939e55fCCa9B53A9ede6CF2fC46")
    }

    @Test func hexToDecimalHandlesBalancesAboveIntMax() {
        // 100 tokens with 18 decimals = 1e20 wei, beyond Int.max
        #expect("56bc75e2d63100000".hexToDecimal() == "100000000000000000000")
        #expect("0".hexToDecimal() == "0")
        #expect("".hexToDecimal() == "0")
        #expect("xyz".hexToDecimal() == nil)
    }

}
