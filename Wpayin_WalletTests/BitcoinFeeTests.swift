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
