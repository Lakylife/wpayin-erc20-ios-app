// Autor Lukas Helebrandt, 2026

import XCTest
@testable import Wpayin_Wallet

/// The Bitcoin send screen compared the fee rate (sat/vB) with the balance in BTC, so every amount was
/// "Insufficient balance". The fee is now a BTC amount; these tests guard the rates behind it.
final class BitcoinFeeTests: XCTestCase {
    override func tearDown() {
        BitcoinFeeCache.latest = nil
    }

    func testFixedRatesWithoutLiveData() {
        BitcoinFeeCache.latest = nil
        XCTAssertEqual(BitcoinFeeCache.rate(for: .slow), 10)
        XCTAssertEqual(BitcoinFeeCache.rate(for: .standard), 20)
        XCTAssertEqual(BitcoinFeeCache.rate(for: .fast), 40)
    }

    func testLiveRatesFromMempool() {
        BitcoinFeeCache.latest = BitcoinFeeRate(fastestFee: 6, halfHourFee: 4, hourFee: 0, economyFee: 1, minimumFee: 1)
        XCTAssertEqual(BitcoinFeeCache.rate(for: .fast), 6)
        XCTAssertEqual(BitcoinFeeCache.rate(for: .standard), 4)
        XCTAssertEqual(BitcoinFeeCache.rate(for: .slow), 1, "never below 1 sat/vB")
    }

    func testSmallBalanceCanBeSent() {
        // 0.000106 BTC with a standard fee of 4 sat/vB on a typical 141 vB payment.
        BitcoinFeeCache.latest = BitcoinFeeRate(fastestFee: 6, halfHourFee: 4, hourFee: 2, economyFee: 1, minimumFee: 1)
        let fee = Double(BitcoinFeeCache.rate(for: .standard) * 141) / 100_000_000
        XCTAssertLessThan(0.0001 + fee, 0.000106)
    }
}

/// Bitcoin Activity from the Esplora API: a send still in the mempool shows as pending with the amount sent.
final class BitcoinActivityTests: XCTestCase {
    let me = "bc1qmine"

    func testPendingSendShowsAmountWithoutFeeAndChange() throws {
        let tx: [String: Any] = [
            "txid": "abc", "fee": 568,
            "status": ["confirmed": false],
            "vin": [["prevout": ["scriptpubkey_address": me, "value": 9173]]],
            "vout": [["scriptpubkey_address": "3Recipient", "value": 2199], ["scriptpubkey_address": me, "value": 6406]],
        ]
        let item = try XCTUnwrap(BitcoinService.activityItem(tx, address: me))
        XCTAssertEqual(item.type, .send)
        XCTAssertEqual(item.status, .pending)
        XCTAssertEqual(item.to, "3Recipient")
        XCTAssertEqual(item.amount, 0.00002199, accuracy: 1e-12)
        XCTAssertEqual(item.gasFee, 0.00000568, accuracy: 1e-12)
        XCTAssertEqual(item.blockchain, .bitcoin)
    }

    func testConfirmedReceive() throws {
        let tx: [String: Any] = [
            "txid": "def", "fee": 1087,
            "status": ["confirmed": true, "block_time": 1_784_238_774, "block_height": 900_000],
            "vin": [["prevout": ["scriptpubkey_address": "bc1qother", "value": 50_000]]],
            "vout": [["scriptpubkey_address": me, "value": 9173], ["scriptpubkey_address": "bc1qother", "value": 39_740]],
        ]
        let item = try XCTUnwrap(BitcoinService.activityItem(tx, address: me))
        XCTAssertEqual(item.type, .receive)
        XCTAssertEqual(item.status, .confirmed)
        XCTAssertEqual(item.amount, 0.00009173, accuracy: 1e-12)
        XCTAssertEqual(item.blockNumber, "900000")
    }
}
