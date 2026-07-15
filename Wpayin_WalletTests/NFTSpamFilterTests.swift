// Autor Lukas Helebrandt, 2026

import XCTest
@testable import Wpayin_Wallet

final class NFTSpamFilterTests: XCTestCase {
    func testProviderClassificationAlwaysHidesNFT() {
        let nft = makeNFT(name: "Collectible", providerMarkedSpam: true)
        XCTAssertTrue(NFTSpamFilter.isLikelySpam(nft))
    }

    func testClaimLinkAndRewardAreClassifiedAsSpam() {
        let nft = makeNFT(
            name: "Claim 5,000 USDC reward at bonus.xyz",
            description: "Connect wallet and claim now",
            externalURL: "https://bonus.xyz"
        )
        XCTAssertTrue(NFTSpamFilter.isLikelySpam(nft))
    }

    func testLegitimateCollectionIsNotHidden() {
        let nft = makeNFT(
            name: "Community Airdrop Pass #42",
            collection: "Wpayin Community",
            description: "A collectible pass for early community members."
        )
        XCTAssertFalse(NFTSpamFilter.isLikelySpam(nft))
    }

    func testSparseMetadataAloneIsNotEnoughToHideNFT() {
        let nft = makeNFT(
            name: "NFT #1",
            collection: "Unknown Collection",
            imageURL: nil
        )
        XCTAssertFalse(NFTSpamFilter.isLikelySpam(nft))
    }

    private func makeNFT(
        name: String,
        collection: String = "Unknown Collection",
        description: String = "",
        imageURL: String? = "https://example.com/nft.png",
        externalURL: String? = nil,
        providerMarkedSpam: Bool? = nil
    ) -> NFT {
        NFT(
            contractAddress: "0x0000000000000000000000000000000000000001",
            tokenId: "1",
            name: name,
            description: description,
            imageUrl: imageURL,
            collectionName: collection,
            blockchain: .ethereum,
            ownerAddress: "0x0000000000000000000000000000000000000002",
            metadata: NFTMetadata(
                attributes: nil,
                externalUrl: externalURL,
                animationUrl: nil
            ),
            providerMarkedSpam: providerMarkedSpam
        )
    }
}
