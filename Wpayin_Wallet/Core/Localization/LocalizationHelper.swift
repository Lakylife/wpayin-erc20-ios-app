// Autor Lukas Helebrandt, 2026

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
        let format = NSLocalizedString(self, comment: "")
        return String(format: format, arguments: args)
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
        static let mainWallet = "wallet.mainWallet"
        static let options = "wallet.options"
        static let connect = "wallet.connect"
        static let noAssets = "wallet.noAssets"
        static let syncing = "wallet.syncing"
        static let portfolioUpToDate = "wallet.portfolioUpToDate"
        static let refresh = "wallet.refresh"
        static let loadingData = "wallet.loadingData"
        static let failedToLoad = "wallet.failedToLoad"
        static let retry = "wallet.retry"
    }

    // MARK: - Tokens
    enum Tokens {
        static let title = "tokens.title"
        static let defi = "tokens.defi"
        static let nfts = "tokens.nfts"
        static let addToken = "tokens.addToken"
        static let balance = "tokens.balance"
        static let myAssets = "tokens.myAssets"
        static let noTokens = "tokens.noTokens"
        static let loadAll = "tokens.loadAll"
        static let selectToken = "tokens.selectToken"
        static let details = "tokens.details"
        static let distribution = "tokens.distribution"
    }

    // MARK: - Networks
    enum Networks {
        static let title = "networks.title"
        static let available = "networks.available"
        static let active = "networks.active"
        static let manage = "networks.manage"
        static let addCustom = "networks.addCustom"
        static let activeBlockchains = "networks.activeBlockchains"
        static let networkCount = "networks.count"
    }

    // MARK: - Settings
    enum Settings {
        static let title = "settings.title"
        static let currency = "settings.currency"
        static let language = "settings.language"
        static let security = "settings.security"
        static let about = "settings.about"
        static let faceId = "settings.faceId"
        static let touchId = "settings.touchId"
        static let biometricAuth = "settings.biometricAuth"
        static let autoLock = "settings.autoLock"
        static let notifications = "settings.notifications"
        static let wallet = "settings.wallet"
        static let showPrivateKey = "settings.showPrivateKey"
        static let exportWallet = "settings.exportWallet"
        static let manageNetworks = "settings.manageNetworks"
        static let helpCenter = "settings.helpCenter"
        static let contactUs = "settings.contactUs"
        static let deleteWallet = "settings.deleteWallet"
        static let version = "settings.version"
        static let preferences = "settings.preferences"
        static let support = "settings.support"
        static let dangerZone = "settings.dangerZone"
    }

    // MARK: - Actions
    enum Action {
        static let send = "action.send"
        static let receive = "action.receive"
        static let swap = "action.swap"
        static let buy = "action.buy"
        static let sell = "action.sell"
        static let cancel = "action.cancel"
        static let done = "action.done"
        static let understand = "action.understand"
        static let copy = "action.copy"
        static let close = "action.close"
        static let delete = "action.delete"
        static let create = "action.create"
        static let importWallet = "action.import"
        static let getStarted = "action.getStarted"
        static let `continue` = "action.continue"
        static let skip = "action.skip"
        static let edit = "action.edit"
        static let set = "action.set"
        static let depositSubtitle = "action.depositSubtitle"
        static let sendSubtitle = "action.sendSubtitle"
        static let swapSubtitle = "action.swapSubtitle"
    }

    // MARK: - Security
    enum Security {
        static let keepSafe = "security.keepSafe"
        static let warning = "security.warning"
        static let yourKey = "security.yourKey"
        static let notAvailable = "security.notAvailable"
        static let mnemonicWarning = "security.mnemonicWarning"
        static let biometricSubtitle = "security.biometricSubtitle"
        static let notAvailableDevice = "security.notAvailableDevice"
        static let micaAgreement = "security.micaAgreement"
        static let legalNotice = "security.legalNotice"
        static let unlockReason = "security.unlockReason"
    }

    // MARK: - Help Center
    enum Help {
        static let search = "help.search"
        static let noResults = "help.noResults"
        static let tryDifferent = "help.tryDifferent"
        static let articles = "help.articles"
        static let stepByStep = "help.stepByStep"
        static let related = "help.related"
    }

    // MARK: - Bridge
    enum Bridge {
        static let title = "bridge.title"
        static let fromNetwork = "bridge.fromNetwork"
        static let toNetwork = "bridge.toNetwork"
        static let provider = "bridge.provider"
        static let estimatedTime = "bridge.estimatedTime"
        static let review = "bridge.review"
        static let gettingQuote = "bridge.gettingQuote"
        static let bridging = "bridge.bridging"
        static let submitted = "bridge.submitted"
        static let failed = "bridge.failed"
        static let sameNetwork = "bridge.sameNetwork"
    }

    // MARK: - Swap
    enum Swap {
        static let title = "swap.title"
        static let subtitle = "swap.subtitle"
        static let from = "swap.from"
        static let to = "swap.to"
        static let rate = "swap.rate"
        static let slippage = "swap.slippage"
        static let networkFee = "swap.networkFee"
        static let insufficient = "swap.insufficient"
        static let selectNetwork = "swap.selectNetwork"
        static let slippageTolerance = "swap.slippageTolerance"
        static let slippageWarning = "swap.slippageWarning"
        static let slippageHighWarning = "swap.slippageHighWarning"
        static let gasSpeed = "swap.gasSpeed"
        static let youPay = "swap.youPay"
        static let youReceive = "swap.youReceive"
        static let estimatedAmount = "swap.estimatedAmount"
        static let minimumReceived = "swap.minimumReceived"
        static let review = "swap.review"
        static let confirm = "swap.confirm"
    }

    // MARK: - Activity
    enum Activity {
        static let title = "activity.title"
        static let search = "activity.search"
        static let noTransactions = "activity.noTransactions"
        static let viewExplorer = "activity.viewExplorer"
        static let details = "activity.details"
        static let filterAll = "activity.filterAll"
        static let filterSent = "activity.filterSent"
        static let filterReceived = "activity.filterReceived"
        static let filterSwapped = "activity.filterSwapped"
        static let noResultsFound = "activity.noResultsFound"
        static let tryAdjusting = "activity.tryAdjusting"
        static let recent = "activity.recent"
        static let emptyDesc = "activity.emptyDesc"
        static let tokenEmptyDesc = "activity.tokenEmptyDesc"
        static let transactions = "activity.transactions"
        static let overview = "activity.overview"
        static let today = "activity.today"
        static let yesterday = "activity.yesterday"
    }

    // MARK: - Market
    enum Market {
        static let priceChart = "market.priceChart"
        static let high24h = "market.high24h"
        static let low24h = "market.low24h"
        static let volume24h = "market.volume24h"
        static let marketCap = "market.marketCap"
        static let circulatingSupply = "market.circulatingSupply"
        static let totalSupply = "market.totalSupply"
    }

    // MARK: - Onboarding
    enum Onboarding {
        static let welcome = "onboarding.welcome"
        static let step = "onboarding.step"
        static let secureTitle = "onboarding.secureTitle"
        static let secureDesc = "onboarding.secureDesc"
        static let tradingTitle = "onboarding.tradingTitle"
        static let tradingDesc = "onboarding.tradingDesc"
        static let multiChainTitle = "onboarding.multiChainTitle"
        static let multiChainDesc = "onboarding.multiChainDesc"
    }

    // MARK: - Welcome
    enum Welcome {
        static let subtitle = "welcome.subtitle"
    }
}
