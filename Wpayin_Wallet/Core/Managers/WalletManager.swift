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
    @Published var transactions: [Transaction] = []
    @Published var balance: Double = 0.0
    @Published var previousBalance: Double = 0.0
    @Published var balanceChangePercentage: Double = 0.0
    @Published var selectedBlockchains: Set<BlockchainPlatform> = [.ethereum]
    @Published var favoriteTokenSymbols: Set<String> = []

    let keychain = KeychainManager()
    private let apiService = APIService.shared
    private let mnemonicService = MnemonicService()

    private let walletsStorageKey = "MultiChainWallets"
    private let blockchainsStorageKey = "AvailableBlockchainConfigs"
    private let favoritesStorageKey = "FavoriteTokens"
    private let selectedBlockchainsKey = "SelectedBlockchains"  // NEW: Persistence key

    private var chainAccounts: [BlockchainType: ChainAccount] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var priceUpdateTimer: Timer?
    private let priceUpdateInterval: TimeInterval = 30 // Update prices every 30 seconds
    private var savedCustomTokens: [Token] = []

    // Public access to chain accounts for deposit address generation
    var availableChainAccounts: [BlockchainType: ChainAccount] {
        return chainAccounts
    }

    // Computed property to group tokens by symbol and combine balances
    var groupedTokens: [Token] {
        let grouped = Dictionary(grouping: tokens, by: { $0.symbol })
        return grouped.compactMap { symbol, tokens in
            guard let firstToken = tokens.first else { return nil }

            let totalBalance = tokens.reduce(0) { $0 + $1.balance }

            // For ETH and other cross-chain tokens, use the same price across all networks
            let unifiedPrice: Double
            if symbol == "ETH" {
                // All Ethereum-based networks should have the same ETH price
                unifiedPrice = tokens.first?.price ?? 0
            } else {
                // For other tokens, calculate average price
                let totalValue = tokens.reduce(0) { $0 + $1.totalValue }
                unifiedPrice = totalBalance > 0 ? totalValue / totalBalance : tokens.first?.price ?? 0
            }

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

    // Available blockchains for the selected platforms
    var availableBlockchainsForPlatforms: [BlockchainConfig] {
        availableBlockchains.filter { config in
            selectedBlockchains.contains(config.platform) && config.isEnabled && config.network == .mainnet
        }
    }
    
    // Filtered tokens - only show tokens from selected blockchains
    var visibleTokens: [Token] {
        tokens.filter { token in
            guard let platform = BlockchainPlatform(rawValue: token.blockchain.rawValue) else {
                return false
            }
            return selectedBlockchains.contains(platform)
        }
    }
    
    // Filtered grouped tokens - only show from selected blockchains
    var visibleGroupedTokens: [Token] {
        groupedTokens.filter { token in
            guard let platform = BlockchainPlatform(rawValue: token.blockchain.rawValue) else {
                return false
            }
            return selectedBlockchains.contains(platform)
        }
    }

    init() {
        setupDefaultBlockchains()
        loadWallets()
        loadSavedAddresses()
        loadFavorites()
        loadCustomTokens()
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
        await MainActor.run {
            isInitializing = true
        }

        hasWallet = keychain.hasSeedPhrase() || keychain.hasPrivateKey()

        if hasWallet {
            await refreshWalletData()
        }

        await MainActor.run {
            isInitializing = false
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
            let success = keychain.storePrivateKey(normalized)
            if success {
                hasWallet = true
                Task {
                    await refreshWalletData()
                    await MainActor.run {
                        isInitializing = false
                    }
                }
            }
            return success
        } catch {
            print("Import wallet error: \(error.localizedDescription)")
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
    }

    @MainActor
    func deleteWallet() {
        keychain.deleteSeedPhrase()
        keychain.deletePrivateKey()
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
        token.receivingAddress ?? chainAccounts[token.blockchain]?.address ?? walletAddress
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
            print("✅ Already have data for \(platform.name)")
            return
        }
        
        // Fetch data for new blockchain
        print("🔄 Fetching data for newly enabled blockchain: \(platform.name)")
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
            print("🔄 refreshFromMnemonic started")
            let wallet = try mnemonicService.loadWallet(from: mnemonic)

            // Get account index for the active wallet
            let accountIndex = activeWallet.map { getAccountIndex(for: $0) } ?? 0
            print("📊 Account index: \(accountIndex)")

            let accounts = deriveAccounts(using: wallet, accountIndex: accountIndex)
            chainAccounts = accounts
            print("⛓️ Derived accounts for \(accounts.count) blockchains")

            // Only fetch balances for the selected blockchain platforms
            let selectedPlatformAccounts = accounts.values.filter { account in
                selectedBlockchains.contains(account.config.platform) && account.config.network == .mainnet
            }
            print("✅ Selected \(selectedPlatformAccounts.count) platform accounts from \(selectedBlockchains.count) selected blockchains")

            let requests = selectedPlatformAccounts.map { NativeBalanceRequest(config: $0.config, tokenType: $0.tokenType, address: $0.address) }
            print("📡 Fetching native assets for \(requests.count) requests...")
            var fetchedTokens = await apiService.getNativeAssets(for: requests)
            print("💰 Fetched \(fetchedTokens.count) native tokens")

            // Load Bitcoin balance if selected
            if let btcAccount = accounts[.bitcoin], selectedBlockchains.contains(.bitcoin) {
                print("🪙 Bitcoin account found, loading BTC balance...")
                do {
                    let btcBalanceResult = try await BitcoinService.shared.fetchBalance(address: btcAccount.address)
                    let btcBalance = BitcoinService.shared.satoshisToBTC(btcBalanceResult.confirmed)
                    
                    // Try to get BTC price and icon from API
                    let existingBtcToken = fetchedTokens.first(where: { $0.symbol == "BTC" })
                    let btcPrice = existingBtcToken?.price ?? 0
                    let btcIconUrl = existingBtcToken?.iconUrl ?? getDefaultIconUrl(for: "BTC")
                    
                    let btcToken = Token(
                        contractAddress: nil,
                        name: "Bitcoin",
                        symbol: "BTC",
                        decimals: 8,
                        balance: NSDecimalNumber(decimal: btcBalance).doubleValue,
                        price: btcPrice,
                        iconUrl: btcIconUrl,
                        blockchain: .bitcoin,
                        isNative: true,
                        receivingAddress: btcAccount.address
                    )
                    fetchedTokens.append(btcToken)
                    print("✅ Bitcoin balance loaded: \(btcBalance) BTC")
                } catch {
                    print("❌ Failed to load Bitcoin balance: \(error)")
                }
            }

            // Load basic ERC-20 tokens (USDT, USDC, WETH)
            if let ethAccount = accounts[.ethereum] {
                print("🔍 Ethereum account found, loading ERC-20 tokens...")
                let ethConfig = ethAccount.config
                let knownTokens = await loadKnownERC20Tokens(for: ethAccount.address, config: ethConfig)
                print("📦 Loaded \(knownTokens.count) ERC-20 tokens")
                fetchedTokens.append(contentsOf: knownTokens)
            } else {
                print("⚠️ No Ethereum account found in accounts")
            }

            print("🎯 Total tokens before updateState: \(fetchedTokens.count)")
            let defaultAddress = accounts[.ethereum]?.address ?? accounts.values.first?.address

            await updateState(with: fetchedTokens, accounts: selectedPlatformAccounts, defaultAddress: defaultAddress)
            print("✅ refreshFromMnemonic completed")
        } catch {
            print("❌ Failed to refresh wallet data: \(error.localizedDescription)")
            resetState()
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

            let requests = evmAccounts.map { NativeBalanceRequest(config: $0.config, tokenType: $0.tokenType, address: $0.address) }
            let fetchedTokens = await apiService.getNativeAssets(for: requests)

            await updateState(with: fetchedTokens, accounts: evmAccounts, defaultAddress: primaryAddress)
        } catch {
            print("Failed to refresh legacy wallet: \(error.localizedDescription)")
            resetState()
        }
    }

    @MainActor
    private func loadKnownERC20Tokens(for address: String, config: BlockchainConfig) async -> [Token] {
        print("🔍 Loading base ERC-20 tokens for address: \(address)")

        // Known Ethereum mainnet token contract addresses
        let knownTokens: [(symbol: String, name: String, contractAddress: String, decimals: Int)] = [
            ("USDT", "Tether USD", "0xdac17f958d2ee523a2206206994597c13d831ec7", 6),
            ("USDC", "USD Coin", "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48", 6),
            ("WETH", "Wrapped Ether", "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2", 18)
        ]

        var tokens: [Token] = []

        for tokenInfo in knownTokens {
            print("🔎 Checking balance for \(tokenInfo.symbol) at \(tokenInfo.contractAddress)")
            do {
                let token = try await apiService.getERC20TokenBalance(
                    address: address,
                    contractAddress: tokenInfo.contractAddress,
                    config: config,
                    name: tokenInfo.name,
                    symbol: tokenInfo.symbol,
                    decimals: tokenInfo.decimals
                )
                if let token = token {
                    print("✅ \(tokenInfo.symbol): balance=\(token.balance), price=$\(token.price), totalValue=$\(token.totalValue)")
                    // Always add the token, even with 0 balance, so users can see it
                    tokens.append(token)
                } else {
                    print("⚠️ API returned nil for \(tokenInfo.symbol)")
                }
            } catch {
                print("❌ Error getting balance for \(tokenInfo.symbol): \(error)")
            }
        }

        print("📦 Loaded \(tokens.count) base tokens (USDT, USDC, WETH)")
        return tokens
    }

    @MainActor
    private func updateState(with tokens: [Token], accounts: [ChainAccount], defaultAddress: String?) async {
        print("📊 updateState called with \(tokens.count) tokens")

        // Instead of replacing all tokens, merge new tokens with existing ones
        var existingTokensMap = Dictionary(uniqueKeysWithValues: self.tokens.map { 
            ($0.blockchain.rawValue + ($0.contractAddress ?? "native"), $0) 
        })
        
        // Update or add new tokens (preserve iconUrl if new token doesn't have one)
        for token in tokens {
            let key = token.blockchain.rawValue + (token.contractAddress ?? "native")
            
            // If updating existing token and new token has no icon, preserve old icon
            if let existingToken = existingTokensMap[key],
               token.iconUrl == nil,
               let existingIconUrl = existingToken.iconUrl {
                
                // Create new token with preserved iconUrl
                let updatedToken = Token(
                    contractAddress: token.contractAddress,
                    name: token.name,
                    symbol: token.symbol,
                    decimals: token.decimals,
                    balance: token.balance,
                    price: token.price,
                    iconUrl: existingIconUrl,  // Preserve existing icon
                    blockchain: token.blockchain,
                    isNative: token.isNative,
                    receivingAddress: token.receivingAddress
                )
                existingTokensMap[key] = updatedToken
            } else {
                // Use new token as-is (has icon or is completely new)
                existingTokensMap[key] = token
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
        print("📊 Total tokens after merging: \(self.tokens.count)")

        // Debug: print all tokens and their values
        for token in self.tokens {
            print("  💎 \(token.symbol): balance=\(token.balance), price=$\(token.price), totalValue=$\(token.totalValue)")
        }

        // Resolve address first - use visible tokens only
        let resolvedAddress = defaultAddress ?? self.visibleTokens.first?.receivingAddress ?? walletAddress
        self.walletAddress = resolvedAddress
        print("📍 Wallet address: \(resolvedAddress)")

        // Calculate new balance from visible tokens only (respecting selectedBlockchains)
        let newBalance = self.visibleTokens.reduce(0) { $0 + $1.totalValue }
        print("💰 New balance calculated: $\(newBalance) (from \(self.visibleTokens.count) visible tokens)")

        // Load previous balance from UserDefaults only once (on first load)
        let savedPreviousBalance = UserDefaults.standard.double(forKey: "previousBalance_\(resolvedAddress)")
        print("📖 Saved previous balance from UserDefaults: $\(savedPreviousBalance)")
        print("🧠 In-memory previous balance: $\(previousBalance)")

        // If we don't have previousBalance in memory yet, load from UserDefaults or set new baseline
        if previousBalance == 0.0 {
            if savedPreviousBalance > 0 {
                // Use saved previous balance from UserDefaults
                previousBalance = savedPreviousBalance
                print("✅ Loaded previous balance from UserDefaults: $\(savedPreviousBalance)")
            } else {
                // No saved balance - this is truly the first time, set baseline
                previousBalance = newBalance
                print("🆕 Setting new baseline: $\(newBalance)")
                // Only save if newBalance > 0 to avoid saving 0 as baseline
                if newBalance > 0 {
                    UserDefaults.standard.set(newBalance, forKey: "previousBalance_\(resolvedAddress)")
                    print("💾 Saved baseline to UserDefaults")
                }
            }
        }
        // Otherwise keep the in-memory previousBalance (don't reload from UserDefaults)

        // Calculate percentage change
        if previousBalance > 0 && newBalance != previousBalance {
            balanceChangePercentage = ((newBalance - previousBalance) / previousBalance) * 100
            print("📈 Balance change: \(balanceChangePercentage)% (from $\(previousBalance) to $\(newBalance))")
        } else {
            balanceChangePercentage = 0 // No change
            print("➖ No balance change (previous: $\(previousBalance), new: $\(newBalance))")
        }

        // Update current balance (but keep previousBalance unchanged for comparison)
        self.balance = newBalance
        self.hasWallet = !self.tokens.isEmpty || keychain.hasSeedPhrase() || keychain.hasPrivateKey()

        // Load real NFTs from API
        Task {
            do {
                let fetchedNFTs = try await APIService.shared.fetchNFTs(for: resolvedAddress)
                await MainActor.run {
                    self.nfts = fetchedNFTs
                    print("✅ Loaded \(fetchedNFTs.count) NFTs for wallet")
                }
            } catch {
                print("Failed to load NFTs: \(error)")
                await MainActor.run {
                    // Don't show fake data - just empty array if fetch fails
                    self.nfts = []
                    print("❌ NFT fetch failed, showing empty list")
                }
            }
        }

        guard !resolvedAddress.isEmpty else {
            transactions = []
            return
        }

        let configs = accounts.map { $0.config }
        if configs.isEmpty {
            transactions = tokens.isEmpty ? [] : generateRealisticTransactions(for: tokens, walletAddress: resolvedAddress)
            return
        }

        do {
            let fetchedTransactions = try await apiService.getTransactions(for: resolvedAddress, using: configs)
            transactions = fetchedTransactions
        } catch let apiError as APIError {
            print("Transaction fetch error: \(apiError.localizedDescription)")
            switch apiError {
            case .missingAPIKeys:
                transactions = []
            default:
                transactions = tokens.isEmpty ? [] : generateRealisticTransactions(for: tokens, walletAddress: resolvedAddress)
            }
        } catch {
            print("Transaction fetch unexpected error: \(error.localizedDescription)")
            transactions = tokens.isEmpty ? [] : generateRealisticTransactions(for: tokens, walletAddress: resolvedAddress)
        }
    }

    private func deriveAccounts(using wallet: HDWallet, accountIndex: Int = 0) -> [BlockchainType: ChainAccount] {
        var result: [BlockchainType: ChainAccount] = [:]

        // Derive accounts for all networks but prioritize selected network
        for config in availableBlockchains where config.isEnabled {
            guard let tokenType = config.blockchainType else { continue }
            guard tokenType.isEVM || tokenType == .bitcoin else { continue }
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
        let success = keychain.storeSeedPhrase(mnemonic)
        if success {
            keychain.deletePrivateKey()
            hasWallet = true
            Task {
                await refreshWalletData()
                await MainActor.run {
                    isInitializing = false
                }
            }
        }
        return success
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

        // IMPORTANT: Migrate old keychain wallet to new multi-wallet system
        // If we have a seed phrase/private key in keychain but no wallets in the new system,
        // create a "Main Wallet" entry automatically
        if multiChainWallets.isEmpty && (keychain.hasSeedPhrase() || keychain.hasPrivateKey()) {
            print("🔄 Migrating old keychain wallet to multi-wallet system...")

            // We'll create the wallet placeholder - actual accounts will be loaded during refreshWalletData
            let walletType: WalletType = keychain.hasSeedPhrase() ? .seed : .imported
            var mainWallet = MultiChainWallet(
                name: "Main Wallet",
                type: walletType,
                seedPhraseId: keychain.hasSeedPhrase() ? "main_seed" : nil
            )
            mainWallet.isActive = true
            multiChainWallets.append(mainWallet)
            saveWallets()
            print("✅ Main Wallet created and set as active")
        }

        // Ensure only ONE wallet is active
        let activeWallets = multiChainWallets.filter { $0.isActive }
        if activeWallets.count > 1 {
            print("⚠️ Found multiple active wallets! Fixing...")
            // Deactivate all
            for i in 0..<multiChainWallets.count {
                multiChainWallets[i].isActive = false
            }
            // Activate only the first one
            if !multiChainWallets.isEmpty {
                multiChainWallets[0].isActive = true
            }
            saveWallets()
            print("✅ Fixed: Only one wallet is now active")
        }

        activeWallet = multiChainWallets.first(where: { $0.isActive }) ?? multiChainWallets.first
        hasWallet = keychain.hasSeedPhrase() || keychain.hasPrivateKey() || activeWallet != nil

        // Set wallet address from active wallet if available
        if let active = activeWallet, let firstAccount = active.accounts.first {
            walletAddress = firstAccount.address
        }
    }

    // MARK: - Transaction Generation
    private func generateRealisticTransactions(for tokens: [Token], walletAddress: String) -> [Transaction] {
        guard !tokens.isEmpty && !walletAddress.isEmpty else { return [] }

        var transactions: [Transaction] = []
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

        return transactions.sorted { $0.timestamp > $1.timestamp }
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

    // MARK: - Balance Change Tracking

    /// Reset the baseline balance to current balance (sets percentage to 0%)
    func resetBalanceBaseline() {
        previousBalance = balance
        balanceChangePercentage = 0.0
        // Save new baseline to UserDefaults
        UserDefaults.standard.set(balance, forKey: "previousBalance_\(walletAddress)")
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

            // Immediately update wallet address from the first account
            if let firstAccount = multiChainWallets[index].accounts.first {
                walletAddress = firstAccount.address

                // Load previous balance for this wallet from UserDefaults
                previousBalance = UserDefaults.standard.double(forKey: "previousBalance_\(firstAccount.address)")
            }

            // Clear old wallet data immediately
            tokens = []
            transactions = []
            nfts = []
            balance = 0.0
            balanceChangePercentage = 0.0

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

        saveWallets()

        // Refresh wallet data for the new active wallet
        Task {
            await refreshWalletData()
        }
    }

    func removeWallet(_ wallet: MultiChainWallet) {
        multiChainWallets.removeAll { $0.id == wallet.id }

        // If this was the active wallet, set another as active
        if wallet.id == activeWallet?.id {
            activeWallet = multiChainWallets.first
            if let newActive = activeWallet {
                if let index = multiChainWallets.firstIndex(where: { $0.id == newActive.id }) {
                    multiChainWallets[index].isActive = true
                }
            }
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
        // Check if token already exists
        if tokens.contains(where: { $0.contractAddress?.lowercased() == token.contractAddress?.lowercased() }) {
            print("⚠️ Token already exists: \(token.symbol)")
            return
        }

        // Add token to the list
        tokens.append(token)

        // Save to UserDefaults for persistence
        saveCustomTokens()

        // Notify user
        NotificationManager.shared.notifyTokenAdded(name: token.name)

        print("✅ Custom token added: \(token.name) (\(token.symbol))")
    }

    /// Remove a custom token from the wallet
    func removeCustomToken(_ token: Token) {
        tokens.removeAll { $0.contractAddress?.lowercased() == token.contractAddress?.lowercased() }
        saveCustomTokens()
        print("🗑️ Custom token removed: \(token.symbol)")
    }

    private func saveCustomTokens() {
        // Save custom tokens to UserDefaults
        let customTokens = tokens.filter { !$0.isNative }
        if let data = try? JSONEncoder().encode(customTokens) {
            UserDefaults.standard.set(data, forKey: "CustomTokens")
            print("💾 Saved \(customTokens.count) custom tokens")
        }
    }

    private func loadCustomTokens() {
        // Load custom tokens from UserDefaults
        guard let data = UserDefaults.standard.data(forKey: "CustomTokens"),
              let customTokens = try? JSONDecoder().decode([Token].self, from: data) else {
            print("📭 No custom tokens to load")
            savedCustomTokens = []
            return
        }

        savedCustomTokens = customTokens
        print("📦 Loaded \(customTokens.count) custom tokens from storage")
    }

    // MARK: - Multi-Account Management (MetaMask style)

    /// Create a new account from the same seed phrase with next account index
    func createNewAccount(name: String? = nil) async -> Bool {
        guard let seedPhrase = keychain.getSeedPhrase() else {
            print("❌ No seed phrase available")
            return false
        }

        guard let hdWallet = try? mnemonicService.loadWallet(from: seedPhrase) else {
            print("❌ Failed to load wallet from seed phrase")
            return false
        }

        // Find the highest account index from existing seed wallets
        let seedWallets = multiChainWallets.filter { $0.type == .seed && $0.seedPhraseId == "main-seed" }
        let nextAccountIndex = seedWallets.count

        // Derive addresses for all enabled blockchains with the new account index
        var chainAccounts: [BlockchainType: ChainAccount] = [:]

        for config in availableBlockchains where config.isEnabled {
            guard let tokenType = config.blockchainType else { continue }
            guard tokenType.isEVM || tokenType == .bitcoin else { continue }
            guard let coinType = config.coinType else { continue }

            let address = mnemonicService.address(for: coinType, wallet: hdWallet, accountIndex: nextAccountIndex)
            let account = ChainAccount(config: config, tokenType: tokenType, coinType: coinType, address: address)
            chainAccounts[tokenType] = account
        }

        // Get primary address (Ethereum)
        guard chainAccounts[.ethereum]?.address != nil else {
            print("❌ Failed to derive Ethereum address")
            return false
        }

        // Create wallet name
        let walletName = name ?? "Account \(nextAccountIndex + 1)"

        // Create new wallet
        var newWallet = MultiChainWallet(name: walletName, type: .seed, seedPhraseId: "main-seed")

        // Convert chainAccounts to WalletAccount array and populate newWallet.accounts
        newWallet.accounts = chainAccounts.compactMap { (blockchainType, chainAccount) in
            guard let coinType = chainAccount.coinType else { return nil }
            let derivationPath = "m/44'/\(coinType.slip44Id)/0'/0/\(nextAccountIndex)"
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

    // MARK: - Favorite Tokens

    /// Toggle favorite status for a token symbol
    func toggleFavorite(for tokenSymbol: String) {
        if favoriteTokenSymbols.contains(tokenSymbol) {
            favoriteTokenSymbols.remove(tokenSymbol)
            print("🌟 Removed \(tokenSymbol) from favorites")
        } else {
            favoriteTokenSymbols.insert(tokenSymbol)
            print("⭐️ Added \(tokenSymbol) to favorites")
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
            print("📚 Loaded \(favorites.count) favorite tokens")
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
            print("🌐 Loaded \(blockchains.count) selected blockchains: \(blockchains.map { $0.rawValue }.joined(separator: ", "))")
        } else {
            // Default to Ethereum if nothing saved
            selectedBlockchains = [.ethereum]
            print("🌐 No saved blockchains, defaulting to Ethereum")
        }
    }
    
    /// Save selected blockchains to UserDefaults
    private func saveSelectedBlockchains() {
        if let data = try? JSONEncoder().encode(selectedBlockchains) {
            UserDefaults.standard.set(data, forKey: selectedBlockchainsKey)
            print("💾 Saved \(selectedBlockchains.count) selected blockchains")
        }
    }

    // MARK: - Real-time Price Updates

    /// Start automatic price updates
    func startPriceUpdates() {
        stopPriceUpdates() // Stop existing timer if any

        priceUpdateTimer = Timer.scheduledTimer(withTimeInterval: priceUpdateInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            print("🔄 Auto-refreshing prices...")
            Task {
                await self.refreshPricesOnly()
            }
        }

        print("✅ Price auto-refresh started (every \(Int(priceUpdateInterval))s)")
    }

    /// Stop automatic price updates
    func stopPriceUpdates() {
        priceUpdateTimer?.invalidate()
        priceUpdateTimer = nil
        print("⏸️ Price auto-refresh stopped")
    }

    /// Refresh only prices, not balances (lighter operation)
    @MainActor
    private func refreshPricesOnly() async {
        guard !tokens.isEmpty else { return }

        // Update prices for existing tokens
        let symbols = Set(tokens.map { $0.symbol })
        print("📊 Updating prices for \(symbols.count) tokens...")

        // This would call price API
        // For now we trigger full refresh but you could optimize to only update prices
        // await refreshWalletData()
    }

    deinit {
        stopPriceUpdates()
    }

}
