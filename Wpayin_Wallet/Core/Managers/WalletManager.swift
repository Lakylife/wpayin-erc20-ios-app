// Autor Lukas Helebrandt, 2026

//
//  WalletManager.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//
//  ╦ ╦┌─┐┬  ┬  ┌─┐┌┬┐╔═╗┌─┐┬ ┬┬┌┐┌
//  ║║║├─┤│  │  ├┤  │ ╠═╝├─┤└┬┘││││
//  ╚╩╝┴ ┴┴─┘┴─┘└─┘ ┴ ╩  ┴ ┴ ┴ ┴┘└┘
//

import Foundation
import Combine
import WalletCore
import UserNotifications

final class WalletManager: ObservableObject {
    struct ChainAccount: Identifiable, Sendable {
        let id: UUID
        let tokenType: BlockchainType
        let coinType: CoinType?
        let config: BlockchainConfig
        let address: String

        init(config: BlockchainConfig, tokenType: BlockchainType, coinType: CoinType?, address: String) {
            self.id = config.id
            self.tokenType = tokenType
            self.coinType = coinType
            self.config = config
            self.address = address
        }
    }

    // MARK: - Published Properties
    @Published var multiChainWallets: [MultiChainWallet] = []
    @Published var activeWallet: MultiChainWallet?
    @Published var availableBlockchains: [BlockchainConfig] = []
    @Published var savedAddresses: [SavedAddress] = []
    @Published var isLoading: Bool = false
    @Published var hasWallet: Bool = false
    @Published var hasCompletedOnboarding: Bool = false
    @Published var isInitializing: Bool = true

    @Published var walletAddress: String = ""
    @Published var tokens: [Token] = []
    @Published var nfts: [NFT] = []
    @Published private(set) var isLoadingNFTs = false
    @Published private var manuallyHiddenNFTIdentities: Set<String> = []
    @Published private var trustedNFTIdentities: Set<String> = []
    @Published var transactions: [Transaction] = []
    @Published var balance: Double = 0.0
    @Published var selectedBlockchains: Set<BlockchainPlatform> = [.ethereum]
    @Published var favoriteTokenSymbols: Set<String> = []
    /// 24h price change in percent, keyed by uppercased token symbol (live-updated).
    @Published var priceChanges24h: [String: Double] = [:]

    /// 24h portfolio change derived from each visible token's 24h price move,
    /// weighted by its current value. Depends only on live market data — never
    /// on locally persisted balance snapshots.
    var balanceChangePercentage: Double {
        let holdings = visibleTokens.filter { $0.totalValue > 0 }
        let currentValue = holdings.reduce(0) { $0 + $1.totalValue }
        guard currentValue > 0 else { return 0 }

        var valueDayAgo = 0.0
        for token in holdings {
            let changePct = priceChanges24h[token.symbol.uppercased()] ?? 0
            valueDayAgo += token.totalValue / (1 + changePct / 100)
        }
        guard valueDayAgo > 0 else { return 0 }
        return (currentValue - valueDayAgo) / valueDayAgo * 100
    }
    /// Bumped on every completed live price refresh (drives "updated" pulses).
    @Published var lastPriceUpdate: Date?

    let keychain = KeychainManager()
    private let apiService = APIService.shared
    private let mnemonicService = MnemonicService()

    private let walletsStorageKey = "MultiChainWallets"
    private let blockchainsStorageKey = "AvailableBlockchainConfigs"
    private let favoritesStorageKey = "FavoriteTokens"
    private let selectedBlockchainsKey = "SelectedBlockchains"  // NEW: Persistence key
    private let cachedTokenPricesKey = "CachedTokenPrices"
    private let cachedTransactionsPrefix = "CachedTransactions"
    private let cachedHoldingsPrefix = "CachedHoldings"
    private let seenTransactionsPrefix = "SeenTransactionHashes"
    private let hiddenTokenIdentitiesKey = "HiddenTokenIdentities"
    private let hiddenNFTIdentitiesKey = "HiddenNFTIdentities"
    private let trustedNFTIdentitiesKey = "TrustedNFTIdentities"

    private var chainAccounts: [BlockchainType: ChainAccount] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var priceUpdateTimer: Timer?
    private let priceUpdateInterval: TimeInterval = 60 // Live prices — CoinGecko free tier is fine with 1 call/min
    private var savedCustomTokens: [Token] = []
    private var hiddenTokenIdentities: Set<String> = []

    // Public access to chain accounts for deposit address generation
    var availableChainAccounts: [BlockchainType: ChainAccount] {
        return chainAccounts
    }

    var visibleTokens: [Token] {
        tokens.filter { token in
            guard let platform = BlockchainPlatform(rawValue: token.blockchain.rawValue) else {
                return false
            }
            return selectedBlockchains.contains(platform)
                && hasActiveAccount(for: token.blockchain)
                && !hiddenTokenIdentities.contains(tokenIdentityKey(for: token))
        }
    }

    var visibleSupportedTokens: [Token] {
        mergedSupportedTokens(with: visibleTokens).filter {
            !hiddenTokenIdentities.contains(tokenIdentityKey(for: $0))
        }
    }

    /// Main gallery. Spam and manually hidden collectibles stay reviewable in
    /// a separate folder; nothing is burned or transferred on-chain.
    var visibleNFTs: [NFT] {
        nfts.filter { nft in
            let identity = nftIdentityKey(for: nft)
            if trustedNFTIdentities.contains(identity) { return true }
            return !manuallyHiddenNFTIdentities.contains(identity)
                && !NFTSpamFilter.isLikelySpam(nft)
        }
    }

    var suspiciousNFTs: [NFT] {
        nfts.filter { nft in
            let identity = nftIdentityKey(for: nft)
            if trustedNFTIdentities.contains(identity) { return false }
            return manuallyHiddenNFTIdentities.contains(identity)
                || NFTSpamFilter.isLikelySpam(nft)
        }
    }

    // Computed property to group tokens by symbol and combine balances
    var groupedTokens: [Token] {
        groupedTokens(from: tokens)
    }

    // Filtered grouped tokens - only show from selected blockchains
    var visibleGroupedTokens: [Token] {
        groupedTokens(from: visibleTokens)
    }

    private func groupedTokens(from sourceTokens: [Token]) -> [Token] {
        let grouped = Dictionary(grouping: sourceTokens, by: { $0.symbol.uppercased() })
        return grouped.compactMap { symbol, tokens in
            guard let firstToken = tokens.first else { return nil }

            let totalBalance = tokens.reduce(0) { $0 + $1.balance }

            let unifiedPrice = unifiedPrice(for: symbol, tokens: tokens, totalBalance: totalBalance)

            // Use the primary blockchain for the symbol (Ethereum for ETH, Bitcoin for BTC, etc.)
            let primaryBlockchain = getPrimaryBlockchain(for: symbol)
            let primaryToken = tokens.first { $0.blockchain == primaryBlockchain } ?? firstToken

            return Token(
                contractAddress: primaryToken.contractAddress,
                name: primaryToken.name,
                symbol: symbol,
                decimals: primaryToken.decimals,
                balance: totalBalance,
                price: unifiedPrice,
                iconUrl: primaryToken.iconUrl,
                blockchain: primaryBlockchain,
                isNative: primaryToken.isNative,
                receivingAddress: primaryToken.receivingAddress
            )
        }.sorted { $0.totalValue > $1.totalValue }
    }

    private func unifiedPrice(for symbol: String, tokens: [Token], totalBalance: Double) -> Double {
        if symbol == "ETH",
           let mainnetEthPrice = tokens.first(where: { $0.blockchain == .ethereum && $0.price > 1 })?.price {
            return mainnetEthPrice
        }

        let meaningfulPrices = tokens.map { $0.price }.filter { isMeaningfulPrice($0, for: symbol) }
        if let highestMeaningfulPrice = meaningfulPrices.max() {
            return highestMeaningfulPrice
        }

        let totalValue = tokens.reduce(0) { $0 + $1.totalValue }
        if totalBalance > 0, totalValue > 0 {
            return totalValue / totalBalance
        }

        return tokens.first(where: { $0.price > 0 })?.price ?? 0
    }

    private func isMeaningfulPrice(_ price: Double, for symbol: String) -> Bool {
        guard price > 0 else { return false }
        switch symbol.uppercased() {
        case "ETH", "WETH", "BTC", "BNB", "SOL", "AVAX", "MATIC":
            return price > 10
        default:
            return true
        }
    }

    /// Current USD price used to value explorer transactions. Prefer the
    /// exact asset on the exact network, then fall back to the same symbol on
    /// another network (for example ETH on Ethereum for an L2 gas fee).
    func currentUSDPrice(for symbol: String, blockchain: BlockchainType) -> Double? {
        if let exactPrice = tokens.first(where: {
            $0.blockchain == blockchain
                && $0.symbol.caseInsensitiveCompare(symbol) == .orderedSame
                && $0.price > 0
        })?.price {
            return exactPrice
        }

        return tokens.first(where: {
            $0.symbol.caseInsensitiveCompare(symbol) == .orderedSame && $0.price > 0
        })?.price
    }

    func currentUSDValue(for transaction: Transaction) -> Double? {
        guard transaction.amount > 0,
              let price = currentUSDPrice(
                for: transaction.token,
                blockchain: transaction.resolvedBlockchain
              ) else {
            return nil
        }
        return transaction.amount * price
    }

    func currentGasFeeUSDValue(for transaction: Transaction) -> Double? {
        guard transaction.gasFee > 0,
              let price = currentUSDPrice(
                for: transaction.resolvedBlockchain.nativeToken,
                blockchain: transaction.resolvedBlockchain
              ) else {
            return nil
        }
        return transaction.gasFee * price
    }

    // Available blockchains for the selected platforms
    var availableBlockchainsForPlatforms: [BlockchainConfig] {
        availableBlockchains.filter { config in
            selectedBlockchains.contains(config.platform) && config.network == .mainnet
        }
    }

