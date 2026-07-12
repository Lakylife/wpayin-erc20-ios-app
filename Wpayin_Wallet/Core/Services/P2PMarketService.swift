// Autor Lukas Helebrandt, 2026

//
//  P2PMarketService.swift
//  Wpayin_Wallet
//
//  Public P2P offer board backed by a Supabase (PostgREST) table — plain
//  HTTPS with the project's anon key, so it works with any Apple team (no
//  iCloud entitlement or account needed). Sellers publish signed offers so
//  other Wpayin users discover them in the app; the board is discovery only,
//  every offer still goes through P2PTradeService's full on-chain validation
//  before it can be accepted, so a fake or stale listing can never hurt
//  a buyer. One-time backend setup: docs/P2P_OFFER_BOARD.md.
//

import Foundation

enum P2PMarketError: LocalizedError {
    case boardUnavailable
    case publishFailed

    var errorDescription: String? {
        switch self {
        case .boardUnavailable:
            return "error.p2p.boardUnavailable".localized
        case .publishFailed:
            return "error.p2p.publishFailed".localized
        }
    }
}

/// A published listing: the raw signed payload plus display metadata.
struct P2PListing: Identifiable {
    let id: String            // row id (derived from the offer nonce)
    let payload: String
    let offer: P2POffer
    let createdAt: Date
}

final class P2PMarketService {
    static let shared = P2PMarketService()
    private init() {}

    private let offersTable = "p2p_offers"
    private let reportsTable = "p2p_reports"
    private let cacheKey = "CachedP2POfferBoard"
    private let blockedWalletsKey = "BlockedP2PWallets"

    private struct CachedListing: Codable {
        let id: String
        let payload: String
        let createdAt: Date
    }

    private func listingId(for offer: P2POffer) -> String {
        "offer-\(offer.chainId)-\(offer.nonce)"
    }

    // MARK: - REST plumbing

