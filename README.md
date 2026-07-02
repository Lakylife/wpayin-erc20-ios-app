# Wpayin Wallet 1.1.6

Wpayin Wallet is a non-custodial iOS wallet built with SwiftUI and Trust
Wallet Core. It supports Bitcoin, Ethereum, Solana, EVM-compatible networks,
tokens, transaction history, NFTs, and DEX swaps.

> This project has not received a professional security audit. Use test
> accounts and small amounts only. You are responsible for protecting your
> recovery phrase and private keys.

<p align="center">
  <img src="./screenshots/20260609_app_update/01_launch.png" width="220" alt="Wpayin Wallet onboarding">
  <img src="./screenshots/20260609_app_update/02_home.png" width="220" alt="Wpayin Wallet home">
  <img src="./screenshots/20260609_app_update/03_swap.png" width="220" alt="Wpayin Wallet swap">
</p>

## Version 1.1.6

- Hardened Keychain access for recovery phrases and private keys.
- Added an enforced Face ID / Touch ID app lock with passcode fallback.
- Reworked EVM and Bitcoin transaction signing with Trust Wallet Core.
- Fixed ERC-20 allowance, approval, quote, and swap transaction handling.
- Fixed Solana, Bitcoin, and EVM address derivation across multiple accounts.
- Added Solana balance loading and persistent wallet/network selection.
- Updated wallet, activity, buy, asset picker, and token icon interfaces.
- Removed committed API credentials and configuration templates.

See [RELEASE_NOTES_v1.1.6.md](RELEASE_NOTES_v1.1.6.md) for the complete
release notes.

## Requirements

- macOS with Xcode 16 or newer
- iOS 15.0 or newer
- An Apple development team for installation on a physical device

## Build and run

```bash
git clone https://github.com/Lakylife/wpayin-erc20-ios-app.git
cd wpayin-erc20-ios-app
open Wpayin_Wallet.xcodeproj
```

Xcode resolves the pinned Swift Package Manager dependencies automatically.
Select the `Wpayin_Wallet` scheme, choose an iPhone simulator, and press
`Cmd-R`.

The command-line equivalent is:

```bash
xcodebuild \
  -project Wpayin_Wallet.xcodeproj \
  -scheme Wpayin_Wallet \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

No configuration file needs to be copied or created. Public RPC endpoints and
keyless services provide the base wallet functionality.

## Optional API integrations

NFT discovery and indexed transaction history use optional third-party API
keys. In Xcode, open **Product → Scheme → Edit Scheme → Run → Arguments** and
add the required values under **Environment Variables**:

| Variable | Purpose |
| --- | --- |
| `ALCHEMY_API_KEY` | Ethereum NFT discovery |
| `ETHERSCAN_API_KEY` | Indexed EVM transaction history |
| `COINGECKO_API_KEY` | Optional authenticated CoinGecko access |

The app still builds and runs when these values are absent; the corresponding
optional data is simply unavailable. Do not add credentials to source files.
Any credential shipped in an iOS binary can be extracted, so production
deployments should use restricted keys or a server-side proxy.

## Supported networks

- Bitcoin (Native SegWit/BIP84)
- Ethereum
- Solana
- BNB Chain
- Polygon
- Arbitrum
- Optimism
- Avalanche C-Chain
- Base

## Project layout

```text
Wpayin_Wallet/
├── Assets.xcassets/
├── Core/
│   ├── API/
│   ├── Config/
│   ├── Managers/
│   └── Services/
├── Models/
├── Resources/
└── Views/
Wpayin_WalletTests/
Wpayin_WalletUITests/
```

The project pins WalletCore, web3swift, CryptoSwift, BigInt, and secp256k1 in
`Package.resolved`.

## Security

- Recovery phrases and private keys are stored in the iOS Keychain with
  `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
- App lock supports Face ID, Touch ID, and device-passcode fallback.
- Sensitive wallet data must never be committed, logged, or included in
  screenshots.
- Review [SECURITY.md](SECURITY.md) before using or modifying transaction and
  key-management code.

To report a vulnerability, use a private GitHub security advisory rather than
a public issue.

## License

Released under the [MIT License](LICENSE).
