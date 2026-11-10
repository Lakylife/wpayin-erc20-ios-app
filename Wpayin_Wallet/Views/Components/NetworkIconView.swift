// Autor Lukas Helebrandt, 2026

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
        if blockchain == .solana {
            SolanaIconMark(size: size)
        } else if blockchain == .quintium {
            QuintiumIconMark(size: size)
        } else if blockchain == .polygon {
            PolygonIconMark(size: size)
        } else {
            BlockchainIconHelper.icon(for: blockchain, size: size)
        }
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
        case .quintium:
            return QuintiumIconMark.gold
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
        case .quintium:
            return "pentagon.fill"
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
                if token.isQuintiumCoin {
                    // Our own coin: Quintium logo for QU (mainnet) and tQU (testnet)
                    QuintiumIconMark(size: size)
                } else if token.symbol.uppercased() == "WETH" {
                    // Official WETH icon with drawn mark as offline fallback
                    AsyncImage(url: URL(string: token.iconUrl?.hasPrefix("http") == true
                                        ? token.iconUrl!
                                        : "https://assets.coingecko.com/coins/images/2518/large/weth.png")) { phase in
                        if case .success(let image) = phase {
                            image
                                .resizable()
                                .scaledToFit()
                        } else {
                            WrappedEthIconMark(size: size)
                        }
                    }
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                } else if token.symbol.uppercased() == "USDT" {
                    StablecoinIconMark(size: size, symbol: "₮", color: Color(red: 0.20, green: 0.63, blue: 0.54))
                } else if token.symbol.uppercased() == "USDC" {
                    StablecoinIconMark(size: size, symbol: "$", color: Color(red: 0.16, green: 0.52, blue: 0.95))
                } else if token.symbol.uppercased() == "SOL" {
                    SolanaIconMark(size: size)
                } else if token.symbol.uppercased() == "MATIC" {
                    PolygonIconMark(size: size)
                }
                // 1. ALWAYS try local asset FIRST (regardless of iconUrl)
                else if let localIconName = TokenIconHelper.iconName(symbol: token.symbol, blockchain: token.blockchain) {
                    Image(localIconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size, height: size)
                        .onAppear {
                            Logger.log("✅ TokenIcon: Loading \(localIconName) for \(token.symbol)")
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
                NetworkIconView(blockchain: token.blockchain, size: size * 0.42)
                    .frame(width: size * 0.42, height: size * 0.42)
                    .clipShape(Circle())
                    .overlay(
                        // Ring in the app background color visually separates
                        // the badge from the token icon underneath.
                        Circle()
                            .stroke(WpayinColors.background, lineWidth: max(1.5, size * 0.055))
                    )
                    .offset(x: size * 0.12, y: size * 0.12)
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
                .font(.system(size: token.symbol.uppercased() == "USDC" ? size * 0.42 : size * 0.5, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

struct SolanaIconMark: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black)
                .frame(width: size, height: size)

            VStack(spacing: size * 0.08) {
                solanaBar(colors: [Color(red: 0.00, green: 1.00, blue: 0.64), Color(red: 0.56, green: 0.25, blue: 1.00)])
                    .offset(x: size * 0.04)
                solanaBar(colors: [Color(red: 0.56, green: 0.25, blue: 1.00), Color(red: 0.00, green: 0.78, blue: 1.00)])
                    .offset(x: -size * 0.04)
                solanaBar(colors: [Color(red: 0.00, green: 0.78, blue: 1.00), Color(red: 0.00, green: 1.00, blue: 0.64)])
                    .offset(x: size * 0.04)
            }
        }
    }

    private func solanaBar(colors: [Color]) -> some View {
        RoundedRectangle(cornerRadius: size * 0.04)
            .fill(
                LinearGradient(
                    colors: colors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: size * 0.58, height: size * 0.11)
            .rotationEffect(.degrees(-8))
    }
}

struct WrappedEthIconMark: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.27, green: 0.42, blue: 1.0),
                            Color(red: 0.08, green: 0.14, blue: 0.36)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            Circle()
                .stroke(Color.white.opacity(0.9), lineWidth: max(1.2, size * 0.055))
                .frame(width: size * 0.76, height: size * 0.76)

            EthereumDiamondMark(size: size * 0.5)
                .foregroundColor(.white)
        }
    }
}