    private func mergedSupportedTokens(with existingTokens: [Token]) -> [Token] {
        var tokenMap: [String: Token] = [:]
        for token in existingTokens {
            tokenMap[tokenIdentityKey(for: token)] = token
        }

        for config in availableBlockchainsForPlatforms {
            guard let blockchain = config.blockchainType else { continue }
            let accountAddress = chainAccounts[blockchain]?.address
            guard let accountAddress, !accountAddress.isEmpty else { continue }
            let nativeKey = "\(blockchain.rawValue):native"

            if tokenMap[nativeKey] == nil {
                tokenMap[nativeKey] = Token(
                    contractAddress: nil,
                    name: blockchain.name,
                    symbol: blockchain.nativeToken,
                    decimals: blockchain.nativeDecimals,
                    balance: 0,
                    price: cachedPrice(for: blockchain.nativeToken) ?? 0,
                    iconUrl: cachedIconUrl(for: blockchain.nativeToken) ?? getDefaultIconUrl(for: blockchain.nativeToken),
                    blockchain: blockchain,
                    isNative: true,
                    receivingAddress: accountAddress
                )
            }

            for tokenInfo in knownERC20Tokens(for: config.platform) {
                let key = "\(blockchain.rawValue):\(tokenInfo.contractAddress.lowercased())"
                if tokenMap[key] == nil {
                    tokenMap[key] = Token(
                        contractAddress: tokenInfo.contractAddress,
                        name: tokenInfo.name,
                        symbol: tokenInfo.symbol,
                        decimals: tokenInfo.decimals,
                        balance: 0,
                        price: cachedPrice(for: tokenInfo.symbol) ?? 0,
                        iconUrl: cachedIconUrl(for: tokenInfo.symbol) ?? getDefaultIconUrl(for: tokenInfo.symbol),
                        blockchain: blockchain,
                        isNative: false,
                        receivingAddress: accountAddress
                    )
                }
            }
        }

        return Array(tokenMap.values)
    }

    private func tokenIdentityKey(for token: Token) -> String {
        "\(token.blockchain.rawValue):\((token.contractAddress ?? "native").lowercased())"
    }

    private func nftIdentityKey(for nft: NFT) -> String {
        [
            nft.ownerAddress.lowercased(),
            nft.blockchain.rawValue,
            nft.contractAddress.lowercased(),
            nft.tokenId.lowercased()
        ].joined(separator: ":")
    }

    func isNFTInSpamFolder(_ nft: NFT) -> Bool {
        let identity = nftIdentityKey(for: nft)
        if trustedNFTIdentities.contains(identity) { return false }
        return manuallyHiddenNFTIdentities.contains(identity) || NFTSpamFilter.isLikelySpam(nft)
    }

    func hideNFT(_ nft: NFT) {
        let identity = nftIdentityKey(for: nft)
        trustedNFTIdentities.remove(identity)
        manuallyHiddenNFTIdentities.insert(identity)
        saveNFTVisibilityPreferences()
        AppToast.show("NFT moved to Hidden Spam".localized, icon: "eye.slash.fill")
    }

    func trustNFT(_ nft: NFT) {
        let identity = nftIdentityKey(for: nft)
        manuallyHiddenNFTIdentities.remove(identity)
        trustedNFTIdentities.insert(identity)
        saveNFTVisibilityPreferences()
        AppToast.show("NFT restored to gallery".localized, icon: "checkmark.shield.fill")
    }
    

    init() {
        setupDefaultBlockchains()
        loadWallets()
        loadSavedAddresses()
        loadFavorites()
        loadCustomTokens()
        loadHiddenTokenIdentities()
        loadNFTVisibilityPreferences()
        loadSelectedBlockchains()  // NEW: Load selected blockchains
        checkOnboardingStatus()
        // Don't set isInitializing = false here, let ContentView handle it
    }

    /// Setup listener for currency/language changes from SettingsManager
    func setupSettingsListener(_ settingsManager: SettingsManager) {
        // Listen for currency changes and refresh wallet data
        settingsManager.$selectedCurrency
            .dropFirst() // Skip initial value
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task {
                    await self.refreshWalletData()
                }
            }
            .store(in: &cancellables)

