// Autor Lukas Helebrandt, 2026

//
//  P2PMarketService.swift
//  Wpayin_Wallet
//
//  Public P2P offer board backed by CloudKit's public database — no custom
//  server or API keys needed. Sellers can publish signed offers so other
//  Wpayin users discover them in the app; the board is discovery only, every
//  offer still goes through P2PTradeService's full on-chain validation
//  before it can be accepted, so a fake or stale listing can never hurt
//  a buyer.
//

import Foundation
import CloudKit

enum P2PMarketError: LocalizedError {
    case iCloudUnavailable
    case publishFailed

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            return "error.p2p.iCloudUnavailable".localized
        case .publishFailed:
            return "error.p2p.publishFailed".localized
        }
    }
}

/// A published listing: the raw signed payload plus display metadata.
struct P2PListing: Identifiable {
    let id: String            // record name (derived from the offer nonce)
    let payload: String
    let offer: P2POffer
    let createdAt: Date
}

final class P2PMarketService {
    static let shared = P2PMarketService()
    private init() {}

    private let recordType = "P2POffer"
    private var database: CKDatabase {
        CKContainer.default().publicCloudDatabase
    }

    private func recordName(for offer: P2POffer) -> String {
        "offer-\(offer.chainId)-\(offer.nonce)"
    }

    // MARK: - Publish / remove (seller)

    /// Publish a signed offer to the public board. Requires an iCloud account.
    func publish(_ offer: P2POffer) async throws {
        // Guard: CKContainer.default() raises an exception when the app is
        // built without the iCloud entitlement (free personal teams).
        guard AppConfig.p2pOfferBoardEnabled else { throw P2PMarketError.iCloudUnavailable }
        let status = try await CKContainer.default().accountStatus()
        guard status == .available else { throw P2PMarketError.iCloudUnavailable }

        guard let payload = P2PTradeService.shared.encode(offer) else {
            throw P2PMarketError.publishFailed
        }

        let record = CKRecord(
            recordType: recordType,
            recordID: CKRecord.ID(recordName: recordName(for: offer))
        )
        record["payload"] = payload
        record["chainId"] = offer.chainId
        record["sellSymbol"] = offer.signerSymbol
        record["buySymbol"] = offer.senderSymbol
        record["sellAmount"] = (offer.signerAmountDecimal as NSDecimalNumber).doubleValue
        record["buyAmount"] = (offer.senderAmountDecimal as NSDecimalNumber).doubleValue
        record["expiry"] = Date(timeIntervalSince1970: offer.expiry)
        record["signer"] = offer.signerWallet

        do {
            _ = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
        } catch {
            Logger.log("🛑 P2P publish failed: \(error.localizedDescription)")
            throw P2PMarketError.publishFailed
        }
        Logger.log("📢 P2P offer published to the board")
    }

    /// Remove a listing (after cancel, fill or on request). Best-effort.
    func removeListing(for offer: P2POffer) async {
        guard AppConfig.p2pOfferBoardEnabled else { return }
        let recordID = CKRecord.ID(recordName: recordName(for: offer))
        do {
            try await database.deleteRecord(withID: recordID)
            Logger.log("🧹 P2P listing removed")
        } catch {
            Logger.log("⚠️ P2P listing removal failed (may not exist): \(error.localizedDescription)")
        }
    }

    // MARK: - Browse (buyer)

    /// Fetch live listings, newest first. Works without an iCloud account.
    /// Decoding + expiry filtering happens client-side; full trust checks are
    /// done by P2PTradeService.validateOffer when the user opens a listing.
    func fetchListings() async throws -> [P2PListing] {
        guard AppConfig.p2pOfferBoardEnabled else { throw P2PMarketError.iCloudUnavailable }
        let predicate = NSPredicate(format: "expiry > %@", Date() as NSDate)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let (results, _) = try await database.records(matching: query, resultsLimit: 100)

        var listings: [P2PListing] = []
        for (recordID, result) in results {
            guard case .success(let record) = result,
                  let payload = record["payload"] as? String,
                  let offer = P2PTradeService.shared.decode(payload),
                  !offer.isExpired else { continue }

            listings.append(P2PListing(
                id: recordID.recordName,
                payload: payload,
                offer: offer,
                createdAt: record.creationDate ?? Date()
            ))
        }
        return listings
    }
}
