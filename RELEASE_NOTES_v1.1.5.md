# 🎉 Wpayin Wallet v1.1.5 Release Notes

**Release Date:** June 9, 2026

## ✨ New Features & Improvements

### 🪙 Token Icon Fixes
- Fixed WETH icon handling across Home, Select Token, and All Assets
- Corrected Solana, USDT, and USDC icons in Select Asset
- Improved fallback behavior for missing token metadata

### 🔄 Chain-Aware Wallet Flows
- Send, Receive, and Swap now resolve the correct chain per asset
- Deposit and Withdraw now use the proper network-specific address data
- Better separation between Ethereum tokens and non-EVM assets in asset lists

### 👛 Wallet Restore
- Re-login now restores the same wallet set and active chain state
- Import flows persist wallet metadata more reliably
- Solana and Bitcoin wallet handling is now more explicit

### 📷 QR Scanner
- The top-right QR action now opens the camera for scanning recipient addresses

### 🎨 UI Refresh
- Updated app icon and branding assets
- Cleaner, more minimal bottom navigation
- Improved spacing in asset rows and token cards

## 🐛 Bug Fixes

- Fixed incorrect icon rendering in Home, Select Asset, Select Token, and All Assets
- Fixed missing assets in Deposit and Withdraw selectors
- Fixed wallet state not reloading properly after sign-out and sign-in
- Fixed layout issues where longer token names could clip in asset rows

## 🔐 Security

- Continues to use iOS Keychain for sensitive wallet material
- No API keys or secret files are included in this release
- README and release docs were updated to match the current app state

## 📦 What's Included

- Current app source code
- Updated screenshots for the README
- Updated release documentation

## 🚀 Upgrade Notes

This is the current production update. No manual data migration is required for users who already have a wallet backed up with a seed phrase or private key.

### For Users:
- Update the app normally
- Re-import or re-login with your existing wallet if needed

### For Developers:
- See `README.md` for the updated release summary
- See `SECURITY.md` for the current security guidance

## 🔗 Links

- [Source Code](https://github.com/Lakylife/wpayin-erc20-ios-app)
- [README](https://github.com/Lakylife/wpayin-erc20-ios-app/blob/main/README.md)
- [Security Policy](https://github.com/Lakylife/wpayin-erc20-ios-app/blob/main/SECURITY.md)

