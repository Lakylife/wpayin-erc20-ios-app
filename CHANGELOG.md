# Changelog

All notable changes to Wpayin Wallet will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v1.1.0.html).

## [1.1.0] - 2024-11-08

### 🆕 Added

#### Bitcoin Integration
- Full Bitcoin support with Native SegWit (BIP84) addresses
- Bitcoin address derivation using `bc1...` format (Bech32)
- Real-time Bitcoin balance fetching via Blockstream API
- Bitcoin transaction sending with configurable fee rates
- Bitcoin receive addresses with QR code generation
- Multi-account Bitcoin address derivation (m/84'/0'/0'/0/{index})
- Bitcoin fee estimation (Slow/Standard/Fast: 10/20/40 sat/vB)

#### Real Token Swapping
- DEX router integration (Uniswap V2, PancakeSwap, QuickSwap, SushiSwap)
- Real on-chain token swaps across all EVM chains
- Swap quote system with price impact analysis
- Slippage tolerance configuration (0.1% - 5%)
- Multi-chain swap support (Ethereum, BSC, Polygon, Arbitrum, etc.)
- Gas estimation for swap transactions
- Swap transaction signing and broadcasting

#### Real Transaction Sending
- Native token transfers (ETH, BNB, MATIC, AVAX, etc.)
- ERC-20 token transfers on all EVM chains
- Transaction signing with EIP-155
- RLP encoding for Ethereum transactions
- Automatic nonce management
- Gas price fetching from network
- Transaction broadcasting to blockchain
- Transaction result with hash and status

#### Network Management
- Multiple RPC sources per blockchain with failover
- Network configuration for 8 blockchains
- Automatic RPC switching on failure
- Custom explorer URLs for each chain
- EIP-1559 detection per network
- Chain ID verification

#### Gas Price Intelligence
- EIP-1559 gas pricing (Ethereum, Polygon, Arbitrum, Optimism, Avalanche, Base)
  - Base fee + priority fee calculation
  - Dynamic fee adjustment
  - Safety range detection (90%-150%)
- Legacy gas pricing (BSC)
  - Simple gas price in Gwei
  - Network-based estimation
- Gas price warnings:
  - Too low: Risk of stuck transaction
  - Optimal: Safe range
  - Too high: Overpaying
- Estimated wait times per fee tier

#### Multi-Account Wallet System
- Create multiple accounts from single seed phrase
- MetaMask-compatible derivation paths
- Independent addresses per blockchain per account
- Account naming and organization
- Quick account switcher in UI
- Account-specific transaction history
- Per-account balance tracking

#### Token Icon System
- Default icon URLs for major tokens (BTC, ETH, USDT, USDC, BNB, MATIC, AVAX, SOL)
- Icon preservation during token updates
- Fallback mechanism when API fails
- CoinGecko CDN integration
- Smart icon merging during token refresh

### 🔧 Improved

#### Token Management
- Optimized token merging - preserves existing tokens when adding blockchains
- Smart blockchain filtering - show/hide chains without data loss
- Intelligent token caching
- Better token deduplication
- Icon preservation across updates

#### Balance Calculation
- Respects active/inactive blockchains
- Accurate total portfolio value
- Per-blockchain balance tracking
- Real-time balance updates
- Cached previous balance for change calculation

#### UI/UX
- Better wallet selector with correct addresses per blockchain
- Primary address detection (Ethereum > EVM > any)
- Improved address formatting (6...4 truncation)
- Better blockchain icons and colors
- Loading states for async operations

#### Code Quality
- Zero compiler warnings
- Swift 6 concurrency safety
- Proper actor isolation with `@MainActor`
- `nonisolated(unsafe)` for constants
- `@unchecked Sendable` conformance
- Clean error handling
- Comprehensive logging

### 🐛 Fixed

#### Critical Fixes
- **Blockchain Activation Bug**: Adding Bitcoin no longer breaks Ethereum assets
- **Icon Loss**: Tokens now preserve icons when blockchains are toggled
- **Address Display**: Wallet selector shows correct address per blockchain
- **Balance Reset**: Balance persists when switching blockchains

#### Compiler Warnings
- Infinite recursion in `Data.reversed()` → renamed to `reversedBytes()`
- Unused variable `primaryAddress` in WalletManager
- Unused variable `keychain` in SwapService
- Unused variable `deadlineTimestamp` in SwapService
- Unused variable `transactionService` in SwapService
- Unused variable `recoveryPhrase` in RecoveryPhraseView
- Missing `@unchecked Sendable` conformance in BundleExtension
- Main actor isolation warning in `defaultConfigs`
- Main actor isolation warning in `BitcoinDerivation.default`

#### Data Consistency
- Token merging now preserves icons
- Blockchain toggling doesn't delete tokens
- Custom tokens persist across updates
- Balance calculation uses only visible tokens

### 📚 Documentation

#### New Files
- `BLOCKCHAIN_MANAGEMENT_FIX.md` - Explains blockchain activation system
- `BITCOIN_ADDRESS_AND_ICONS_FIX.md` - Bitcoin derivation and icon system
- `COMPILER_WARNINGS_FIXED.md` - Details of all warning fixes
- `CHANGELOG.md` - This file

#### Updated Files
- `README.md` - Comprehensive v1.1.0 feature list
- `AGENTS.md` - Updated with new services and patterns

### 🏗️ Technical Changes

#### New Services
- `BitcoinService.swift` (497 lines)
  - Address derivation
  - Balance fetching
  - UTXO management
  - Fee rate estimation
  - Transaction building (simplified for MVP)
  - Transaction broadcasting

- `NetworkManager.swift` (222 lines)
  - Multi-RPC configuration
  - Network switching
  - Explorer URL generation
  - EIP-1559 detection

- `GasPriceService.swift` (343 lines)
  - EIP-1559 gas price calculation
  - Legacy gas price estimation
  - Safety warnings
  - Fee tier recommendations

#### Updated Services
- `TransactionService.swift`
  - Real transaction sending
  - EIP-155 signing
  - RLP encoding
  - Nonce management
  - Gas price integration

- `SwapService.swift`
  - Real DEX integration
  - Router address mapping
  - Swap quote generation
  - Transaction encoding

- `WalletManager.swift`
  - Token merging logic
  - Icon preservation
  - Blockchain filtering
  - Multi-account support
  - Bitcoin balance loading

#### Model Updates
- `Token.swift`
  - Icon URL property
  - Bitcoin support

- `Blockchain.swift`
  - Bitcoin blockchain type
  - Network configurations

### ⚠️ Breaking Changes

**None** - All changes are backward compatible

### 🔄 Migration Guide

No migration needed. Existing wallets will:
- Automatically gain Bitcoin support
- Preserve all existing tokens
- Maintain transaction history
- Keep custom tokens

Simply update to v1.1.0 and activate Bitcoin in Settings → Networks if desired.

### 📊 Statistics

- **Lines of Code Added**: ~2,000
- **New Features**: 7 major features
- **Bug Fixes**: 13 critical + warning fixes
- **New Services**: 3 (Bitcoin, Network, GasPrice)
- **Updated Services**: 3 (Transaction, Swap, Wallet)
- **Documentation**: 4 new markdown files
- **Supported Blockchains**: 8 (was 7)
- **Compiler Warnings**: 0 (was 9)

### 🙏 Credits

Special thanks to:
- **Unstoppable Wallet** - Architecture inspiration
- **Trust Wallet Core** - Bitcoin integration
- **Blockstream** - Bitcoin API
- **Mempool.space** - Fee estimation

---

## [1.0.0] - 2024-10-15

### Initial Release

#### Features
- Ethereum wallet support
- ERC-20 token management
- NFT gallery
- Transaction history
- Multi-language support (7 languages)
- Dark theme
- QR code generation
- Biometric authentication
- Seed phrase backup
- Custom token addition

#### Supported Networks
- Ethereum Mainnet
- Polygon
- Binance Smart Chain
- Arbitrum
- Optimism
- Avalanche
- Base

---

**Version Format**: MAJOR.MINOR.PATCH
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)
