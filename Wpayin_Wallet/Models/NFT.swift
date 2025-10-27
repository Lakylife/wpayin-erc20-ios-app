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

    static let mockNFTs: [NFT] = [
        NFT(
            contractAddress: "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D",
            tokenId: "1234",
            name: "Bored Ape #1234",
            description: "A unique Bored Ape Yacht Club NFT with rare traits",
            imageUrl: "https://picsum.photos/400/400?random=1",
            collectionName: "Bored Ape Yacht Club",
            blockchain: .ethereum,
            ownerAddress: "0x742d35Cc6D06b73494d45e5d2b0542f2f"
        ),
        NFT(
            contractAddress: "0x60E4d786628Fea6478F785A6d7e704777c86a7c6",
            tokenId: "5678",
            name: "Mutant Ape #5678",
            description: "A genetically enhanced Mutant Ape with powerful serums",
            imageUrl: "https://picsum.photos/400/400?random=2",
            collectionName: "Mutant Ape Yacht Club",
            blockchain: .ethereum,
            ownerAddress: "0x742d35Cc6D06b73494d45e5d2b0542f2f"
        ),
        NFT(
            contractAddress: "0x8943C7bAC1914C9A7ABa750Bf2B6B09Fd21037E0",
            tokenId: "9101",
            name: "Lazy Lions #9101",
            description: "A majestic lion from the Lazy Lions pride",
            imageUrl: "https://picsum.photos/400/400?random=3",
            collectionName: "Lazy Lions",
            blockchain: .ethereum,
            ownerAddress: "0x742d35Cc6D06b73494d45e5d2b0542f2f"
        ),
        NFT(
            contractAddress: "0x524cAB2ec69124574082676e6F654a18df49A048",
            tokenId: "1122",
            name: "Lil Pudgy #1122",
            description: "A cute and chubby penguin from the Lil Pudgys collection",
            imageUrl: "https://picsum.photos/400/400?random=4",
            collectionName: "Lil Pudgys",
            blockchain: .ethereum,
            ownerAddress: "0x742d35Cc6D06b73494d45e5d2b0542f2f"
        )
    ]
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