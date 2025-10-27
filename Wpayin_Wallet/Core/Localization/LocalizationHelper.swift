//
//  LocalizationHelper.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import Foundation

extension String {
    /// Localized string shorthand
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }

    /// Localized string with arguments
    func localized(_ args: CVarArg...) -> String {
        return String(format: NSLocalizedString(self, comment: ""), arguments: args)
    }
}

/// Localization keys for type-safe access
enum L10n {
    // MARK: - Wallet
    enum Wallet {
        static let totalBalance = "wallet.totalBalance"
        static let home = "wallet.home"
        static let swap = "wallet.swap"
        static let activity = "wallet.activity"
        static let settings = "wallet.settings"
        static let yourAssets = "wallet.yourAssets"
        static let viewAll = "wallet.viewAll"
        static let send = "wallet.send"
        static let receive = "wallet.receive"
        static let buy = "wallet.buy"
    }

    // MARK: - Tokens
    enum Tokens {
        static let title = "tokens.title"
        static let defi = "tokens.defi"
        static let nfts = "tokens.nfts"
        static let addToken = "tokens.addToken"
        static let balance = "tokens.balance"
    }

    // MARK: - Networks
    enum Networks {
        static let title = "networks.title"
        static let available = "networks.available"
        static let active = "networks.active"
    }

    // MARK: - Settings
    enum Settings {
        static let title = "settings.title"
        static let currency = "settings.currency"
        static let language = "settings.language"
        static let security = "settings.security"
        static let about = "settings.about"
    }

    // MARK: - Actions
    enum Action {
        static let send = "action.send"
        static let receive = "action.receive"
        static let swap = "action.swap"
        static let buy = "action.buy"
        static let cancel = "action.cancel"
        static let done = "action.done"
    }
}