        // Listen for language changes
        settingsManager.$selectedLanguage
            .dropFirst() // Skip initial value
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task {
                    await self.refreshWalletData()
                }
            }
            .store(in: &cancellables)
    }

    func checkExistingWallet() async {
        isInitializing = true

        hasWallet = keychain.hasSeedPhrase() || keychain.hasPrivateKey()

        if hasWallet {
            // Restore addresses, cached prices and transaction history before
            // the first network request. The wallet becomes usable immediately
            // while fresh balances replace the cached shell in the background.
            primeWalletForImmediateDisplay()
            isInitializing = false
            await Task.yield()
            await refreshWalletData()
            startPriceUpdates()
        } else {
            stopPriceUpdates()
            isInitializing = false
        }
    }

    @MainActor
    private func primeWalletForImmediateDisplay() {
        do {
            if let mnemonic = keychain.getSeedPhrase() {
                let wallet = try mnemonicService.loadWallet(from: mnemonic)
                let accountIndex = activeWallet.map { getAccountIndex(for: $0) } ?? 0
                UserDefaults.standard.set(accountIndex, forKey: "ActiveAccountIndex")
                chainAccounts = deriveAccounts(using: wallet, accountIndex: accountIndex)
            } else if let privateKey = keychain.getPrivateKey() {
                let normalized = try mnemonicService.normalizePrivateKey(privateKey)
                let address = try mnemonicService.deriveEthereumAddress(fromPrivateKey: normalized)
                let accounts = availableBlockchains.compactMap { config -> ChainAccount? in
                    guard config.network == .mainnet,
                          config.isEnabled,
                          let tokenType = config.blockchainType,
                          tokenType.isEVM else { return nil }
                    return ChainAccount(
                        config: config,
                        tokenType: tokenType,
                        coinType: config.coinType,
                        address: address
                    )
                }
                chainAccounts = Dictionary(uniqueKeysWithValues: accounts.map { ($0.tokenType, $0) })
            }

            walletAddress = chainAccounts[.ethereum]?.address
                ?? chainAccounts.values.first?.address
                ?? walletAddress
            if tokens.isEmpty, !walletAddress.isEmpty {
                tokens = cachedHoldings(for: walletAddress)
            }
            tokens = mergedSupportedTokens(with: tokens)
            balance = visibleTokens.reduce(0) { $0 + $1.totalValue }
            if transactions.isEmpty, !walletAddress.isEmpty {
                transactions = cachedTransactions(for: walletAddress)
            }
        } catch {
            Logger.log("⚠️ Fast wallet restore failed; continuing with live refresh: \(error.localizedDescription)")
        }
    }

    func createWallet(mnemonic: String) -> Bool {
        let normalized = mnemonicService.normalizeMnemonic(mnemonic)
        guard mnemonicService.isValidMnemonic(normalized) else { return false }
        return persistSeedPhrase(normalized)
    }

    func importWallet(privateKey: String) -> Bool {
        do {
            let normalized = try mnemonicService.normalizePrivateKey(privateKey)
            ensureActiveCredentialBackedUp()

            let credentialId = "private-\(UUID().uuidString)"
            guard keychain.storePrivateKey(normalized, identifier: credentialId),
                  keychain.storePrivateKey(normalized) else { return false }
            keychain.deleteSeedPhrase()

            let address = try mnemonicService.deriveEthereumAddress(fromPrivateKey: normalized)
            var wallet = MultiChainWallet(
                name: nextWalletName(prefix: "Imported Wallet"),
                type: .imported,
                privateKeyId: credentialId
            )
            wallet.accounts = walletAccounts(forEVMAddress: address, privateKeyId: credentialId)
            addWallet(wallet)
            hasWallet = true
            isInitializing = false
            return true
        } catch {
            Logger.log("Import wallet error: \(error.localizedDescription)")
            return false
        }
    }

    func importWalletWithMnemonic(_ mnemonic: String) -> Bool {
        let normalized = mnemonicService.normalizeMnemonic(mnemonic)
        guard mnemonicService.isValidMnemonic(normalized) else { return false }
        return persistSeedPhrase(normalized)
    }

    @MainActor
    func refreshWalletData() async {
        isLoading = true
        defer { isLoading = false }

        if let seedPhrase = keychain.getSeedPhrase() {
            await refreshFromMnemonic(seedPhrase)
        } else if let privateKey = keychain.getPrivateKey() {
            await refreshFromPrivateKey(privateKey)
        } else {
            resetState()
        }

        if hasWallet {
            startPriceUpdates()
        }
    }

    @MainActor
    func deleteWallet() {
        stopPriceUpdates()
        keychain.deleteSeedPhrase()
        keychain.deletePrivateKey()
        for wallet in multiChainWallets {
            if let identifier = wallet.seedPhraseId { keychain.deleteSeedPhrase(identifier: identifier) }
            if let identifier = wallet.privateKeyId { keychain.deletePrivateKey(identifier: identifier) }
        }
        multiChainWallets = []
        activeWallet = nil
        saveWallets()
        resetState()
        savedAddresses = []
        saveSavedAddresses()
    }

    func generateMnemonic() -> String? {
        try? mnemonicService.generateMnemonic()
    }

    func validateMnemonic(_ mnemonic: String) -> Bool {
        mnemonicService.isValidMnemonic(mnemonic)
    }

    func validatePrivateKey(_ privateKey: String) -> Bool {
        (try? mnemonicService.normalizePrivateKey(privateKey)) != nil
    }

    func depositAddress(for token: Token) -> String {
        // Return address only if a wallet (seed/private key) truly exists and onboarding completed
        guard hasWallet && (keychain.hasSeedPhrase() || keychain.hasPrivateKey()) else { return "" }
        return chainAccounts[token.blockchain]?.address ?? ""
    }

    func hasActiveAccount(for blockchain: BlockchainType) -> Bool {
        guard hasWallet && (keychain.hasSeedPhrase() || keychain.hasPrivateKey()) else { return false }
        guard let address = chainAccounts[blockchain]?.address else { return false }
        return !address.isEmpty
    }

    // MARK: - Saved Addresses
    func addSavedAddress(name: String, address: String) {
        let savedAddress = SavedAddress(name: name, address: address)
        savedAddresses.append(savedAddress)
        saveSavedAddresses()
    }

    func removeSavedAddress(_ address: SavedAddress) {
        savedAddresses.removeAll { $0.id == address.id }
        saveSavedAddresses()
    }

    // MARK: - Blockchain Management
    func toggleBlockchain(_ platform: BlockchainPlatform) {
        if selectedBlockchains.contains(platform) {
            selectedBlockchains.remove(platform)
        } else {
            selectedBlockchains.insert(platform)
        }
        saveSelectedBlockchains()  // NEW: Save to UserDefaults
        // Don't refresh all data - just filter displayed tokens
        // Actual blockchain data will be fetched lazily when needed
        Task { await refreshNewBlockchainData(for: platform) }
    }

    func enableBlockchains(_ platforms: Set<BlockchainPlatform>) {
        selectedBlockchains = platforms
        saveSelectedBlockchains()  // NEW: Save to UserDefaults
        // Refresh only newly added blockchains
        Task { await refreshWalletData() }
    }
    
    // MARK: - Refresh specific blockchain data
    @MainActor
    private func refreshNewBlockchainData(for platform: BlockchainPlatform) async {
        // If blockchain was just enabled, fetch its data
        guard selectedBlockchains.contains(platform) else { return }
        
        // Check if we already have data for this blockchain
        let hasDataForBlockchain = tokens.contains(where: { 
            guard let blockchainType = platform.blockchainType else { return false }
            return $0.blockchain == blockchainType 
        })
        
        if hasDataForBlockchain {
            Logger.log("✅ Already have data for \(platform.name)")
            return
        }
        
        // Fetch data for new blockchain
        Logger.log("🔄 Fetching data for newly enabled blockchain: \(platform.name)")
        await refreshWalletData()
    }

    private func getPrimaryBlockchain(for symbol: String) -> BlockchainType {
        switch symbol.uppercased() {
        case "ETH":
            return .ethereum
        case "BTC":
            return .bitcoin
        case "MATIC":
            return .polygon
        case "BNB":
            return .bsc
        case "AVAX":
            return .avalanche
        default:
            return .ethereum // Default to Ethereum for unknown tokens
        }
    }
    
    // MARK: - Icon Helper
    private func getDefaultIconUrl(for symbol: String) -> String? {
        switch symbol.uppercased() {
        case "BTC":
            return "https://assets.coingecko.com/coins/images/1/large/bitcoin.png"
        case "ETH":
            return "https://assets.coingecko.com/coins/images/279/large/ethereum.png"
        case "WETH":
            return "https://assets.coingecko.com/coins/images/2518/large/weth.png"
        case "USDT":
            return "https://assets.coingecko.com/coins/images/325/large/Tether.png"
        case "USDC":
            return "https://assets.coingecko.com/coins/images/6319/large/USD_Coin_icon.png"
        case "BNB":
            return "https://assets.coingecko.com/coins/images/825/large/bnb-icon2_2x.png"
        case "MATIC":
            return "https://assets.coingecko.com/coins/images/4713/large/matic-token-icon.png"
        case "AVAX":
            return "https://assets.coingecko.com/coins/images/12559/large/Avalanche_Circle_RedWhite_Trans.png"
        case "SOL":
            return "https://assets.coingecko.com/coins/images/4128/large/solana.png"
        default:
            return nil
        }
    }

    // MARK: - Private Helpers
    @MainActor
    private func refreshFromMnemonic(_ mnemonic: String) async {
        do {
            Logger.log("🔄 refreshFromMnemonic started")
            let wallet = try mnemonicService.loadWallet(from: mnemonic)

            // Get account index for the active wallet
            let accountIndex = activeWallet.map { getAccountIndex(for: $0) } ?? 0
            Logger.log("📊 Account index: \(accountIndex)")
            // Signing services (TransactionService, SwapService, BitcoinService)
            // read this so they spend from the same account we show balances for.
            UserDefaults.standard.set(accountIndex, forKey: "ActiveAccountIndex")

            let accounts = deriveAccounts(using: wallet, accountIndex: accountIndex)
            chainAccounts = accounts
            if let activeId = activeWallet?.id,
               let index = multiChainWallets.firstIndex(where: { $0.id == activeId }) {
                multiChainWallets[index].accounts = walletAccounts(from: accounts, accountIndex: accountIndex)
                activeWallet = multiChainWallets[index]
                saveWallets()
            }
            Logger.log("⛓️ Derived accounts for \(accounts.count) blockchains")

            // Only fetch balances for the selected blockchain platforms
            let selectedPlatformAccounts = accounts.values.filter { account in
                selectedBlockchains.contains(account.config.platform) && account.config.network == .mainnet
            }
            Logger.log("✅ Selected \(selectedPlatformAccounts.count) platform accounts from \(selectedBlockchains.count) selected blockchains")

            let requests = selectedPlatformAccounts.map { NativeBalanceRequest(config: $0.config, tokenType: $0.tokenType, address: $0.address) }
            Logger.log("📡 Fetching native assets for \(requests.count) requests...")
            var fetchedTokens = await apiService.getNativeAssets(for: requests)
            Logger.log("💰 Fetched \(fetchedTokens.count) native tokens")

            // Known-token calls are independent across networks. Run them in
            // parallel instead of waiting for every chain one after another.
            let evmAccounts = selectedPlatformAccounts.filter { $0.tokenType.isEVM }
            let knownTokens = await withTaskGroup(of: [Token].self) { group in
                for account in evmAccounts {
                    group.addTask { [weak self] in
                        guard let self else { return [] }
                        return await self.loadKnownERC20Tokens(
                            for: account.address,
                            config: account.config
                        )
                    }
                }
                var result: [Token] = []
                for await batch in group { result.append(contentsOf: batch) }
                return result
            }
            fetchedTokens.append(contentsOf: knownTokens)

            Logger.log("🎯 Total tokens before updateState: \(fetchedTokens.count)")
            let defaultAddress = accounts[.ethereum]?.address ?? accounts.values.first?.address

            await updateState(with: fetchedTokens, accounts: selectedPlatformAccounts, defaultAddress: defaultAddress)
            Logger.log("✅ refreshFromMnemonic completed")
        } catch {
            Logger.log("❌ Failed to refresh wallet data: \(error.localizedDescription)")
            // A temporary RPC/API problem must not blank a wallet that was
            // already restored from its last known good snapshot.
            hasWallet = keychain.hasSeedPhrase() || keychain.hasPrivateKey()
        }
    }

    @MainActor
    private func refreshFromPrivateKey(_ privateKey: String) async {
        do {
            let normalizedKey = try mnemonicService.normalizePrivateKey(privateKey)
            let primaryAddress = try mnemonicService.deriveEthereumAddress(fromPrivateKey: normalizedKey)

            let evmAccounts = availableBlockchains
                .filter { $0.isEnabled }
                .compactMap { config -> ChainAccount? in
                    guard let tokenType = config.blockchainType else { return nil }
                    guard tokenType.isEVM else { return nil }
                    let account = ChainAccount(
                        config: config,
                        tokenType: tokenType,
                        coinType: config.coinType,
                        address: primaryAddress
                    )
                    return account
                }

            chainAccounts = Dictionary(uniqueKeysWithValues: evmAccounts.map { ($0.tokenType, $0) })
            if let activeId = activeWallet?.id,
               let index = multiChainWallets.firstIndex(where: { $0.id == activeId }),
               let privateKeyId = multiChainWallets[index].privateKeyId {
                multiChainWallets[index].accounts = walletAccounts(
                    forEVMAddress: primaryAddress,
                    privateKeyId: privateKeyId
                )
                activeWallet = multiChainWallets[index]
                saveWallets()
            }

            let requests = evmAccounts.map { NativeBalanceRequest(config: $0.config, tokenType: $0.tokenType, address: $0.address) }
            let fetchedTokens = await apiService.getNativeAssets(for: requests)

            await updateState(with: fetchedTokens, accounts: evmAccounts, defaultAddress: primaryAddress)
        } catch {
            Logger.log("Failed to refresh legacy wallet: \(error.localizedDescription)")
            hasWallet = keychain.hasSeedPhrase() || keychain.hasPrivateKey()
        }
    }

    @MainActor
    private func loadKnownERC20Tokens(for address: String, config: BlockchainConfig) async -> [Token] {
        Logger.log("🔍 Loading known ERC-20 tokens for \(config.platform.name): \(address)")

        let knownTokens = knownERC20Tokens(for: config.platform)
        guard !knownTokens.isEmpty else {
            Logger.log("ℹ️ No known ERC-20 allowlist for \(config.platform.name)")
            return []
        }

        let tokens = await withTaskGroup(of: Token?.self) { group in
            for tokenInfo in knownTokens {
                group.addTask { [apiService] in
                    do {
                        return try await apiService.getERC20TokenBalance(
                            address: address,
                            contractAddress: tokenInfo.contractAddress,
                            config: config,
                            name: tokenInfo.name,
                            symbol: tokenInfo.symbol,
                            decimals: tokenInfo.decimals
                        )
                    } catch { return nil }
                }
            }
            var result: [Token] = []
            for await token in group {
                if let token { result.append(token) }
            }
            return result
        }

        Logger.log("📦 Loaded \(tokens.count) known ERC-20 tokens")
        return tokens
    }

    private func knownERC20Tokens(for platform: BlockchainPlatform) -> [(symbol: String, name: String, contractAddress: String, decimals: Int)] {
        switch platform {
        case .ethereum:
            return [
                ("USDT", "Tether USD", "0xdac17f958d2ee523a2206206994597c13d831ec7", 6),
                ("USDC", "USD Coin", "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48", 6),
                ("WETH", "Wrapped Ether", "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2", 18),
                ("WBTC", "Wrapped Bitcoin", "0x2260fac5e5542a773aa44fbcfedf7c193bc2c599", 8)
            ]
        case .arbitrum:
            return [
                ("USDT", "Tether USD", "0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9", 6),
                ("USDC", "USD Coin", "0xaf88d065e77c8cc2239327c5edb3a432268e5831", 6),
                ("WETH", "Wrapped Ether", "0x82af49447d8a07e3bd95bd0d56f35241523fbab1", 18),
                ("WBTC", "Wrapped Bitcoin", "0x2f2a2543b76a4166549f7aab2e75bef0aefc5b0f", 8)
            ]
        case .optimism:
            return [
                ("USDT", "Tether USD", "0x94b008aa00579c1307b0ef2c499ad98a8ce58e58", 6),
                ("USDC", "USD Coin", "0x0b2c639c533813f4aa9d7837caf62653d097ff85", 6),
                ("WETH", "Wrapped Ether", "0x4200000000000000000000000000000000000006", 18),
                ("WBTC", "Wrapped Bitcoin", "0x68f180fcce6836688e9084f035309e29bf0a2095", 8)
            ]
        case .base:
            return [
                ("USDT", "Tether USD", "0xfde4c96c8593536e31f229ea8f37b2ada2699bb2", 6),
                ("USDC", "USD Coin", "0x833589fcd6edb6e08f4c7c32d4f71b54bda02913", 6),
                ("WETH", "Wrapped Ether", "0x4200000000000000000000000000000000000006", 18),
                ("cbBTC", "Coinbase Wrapped BTC", "0xcbb7c0000ab88b473b1f5afd9ef808440eed33bf", 8)
            ]
        case .polygon:
            return [
                ("USDT", "Tether USD", "0xc2132d05d31c914a87c6611c10748aeb04b58e8f", 6),
                ("USDC", "USD Coin", "0x3c499c542cef5e3811e1192ce70d8cc03d5c3359", 6),
                ("WETH", "Wrapped Ether", "0x7ceb23fd6bc0add59e62ac25578270cff1b9f619", 18),
                ("WBTC", "Wrapped Bitcoin", "0x1bfd67037b42cf73acf2047067bd4f2c47d9bfd6", 8)
            ]
        case .bsc:
            return [
                ("USDT", "Tether USD", "0x55d398326f99059ff775485246999027b3197955", 18),
                ("USDC", "USD Coin", "0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d", 18),
                ("BTCB", "Bitcoin BEP20", "0x7130d2a12b9bcbfae4f2634d864a1ee1ce3ead9c", 18)
            ]
        case .avalanche:
            return [
                ("USDT", "Tether USD", "0x9702230a8ea53601f5cd2dc00fdbc13d4df4a8c7", 6),
                ("USDC", "USD Coin", "0xb97ef9ef8734c71904d8002f8b6bc66dd9c48a6e", 6),
                ("WETH", "Wrapped Ether", "0x49d5c2bdffac6ce2bfdb6640f4f80f226bc10bab", 18),
                ("BTC.b", "Bitcoin (Avalanche)", "0x152b9d0fdc40c096757f570a51e494bd4b943e50", 8)
            ]
        default:
            return []
        }
    }

    @MainActor
    private func updateState(with tokens: [Token], accounts: [ChainAccount], defaultAddress: String?) async {
        Logger.log("📊 updateState called with \(tokens.count) tokens")

        // Instead of replacing all tokens, merge new tokens with existing ones
        var existingTokensMap = Dictionary(uniqueKeysWithValues: self.tokens.map { 
            ($0.blockchain.rawValue + ($0.contractAddress ?? "native"), $0) 
        })
        
        // Update or add new tokens (preserve iconUrl if new token doesn't have one)
        for token in tokens {
            let key = token.blockchain.rawValue + (token.contractAddress ?? "native")
            
            if let existingToken = existingTokensMap[key] {
                let cachedPrice = cachedPrice(for: token.symbol)
                let resolvedPrice = isMeaningfulPrice(token.price, for: token.symbol)
                    ? token.price
                    : (isMeaningfulPrice(existingToken.price, for: token.symbol) ? existingToken.price : cachedPrice ?? token.price)
                let resolvedIconUrl = token.iconUrl ?? existingToken.iconUrl ?? cachedIconUrl(for: token.symbol)

                existingTokensMap[key] = Token(
                    contractAddress: token.contractAddress,
                    name: token.name,
                    symbol: token.symbol,
                    decimals: token.decimals,
                    balance: token.balance,
                    price: resolvedPrice,
                    iconUrl: resolvedIconUrl,
                    blockchain: token.blockchain,
                    isNative: token.isNative,
                    receivingAddress: token.receivingAddress
                )
            } else {
                let cachedPrice = cachedPrice(for: token.symbol)
                existingTokensMap[key] = Token(
                    contractAddress: token.contractAddress,
                    name: token.name,
                    symbol: token.symbol,
                    decimals: token.decimals,
                    balance: token.balance,
                    price: isMeaningfulPrice(token.price, for: token.symbol) ? token.price : cachedPrice ?? token.price,
                    iconUrl: token.iconUrl ?? cachedIconUrl(for: token.symbol),
                    blockchain: token.blockchain,
                    isNative: token.isNative,
                    receivingAddress: token.receivingAddress
                )
            }
        }

        // Add custom tokens that aren't already in the list
        for customToken in savedCustomTokens {
            let key = customToken.blockchain.rawValue + (customToken.contractAddress ?? "native")
            if existingTokensMap[key] == nil {
                existingTokensMap[key] = customToken
            }
        }

        self.tokens = Array(existingTokensMap.values)
        saveCachedPrices(from: self.tokens)
        Logger.log("📊 Total tokens after merging: \(self.tokens.count)")

        // Debug: print all tokens and their values
        for token in self.tokens {
            Logger.log("  💎 \(token.symbol): balance=\(token.balance), price=$\(token.price), totalValue=$\(token.totalValue)")
        }

        // Resolve address first - use visible tokens only
        let resolvedAddress = defaultAddress ?? self.visibleTokens.first?.receivingAddress ?? walletAddress
        self.walletAddress = resolvedAddress
        cacheHoldings(self.tokens, for: resolvedAddress)
        Logger.log("📍 Wallet address: \(resolvedAddress)")

        if transactions.isEmpty {
            let cached = cachedTransactions(for: resolvedAddress)
            if !cached.isEmpty {
                transactions = cached
                Logger.log("📚 Restored \(cached.count) cached transactions")
            }
        }

        // Calculate new balance from visible tokens only (respecting selectedBlockchains)
        let newBalance = self.visibleTokens.reduce(0) { $0 + $1.totalValue }
        Logger.log("💰 New balance calculated: $\(newBalance) (from \(self.visibleTokens.count) visible tokens)")

        self.balance = newBalance
        updateActiveWalletPortfolioValue(newBalance)
        self.hasWallet = keychain.hasSeedPhrase() || keychain.hasPrivateKey()

        // Load real NFTs from configured providers or the public Blockscout
        // fallback. NFT loading stays independent from fungible balances.
        let nftBlockchains = Array(Set(accounts.compactMap { $0.config.blockchainType }))
            .filter(\.isEVM)
        self.isLoadingNFTs = true
        Task {
            do {
                let fetchedNFTs = try await APIService.shared.fetchNFTs(
                    for: resolvedAddress,
                    blockchains: nftBlockchains
                )
                await MainActor.run {
                    self.nfts = fetchedNFTs
                    self.isLoadingNFTs = false
                    Logger.log("✅ Loaded \(fetchedNFTs.count) NFTs for wallet")
                }
            } catch {
                Logger.log("Failed to load NFTs: \(error)")
                await MainActor.run {
                    // Don't show fake data - just empty array if fetch fails
                    self.nfts = []
                    self.isLoadingNFTs = false
                    Logger.log("❌ NFT fetch failed, showing empty list")
                }
            }
        }

        guard !resolvedAddress.isEmpty else {
            transactions = []
            return
        }

        let configs = accounts.map { $0.config }
        if configs.isEmpty {
            transactions = []
            return
        }

        // Explorer indexing is slower than balance RPCs and is not required to
        // enable Send/Swap/Bridge. Cached Activity is already visible, so let
        // the live history refresh finish outside the critical refresh path.
        Task { [weak self] in
            guard let self else { return }
            do {
                let fetchedTransactions = try await self.apiService.getTransactions(
                    for: resolvedAddress,
                    using: configs
                )
                await MainActor.run {
                    self.notifyForNewTransactions(fetchedTransactions, walletAddress: resolvedAddress)
                    let merged = self.mergingLocalTransactions(into: fetchedTransactions)
                    self.transactions = merged
                    self.cacheTransactions(merged, for: resolvedAddress)
                }
            } catch let apiError as APIError {
                Logger.log("Transaction fetch error: \(apiError.localizedDescription)")
            } catch {
                Logger.log("Transaction fetch unexpected error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Locally Submitted Transactions

    /// Register a just-broadcast transaction so Activity shows it immediately,
    /// before any explorer indexes it.
    @MainActor
    func registerLocalTransaction(_ transaction: Transaction) {
        guard !transactions.contains(where: {
            $0.hash.caseInsensitiveCompare(transaction.hash) == .orderedSame
        }) else { return }

        transactions.insert(transaction, at: 0)
        cacheTransactions(transactions, for: walletAddress)

        if transaction.status == .pending, transaction.resolvedBlockchain.isEVM {
            Task { [weak self] in
                await self?.watchLocalTransaction(hash: transaction.hash,
                                                  blockchain: transaction.resolvedBlockchain)
            }
        }
    }

    /// Reflect a broadcast send immediately instead of briefly showing the
    /// pre-transaction RPC balance. The next confirmed/failed refresh replaces
    /// this projection with authoritative chain data.
    @MainActor
    func applyOptimisticSend(token: Token, tokenDebit: Double, nativeGasDebit: Double) {
        func identityMatches(_ candidate: Token, _ target: Token) -> Bool {
            candidate.blockchain == target.blockchain &&
            (candidate.contractAddress ?? "native").lowercased() ==
                (target.contractAddress ?? "native").lowercased()
        }

        tokens = tokens.map { current in
            var debit = 0.0
            if identityMatches(current, token) {
                debit += tokenDebit
            }
            if current.blockchain == token.blockchain, current.isNative {
                debit += nativeGasDebit
            }
            guard debit > 0 else { return current }

            return Token(
                contractAddress: current.contractAddress,
                name: current.name,
                symbol: current.symbol,
                decimals: current.decimals,
                balance: max(0, current.balance - debit),
                price: current.price,
                iconUrl: current.iconUrl,
                blockchain: current.blockchain,
                isNative: current.isNative,
                id: current.id,
                receivingAddress: current.receivingAddress,
                tokenProtocol: current.tokenProtocol
            )
        }
        balance = visibleTokens.reduce(0) { $0 + $1.totalValue }
        updateActiveWalletPortfolioValue(balance)
    }

    private func watchLocalTransaction(hash: String, blockchain: BlockchainType) async {
        let deadline = Date().addingTimeInterval(15 * 60)
        while Date() < deadline, !Task.isCancelled {
            if let state = try? await SwapService.shared.fetchTransactionState(
                hash: hash,
                blockchain: blockchain
            ) {
                switch state {
                case .notFound, .pending:
                    break
                case .confirmed(let blockNumber, let gasUsed, let gasFeeNative):
                    updateLocalTransactionStatus(hash: hash, status: .confirmed,
                                                 gasUsed: gasUsed, gasFee: gasFeeNative,
                                                 blockNumber: blockNumber)
                    await refreshWalletData()
                    return
                case .failed(let blockNumber, let gasUsed, let gasFeeNative):
                    updateLocalTransactionStatus(hash: hash, status: .failed,
                                                 gasUsed: gasUsed, gasFee: gasFeeNative,
                                                 blockNumber: blockNumber)
                    await refreshWalletData()
                    return
                }
            }
            try? await Task.sleep(nanoseconds: 5_000_000_000)
        }
    }

    /// Update a locally tracked transaction once its on-chain receipt is known.
    /// `newHash`/`newAmount`/`newExplorerUrl` replace placeholder values used
    /// while a bridge destination transaction is still unknown.
    @MainActor
    func updateLocalTransactionStatus(
        hash: String,
        status: Transaction.TransactionStatus,
        gasUsed: Double? = nil,
        gasFee: Double? = nil,
        blockNumber: String? = nil,
        newHash: String? = nil,
        newAmount: Double? = nil,
        newExplorerUrl: URL? = nil
    ) {
        guard let index = transactions.firstIndex(where: {
            $0.hash.caseInsensitiveCompare(hash) == .orderedSame
        }) else { return }

        let old = transactions[index]
        transactions[index] = Transaction(
            hash: newHash ?? old.hash,
            from: old.from,
            to: old.to,
            amount: newAmount ?? old.amount,
            token: old.token,
            type: old.type,
            status: status,
            timestamp: old.timestamp,
            gasUsed: gasUsed ?? old.gasUsed,
            gasFee: gasFee ?? old.gasFee,
            blockNumber: blockNumber ?? old.blockNumber,
            explorerUrl: newExplorerUrl ?? old.explorerUrl,
            blockchain: old.blockchain,
            id: old.id
        )
        cacheTransactions(transactions, for: walletAddress)
    }

    /// Explorers index with a delay — keep recent locally submitted
    /// transactions the fetch doesn't know about yet instead of dropping
    /// them. Confirmed local entries are kept for good: bridge arrivals are
    /// internal transactions the explorer `txlist` fetch never returns.
    /// When the explorer does index a hash we know, its richer data wins but
    /// our more specific type (swap/bridge) is kept.
    private func mergingLocalTransactions(into fetched: [Transaction]) -> [Transaction] {
        var localTypes: [String: Transaction.TransactionType] = [:]
        for tx in transactions where tx.type == .swap || tx.type == .bridge || tx.type == .bridgeReceive {
            localTypes[tx.hash.lowercased()] = tx.type
        }
        let relabeled = fetched.map { tx -> Transaction in
            guard let localType = localTypes[tx.hash.lowercased()], localType != tx.type else { return tx }
            return Transaction(
                hash: tx.hash,
                from: tx.from,
                to: tx.to,
                amount: tx.amount,
                token: tx.token,
                type: localType,
                status: tx.status,
                timestamp: tx.timestamp,
                gasUsed: tx.gasUsed,
                gasFee: tx.gasFee,
                blockNumber: tx.blockNumber,
                explorerUrl: tx.explorerUrl,
                blockchain: tx.blockchain,
                id: tx.id
            )
        }

        let fetchedHashes = Set(relabeled.map { $0.hash.lowercased() })
        let cutoff = Date().addingTimeInterval(-48 * 3600)
        let localOnly = transactions.filter {
            !fetchedHashes.contains($0.hash.lowercased()) &&
            ($0.timestamp > cutoff || $0.status == .confirmed)
        }
        guard !localOnly.isEmpty else { return relabeled }
        return (localOnly + relabeled).sorted { $0.timestamp > $1.timestamp }
    }

    private func cachedTransactions(for walletAddress: String) -> [Transaction] {
        guard !walletAddress.isEmpty,
              let data = UserDefaults.standard.data(
                forKey: "\(cachedTransactionsPrefix)_\(walletAddress.lowercased())"
              ),
              let cached = try? JSONDecoder().decode([Transaction].self, from: data) else {
            return []
        }

        return cached.sorted { $0.timestamp > $1.timestamp }
    }

    private func cacheTransactions(_ transactions: [Transaction], for walletAddress: String) {
        guard !walletAddress.isEmpty,
              let data = try? JSONEncoder().encode(transactions) else {
            return
        }

        UserDefaults.standard.set(
            data,
            forKey: "\(cachedTransactionsPrefix)_\(walletAddress.lowercased())"
        )
    }

    /// Last known good holdings are deliberately account-scoped. They provide
    /// an immediate, stable wallet UI while fresh RPC values load, and are only
    /// replaced after a successful refresh.
    private func cachedHoldings(for walletAddress: String) -> [Token] {
        guard !walletAddress.isEmpty,
              let data = UserDefaults.standard.data(
                forKey: "\(cachedHoldingsPrefix)_\(walletAddress.lowercased())"
              ),
              let cached = try? JSONDecoder().decode([Token].self, from: data) else {
            return []
        }
        return cached
    }

    private func cacheHoldings(_ tokens: [Token], for walletAddress: String) {
        guard !walletAddress.isEmpty, !tokens.isEmpty,
              let data = try? JSONEncoder().encode(tokens) else { return }
        UserDefaults.standard.set(
            data,
            forKey: "\(cachedHoldingsPrefix)_\(walletAddress.lowercased())"
        )
    }

    private func notifyForNewTransactions(_ fetchedTransactions: [Transaction], walletAddress: String) {
        guard UserDefaults.standard.bool(forKey: "NotificationsEnabled") else { return }

        let key = "\(seenTransactionsPrefix)_\(walletAddress)"
        let existing = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
        let fetchedHashes = Set(fetchedTransactions.map { $0.hash })

        guard !existing.isEmpty else {
            UserDefaults.standard.set(Array(fetchedHashes), forKey: key)
            return
        }

        let newTransactions = fetchedTransactions.filter { !existing.contains($0.hash) }
        guard !newTransactions.isEmpty else { return }

        for transaction in newTransactions.prefix(3) {
            let content = UNMutableNotificationContent()
            content.title = "Transaction Update".localized
            content.body = "%@ %@ %@".localized(transaction.type.displayName, String(format: "%.4f", transaction.amount), transaction.token)
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "tx_\(transaction.hash)",
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request)
        }

        UserDefaults.standard.set(Array(existing.union(fetchedHashes)), forKey: key)
    }

    private func deriveAccounts(using wallet: HDWallet, accountIndex: Int = 0) -> [BlockchainType: ChainAccount] {
        var result: [BlockchainType: ChainAccount] = [:]

        // Derive mainnet accounts for supported chains; Manage Networks controls visibility/fetching.
        for config in availableBlockchains where config.network == .mainnet {
            guard let tokenType = config.blockchainType else { continue }
            guard tokenType.isEVM || tokenType == .bitcoin || tokenType == .solana else { continue }
            let coinType = config.coinType
            let address: String

            if let coinType {
                address = mnemonicService.address(for: coinType, wallet: wallet, accountIndex: accountIndex)
            } else {
                // Fallback to Ethereum address for unknown coin types
                address = mnemonicService.address(for: .ethereum, wallet: wallet, accountIndex: accountIndex)
            }

            let account = ChainAccount(config: config, tokenType: tokenType, coinType: coinType, address: address)
            result[tokenType] = account
        }

        return result
    }

    private func persistSeedPhrase(_ mnemonic: String) -> Bool {
        ensureActiveCredentialBackedUp()

        let credentialId = "seed-\(UUID().uuidString)"
        guard keychain.storeSeedPhrase(mnemonic, identifier: credentialId),
              keychain.storeSeedPhrase(mnemonic),
              let hdWallet = try? mnemonicService.loadWallet(from: mnemonic) else { return false }
        keychain.deletePrivateKey()

        let accountIndex = 0
        let derived = deriveAccounts(using: hdWallet, accountIndex: accountIndex)
        var wallet = MultiChainWallet(
            name: multiChainWallets.isEmpty ? "Main Wallet" : nextWalletName(prefix: "Wallet"),
            type: .seed,
            seedPhraseId: credentialId
        )
        wallet.accounts = walletAccounts(from: derived, accountIndex: accountIndex)
        chainAccounts = derived
        addWallet(wallet)
        hasWallet = true
        isInitializing = false
        return true
    }

    private func nextWalletName(prefix: String) -> String {
        let existingNames = Set(multiChainWallets.map(\.name))
        var index = 1
        var candidate = prefix == "Wallet" ? "Wallet \(multiChainWallets.count + 1)" : prefix
        while existingNames.contains(candidate) {
            index += 1
            candidate = "\(prefix) \(index)"
        }
        return candidate
    }

    private func walletAccounts(
        from accounts: [BlockchainType: ChainAccount],
        accountIndex: Int
    ) -> [WalletAccount] {
        accounts.values.compactMap { account in
            guard let coinType = account.coinType else { return nil }
            return WalletAccount(
                blockchainConfig: account.config,
                address: account.address,
                derivationPath: mnemonicService.derivationPath(for: coinType, accountIndex: accountIndex)
            )
        }
    }

    private func walletAccounts(forEVMAddress address: String, privateKeyId: String) -> [WalletAccount] {
        availableBlockchains.compactMap { config in
            guard config.network == .mainnet,
                  config.blockchainType?.isEVM == true else { return nil }
            return WalletAccount(
                blockchainConfig: config,
                address: address,
                privateKeyId: privateKeyId
            )
        }
    }

    private func ensureActiveCredentialBackedUp() {
        guard let wallet = activeWallet else { return }
        if let identifier = wallet.seedPhraseId,
           keychain.getSeedPhrase(identifier: identifier) == nil,
           let seed = keychain.getSeedPhrase() {
            _ = keychain.storeSeedPhrase(seed, identifier: identifier)
        }
        if let identifier = wallet.privateKeyId,
           keychain.getPrivateKey(identifier: identifier) == nil,
           let privateKey = keychain.getPrivateKey() {
            _ = keychain.storePrivateKey(privateKey, identifier: identifier)
        }
    }

    @discardableResult
    private func activateCredential(for wallet: MultiChainWallet) -> Bool {
        if let identifier = wallet.seedPhraseId,
           let seed = keychain.getSeedPhrase(identifier: identifier) ??
                (identifier == "main-seed" ? keychain.getSeedPhrase() : nil) {
            guard keychain.storeSeedPhrase(seed) else { return false }
            keychain.deletePrivateKey()
            return true
        }
        if let identifier = wallet.privateKeyId,
           let privateKey = keychain.getPrivateKey(identifier: identifier) ??
                (identifier == "main-private" ? keychain.getPrivateKey() : nil) {
            guard keychain.storePrivateKey(privateKey) else { return false }
            keychain.deleteSeedPhrase()
            return true
        }
        return false
    }

    @MainActor
    private func resetState() {
        hasWallet = false
        walletAddress = ""
        balance = 0
        tokens = []
        nfts = []
        transactions = []
        chainAccounts = [:]
    }

    private func saveSavedAddresses() {
        if let data = try? JSONEncoder().encode(savedAddresses) {
            UserDefaults.standard.set(data, forKey: "SavedAddresses")
        }
    }

    private func loadSavedAddresses() {
        guard let data = UserDefaults.standard.data(forKey: "SavedAddresses"),
              let addresses = try? JSONDecoder().decode([SavedAddress].self, from: data) else {
            savedAddresses = []
            return
        }
        savedAddresses = addresses
    }

    private func setupDefaultBlockchains() {
        if let data = UserDefaults.standard.data(forKey: blockchainsStorageKey),
           let stored = try? JSONDecoder().decode([BlockchainConfig].self, from: data) {
            availableBlockchains = stored
            return
        }

        availableBlockchains = BlockchainConfig.defaultConfigs

        if let data = try? JSONEncoder().encode(availableBlockchains) {
            UserDefaults.standard.set(data, forKey: blockchainsStorageKey)
        }
    }

    private func loadWallets() {
        if let data = UserDefaults.standard.data(forKey: walletsStorageKey),
           let stored = try? JSONDecoder().decode([MultiChainWallet].self, from: data) {
            multiChainWallets = stored
        } else {
            multiChainWallets = []
        }

        // Migration: unify legacy "main_seed" identifier with the canonical "main-seed"
        // (a mismatch here made new accounts reuse account index 0).
        var needsSave = false
        for i in 0..<multiChainWallets.count where multiChainWallets[i].seedPhraseId == "main_seed" {
            multiChainWallets[i].seedPhraseId = "main-seed"
            needsSave = true
        }
        for i in 0..<multiChainWallets.count
        where multiChainWallets[i].type == .imported && multiChainWallets[i].privateKeyId == nil {
            multiChainWallets[i].privateKeyId = "main-private"
            needsSave = true
        }
        if needsSave {
            saveWallets()
        }

        // Preserve the original single-wallet credential before any newly
        // created/imported wallet becomes the active legacy signing slot.
        if let legacySeed = keychain.getSeedPhrase(),
           let seedId = multiChainWallets.first(where: { $0.seedPhraseId != nil })?.seedPhraseId,
           keychain.getSeedPhrase(identifier: seedId) == nil {
            _ = keychain.storeSeedPhrase(legacySeed, identifier: seedId)
        }
        if let legacyKey = keychain.getPrivateKey(),
           let keyId = multiChainWallets.first(where: { $0.type == .imported })?.privateKeyId,
           keychain.getPrivateKey(identifier: keyId) == nil {
            _ = keychain.storePrivateKey(legacyKey, identifier: keyId)
        }

        // IMPORTANT: Migrate old keychain wallet to new multi-wallet system
        // If we have a seed phrase/private key in keychain but no wallets in the new system,
        // create a "Main Wallet" entry automatically
        if multiChainWallets.isEmpty && (keychain.hasSeedPhrase() || keychain.hasPrivateKey()) {
            Logger.log("🔄 Migrating old keychain wallet to multi-wallet system...")

            // We'll create the wallet placeholder - actual accounts will be loaded during refreshWalletData
            let walletType: WalletType = keychain.hasSeedPhrase() ? .seed : .imported
            var mainWallet = MultiChainWallet(
                name: "Main Wallet",
                type: walletType,
                seedPhraseId: keychain.hasSeedPhrase() ? "main-seed" : nil,
                privateKeyId: keychain.hasPrivateKey() ? "main-private" : nil
            )
            mainWallet.isActive = true
            multiChainWallets.append(mainWallet)
            if let seed = keychain.getSeedPhrase() {
                _ = keychain.storeSeedPhrase(seed, identifier: "main-seed")
            }
            if let privateKey = keychain.getPrivateKey() {
                _ = keychain.storePrivateKey(privateKey, identifier: "main-private")
            }
            saveWallets()
            Logger.log("✅ Main Wallet created and set as active")
        }

        // Ensure only ONE wallet is active
        let activeWallets = multiChainWallets.filter { $0.isActive }
        if activeWallets.count > 1 {
            Logger.log("⚠️ Found multiple active wallets! Fixing...")
            // Deactivate all
            for i in 0..<multiChainWallets.count {
                multiChainWallets[i].isActive = false
            }
            // Activate only the first one
            if !multiChainWallets.isEmpty {
                multiChainWallets[0].isActive = true
            }
            saveWallets()
            Logger.log("✅ Fixed: Only one wallet is now active")
        }

        activeWallet = multiChainWallets.first(where: { $0.isActive }) ?? multiChainWallets.first
        if let activeWallet {
            _ = activateCredential(for: activeWallet)
            UserDefaults.standard.set(getAccountIndex(for: activeWallet), forKey: "ActiveAccountIndex")
        }
        hasWallet = !multiChainWallets.isEmpty && (keychain.hasSeedPhrase() || keychain.hasPrivateKey())

        // Set wallet address from active wallet if available
        if (keychain.hasSeedPhrase() || keychain.hasPrivateKey()),
           let active = activeWallet, let firstAccount = active.accounts.first {
            walletAddress = firstAccount.address
        } else {
            walletAddress = ""
        }
    }

    // MARK: - Transaction Generation
    // Transaction generation (disabled placeholder)
    private func generateRealisticTransactions(for tokens: [Token], walletAddress: String) -> [Transaction] { /* disabled */
        guard !tokens.isEmpty && !walletAddress.isEmpty else { return [] }

        var transactions: [Transaction] = [] /* disabled */
        let currentTime = Date()

        // Generate transactions for each token the user has
        for token in tokens {
            let walletAddressForToken = token.receivingAddress ?? walletAddress

            // Generate some receive transactions (how the user got these tokens)
            if token.balance > 0 {
                // Initial receive transaction
                let receiveAmount = min(token.balance * 0.6, token.balance)
                if receiveAmount > 0 {
                    transactions.append(Transaction(
                        hash: generateTransactionHash(),
                        from: generateRandomAddress(),
                        to: walletAddressForToken,
                        amount: receiveAmount,
                        token: token.symbol,
                        type: .receive,
                        status: .confirmed,
                        timestamp: currentTime.addingTimeInterval(-Double.random(in: 3600...86400 * 7)),
                        gasUsed: Double.random(in: 21000...50000),
                        gasFee: Double.random(in: 0.001...0.01)
                    ))
                }

                // Possible additional deposit
                if Double.random(in: 0...1) > 0.6 {
                    let depositAmount = token.balance - receiveAmount
                    if depositAmount > 0 {
                        transactions.append(Transaction(
                            hash: generateTransactionHash(),
                            from: generateRandomAddress(),
                            to: walletAddressForToken,
                            amount: depositAmount,
                            token: token.symbol,
                            type: .deposit,
                            status: .confirmed,
                            timestamp: currentTime.addingTimeInterval(-Double.random(in: 1800...43200)),
                            gasUsed: Double.random(in: 21000...35000),
                            gasFee: Double.random(in: 0.001...0.005)
                        ))
                    }
                }

                // Possible send transaction (partial amount)
                if Double.random(in: 0...1) > 0.7 && token.balance > 0.1 {
                    transactions.append(Transaction(
                        hash: generateTransactionHash(),
                        from: walletAddressForToken,
                        to: generateRandomAddress(),
                        amount: min(token.balance * 0.2, 0.5),
                        token: token.symbol,
                        type: .send,
                        status: .confirmed,
                        timestamp: currentTime.addingTimeInterval(-Double.random(in: 900...7200)),
                        gasUsed: Double.random(in: 21000...45000),
                        gasFee: Double.random(in: 0.002...0.008)
                    ))
                }
            }
        }

        // Add some swap transactions between available tokens
        if tokens.count > 1 {
            let tokenPairs = Array(tokens.prefix(3))
            for i in 0..<min(2, tokenPairs.count - 1) {
                let fromToken = tokenPairs[i]
                let toToken = tokenPairs[i + 1]
                let maxSwapAmount = min(fromToken.balance * 0.3, 1.0)

                guard maxSwapAmount >= 0.01 else { continue }

                transactions.append(Transaction(
                    hash: generateTransactionHash(),
                    from: fromToken.receivingAddress ?? walletAddress,
                    to: toToken.receivingAddress ?? walletAddress,
                    amount: Double.random(in: 0.01...maxSwapAmount),
                    token: "\(fromToken.symbol) → \(toToken.symbol)",
                    type: .swap,
                    status: Bool.random() ? .confirmed : .pending,
                    timestamp: currentTime.addingTimeInterval(-Double.random(in: 300...3600)),
                    gasUsed: Double.random(in: 80000...150000),
                    gasFee: Double.random(in: 0.008...0.02)
                ))
            }
        }

        // Add one recent pending transaction
        if let firstToken = tokens.first {
            let pendingAddress = firstToken.receivingAddress ?? walletAddress
            transactions.append(Transaction(
                hash: generateTransactionHash(),
                from: generateRandomAddress(),
                to: pendingAddress,
                amount: Double.random(in: 0.001...0.1),
                token: firstToken.symbol,
                type: .receive,
                status: .pending,
                timestamp: currentTime.addingTimeInterval(-Double.random(in: 60...300)),
                gasUsed: Double.random(in: 21000...35000),
                gasFee: Double.random(in: 0.001...0.005)
            ))
        }

        return [] // Intentionally empty until real history implemented
    }

    private func generateTransactionHash() -> String {
        let chars = "0123456789abcdef"
        return "0x" + String((0..<64).map { _ in chars.randomElement()! })
    }

    private func generateRandomAddress() -> String {
        let chars = "0123456789abcdef"
        return "0x" + String((0..<40).map { _ in chars.randomElement()! })
    }

    // MARK: - Onboarding Methods

    private func checkOnboardingStatus() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        isInitializing = false
    }

    // MARK: - Multi-Wallet Management

    func setActiveWallet(_ wallet: MultiChainWallet) {
        // Deactivate current wallet
        for i in 0..<multiChainWallets.count {
            multiChainWallets[i].isActive = false
        }

        // Activate selected wallet
        if let index = multiChainWallets.firstIndex(where: { $0.id == wallet.id }) {
            multiChainWallets[index].isActive = true
            activeWallet = multiChainWallets[index]

            guard activateCredential(for: multiChainWallets[index]) else {
                Logger.log("❌ Unable to activate wallet credential")
                return
            }

            let accountIndex = getAccountIndex(for: multiChainWallets[index])
            UserDefaults.standard.set(accountIndex, forKey: "ActiveAccountIndex")

            // Immediately update wallet address from the first account
            if let firstAccount = multiChainWallets[index].accounts.first {
                walletAddress = firstAccount.address
            }

            // Clear old wallet data immediately
            tokens = []
            transactions = []
            nfts = []
            balance = 0.0

            // Save to UserDefaults
            saveWallets()

            // Refresh wallet data for the new active wallet (loads balances, transactions, etc.)
            Task {
                await refreshWalletData()
            }
        }
    }

    func addWallet(_ wallet: MultiChainWallet) {
        // Deactivate all existing wallets
        for i in 0..<multiChainWallets.count {
            multiChainWallets[i].isActive = false
        }

        // Add and activate new wallet
        var newWallet = wallet
        newWallet.isActive = true
        multiChainWallets.append(newWallet)
        activeWallet = newWallet

        _ = activateCredential(for: newWallet)
        UserDefaults.standard.set(getAccountIndex(for: newWallet), forKey: "ActiveAccountIndex")

        saveWallets()

        // Refresh wallet data for the new active wallet
        Task {
            await refreshWalletData()
        }
    }

    func removeWallet(_ wallet: MultiChainWallet) {
        if let identifier = wallet.seedPhraseId,
           !multiChainWallets.contains(where: { $0.id != wallet.id && $0.seedPhraseId == identifier }) {
            keychain.deleteSeedPhrase(identifier: identifier)
        }
        if let identifier = wallet.privateKeyId {
            keychain.deletePrivateKey(identifier: identifier)
        }
        multiChainWallets.removeAll { $0.id == wallet.id }

        // If this was the active wallet, set another as active
        if wallet.id == activeWallet?.id {
            activeWallet = multiChainWallets.first
            if let newActive = activeWallet {
                if let index = multiChainWallets.firstIndex(where: { $0.id == newActive.id }) {
                    multiChainWallets[index].isActive = true
                }
                _ = activateCredential(for: newActive)
                UserDefaults.standard.set(getAccountIndex(for: newActive), forKey: "ActiveAccountIndex")
            }
        } else if let current = activeWallet {
            _ = activateCredential(for: current)
        }

        saveWallets()

        // Refresh if we changed the active wallet
        if activeWallet != nil {
            Task {
                await refreshWalletData()
            }
        }
    }

    /// Add a custom token to the wallet
    func addCustomToken(_ token: Token) {
        let identity = tokenIdentityKey(for: token)

        // Adding a previously removed contract makes it visible again.
        hiddenTokenIdentities.remove(identity)
        saveHiddenTokenIdentities()

        if savedCustomTokens.contains(where: { tokenIdentityKey(for: $0) == identity }) {
            Logger.log("⚠️ Token already exists: \(token.symbol)")
            return
        }

        savedCustomTokens.append(token)

        if let existingIndex = tokens.firstIndex(where: { tokenIdentityKey(for: $0) == identity }) {
            tokens[existingIndex] = token
        } else {
            tokens.append(token)
        }

        saveCustomTokens()

        // Notify user
        NotificationManager.shared.notifyTokenAdded(name: token.name)

        Logger.log("✅ Custom token added: \(token.name) (\(token.symbol))")
    }

    /// Remove a custom token from the wallet
    func removeCustomToken(_ token: Token) {
        removeTokenFromAssets(token)
    }

    /// Permanently hide a non-native token from Your Assets. This only changes
    /// the local portfolio list; funds and contracts on-chain are untouched.
    func removeTokenFromAssets(_ token: Token) {
        guard !token.isNative else { return }
        let identity = tokenIdentityKey(for: token)
        hiddenTokenIdentities.insert(identity)
        tokens.removeAll { tokenIdentityKey(for: $0) == identity }
        savedCustomTokens.removeAll { tokenIdentityKey(for: $0) == identity }
        saveCustomTokens()
        saveHiddenTokenIdentities()
        Logger.log("🗑️ Token removed from Your Assets: \(token.symbol) on \(token.blockchain.name)")
    }

    /// Your Assets groups equal symbols across chains, so removing a grouped
    /// card hides every non-native network variant represented by that card.
    func removeTokenSymbolFromAssets(_ token: Token) {
        guard !token.isNative else { return }
        let symbol = token.symbol.uppercased()
        let matchingTokens = mergedSupportedTokens(with: tokens).filter {
            !$0.isNative && $0.symbol.uppercased() == symbol
        }
        for matchingToken in matchingTokens {
            hiddenTokenIdentities.insert(tokenIdentityKey(for: matchingToken))
        }
        tokens.removeAll { !$0.isNative && $0.symbol.uppercased() == symbol }
        savedCustomTokens.removeAll { !$0.isNative && $0.symbol.uppercased() == symbol }
        saveCustomTokens()
        saveHiddenTokenIdentities()
        Logger.log("🗑️ Token removed from Your Assets on all networks: \(token.symbol)")
    }

    func canRemoveFromAssets(_ token: Token) -> Bool {
        !token.isNative
    }

    private func saveCustomTokens() {
        if let data = try? JSONEncoder().encode(savedCustomTokens) {
            UserDefaults.standard.set(data, forKey: "CustomTokens")
            Logger.log("💾 Saved \(savedCustomTokens.count) custom tokens")
        }
    }

    private func loadCustomTokens() {
        // Load custom tokens from UserDefaults
        guard let data = UserDefaults.standard.data(forKey: "CustomTokens"),
              let customTokens = try? JSONDecoder().decode([Token].self, from: data) else {
            Logger.log("📭 No custom tokens to load")
            savedCustomTokens = []
            return
        }

        savedCustomTokens = customTokens
        Logger.log("📦 Loaded \(customTokens.count) custom tokens from storage")
    }

    private func loadHiddenTokenIdentities() {
        guard let data = UserDefaults.standard.data(forKey: hiddenTokenIdentitiesKey),
              let identities = try? JSONDecoder().decode(Set<String>.self, from: data) else {
            hiddenTokenIdentities = []
            return
        }
        hiddenTokenIdentities = identities
    }

    private func saveHiddenTokenIdentities() {
        guard let data = try? JSONEncoder().encode(hiddenTokenIdentities) else { return }
        UserDefaults.standard.set(data, forKey: hiddenTokenIdentitiesKey)
    }

    private func loadNFTVisibilityPreferences() {
        if let hidden = UserDefaults.standard.stringArray(forKey: hiddenNFTIdentitiesKey) {
            manuallyHiddenNFTIdentities = Set(hidden)
        }
        if let trusted = UserDefaults.standard.stringArray(forKey: trustedNFTIdentitiesKey) {
            trustedNFTIdentities = Set(trusted)
        }
    }

    private func saveNFTVisibilityPreferences() {
        UserDefaults.standard.set(Array(manuallyHiddenNFTIdentities), forKey: hiddenNFTIdentitiesKey)
        UserDefaults.standard.set(Array(trustedNFTIdentities), forKey: trustedNFTIdentitiesKey)
    }

    private struct CachedTokenPrice: Codable {
        let price: Double
        let iconUrl: String?
    }

    private func cachedPrice(for symbol: String) -> Double? {
        loadCachedPrices()[symbol.uppercased()]?.price
    }

    private func cachedIconUrl(for symbol: String) -> String? {
        loadCachedPrices()[symbol.uppercased()]?.iconUrl
    }

    private func loadCachedPrices() -> [String: CachedTokenPrice] {
        guard let data = UserDefaults.standard.data(forKey: cachedTokenPricesKey),
              let cached = try? JSONDecoder().decode([String: CachedTokenPrice].self, from: data) else {
            return [:]
        }
        return cached
    }

    private func saveCachedPrices(from tokens: [Token]) {
        var cached = loadCachedPrices()
        for token in tokens where isMeaningfulPrice(token.price, for: token.symbol) {
            let key = token.symbol.uppercased()
            cached[key] = CachedTokenPrice(price: token.price, iconUrl: token.iconUrl ?? cached[key]?.iconUrl)
        }

        if let data = try? JSONEncoder().encode(cached) {
            UserDefaults.standard.set(data, forKey: cachedTokenPricesKey)
        }
    }

    // MARK: - Multi-Account Management (MetaMask style)

    /// Create a new account from the same seed phrase with next account index
    func createNewAccount(name: String? = nil) async -> Bool {
        guard let sourceWallet = activeWallet,
              sourceWallet.type == .seed,
              let sourceSeedId = sourceWallet.seedPhraseId,
              let seedPhrase = keychain.getSeedPhrase(identifier: sourceSeedId) ?? keychain.getSeedPhrase() else {
            Logger.log("❌ No seed phrase available")
            return false
        }

        guard let hdWallet = try? mnemonicService.loadWallet(from: seedPhrase) else {
            Logger.log("❌ Failed to load wallet from seed phrase")
            return false
        }

        // Find the highest account index from existing seed wallets
        let seedWallets = multiChainWallets.filter { $0.type == .seed && $0.seedPhraseId == sourceSeedId }
        let nextAccountIndex = seedWallets.count
        UserDefaults.standard.set(nextAccountIndex, forKey: "ActiveAccountIndex")

        // Derive addresses for all supported mainnet blockchains with the new account index.
        var chainAccounts: [BlockchainType: ChainAccount] = [:]

        for config in availableBlockchains where config.network == .mainnet {
            guard let tokenType = config.blockchainType else { continue }
            guard tokenType.isEVM || tokenType == .bitcoin || tokenType == .solana else { continue }
            guard let coinType = config.coinType else { continue }

            let address = mnemonicService.address(for: coinType, wallet: hdWallet, accountIndex: nextAccountIndex)
            let account = ChainAccount(config: config, tokenType: tokenType, coinType: coinType, address: address)
            chainAccounts[tokenType] = account
        }

        // Get primary address (Ethereum)
        guard chainAccounts[.ethereum]?.address != nil else {
            Logger.log("❌ Failed to derive Ethereum address")
            return false
        }

        // Create wallet name
        let walletName = name ?? "Account \(nextAccountIndex + 1)"

        // Create new wallet
        var newWallet = MultiChainWallet(name: walletName, type: .seed, seedPhraseId: sourceSeedId)

        // Convert chainAccounts to WalletAccount array and populate newWallet.accounts
        newWallet.accounts = chainAccounts.compactMap { (blockchainType, chainAccount) in
            guard let coinType = chainAccount.coinType else { return nil }
            let derivationPath = mnemonicService.derivationPath(for: coinType, accountIndex: nextAccountIndex)
            return WalletAccount(
                blockchainConfig: chainAccount.config,
                address: chainAccount.address,
                derivationPath: derivationPath,
                privateKeyId: nil  // Derived from seed, no separate private key
            )
        }

        // Deactivate all existing wallets
        for i in 0..<multiChainWallets.count {
            multiChainWallets[i].isActive = false
        }

        // Add and activate new wallet
        newWallet.isActive = true
        multiChainWallets.append(newWallet)
        activeWallet = newWallet

        // Store the chain accounts for this wallet
        self.chainAccounts = chainAccounts

        saveWallets()

        // Refresh wallet data
        await refreshWalletData()

        return true
    }

    /// Get account index for a seed wallet (counts how many seed wallets come before it)
    func getAccountIndex(for wallet: MultiChainWallet) -> Int {
        guard wallet.type == .seed else { return 0 }
        let seedWallets = multiChainWallets.filter { $0.type == .seed && $0.seedPhraseId == wallet.seedPhraseId }
        return seedWallets.firstIndex(where: { $0.id == wallet.id }) ?? 0
    }

    private func saveWallets() {
        if let data = try? JSONEncoder().encode(multiChainWallets) {
            UserDefaults.standard.set(data, forKey: walletsStorageKey)
        }
    }

    func portfolioValue(for wallet: MultiChainWallet) -> Double {
        wallet.id == activeWallet?.id ? balance : (wallet.portfolioValueUSD ?? 0)
    }

    /// Refresh selector totals from each wallet's persisted public addresses.
    /// This never changes the active signing credential or the visible wallet.
    func refreshWalletPortfolioValues() async {
        for wallet in multiChainWallets where wallet.id != activeWallet?.id {
            let accounts = wallet.accounts.compactMap { account -> ChainAccount? in
                let config = account.blockchainConfig
                guard config.network == .mainnet,
                      config.isEnabled,
                      selectedBlockchains.contains(config.platform),
                      let blockchain = config.blockchainType else { return nil }
                return ChainAccount(
                    config: config,
                    tokenType: blockchain,
                    coinType: config.coinType,
                    address: account.address
                )
            }

            guard !accounts.isEmpty else { continue }
            let requests = accounts.map {
                NativeBalanceRequest(config: $0.config, tokenType: $0.tokenType, address: $0.address)
            }
            var walletTokens = await apiService.getNativeAssets(for: requests)

            for account in accounts where account.tokenType.isEVM {
                walletTokens.append(contentsOf: await loadKnownERC20Tokens(
                    for: account.address,
                    config: account.config
                ))
            }

            let value = walletTokens.reduce(0) { $0 + $1.totalValue }
            if let index = multiChainWallets.firstIndex(where: { $0.id == wallet.id }) {
                multiChainWallets[index].portfolioValueUSD = value
                saveWallets()
            }
        }
    }

    private func updateActiveWalletPortfolioValue(_ value: Double) {
        guard let activeId = activeWallet?.id,
              let index = multiChainWallets.firstIndex(where: { $0.id == activeId }) else { return }
        multiChainWallets[index].portfolioValueUSD = value
        activeWallet = multiChainWallets[index]
        saveWallets()
    }

    // MARK: - Favorite Tokens

    /// Toggle favorite status for a token symbol
    func toggleFavorite(for tokenSymbol: String) {
        if favoriteTokenSymbols.contains(tokenSymbol) {
            favoriteTokenSymbols.remove(tokenSymbol)
            Logger.log("🌟 Removed \(tokenSymbol) from favorites")
        } else {
            favoriteTokenSymbols.insert(tokenSymbol)
            Logger.log("⭐️ Added \(tokenSymbol) to favorites")
        }
        saveFavorites()
    }

    /// Check if a token is favorite
    func isFavorite(_ tokenSymbol: String) -> Bool {
        return favoriteTokenSymbols.contains(tokenSymbol)
    }

    /// Load favorites from UserDefaults
    func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: favoritesStorageKey),
           let favorites = try? JSONDecoder().decode(Set<String>.self, from: data) {
            favoriteTokenSymbols = favorites
            Logger.log("📚 Loaded \(favorites.count) favorite tokens")
        }
    }

    /// Save favorites to UserDefaults
    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(favoriteTokenSymbols) {
            UserDefaults.standard.set(data, forKey: favoritesStorageKey)
        }
    }
    
    // MARK: - Selected Blockchains Persistence
    
    /// Load selected blockchains from UserDefaults
    private func loadSelectedBlockchains() {
        if let data = UserDefaults.standard.data(forKey: selectedBlockchainsKey),
           let blockchains = try? JSONDecoder().decode(Set<BlockchainPlatform>.self, from: data) {
            selectedBlockchains = blockchains
            Logger.log("🌐 Loaded \(blockchains.count) selected blockchains: \(blockchains.map { $0.rawValue }.joined(separator: ", "))")
        } else {
            // Default to Ethereum if nothing saved
            selectedBlockchains = [.ethereum]
            Logger.log("🌐 No saved blockchains, defaulting to Ethereum")
        }
    }
    
    /// Save selected blockchains to UserDefaults
    private func saveSelectedBlockchains() {
        if let data = try? JSONEncoder().encode(selectedBlockchains) {
            UserDefaults.standard.set(data, forKey: selectedBlockchainsKey)
            Logger.log("💾 Saved \(selectedBlockchains.count) selected blockchains")
        }
    }

    // MARK: - Real-time Price Updates

    /// Start automatic price updates
    func startPriceUpdates() {
        stopPriceUpdates() // Stop existing timer if any

        priceUpdateTimer = Timer.scheduledTimer(withTimeInterval: priceUpdateInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Logger.log("🔄 Auto-refreshing prices...")
            Task {
                await self.refreshPricesOnly()
            }
        }

        // First refresh right away so 24h changes appear without waiting a full interval
        Task {
            await refreshPricesOnly()
        }

        Logger.log("✅ Price auto-refresh started (every \(Int(priceUpdateInterval))s)")
    }

    /// Stop automatic price updates
    func stopPriceUpdates() {
        priceUpdateTimer?.invalidate()
        priceUpdateTimer = nil
        Logger.log("⏸️ Price auto-refresh stopped")
    }

    /// Refresh only prices, not balances (lighter operation)
    @MainActor
    private func refreshPricesOnly() async {
        guard !tokens.isEmpty else { return }

        let coinIds = Array(Set(tokens.map { APIService.getCoinId(for: $0.symbol) }))
        Logger.log("📊 Updating prices/logos for \(coinIds.count) assets...")

        do {
            let lookup = try await apiService.fetchPricesAndLogos(for: coinIds)
            tokens = tokens.map { token in
                let coinId = APIService.getCoinId(for: token.symbol)
                guard let priceInfo = lookup[coinId] else { return token }

                return Token(
                    contractAddress: token.contractAddress,
                    name: token.name,
                    symbol: token.symbol,
                    decimals: token.decimals,
                    balance: token.balance,
                    price: priceInfo.price,
                    iconUrl: token.iconUrl ?? priceInfo.imageUrl,
                    blockchain: token.blockchain,
                    isNative: token.isNative,
                    receivingAddress: token.receivingAddress
                )
            }
            saveCachedPrices(from: tokens)

            var changes: [String: Double] = [:]
            for token in tokens {
                let coinId = APIService.getCoinId(for: token.symbol)
                if let change = lookup[coinId]?.priceChange24h {
                    changes[token.symbol.uppercased()] = change
                }
            }
            priceChanges24h = changes
            lastPriceUpdate = Date()

            balance = visibleTokens.reduce(0) { $0 + $1.totalValue }
            updateActiveWalletPortfolioValue(balance)
            Logger.log("✅ Price/logo refresh completed")
        } catch {
            Logger.log("❌ Price/logo refresh failed: \(error.localizedDescription)")
        }
    }

    deinit {
        stopPriceUpdates()
    }

}
