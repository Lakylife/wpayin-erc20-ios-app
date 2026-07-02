// Autor Lukas Helebrandt, 2026

//
//  WpayinButton.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI

struct WpayinButton: View {
    let title: String
    let style: ButtonStyle
    let action: () -> Void

    enum ButtonStyle {
        case primary
        case secondary
        case tertiary
        case destructive

        var backgroundColor: Color {
            switch self {
            case .primary: return WpayinColors.primary
            case .secondary: return WpayinColors.surface
            case .tertiary: return Color.clear
            case .destructive: return WpayinColors.error
            }
        }

        var foregroundColor: Color {
            switch self {
            case .primary: return WpayinColors.secondary
            case .secondary: return WpayinColors.text
            case .tertiary: return WpayinColors.primary
            case .destructive: return WpayinColors.secondary
            }
        }

        var borderColor: Color {
            switch self {
            case .primary: return Color.clear
            case .secondary: return WpayinColors.surfaceBorder
            case .tertiary: return WpayinColors.primary.opacity(0.6)
            case .destructive: return Color.clear
            }
        }
    }

    var body: some View {
        Button(action: action) {
            HStack {
                Spacer()
                Text(title.localized)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(style.foregroundColor)
                Spacer()
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .background(
                Group {
                    if style == .primary {
                        WpayinColors.accentGradient
                    } else {
                        style.backgroundColor
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: WpayinRadius.medium, style: .continuous)
                    .stroke(style.borderColor, lineWidth: 1.5)
            )
            .cornerRadius(WpayinRadius.medium)
            .shadow(
                color: style == .primary ? WpayinColors.primary.opacity(0.35) : .clear,
                radius: 12, x: 0, y: 6
            )
        }
        .buttonStyle(WpayinPressableStyle())
    }
}

#Preview {
    VStack(spacing: 20) {
        WpayinButton(title: "Primary Button", style: .primary) {}
        WpayinButton(title: "Secondary Button", style: .secondary) {}
        WpayinButton(title: "Tertiary Button", style: .tertiary) {}
        WpayinButton(title: "Destructive Button", style: .destructive) {}
    }
    .padding()
    .background(WpayinColors.background)
}