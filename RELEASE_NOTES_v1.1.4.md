# 🎉 Wpayin Wallet v1.1.4 Release Notes

**Release Date:** November 9, 2024

## ✨ New Features & Improvements

### 📱 In-App Help Center
- **NEW**: Help Center now opens inside the app instead of external browser
- Browse comprehensive help articles organized by categories
- Search functionality to quickly find answers
- Topics include: Getting Started, Security, Transactions, Networks, NFTs, and Troubleshooting

### 🎨 Icon System Enhancements
- **IMPROVED**: Network icons now use high-quality assets from `Assets.xcassets`
- Enhanced icon display in:
  - Settings → Manage Networks
  - Swap → Select Network
  - Your Assets token list
- Added fallback system for missing icons
- Debug logging for icon loading (development)

### ⚙️ Settings & UI
- Updated app version display to 1.1.4
- Consistent icon styling across all views
- Improved network selector UI in Swap view

## 🐛 Bug Fixes

- Fixed network icon display in Settings and Swap views
- Resolved icon rendering for native tokens (ETH, MATIC, BNB, etc.)
- Improved asset loading priority system
- Enhanced error handling for missing icons

## 🧹 Code Quality & Maintenance

- Cleaned up documentation files (removed 40+ .md files)
- Kept only essential docs: README.md and SECURITY.md
- Improved code organization
- Added comprehensive icon mapping system
- Enhanced TokenIconHelper with better fallback logic

## 📋 Technical Details

### Assets Added
- High-quality blockchain network icons for:
  - Ethereum, Bitcoin, Polygon, BSC, Arbitrum, Optimism, Avalanche, Base, Gnosis, zkSync, Fantom, and more
- Provider icons for DeFi integrations
- Rating and metric visualization assets

### Code Changes
- Enhanced `BlockchainSettingsView` with asset icon support
- Updated `SwapView` network selector with proper icons
- Improved `TokenIconView` component with debug logging
- Added `assetIconName` property to `BlockchainPlatform`

## 🔐 Security

- No security changes in this release
- Maintains all existing security features:
  - Non-custodial wallet architecture
  - Biometric authentication support
  - Secure keychain storage
  - Local-only seed phrase management

## 📦 What's Included

- iOS application source code
- Comprehensive test suites
- Asset catalog with all blockchain icons
- Help Center documentation
- Security guidelines

## 🚀 Upgrade Notes

This is a minor update from v1.1.0 to v1.1.4. No breaking changes or data migration required.

### For Users:
- Simply update the app
- All settings and wallets are preserved
- New Help Center available in Settings → Support

### For Developers:
- Review `TokenIconHelper.swift` for icon mapping logic
- Check `NetworkIconView.swift` for updated icon rendering
- See `HelpCenterView.swift` for in-app help implementation

## 🐞 Known Issues

- Token icons may still show text symbols for some networks (debugging in progress)
- Some custom tokens may not have icons (will use placeholder)

## 📝 Changelog

### Added
- In-app Help Center with comprehensive articles
- Asset icon support for all blockchain networks
- Debug logging for icon loading
- High-quality network icons in Assets.xcassets

### Changed
- Updated app version to 1.1.4
- Improved network selector UI in Swap
- Enhanced icon display across all views
- Cleaned up repository documentation

### Fixed
- Help Center opening external URL
- Network icons not displaying in Settings
- Swap view network selector icons
- Icon fallback system

### Removed
- 40+ unnecessary .md documentation files
- Duplicate icon extension code

## 🙏 Credits

Built with ❤️ using:
- Swift & SwiftUI
- WalletCore by Trust Wallet
- Community feedback

## 📞 Support

- **Help Center**: Available in-app (Settings → Support)
- **Email**: support@wpayin.com
- **Issues**: [GitHub Issues](https://github.com/Lakylife/wpayin-erc20-ios-app/issues)

## 🔗 Links

- [Source Code](https://github.com/Lakylife/wpayin-erc20-ios-app)
- [README](https://github.com/Lakylife/wpayin-erc20-ios-app/blob/main/README.md)
- [Security Policy](https://github.com/Lakylife/wpayin-erc20-ios-app/blob/main/SECURITY.md)

---

**Full Changelog**: [v1.1.0...v1.1.4](https://github.com/Lakylife/wpayin-erc20-ios-app/compare/v1.1.0...v1.1.4)
