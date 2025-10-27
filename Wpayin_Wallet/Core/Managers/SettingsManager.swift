//
//  SettingsManager.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import Foundation
import SwiftUI
import Combine
import LocalAuthentication

enum Currency: String, CaseIterable, Identifiable {
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"
    case jpy = "JPY"
    case cny = "CNY"
    case krw = "KRW"
    case czk = "CZK"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .usd: return "$"
        case .eur: return "€"
        case .gbp: return "£"
        case .jpy: return "¥"
        case .cny: return "¥"
        case .krw: return "₩"
        case .czk: return "Kč"
        }
    }

    var name: String {
        switch self {
        case .usd: return "US Dollar"
        case .eur: return "Euro"
        case .gbp: return "British Pound"
        case .jpy: return "Japanese Yen"
        case .cny: return "Chinese Yuan"
        case .krw: return "South Korean Won"
        case .czk: return "Czech Koruna"
        }
    }
}

enum Language: String, CaseIterable, Identifiable {
    case english = "en"
    case czech = "cs"
    case german = "de"
    case french = "fr"
    case spanish = "es"
    case chinese = "zh"
    case japanese = "ja"
    case korean = "ko"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .english: return "English"
        case .czech: return "Čeština"
        case .german: return "Deutsch"
        case .french: return "Français"
        case .spanish: return "Español"
        case .chinese: return "中文"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        }
    }

    var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .czech: return "🇨🇿"
        case .german: return "🇩🇪"
        case .french: return "🇫🇷"
        case .spanish: return "🇪🇸"
        case .chinese: return "🇨🇳"
        case .japanese: return "🇯🇵"
        case .korean: return "🇰🇷"
        }
    }
}

enum AutoLockDuration: String, CaseIterable, Identifiable {
    case immediately = "immediately"
    case after1min = "1min"
    case after5min = "5min"
    case after15min = "15min"
    case after1hour = "1hour"
    case never = "never"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .immediately: return "Immediately"
        case .after1min: return "1 minute"
        case .after5min: return "5 minutes"
        case .after15min: return "15 minutes"
        case .after1hour: return "1 hour"
        case .never: return "Never"
        }
    }

    var seconds: TimeInterval? {
        switch self {
        case .immediately: return 0
        case .after1min: return 60
        case .after5min: return 300
        case .after15min: return 900
        case .after1hour: return 3600
        case .never: return nil
        }
    }
}

final class SettingsManager: ObservableObject {

    // MARK: - Published Properties
    @Published var selectedCurrency: Currency = .usd
    @Published var selectedLanguage: Language = .english
    @Published var biometricAuthEnabled: Bool = false
    @Published var autoLockDuration: AutoLockDuration = .after5min
    @Published var notificationsEnabled: Bool = true

    // State variable to force UI refresh when settings change
    @Published var refreshID = UUID()

    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let context = LAContext()

    // MARK: - UserDefaults Keys
    private enum Keys {
        static let currency = "SelectedCurrency"
        static let language = "SelectedLanguage"
        static let biometricAuth = "BiometricAuthEnabled"
        static let autoLock = "AutoLockDuration"
        static let notifications = "NotificationsEnabled"
    }

    // MARK: - Initialization
    init() {
        loadSettings()
        setupBiometricAvailability()
        applyLanguagePreference()
    }

    // MARK: - Settings Management
    private func loadSettings() {
        if let currencyRaw = userDefaults.string(forKey: Keys.currency),
           let currency = Currency(rawValue: currencyRaw) {
            selectedCurrency = currency
        }

        if let languageRaw = userDefaults.string(forKey: Keys.language),
           let language = Language(rawValue: languageRaw) {
            selectedLanguage = language
        }

        biometricAuthEnabled = userDefaults.bool(forKey: Keys.biometricAuth)

        if let autoLockRaw = userDefaults.string(forKey: Keys.autoLock),
           let autoLock = AutoLockDuration(rawValue: autoLockRaw) {
            autoLockDuration = autoLock
        }

        notificationsEnabled = userDefaults.bool(forKey: Keys.notifications)
    }

    private func applyLanguagePreference() {
        // Apply the selected language to the app
        Bundle.setLanguage(selectedLanguage.rawValue)

        if let savedLanguages = userDefaults.array(forKey: "AppleLanguages") as? [String],
           !savedLanguages.isEmpty {
            // Language preference already set
            print("✅ App language set to: \(savedLanguages.first ?? "unknown")")
        } else {
            // Set default language
            userDefaults.set([selectedLanguage.rawValue], forKey: "AppleLanguages")
            userDefaults.synchronize()
            print("✅ Default language set to: \(selectedLanguage.rawValue)")
        }
    }

    func updateCurrency(_ currency: Currency) {
        selectedCurrency = currency
        userDefaults.set(currency.rawValue, forKey: Keys.currency)

        // Force immediate UI refresh
        refreshID = UUID()
        objectWillChange.send()
    }

    func updateLanguage(_ language: Language) {
        selectedLanguage = language
        userDefaults.set(language.rawValue, forKey: Keys.language)

        // Set the app language using Bundle extension
        Bundle.setLanguage(language.rawValue)

        // Set the app language for system
        userDefaults.set([language.rawValue], forKey: "AppleLanguages")
        userDefaults.synchronize()

        // Force immediate UI refresh
        refreshID = UUID()
        objectWillChange.send()

        // Post notification for any views that need manual refresh
        NotificationCenter.default.post(name: NSNotification.Name("LanguageChanged"), object: nil)

        print("✅ Language changed to: \(language.name)")
    }

    func updateBiometricAuth(_ enabled: Bool) {
        biometricAuthEnabled = enabled
        userDefaults.set(enabled, forKey: Keys.biometricAuth)
    }

    func updateAutoLock(_ duration: AutoLockDuration) {
        autoLockDuration = duration
        userDefaults.set(duration.rawValue, forKey: Keys.autoLock)
    }

    func updateNotifications(_ enabled: Bool) {
        notificationsEnabled = enabled
        userDefaults.set(enabled, forKey: Keys.notifications)
    }

    // MARK: - Biometric Authentication
    var biometricType: LABiometryType {
        context.biometryType
    }

    var isBiometricAvailable: Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    private func setupBiometricAvailability() {
        if !isBiometricAvailable && biometricAuthEnabled {
            biometricAuthEnabled = false
            userDefaults.set(false, forKey: Keys.biometricAuth)
        }
    }

    func authenticateWithBiometry() async -> Bool {
        guard isBiometricAvailable else { return false }

        let reason = "Unlock your wallet with biometry"

        do {
            let result = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            return result
        } catch {
            print("Biometric authentication failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Contact & Support
    func openContactUs() {
        if let url = URL(string: "mailto:support@wpayin.com?subject=Wpayin%20Wallet%20Support") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
    }

    func openHelpCenter() {
        if let url = URL(string: "https://help.wpayin.com") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
    }
}