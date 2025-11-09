//
//  NetworkIconView.swift
//  Wpayin_Wallet
//
//  Network/Blockchain icon component with fallback support
//

import SwiftUI

struct NetworkIconView: View {
    let blockchain: BlockchainType
    let size: CGFloat
    
    var body: some View {
        BlockchainIconHelper.icon(for: blockchain, size: size)
    }
    
    private var blockchainColor: Color {
        switch blockchain {
        case .ethereum:
            return Color(red: 0.39, green: 0.47, blue: 1.0)
        case .bsc:
            return Color(red: 0.95, green: 0.77, blue: 0.19)
        case .polygon:
            return Color(red: 0.51, green: 0.29, blue: 0.93)
        case .arbitrum:
            return Color(red: 0.18, green: 0.57, blue: 1.0)
        case .optimism:
            return Color(red: 1.0, green: 0.04, blue: 0.13)
        case .avalanche:
            return Color(red: 0.91, green: 0.24, blue: 0.20)
        case .base:
            return Color(red: 0.0, green: 0.46, blue: 0.87)
        case .bitcoin:
            return Color(red: 1.0, green: 0.65, blue: 0.0)
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
    
    private var blockchainIconName: String {
        switch blockchain {
        case .ethereum:
            return "diamond.fill"
        case .bitcoin:
            return "bitcoinsign.circle.fill"
        case .bsc:
            return "b.circle.fill"
        case .polygon:
            return "pentagon.fill"
        case .arbitrum:
            return "a.circle.fill"
        case .optimism:
            return "o.circle.fill"
        case .avalanche:
            return "mountain.2.fill"
        case .base:
            return "cube.fill"
        case .litecoin:
            return "l.circle.fill"
        case .bitcoinCash:
            return "banknote.fill"
        case .dash:
            return "d.circle.fill"
        case .zcash:
            return "z.circle.fill"
        case .monero:
            return "m.circle.fill"
        case .eCash:
            return "e.circle.fill"
        case .gnosis:
            return "g.circle.fill"
        case .zkSync:
            return "arrow.triangle.2.circlepath.circle.fill"
        case .fantom:
            return "f.circle.fill"
        case .solana:
            return "sun.max.fill"
        }
    }
}

/// Platform icon view for blockchain platforms
struct PlatformIconView: View {
    let platform: BlockchainPlatform
    let size: CGFloat
    
    var body: some View {
        if let blockchainType = platform.blockchainType {
            NetworkIconView(blockchain: blockchainType, size: size)
        } else {
            // Fallback for platforms without blockchain type
            ZStack {
                Circle()
                    .fill(platform.color)
                    .frame(width: size, height: size)
                
                Image(systemName: platform.iconName)
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
}

/// Token icon view with network badge
struct TokenIconView: View {
    let token: Token
    let size: CGFloat
    var showNetworkBadge: Bool = true
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Main token icon - Priority: local asset > iconUrl > colored placeholder > blockchain icon
            
            Group {
                // 1. ALWAYS try local asset FIRST (regardless of iconUrl)
                if let localIconName = TokenIconHelper.iconName(symbol: token.symbol, blockchain: token.blockchain) {
                    Image(localIconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size, height: size)
                        .background(Color.black.opacity(0.05)) // Debug: show image bounds
                        .onAppear {
                            print("✅ TokenIcon: Loading \(localIconName) for \(token.symbol)")
                        }
                }
                // 2. If no local asset, try iconUrl from API
                else if let iconUrl = token.iconUrl, !iconUrl.isEmpty {
                    if let url = URL(string: iconUrl), iconUrl.hasPrefix("http") {
                        // Load from URL
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: size, height: size)
                            case .failure, .empty:
                                tokenPlaceholderIcon
                            @unknown default:
                                tokenPlaceholderIcon
                            }
                        }
                    } else {
                        // Try iconUrl as local asset name
                        Image(iconUrl)
                            .resizable()
                            .scaledToFit()
                            .frame(width: size, height: size)
                    }
                }
                // 3. For well-known stablecoins without local asset, use colored placeholder
                else if ["USDT", "USDC", "DAI", "BUSD"].contains(token.symbol.uppercased()) {
                    tokenPlaceholderIcon
                }
                // 4. For ERC20/BEP20 tokens without icon, use colored placeholder
                else if !token.isNative {
                    tokenPlaceholderIcon
                }
                // 5. Final fallback: blockchain icon for native tokens
                else {
                    NetworkIconView(blockchain: token.blockchain, size: size)
                }
            }
            
            // Network badge for non-native tokens
            if showNetworkBadge && !token.isNative {
                Circle()
                    .fill(WpayinColors.surface)
                    .frame(width: size * 0.35, height: size * 0.35)
                    .overlay(
                        NetworkIconView(blockchain: token.blockchain, size: size * 0.3)
                    )
                    .offset(x: size * 0.1, y: size * 0.1)
            }
        }
    }
    
    // Helper: Colored placeholder icon for tokens without assets
    private var tokenPlaceholderIcon: some View {
        ZStack {
            Circle()
                .fill(TokenIconHelper.tokenColor(symbol: token.symbol))
                .frame(width: size, height: size)
            
            Text(TokenIconHelper.symbolLetter(symbol: token.symbol))
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        // Network icons
        HStack(spacing: 15) {
            NetworkIconView(blockchain: .ethereum, size: 44)
            NetworkIconView(blockchain: .bitcoin, size: 44)
            NetworkIconView(blockchain: .bsc, size: 44)
            NetworkIconView(blockchain: .polygon, size: 44)
        }
        
        // Platform icons
        HStack(spacing: 15) {
            PlatformIconView(platform: .ethereum, size: 44)
            PlatformIconView(platform: .bitcoin, size: 44)
            PlatformIconView(platform: .bsc, size: 44)
            PlatformIconView(platform: .polygon, size: 44)
        }
    }
    .padding()
}
