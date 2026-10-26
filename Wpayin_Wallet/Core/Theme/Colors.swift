// Autor Lukas Helebrandt, 2026

//
//  Colors.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI

extension Color {
    // Deep ink-navy scale — softer and more elegant than pure black
    static let wpayinBlack = Color(red: 0.027, green: 0.031, blue: 0.055) // #070810
    static let wpayinDarkGray = Color(red: 0.055, green: 0.063, blue: 0.102) // #0E101A
    static let wpayinMediumGray = Color(red: 0.086, green: 0.098, blue: 0.149) // #161926
    static let wpayinLightGray = Color(red: 0.125, green: 0.141, blue: 0.204) // #202434
    static let wpayinWhite = Color(red: 1.0, green: 1.0, blue: 1.0)
    static let wpayinBlue = Color(red: 0.443, green: 0.541, blue: 0.973) // #718AF8
    static let wpayinBlueDark = Color(red: 0.333, green: 0.412, blue: 0.827) // #5568d3
    static let wpayinViolet = Color(red: 0.545, green: 0.408, blue: 0.965) // #8B68F6
    static let wpayinSuccess = Color(red: 0.204, green: 0.827, blue: 0.6) // #34D399
    static let wpayinError = Color(red: 0.973, green: 0.443, blue: 0.443) // #F87171
    static let wpayinWarning = Color(red: 0.984, green: 0.749, blue: 0.141) // #FBBF24

    // Token colors from design specification
    static let tokenEth = Color(red: 0.384, green: 0.494, blue: 0.918) // #627eea
    static let tokenUsdt = Color(red: 0.149, green: 0.635, blue: 0.482) // #26a17b
    static let tokenBnb = Color(red: 0.953, green: 0.729, blue: 0.184) // #f3ba2f
    static let tokenUsdc = Color(red: 0.153, green: 0.459, blue: 0.792) // #2775ca
    static let tokenSol = Color(red: 0.6, green: 0.271, blue: 1.0) // #9945FF
}

// MARK: - App color themes (user-selectable accent palette)

enum AppColorTheme: String, CaseIterable, Identifiable {
    case indigo
    case emerald
    case amber
    case rose
    case sky

    var id: String { rawValue }

    /// Display name — pass through .localized at render time.
    var displayName: String {
        switch self {
        case .indigo: return "Indigo"
        case .emerald: return "Emerald"
        case .amber: return "Amber"
        case .rose: return "Rose"
        case .sky: return "Sky"
        }
    }

    var primary: Color {
        switch self {
        case .indigo: return Color.wpayinBlue // #718AF8
        case .emerald: return Color(red: 0.204, green: 0.827, blue: 0.6) // #34D399
        case .amber: return Color(red: 0.961, green: 0.62, blue: 0.043) // #F59E0B
        case .rose: return Color(red: 0.984, green: 0.443, blue: 0.522) // #FB7185
        case .sky: return Color(red: 0.22, green: 0.741, blue: 0.973) // #38BDF8
        }
    }

    var primaryDark: Color {
        switch self {
        case .indigo: return Color.wpayinBlueDark // #5568D3
        case .emerald: return Color(red: 0.063, green: 0.588, blue: 0.412) // #109669
        case .amber: return Color(red: 0.851, green: 0.467, blue: 0.024) // #D97706
        case .rose: return Color(red: 0.882, green: 0.267, blue: 0.369) // #E1445E
        case .sky: return Color(red: 0.055, green: 0.647, blue: 0.914) // #0EA5E9
        }
    }

    var accent: Color {
        switch self {
        case .indigo: return Color.wpayinViolet // #8B68F6
        case .emerald: return Color(red: 0.176, green: 0.831, blue: 0.749) // #2DD4BF
        case .amber: return Color(red: 0.976, green: 0.451, blue: 0.086) // #F97316
        case .rose: return Color(red: 0.957, green: 0.447, blue: 0.714) // #F472B6
        case .sky: return Color(red: 0.133, green: 0.827, blue: 0.933) // #22D3EE
        }
    }

    static let storageKey = "AppColorTheme"

    static func loadSaved() -> AppColorTheme {
        guard let raw = UserDefaults.standard.string(forKey: storageKey),
              let theme = AppColorTheme(rawValue: raw) else {
            return .indigo
        }
        return theme
    }
}

struct WpayinColors {
    /// Active theme — loaded at startup, updated by SettingsManager.updateColorTheme
    /// (which also bumps refreshID so the whole UI redraws).
    static var currentTheme: AppColorTheme = AppColorTheme.loadSaved()

    // Primary colors follow the selected theme
    static var primary: Color { currentTheme.primary }
    static var primaryDark: Color { currentTheme.primaryDark }
    static var accent: Color { currentTheme.accent }
    static let secondary = Color.wpayinWhite

    // Signature accent gradient (primary → accent)
    static var accentGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [currentTheme.primary, currentTheme.accent]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Background colors with gradient support
    static let background = Color.wpayinBlack
    static let backgroundGradientStart = Color.wpayinDarkGray
    static let backgroundGradientEnd = Color.wpayinBlack

    // Surface colors for cards and components
    static let surface = Color.white.opacity(0.045)
    static let surfaceLight = Color.white.opacity(0.07)
    static let surfaceHover = Color.white.opacity(0.1)
    static let surfaceBorder = Color.white.opacity(0.09)

    // Header background
    static let headerBackground = Color.wpayinLightGray

    // Text colors
    static let text = Color.wpayinWhite
    static let textSecondary = Color(red: 0.61, green: 0.639, blue: 0.71) // #9CA3B5
    static let textTertiary = Color(red: 0.42, green: 0.447, blue: 0.52) // #6B7285

    // Status colors
    static let success = Color.wpayinSuccess
    static let error = Color.wpayinError
    static let warning = Color.wpayinWarning

    // Button colors
    static let buttonBackground = Color.white.opacity(0.06)
    static let buttonBorder = Color.white.opacity(0.1)
    static let buttonHover = Color.white.opacity(0.09)

    // Navigation colors
    static let navBackground = Color(red: 0.047, green: 0.055, blue: 0.09).opacity(0.92)
    static let navBorder = Color.white.opacity(0.07)

    // Legacy colors for compatibility
    static let surfaceElegant = Color.white.opacity(0.05)
    static let borderElegant = Color.white.opacity(0.1)
}

// MARK: - Layout constants

enum WpayinRadius {
    static let small: CGFloat = 10
    static let medium: CGFloat = 14
    static let card: CGFloat = 20
    static let large: CGFloat = 24
}

// MARK: - Shared view styles

extension View {
    /// Standard card container: soft surface, hairline border, rounded corners.
    func wpayinCard(padding: CGFloat = 16, radius: CGFloat = WpayinRadius.card) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(WpayinColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                    )
            )
    }
}

/// Button style with a gentle press-down scale for tactile feedback.
struct WpayinPressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
