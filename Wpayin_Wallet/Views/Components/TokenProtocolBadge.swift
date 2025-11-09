//
//  TokenProtocolBadge.swift
//  Wpayin_Wallet
//
//  Token protocol badge component (ERC20, BEP20, BIP84, etc.)
//

import SwiftUI

struct TokenProtocolBadge: View {
    let tokenProtocol: TokenProtocol
    let size: BadgeSize
    
    enum BadgeSize {
        case small
        case medium
        case large
        
        var fontSize: CGFloat {
            switch self {
            case .small: return 9
            case .medium: return 10
            case .large: return 11
            }
        }
        
        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4)
            case .medium: return EdgeInsets(top: 3, leading: 6, bottom: 3, trailing: 6)
            case .large: return EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
            }
        }
    }
    
    var body: some View {
        if !tokenProtocol.shortName.isEmpty {
            Text(tokenProtocol.shortName)
                .font(.system(size: size.fontSize, weight: .semibold))
                .foregroundColor(badgeTextColor)
                .padding(size.padding)
                .background(badgeBackgroundColor)
                .cornerRadius(4)
        }
    }
    
    private var badgeBackgroundColor: Color {
        switch tokenProtocol {
        case .erc20:
            return Color(red: 0.39, green: 0.47, blue: 1.0).opacity(0.15)
        case .bep20:
            return Color(red: 0.95, green: 0.77, blue: 0.19).opacity(0.15)
        case .trc20:
            return Color.red.opacity(0.15)
        case .bep2:
            return Color.yellow.opacity(0.15)
        case .spl:
            return Color.purple.opacity(0.15)
        case .bip84, .bip49, .bip44:
            return Color.orange.opacity(0.15)
        case .native:
            return Color.gray.opacity(0.15)
        }
    }
    
    private var badgeTextColor: Color {
        switch tokenProtocol {
        case .erc20:
            return Color(red: 0.39, green: 0.47, blue: 1.0)
        case .bep20:
            return Color(red: 0.8, green: 0.6, blue: 0.0)
        case .trc20:
            return Color.red
        case .bep2:
            return Color.orange
        case .spl:
            return Color.purple
        case .bip84, .bip49, .bip44:
            return Color.orange
        case .native:
            return Color.gray
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack(spacing: 8) {
            TokenProtocolBadge(tokenProtocol: .erc20, size: .small)
            TokenProtocolBadge(tokenProtocol: .bep20, size: .small)
            TokenProtocolBadge(tokenProtocol: .bip84, size: .small)
        }
        
        HStack(spacing: 8) {
            TokenProtocolBadge(tokenProtocol: .erc20, size: .medium)
            TokenProtocolBadge(tokenProtocol: .bep20, size: .medium)
            TokenProtocolBadge(tokenProtocol: .bip84, size: .medium)
        }
        
        HStack(spacing: 8) {
            TokenProtocolBadge(tokenProtocol: .erc20, size: .large)
            TokenProtocolBadge(tokenProtocol: .bep20, size: .large)
            TokenProtocolBadge(tokenProtocol: .bip84, size: .large)
        }
    }
    .padding()
}
