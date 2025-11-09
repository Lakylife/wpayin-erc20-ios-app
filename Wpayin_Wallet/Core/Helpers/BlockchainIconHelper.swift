//
//  BlockchainIconHelper.swift
//  Wpayin_Wallet
//
//  Helper for loading blockchain icons
//

import SwiftUI

struct BlockchainIconHelper {
    static func iconName(for blockchain: BlockchainType) -> String {
        switch blockchain {
        case .bitcoin:
            return "bitcoin" // Special case - no suffix
        case .ethereum:
            return "ethereum_trx_32"
        case .bsc:
            return "binance-smart-chain_trx_32"
        case .polygon:
            return "polygon-pos_trx_32"
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
        case .solana:
            return "solana_trx_32"
        case .litecoin, .dash, .zcash, .bitcoinCash, .monero, .eCash:
            return "" // Will use fallback - not in assets
        }
    }
    
    static func icon(for blockchain: BlockchainType, size: CGFloat = 32) -> some View {
        let imageName = iconName(for: blockchain)
        
        return Group {
            if !imageName.isEmpty {
                // Try to load from Assets
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
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
