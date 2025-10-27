# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Wpayin Wallet is a comprehensive ERC-20 cryptocurrency wallet built with SwiftUI for iOS. The app provides secure wallet creation, import, token management, DeFi features, and swap functionality with an elegant black/white/blue design theme.

## Architecture

### Core Framework
- **Framework**: SwiftUI + Combine + WalletCore (Trust Wallet Core)
- **Target**: iOS 15.0+, supports iPhone and iPad
- **Dependencies**: WalletCore, web3swift, CryptoSwift, BigInt, secp256k1, SwiftProtobuf
- **Security**: Keychain for private key storage, biometric authentication support

### App Structure
```
Wpayin_Wallet/
├── Core/
│   ├── Theme/           # Colors, fonts, design system
│   ├── Managers/        # WalletManager, KeychainManager
│   └── API/             # API service layer
├── Models/              # Token, Transaction data models
├── Views/
│   ├── Welcome/         # Onboarding and welcome screens
│   ├── Wallet/          # Wallet creation, import, main dashboard
│   ├── Components/      # Reusable UI components
│   ├── Main/            # Tab view and navigation
│   ├── Swap/            # Token swap functionality
│   ├── Activity/        # Transaction history
│   ├── DeFi/            # DeFi protocols and features
│   └── Settings/        # App settings and security
```

## Key Features

### Wallet Management
- **Create Wallet**: 12-word mnemonic generation with 3-word verification
- **Import Wallet**: Support for mnemonic phrases and private keys
- **Security**: Keychain storage, biometric auth, terms acceptance

### Token Operations
- **ERC-20 Support**: Add custom tokens, manage balances
- **Deposit**: QR codes, address copying
- **Withdraw**: Send tokens with gas estimation
- **Swap**: Token exchange with slippage protection

### DeFi Integration
- **Portfolio Overview**: Total value tracking
- **Protocols**: Lending, staking, yield farming
- **Activity Tracking**: DeFi position monitoring

## Design System

### Colors (WpayinColors)
- **Primary**: Blue (#007AFF)
- **Background**: Black (#0D0D0D)
- **Surface**: Dark gray (#262626)
- **Text**: White (#FAFAFA)
- **Success**: Green (#00CC66)
- **Error**: Red (#FF4D4D)

### Components
- `WpayinButton`: Consistent button styling
- `ProgressBar`: Multi-step flow progress
- `TokenRowView`: Token display with balance/value
- `TransactionRowView`: Activity history items

## Development Commands

### Building
```bash
# Build the project
xcodebuild -project Wpayin_Wallet.xcodeproj -scheme Wpayin_Wallet -destination 'platform=iOS Simulator,name=iPhone 15' build
```

### Testing
```bash
# Run unit tests
xcodebuild -project Wpayin_Wallet.xcodeproj -scheme Wpayin_Wallet -destination 'platform=iOS Simulator,name=iPhone 15' test
```

### Using Xcode
- Open `Wpayin_Wallet.xcodeproj` in Xcode
- Use Cmd+B to build
- Use Cmd+U to run tests
- Use Cmd+R to run the app

## Security Implementation

### Private Key Management
- **KeychainManager**: Secure storage using iOS Keychain
- **No Plain Text**: Private keys never stored in UserDefaults
- **Biometric Protection**: Face ID/Touch ID integration

### Wallet Recovery
- **Mnemonic Generation**: BIP39 compatible via WalletCore HDWallet
- **Phrase Verification**: User must confirm 3 random words during setup
- **Import Support**: Both 12-word mnemonics and private keys
- **Multi-Chain Derivation**: Supports Bitcoin, Ethereum, and EVM-compatible chains

## API Integration

### Endpoints Structure
```
/wallet/{address}/balance     - Get wallet balance
/wallet/{address}/tokens      - Get token list
/wallet/{address}/transactions - Get transaction history
/transactions/send           - Send transaction
/transactions/estimate-gas   - Gas estimation
/swap/quote                  - Get swap quote
/swap/execute               - Execute swap
/defi/protocols             - DeFi protocol list
/defi/positions/{address}   - User DeFi positions
```

### Real Blockchain Integration
- **Public RPC**: Direct blockchain RPC calls (Ethereum, Bitcoin via Blockstream)
- **CoinGecko API**: Live price data and market information
- **Multi-Chain Support**: EVM chains and Bitcoin balance fetching
- **Async/Await**: Modern Swift concurrency throughout

## Bundle Identifier
`io.noriskservis.standart.Wpayin-Wallet`

## Development Team
Development Team ID: `AA9GARUABY`

## State Management
- **WalletManager**: Central @ObservableObject managing wallet state
- **Environment Objects**: Shared across SwiftUI view hierarchy
- **UserDefaults**: For blockchain configs and saved addresses
- **Keychain**: Secure storage for sensitive cryptographic data

## Key Architectural Patterns
- **MVVM**: SwiftUI Views + ObservableObject ViewModels
- **Manager Pattern**: WalletManager, KeychainManager, MnemonicService
- **Service Layer**: APIService for external blockchain/price APIs
- **Error Handling**: Swift Result types and throwing functions

## Important Notes
- Uses real blockchain RPCs and live price data
- Private keys secured via iOS Keychain with biometric protection
- Multi-chain wallet supporting Bitcoin and EVM networks
- Production-ready crypto wallet implementation
- Security audit recommended before mainnet use with real funds