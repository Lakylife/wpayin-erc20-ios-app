//
//  NFTGridView.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI

struct NFTGridView: View {
    let nfts: [NFT]
    let onNFTTap: (NFT) -> Void

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(nfts) { nft in
                NFTCard(nft: nft, onTap: { onNFTTap(nft) })
            }
        }
        .padding(.horizontal, 20)
    }
}

struct NFTCard: View {
    let nft: NFT
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // NFT Image with better error handling
                if let imageUrl = nft.imageUrl, !imageUrl.isEmpty, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .frame(height: 160)
                                .clipped()
                        case .failure(_):
                            // Show collection-specific placeholder for failed loads
                            nftPlaceholder
                        case .empty:
                            // Loading placeholder
                            RoundedRectangle(cornerRadius: 12)
                                .fill(WpayinColors.surface)
                                .frame(maxWidth: .infinity)
                                .frame(height: 160)
                                .overlay(
                                    VStack(spacing: 8) {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: WpayinColors.primary))
                                            .scaleEffect(0.7)
                                        Text("Loading...")
                                            .font(.system(size: 10))
                                            .foregroundColor(WpayinColors.textTertiary)
                                    }
                                )
                        @unknown default:
                            nftPlaceholder
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    // No image URL - show nice placeholder (Uniswap LP, etc.)
                    nftPlaceholder
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // NFT Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(nft.displayName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(WpayinColors.text)
                        .lineLimit(1)

                    Text(nft.collectionName)
                        .font(.system(size: 12))
                        .foregroundColor(WpayinColors.textSecondary)
                        .lineLimit(1)

                    // Blockchain badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(blockchainColor(nft.blockchain))
                            .frame(width: 8, height: 8)

                        Text(nft.blockchain.name)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(WpayinColors.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(WpayinColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // Placeholder for NFTs without images (Uniswap LP, etc.)
    private var nftPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    colors: [
                        WpayinColors.primary.opacity(0.3),
                        WpayinColors.primary.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .overlay(
                VStack(spacing: 8) {
                    // Icon based on collection name
                    Image(systemName: collectionIcon)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(WpayinColors.primary)

                    Text(nft.collectionName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(WpayinColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 8)
                }
            )
    }

    private var collectionIcon: String {
        let name = nft.collectionName.lowercased()
        if name.contains("uniswap") {
            return "arrow.triangle.swap"
        } else if name.contains("opensea") {
            return "water.waves"
        } else if name.contains("poap") {
            return "ticket.fill"
        } else if name.contains("ens") {
            return "text.bubble.fill"
        } else {
            return "photo.artframe"
        }
    }

    private func blockchainColor(_ blockchain: BlockchainType) -> Color {
        switch blockchain {
        case .ethereum:
            return Color.blue
        case .polygon:
            return Color.purple
        case .bsc:
            return Color.yellow
        case .arbitrum:
            return Color.cyan
        case .optimism:
            return Color.red
        default:
            return WpayinColors.primary
        }
    }
}

struct NFTDetailView: View {
    let nft: NFT
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Large NFT Image with better error handling
                    AsyncImage(url: URL(string: nft.imageUrl ?? "")) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(1, contentMode: .fit)
                        case .failure(_):
                            RoundedRectangle(cornerRadius: 20)
                                .fill(WpayinColors.surface)
                                .aspectRatio(1, contentMode: .fit)
                                .overlay(
                                    VStack(spacing: 12) {
                                        Image(systemName: "exclamationmark.triangle")
                                            .font(.system(size: 48))
                                            .foregroundColor(WpayinColors.error)
                                        Text("Failed to load NFT image")
                                            .font(.system(size: 14))
                                            .foregroundColor(WpayinColors.textSecondary)
                                    }
                                )
                        case .empty:
                            RoundedRectangle(cornerRadius: 20)
                                .fill(WpayinColors.surface)
                                .aspectRatio(1, contentMode: .fit)
                                .overlay(
                                    VStack(spacing: 12) {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: WpayinColors.primary))
                                        Text("Loading NFT...")
                                            .font(.system(size: 14))
                                            .foregroundColor(WpayinColors.textSecondary)
                                    }
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)

                    // NFT Details
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(nft.collectionName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(WpayinColors.primary)

                            Text(nft.displayName)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(WpayinColors.text)
                        }

                        if !nft.description.isEmpty {
                            Text(nft.description)
                                .font(.system(size: 16))
                                .foregroundColor(WpayinColors.textSecondary)
                                .lineLimit(nil)
                        }

                        // Blockchain info
                        HStack(spacing: 12) {
                            Circle()
                                .fill(blockchainColor(nft.blockchain))
                                .frame(width: 12, height: 12)

                            Text(nft.blockchain.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(WpayinColors.text)

                            Spacer()

                            Text("Token ID: \(nft.tokenId)")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(WpayinColors.textTertiary)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(WpayinColors.surface)
                        )

                        // Contract Address
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Contract Address")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(WpayinColors.textSecondary)
                                .textCase(.uppercase)

                            HStack {
                                Text(formatAddress(nft.contractAddress))
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundColor(WpayinColors.text)

                                Spacer()

                                Button(action: {
                                    UIPasteboard.general.string = nft.contractAddress
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 14))
                                        .foregroundColor(WpayinColors.primary)
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(WpayinColors.surface)
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
            }
            .background(WpayinColors.background)
            .navigationTitle("NFT Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(WpayinColors.primary)
                }
            }
        }
    }

    private func blockchainColor(_ blockchain: BlockchainType) -> Color {
        switch blockchain {
        case .ethereum:
            return Color.blue
        case .polygon:
            return Color.purple
        case .bsc:
            return Color.yellow
        case .arbitrum:
            return Color.cyan
        case .optimism:
            return Color.red
        default:
            return WpayinColors.primary
        }
    }

    private func formatAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        return "\(address.prefix(6))...\(address.suffix(4))"
    }
}

#Preview {
    // NFTGridView(nfts: NFT.sampleNFTs, onNFTTap: { _ in }) // disabled
}