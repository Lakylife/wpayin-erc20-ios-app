# Wpayin Wallet - ERC-20 iOS Wallet

A comprehensive, secure, and feature-rich cryptocurrency wallet for iOS built with SwiftUI and Trust Wallet Core. Wpayin Wallet supports ERC-20 tokens, NFTs, DeFi protocols, and token swaps with an elegant black/white/blue design.

<p align="center">
  <img src="./screenshots/demo.png" width="300" alt="Wpayin Wallet Demo">
</p>

## Features

### 🔐 Security First
- **Secure Key Storage**: Private keys and seed phrases stored in iOS Keychain
- **Biometric Authentication**: Face ID / Touch ID support
- **BIP39 Compatible**: 12-word mnemonic generation and import
- **Multi-Chain Support**: Ethereum, Bitcoin, and all EVM-compatible chains
- **Non-Custodial**: You control your keys, always

### 💎 Token Management
- **ERC-20 Support**: Full support for Ethereum and EVM token standards
- **Custom Tokens**: Add any ERC-20 token by contract address with auto-fetch
- **Real-Time Prices**: Live price data from CoinGecko
- **Balance Tracking**: Track portfolio value across all tokens
- **Token Import/Export**: Easy token management

### 🎨 NFT Support
- **NFT Gallery**: View your NFT collection
- **Metadata Display**: Full NFT metadata with images
- **Alchemy Integration**: Reliable NFT data via Alchemy API

### 💱 DeFi & Swap
- **Token Swap**: Exchange tokens directly in the app
- **DeFi Protocols**: Access to lending, staking, and yield farming
- **Gas Estimation**: Accurate gas fee calculation
- **Slippage Protection**: Customizable slippage tolerance

### 📱 User Experience
- **Multi-Wallet Support**: Create and manage multiple wallets
- **QR Code Scanning**: Quick address input and deposit
- **Transaction History**: Full transaction history with Etherscan integration
- **Multi-Language Support**: English, Czech, Spanish, French, Japanese, Korean, Chinese
- **Dark Theme**: Elegant black-based design optimized for OLED

## Requirements

- **iOS**: 15.0 or later
- **Xcode**: 15.0 or later
- **Swift**: 5.9 or later
- **Device**: iPhone or iPad

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/Lakylife/wpayin-erc20-ios-app.git
cd wpayin-erc20-ios-app
```

### 2. Configure API Keys

The app requires API keys for full functionality. These are **not included** in the repository for security reasons.

#### Step-by-step Configuration:

1. **Copy the template file**:
   ```bash
   cp Wpayin_Wallet/Core/Config/Config.swift.template Wpayin_Wallet/Core/Config/Config.swift
   ```

2. **Get your API keys**:

   - **Alchemy API** (Required for NFTs):
     - Sign up at [https://www.alchemy.com/](https://www.alchemy.com/)
     - Create a new app (select Ethereum Mainnet)
     - Copy your API key

   - **Etherscan API** (Required for transaction history):
     - Sign up at [https://etherscan.io/](https://etherscan.io/)
     - Go to API Keys section
     - Create a new API key
     - Copy your API key

3. **Update Config.swift**:
   ```swift
   // Replace these values in Config.swift:
   static let alchemyApiKey = "YOUR_ALCHEMY_API_KEY"
   static let etherscanApiKey = "YOUR_ETHERSCAN_API_KEY"
   ```

4. **Optional - Custom RPC endpoints**:
   ```swift
   // You can also customize RPC URLs for better performance:
   static let ethereumRpcUrl = "https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY"
   ```

> **Note**: `Config.swift` is in `.gitignore` and will **never** be committed to Git. Keep your API keys secret!

### 3. Install Dependencies

The project uses Swift Package Manager for dependencies. Xcode will automatically resolve and download them when you open the project.

```bash
open Wpayin_Wallet.xcodeproj
```

Dependencies include:
- **WalletCore** (Trust Wallet Core) - HD wallet and key management
- **web3swift** - Ethereum interactions
- **CryptoSwift** - Cryptographic functions
- **BigInt** - Large number handling
- **secp256k1** - Elliptic curve cryptography

### 4. Build and Run

1. Open `Wpayin_Wallet.xcodeproj` in Xcode
2. Select your target device or simulator
3. Press **Cmd + B** to build
4. Press **Cmd + R** to run

Or use the command line:

```bash
xcodebuild -project Wpayin_Wallet.xcodeproj \
  -scheme Wpayin_Wallet \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build