struct EthereumDiamondMark: View {
    let size: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Path { path in
                path.move(to: CGPoint(x: size * 0.5, y: 0))
                path.addLine(to: CGPoint(x: size, y: size * 0.48))
                path.addLine(to: CGPoint(x: size * 0.5, y: size * 0.68))
                path.addLine(to: CGPoint(x: 0, y: size * 0.48))
                path.closeSubpath()
            }
            .fill(Color.white)
            .frame(width: size, height: size * 0.68)

            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: size * 0.5, y: size * 0.3))
                path.addLine(to: CGPoint(x: size, y: 0))
                path.addLine(to: CGPoint(x: size * 0.5, y: size * 0.72))
                path.closeSubpath()
            }
            .fill(Color.white.opacity(0.82))
            .frame(width: size, height: size * 0.36)
        }
        .frame(width: size, height: size * 1.04)
    }
}

struct StablecoinIconMark: View {
    let size: CGFloat
    let symbol: String
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: size, height: size)

            Circle()
                .stroke(Color.white.opacity(0.9), lineWidth: max(1, size * 0.07))
                .frame(width: size * 0.68, height: size * 0.68)

            Text(symbol)
                .font(.system(size: size * 0.46, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}

extension Token {
    /// Native QU or tQU on the Quintium chain.
    var isQuintiumCoin: Bool {
        guard blockchain == .quintium else { return false }
        let upper = self.symbol.uppercased()
        return isNative || upper == "QU" || upper == "TQU"
    }
}

/// Quintium coin: a star-gold disc with the night-blue "Q" pentagon, drawn
/// from `packages/explorer/public/coin.svg` (64×64 viewBox) of the Quintium repo.
struct QuintiumIconMark: View {
    let size: CGFloat

    static let gold = Color(red: 0.949, green: 0.710, blue: 0.267)   // #F2B544
    static let night = Color(red: 0.043, green: 0.086, blue: 0.133)  // #0B1622

    var body: some View {
        ZStack {
            Circle()
                .fill(Self.gold)
                .frame(width: size * 60 / 64, height: size * 60 / 64)
            QuintiumGlyph()
                .fill(Self.night)
                .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
    }
}

private struct QuintiumGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 64
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scale, y: rect.minY + y * scale)
        }
        var path = Path()
        // Outer pentagon
        path.addLines([p(32, 12.4), p(50.55, 25.87), p(43.46, 47.68), p(20.54, 47.68), p(13.45, 25.87)])
        path.closeSubpath()
        // Inner pentagon (hole: wound opposite to the outer one, nonzero fill)
        path.addLines([p(22.73, 28.89), p(26.27, 39.79), p(37.73, 39.79), p(41.27, 28.89), p(32, 22.15)])
        path.closeSubpath()
        // Tail of the Q
        path.addLines([p(36.96, 33.28), p(47.63, 47.97), p(42.45, 51.73), p(31.78, 37.05)])
        path.closeSubpath()
        return path
    }
}

struct PolygonIconMark: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.51, green: 0.29, blue: 0.93))
                .frame(width: size, height: size)

            HStack(spacing: size * 0.02) {
                hexagon
                hexagon
                    .offset(y: size * 0.11)
            }
            .overlay(
                Rectangle()
                    .fill(Color.white)
                    .frame(width: size * 0.24, height: size * 0.07)
                    .rotationEffect(.degrees(-22))
            )
        }
    }

    private var hexagon: some View {
        Image(systemName: "hexagon")
            .font(.system(size: size * 0.35, weight: .bold))
            .foregroundColor(.white)
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
