// Autor Lukas Helebrandt, 2026

//
//  NFT.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import Foundation

struct NFT: Identifiable, Codable, Sendable {
    let id: UUID
    let contractAddress: String
    let tokenId: String
    let name: String
    let description: String
    let imageUrl: String?
    let collectionName: String
    let blockchain: BlockchainType
    let ownerAddress: String
    let metadata: NFTMetadata?
    /// Classification supplied by the NFT indexer, when available.
    let providerMarkedSpam: Bool?

    init(
        contractAddress: String,
        tokenId: String,
        name: String,
        description: String,
        imageUrl: String?,
        collectionName: String,
        blockchain: BlockchainType,
        ownerAddress: String,
        metadata: NFTMetadata? = nil,
        providerMarkedSpam: Bool? = nil,
        id: UUID = UUID()
    ) {
        self.id = id
        self.contractAddress = contractAddress
        self.tokenId = tokenId
        self.name = name
        self.description = description
        self.imageUrl = imageUrl
        self.collectionName = collectionName
        self.blockchain = blockchain
        self.ownerAddress = ownerAddress
        self.metadata = metadata
        self.providerMarkedSpam = providerMarkedSpam
    }

    var displayName: String {
        name.isEmpty ? "#\(tokenId)" : name
    }
}

/// Conservative local fallback for providers that do not expose spam labels.
/// It deliberately requires multiple signals so legitimate airdrops or NFT
/// collections are not hidden just because of one generic word.
enum NFTSpamFilter {
    private static let directCallToAction = [
        "claim now", "claim at", "visit to claim", "redeem at", "redeem now",
        "verify wallet", "validate wallet", "connect wallet", "scan qr"
    ]

    private static let promotionalTerms = [
        "airdrop", "reward", "bonus", "giveaway", "voucher", "free mint", "free nft"
    ]

    private static let suspiciousURLMarkers = [
        "http://", "https://", "www.", ".xyz", ".top", ".click", ".site", ".live"
    ]

    private static let financialLures = [
        " usdc", " usdt", " eth", " btc", "$", "usd reward", "token reward"
    ]

    static func isLikelySpam(_ nft: NFT) -> Bool {
        if nft.providerMarkedSpam == true { return true }

        let title = "\(nft.name) \(nft.collectionName)".lowercased()
        let description = nft.description.lowercased()
        let externalURL = nft.metadata?.externalUrl?.lowercased() ?? ""
        let allText = "\(title) \(description) \(externalURL)"
        var score = 0

        if containsAny(title, suspiciousURLMarkers) { score += 4 }
        if containsAny(title, directCallToAction) { score += 3 }
        if containsAny(description, directCallToAction) { score += 2 }
        if containsAny(title, promotionalTerms) { score += 2 }

        if !externalURL.isEmpty,
           containsAny(allText, directCallToAction + promotionalTerms) {
            score += 2
        }

        if containsAny(allText, financialLures),
           containsAny(allText, directCallToAction + promotionalTerms) {
            score += 2
        }

        let hasSparseMetadata = nft.imageUrl?.isEmpty != false
            && nft.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && nft.collectionName.localizedCaseInsensitiveContains("unknown")
        if hasSparseMetadata { score += 1 }

        return score >= 4
    }

    private static func containsAny(_ value: String, _ patterns: [String]) -> Bool {
        patterns.contains { value.contains($0) }
    }
}

struct NFTMetadata: Codable, Sendable {
    let attributes: [NFTAttribute]?
    let externalUrl: String?
    let animationUrl: String?

    private enum CodingKeys: String, CodingKey {
        case attributes
        case externalUrl = "external_url"
        case animationUrl = "animation_url"
    }
}

struct NFTAttribute: Codable, Sendable {
    let traitType: String
    let value: String
    let displayType: String?

    private enum CodingKeys: String, CodingKey {
        case traitType = "trait_type"
        case value
        case displayType = "display_type"
    }
}