    private func request(
        table: String,
        query: [URLQueryItem] = [],
        method: String,
        body: Data? = nil,
        prefer: String? = nil
    ) throws -> URLRequest {
        guard AppConfig.p2pOfferBoardEnabled,
              var components = URLComponents(string: "\(AppConfig.p2pBoardURL)/rest/v1/\(table)") else {
            throw P2PMarketError.boardUnavailable
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw P2PMarketError.boardUnavailable }

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = method
        request.httpBody = body
        request.setValue(AppConfig.p2pBoardAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(AppConfig.p2pBoardAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let prefer { request.setValue(prefer, forHTTPHeaderField: "Prefer") }
        return request
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            Logger.log("🛑 P2P board HTTP \(status): \(String(data: data, encoding: .utf8) ?? "")")
            throw P2PMarketError.boardUnavailable
        }
        return data
    }

    /// Supabase timestamps come as ISO 8601 with or without fractional seconds.
    private static let isoWithFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let isoPlain = ISO8601DateFormatter()

    private static func parseDate(_ value: String) -> Date? {
        isoWithFraction.date(from: value) ?? isoPlain.date(from: value)
    }

    // MARK: - Publish / remove (seller)

    /// Publish a signed offer to the public board.
    func publish(_ offer: P2POffer) async throws {
        guard AppConfig.p2pOfferBoardEnabled else { throw P2PMarketError.boardUnavailable }
        guard let payload = P2PTradeService.shared.encode(offer) else {
            throw P2PMarketError.publishFailed
        }

        let row: [String: Any] = [
            "id": listingId(for: offer),
            "payload": payload,
            "chain_id": offer.chainId,
            "sell_symbol": offer.signerSymbol,
            "buy_symbol": offer.senderSymbol,
            "sell_amount": (offer.signerAmountDecimal as NSDecimalNumber).doubleValue,
            "buy_amount": (offer.senderAmountDecimal as NSDecimalNumber).doubleValue,
            "expiry": Self.isoPlain.string(from: Date(timeIntervalSince1970: offer.expiry)),
            "signer": offer.signerWallet
        ]

        do {
            let body = try JSONSerialization.data(withJSONObject: row)
            // Re-publishing the same offer hits the same row id — ignore it.
            let request = try request(
                table: offersTable,
                query: [URLQueryItem(name: "on_conflict", value: "id")],
                method: "POST",
                body: body,
                prefer: "resolution=ignore-duplicates"
            )
            _ = try await send(request)
        } catch let error as P2PMarketError {
            throw error
        } catch {
            Logger.log("🛑 P2P publish failed: \(error.localizedDescription)")
            throw P2PMarketError.publishFailed
        }
        Logger.log("📢 P2P offer published to the board")
    }

    /// Remove a listing (after cancel, fill or on request). Best-effort.
    func removeListing(for offer: P2POffer) async {
        guard AppConfig.p2pOfferBoardEnabled else { return }
        do {
            let request = try request(
                table: offersTable,
                query: [URLQueryItem(name: "id", value: "eq.\(listingId(for: offer))")],
                method: "DELETE"
            )
            _ = try await send(request)
            Logger.log("🧹 P2P listing removed")
        } catch {
            Logger.log("⚠️ P2P listing removal failed (may not exist): \(error.localizedDescription)")
        }
    }

    // MARK: - Browse (buyer)

    private struct OfferRow: Decodable {
        let id: String
        let payload: String
        let created_at: String
    }

    /// Fetch live listings, newest first. Decoding + expiry filtering happens
    /// client-side; full trust checks are done by P2PTradeService.validateOffer
    /// when the user opens a listing.
    func fetchListings() async throws -> [P2PListing] {
        guard AppConfig.p2pOfferBoardEnabled else { throw P2PMarketError.boardUnavailable }
        let request = try request(
            table: offersTable,
            query: [
                URLQueryItem(name: "select", value: "id,payload,created_at"),
                URLQueryItem(name: "expiry", value: "gt.\(Self.isoPlain.string(from: Date()))"),
                URLQueryItem(name: "order", value: "created_at.desc"),
                URLQueryItem(name: "limit", value: "100")
            ],
            method: "GET"
        )
        let data = try await send(request)
        let rows = try JSONDecoder().decode([OfferRow].self, from: data)

        let listings: [P2PListing] = rows.compactMap { row in
            guard let offer = P2PTradeService.shared.decode(row.payload),
                  !offer.isExpired,
                  !isBlocked(offer.signerWallet) else { return nil }
            return P2PListing(
                id: row.id,
                payload: row.payload,
                offer: offer,
                createdAt: Self.parseDate(row.created_at) ?? Date()
            )
        }
        cache(listings)
        return listings
    }

    /// Instant stale-while-revalidate snapshot for the offer board. Full
    /// on-chain validation still runs when an offer is opened.
    func cachedListings() -> [P2PListing] {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode([CachedListing].self, from: data) else {
            return []
        }
        return cached.compactMap { item in
            guard let offer = P2PTradeService.shared.decode(item.payload),
                  !offer.isExpired,
                  !isBlocked(offer.signerWallet) else { return nil }
            return P2PListing(
                id: item.id,
                payload: item.payload,
                offer: offer,
                createdAt: item.createdAt
            )
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    private func cache(_ listings: [P2PListing]) {
        let snapshot = listings.map {
            CachedListing(id: $0.id, payload: $0.payload, createdAt: $0.createdAt)
        }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    func block(wallet: String) {
        var blocked = blockedWallets()
        blocked.insert(wallet.lowercased())
        UserDefaults.standard.set(Array(blocked), forKey: blockedWalletsKey)
    }

    func report(_ listing: P2PListing) async throws {
        guard AppConfig.p2pOfferBoardEnabled else { throw P2PMarketError.boardUnavailable }
        let row: [String: Any] = [
            "listing_id": listing.id,
            "signer": listing.offer.signerWallet,
            "reason": "Suspicious or misleading offer"
        ]
        let body = try JSONSerialization.data(withJSONObject: row)
        let request = try request(table: reportsTable, method: "POST", body: body)
        _ = try await send(request)
    }

    private func isBlocked(_ wallet: String) -> Bool {
        blockedWallets().contains(wallet.lowercased())
    }

    private func blockedWallets() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: blockedWalletsKey) ?? [])
    }
}
