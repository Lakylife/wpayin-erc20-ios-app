// Autor Lukas Helebrandt, 2026

//
//  BlockchainIconHelper.swift
//  Wpayin_Wallet
//
//  Helper for loading blockchain icons
//

import SwiftUI

struct BlockchainIconHelper {
    /// Full-color circular assets that can be rendered as-is.
    private static func fullColorAssetName(for blockchain: BlockchainType) -> String? {
        switch blockchain {
        case .bitcoin:
            return "BTC"
        case .ethereum:
            return "ETH"
        case .bsc:
            return "BNB"
        default:
            return nil
        }
    }

    /// White glyph assets (the `*_trx_32` set) — these are monochrome marks on
    /// a transparent background and MUST be drawn on a brand-colored circle,
    /// otherwise they show up as white blobs.
    private static func glyphAssetName(for blockchain: BlockchainType) -> String? {
        switch blockchain {
        case .arbitrum:
            return "arbitrum-one_trx_32"
        case .optimism:
            return "optimistic-ethereum_trx_32"
        case .avalanche:
            return "avalanche_trx_32"
        case .base:
            return "base_trx_32"
        case .gnosis:
            return "gnosis_trx_32"
        case .zkSync:
            return "zksync_trx_32"
        case .fantom:
            return "fantom_trx_32"
        default:
            return nil
        }
    }

    /// Official brand background color behind the white glyph.
    private static func glyphBackgroundColor(for blockchain: BlockchainType) -> Color {
        switch blockchain {
        case .arbitrum:
            return Color(red: 0.13, green: 0.19, blue: 0.28)   // #213147 navy
        case .optimism:
            return Color(red: 1.0, green: 0.02, blue: 0.13)    // #FF0420 red
        case .avalanche:
            return Color(red: 0.91, green: 0.26, blue: 0.26)   // #E84142 red
        case .base:
            return Color(red: 0.0, green: 0.32, blue: 1.0)     // #0052FF blue
        case .gnosis:
            return Color(red: 0.02, green: 0.47, blue: 0.36)   // #04795B green
        case .zkSync:
            return Color(red: 0.31, green: 0.36, blue: 0.90)   // indigo
        case .fantom:
            return Color(red: 0.10, green: 0.41, blue: 1.0)    // #1969FF blue
        default:
            return fallbackColor(for: blockchain)
        }
    }

    static func icon(for blockchain: BlockchainType, size: CGFloat = 32) -> some View {
        Group {
            if let assetName = fullColorAssetName(for: blockchain) {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if let glyphName = glyphAssetName(for: blockchain) {
                ZStack {
                    Circle()
                        .fill(glyphBackgroundColor(for: blockchain))
                        .frame(width: size, height: size)

                    Image(glyphName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size * 0.62, height: size * 0.62)
                }
            } else if blockchain == .polygon {
                PolygonIconMark(size: size)
            } else if blockchain == .solana {
                SolanaIconMark(size: size)
            } else {
                // Fallback to colored circle with symbol
                ZStack {
                    Circle()
                        .fill(fallbackColor(for: blockchain))
                        .frame(width: size, height: size)

                    Text(fallbackSymbol(for: blockchain))
                        .font(.system(size: size * 0.5, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    private static func fallbackColor(for blockchain: BlockchainType) -> Color {
        switch blockchain {
        case .bitcoin:
            return Color.orange
        case .ethereum:
            return Color.blue
        case .bsc:
            return Color.yellow
        case .polygon:
            return Color.purple
        case .arbitrum:
            return Color.cyan
        case .optimism:
            return Color.red
        case .avalanche:
            return Color(red: 0.91, green: 0.24, blue: 0.20)
        case .base:
            return Color(red: 0.0, green: 0.46, blue: 0.87)
        case .litecoin:
            return Color(red: 0.2, green: 0.38, blue: 0.62)
        case .bitcoinCash:
            return Color(red: 0.0, green: 0.71, blue: 0.39)
        case .dash:
            return Color(red: 0.0, green: 0.55, blue: 0.88)
        case .zcash:
            return Color(red: 0.96, green: 0.66, blue: 0.2)
        case .monero:
            return Color(red: 1.0, green: 0.39, blue: 0.0)
        case .eCash:
            return Color(red: 0.0, green: 0.48, blue: 0.8)
        case .gnosis:
            return Color(red: 0.0, green: 0.51, blue: 0.47)
        case .zkSync:
            return Color(red: 0.32, green: 0.42, blue: 0.98)
        case .fantom:
            return Color(red: 0.08, green: 0.49, blue: 0.96)
        case .solana:
            return Color(red: 0.66, green: 0.36, blue: 1.0)
        }
    }
    
    private static func fallbackSymbol(for blockchain: BlockchainType) -> String {
        switch blockchain {
        case .bitcoin:
            return "₿"
        case .ethereum:
            return "Ξ"
        case .bsc:
            return "B"
        case .polygon:
            return "P"
        case .arbitrum:
            return "A"
        case .optimism:
            return "O"
        case .avalanche:
            return "V"
        case .base:
            return "B"
        case .litecoin:
            return "Ł"
        case .bitcoinCash:
            return "₿"
        case .dash:
            return "D"
        case .zcash:
            return "Z"
        case .monero:
            return "M"
        case .eCash:
            return "X"
        case .gnosis:
            return "G"
        case .zkSync:
            return "Z"
        case .fantom:
            return "F"
        case .solana:
            return "◎"
        }
    }
}
