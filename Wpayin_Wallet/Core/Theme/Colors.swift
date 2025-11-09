//
//  Colors.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI

extension Color {
    static let wpayinBlack = Color(red: 0.0, green: 0.0, blue: 0.0)
    static let wpayinDarkGray = Color(red: 0.059, green: 0.059, blue: 0.059)
    static let wpayinMediumGray = Color(red: 0.102, green: 0.102, blue: 0.102)
    static let wpayinLightGray = Color(red: 0.161, green: 0.161, blue: 0.161)
    static let wpayinWhite = Color(red: 1.0, green: 1.0, blue: 1.0)
    static let wpayinBlue = Color(red: 0.4, green: 0.494, blue: 0.918) // #667eea
    static let wpayinBlueDark = Color(red: 0.333, green: 0.412, blue: 0.827) // #5568d3
    static let wpayinSuccess = Color(red: 0.298, green: 0.686, blue: 0.314) // #4caf50
    static let wpayinError = Color(red: 0.957, green: 0.263, blue: 0.212) // #f44336
    static let wpayinWarning = Color(red: 1.0, green: 0.8, blue: 0.0)

    // Token colors from design specification
    static let tokenEth = Color(red: 0.384, green: 0.494, blue: 0.918) // #627eea
    static let tokenUsdt = Color(red: 0.149, green: 0.635, blue: 0.482) // #26a17b
    static let tokenBnb = Color(red: 0.953, green: 0.729, blue: 0.184) // #f3ba2f
    static let tokenUsdc = Color(red: 0.153, green: 0.459, blue: 0.792) // #2775ca
    static let tokenSol = Color(red: 0.6, green: 0.271, blue: 1.0) // #9945FF
}

struct WpayinColors {
    // Primary colors matching the design specification
    static let primary = Color.wpayinBlue
    static let primaryDark = Color.wpayinBlueDark
    static let secondary = Color.wpayinWhite

    // Background colors with gradient support
    static let background = Color.wpayinBlack
    static let backgroundGradientStart = Color.wpayinDarkGray
    static let backgroundGradientEnd = Color.wpayinBlack

    // Surface colors for cards and components
    static let surface = Color.white.opacity(0.03)
    static let surfaceLight = Color.white.opacity(0.05)
    static let surfaceHover = Color.white.opacity(0.08)
    static let surfaceBorder = Color.white.opacity(0.08)

    // Header background
    static let headerBackground = Color.wpayinLightGray

    // Text colors
    static let text = Color.wpayinWhite
    static let textSecondary = Color(red: 0.533, green: 0.533, blue: 0.533) // #888
    static let textTertiary = Color(red: 0.4, green: 0.4, blue: 0.4) // #666

    // Status colors
    static let success = Color.wpayinSuccess
    static let error = Color.wpayinError
    static let warning = Color.wpayinWarning

    // Button colors
    static let buttonBackground = Color.white.opacity(0.05)
    static let buttonBorder = Color.white.opacity(0.1)
    static let buttonHover = Color.white.opacity(0.08)

    // Navigation colors
    static let navBackground = Color(red: 0.039, green: 0.039, blue: 0.039).opacity(0.95) // rgba(10, 10, 10, 0.95)
    static let navBorder = Color.white.opacity(0.05)

    // Legacy colors for compatibility
    static let surfaceElegant = Color.white.opacity(0.05)
    static let borderElegant = Color.white.opacity(0.1)
}