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
    }

    var displayName: String {
        name.isEmpty ? "#\(tokenId)" : name
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