```

## Architecture

### Project Structure

```
Wpayin_Wallet/
├── Core/
│   ├── API/              # APIService for blockchain and price data
│   ├── Config/           # Configuration (API keys) - gitignored
│   ├── Extensions/       # Swift extensions
│   ├── Localization/     # Multi-language support
│   ├── Managers/         # WalletManager, KeychainManager
│   └── Theme/            # WpayinColors, design system
├── Models/               # Token, Transaction, Blockchain models
├── Views/
│   ├── Welcome/          # Onboarding flow
│   ├── Wallet/           # Wallet creation, import, main view
│   ├── Components/       # Reusable UI components
│   ├── Main/             # Tab navigation
│   ├── Swap/             # Token swap interface
│   ├── Activity/         # Transaction history
│   ├── DeFi/             # DeFi protocols
│   └── Settings/         # App settings, security
└── Resources/            # Localization strings, assets
```

### Key Technologies

- **SwiftUI**: Modern declarative UI framework
- **Combine**: Reactive programming for state management
- **WalletCore**: BIP32/BIP39/BIP44 HD wallet implementation
- **Keychain**: Secure storage for private keys
- **JSON-RPC**: Direct blockchain interaction
- **REST APIs**: CoinGecko (prices), Alchemy (NFTs), Etherscan (transactions)

### State Management

- **WalletManager**: Central `@ObservableObject` managing wallet state
- **Environment Objects**: Shared across SwiftUI view hierarchy
- **UserDefaults**: Multi-wallet configurations, custom tokens
- **Keychain**: Secure cryptographic material storage

## Security Considerations

### Best Practices

✅ **DO**:
- Keep your seed phrase/private key backed up offline
- Use biometric authentication when available
- Verify recipient addresses before sending
- Start with small test transactions
- Keep the app updated

❌ **DON'T**:
- Share your seed phrase or private key with anyone
- Take screenshots of your seed phrase
- Store seed phrases in cloud services
- Use the wallet on jailbroken devices
- Commit `Config.swift` with API keys to version control

### Development Security

- **No Hardcoded Keys**: All API keys loaded from `Config.swift` (gitignored)
- **Keychain Storage**: Private keys never stored in plain text
- **Memory Safety**: Sensitive data cleared after use
- **Biometric Protection**: Optional Face ID/Touch ID for access

> ⚠️ **Important**: This wallet is for educational and personal use. For production use with significant funds, a professional security audit is strongly recommended.

## Development

### Running Tests

```bash
xcodebuild -project Wpayin_Wallet.xcodeproj \
  -scheme Wpayin_Wallet \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  test
```

### Building for Release

```bash
xcodebuild -project Wpayin_Wallet.xcodeproj \
  -scheme Wpayin_Wallet \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  archive
```

## Configuration Options

### Feature Flags

You can enable/disable features in `Config.swift`:

```swift
struct AppConfig {
    static let nftEnabled = true        // Enable NFT functionality
    static let defiEnabled = true       // Enable DeFi features
    static let swapEnabled = true       // Enable token swaps
}
```

### Supported Networks

- **Ethereum** (Mainnet)
- **Polygon** (MATIC)
- **Binance Smart Chain** (BSC)
- **Arbitrum**
- **Optimism**
- **Avalanche C-Chain**
- **Base**
- **Bitcoin** (balance view only)

## Troubleshooting

### Build Errors

**Error**: `Cannot find type 'AppConfig'`
- **Solution**: Make sure you've created `Config.swift` from the template (see Installation step 2)

**Error**: `No such module 'WalletCore'`
- **Solution**: Wait for Xcode to finish resolving Swift packages, or go to File → Packages → Resolve Package Versions

### Runtime Issues

**NFTs not loading**:
- Check your Alchemy API key in `Config.swift`
- Verify you have an active internet connection
- Ensure the wallet has NFTs (test with a known NFT holder address)

**Transaction history empty**:
- Check your Etherscan API key in `Config.swift`
- Verify the wallet has transaction history on that chain
- Check API rate limits (free tier has restrictions)

**Prices showing $0.00**:
- CoinGecko may have rate limits on free tier
- Check internet connection
- Try refreshing the wallet view

## Contributing

Contributions are welcome! Please follow these guidelines:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Code Style

- Follow Swift naming conventions
- Use SwiftUI best practices
- Comment complex logic
- Update README for new features
- Test on both iPhone and iPad

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- **Trust Wallet Core**: For the excellent HD wallet library
- **Alchemy**: For reliable blockchain APIs
- **CoinGecko**: For comprehensive price data
- **Etherscan**: For transaction indexing
- **SwiftUI Community**: For patterns and best practices

## Support

For issues, questions, or suggestions:

- **Issues**: [GitHub Issues](https://github.com/Lakylife/wpayin-erc20-ios-app/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Lakylife/wpayin-erc20-ios-app/discussions)

## Disclaimer

This software is provided "as is", without warranty of any kind. Use at your own risk. The developers are not responsible for any loss of funds or data. Always test with small amounts first and keep backups of your seed phrase.

---

**Made with ❤️ for the decentralized future**

