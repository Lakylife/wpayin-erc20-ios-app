#!/bin/bash
# 
# Quick Release Script for v1.1.0
# Run this script to prepare GitHub release
#

set -e  # Exit on error

echo "🚀 Preparing Wpayin Wallet v1.1.0 for GitHub Release"
echo ""

# Navigate to project directory
cd /Users/lakylife/Documents/Wpayin_Wallet

# 1. Stage all changes
echo "📦 Step 1/5: Staging changes..."
git add .

echo "   ✅ Changes staged"
echo ""

# 2. Show what will be committed
echo "📋 Files to be committed:"
git status --short
echo ""

read -p "Continue with commit? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "❌ Aborted by user"
    exit 1
fi

# 3. Commit
echo "💾 Step 2/5: Creating commit..."
git commit -m "Release v1.1.0 - Bitcoin Support, Real Swaps & Transactions

Major Features:
- 🪙 Bitcoin support with Native SegWit (bc1...)
- 🔄 Real DEX token swapping (Uniswap, PancakeSwap, etc.)
- 💸 Real transaction sending (ETH, BTC, ERC-20)
- 🌐 Advanced network management with RPC failover
- ⛽ Gas price intelligence (EIP-1559 + Legacy)
- 👛 Multi-account wallet system
- 🎨 Token icon preservation system

Bug Fixes:
- Fixed blockchain activation breaking assets
- Fixed token icons loss
- Fixed incorrect wallet addresses
- Fixed 9 compiler warnings
- Fixed balance calculation

Technical:
- Added BitcoinService (497 lines)
- Added NetworkManager (222 lines)
- Added GasPriceService (343 lines)
- Updated TransactionService, SwapService, WalletManager
- Zero compiler warnings
- Swift 6 concurrency safety

Documentation:
- Updated README.md with v1.1.0 features
- Added CHANGELOG.md
- Added VERSION_2.0.0_SUMMARY.md
- Added technical documentation

Statistics:
- 2,000+ lines of new code
- 3 new services
- 0 compiler warnings
- 8 supported blockchains
- 13 critical fixes"

echo "   ✅ Commit created"
echo ""

# 4. Create tag
echo "🏷️  Step 3/5: Creating tag v1.1.0..."
git tag -a v1.1.0 -m "Version 1.1.0 - Bitcoin, Real Swaps & Transactions

🆕 Major Features:
- Bitcoin support (Native SegWit)
- Real DEX token swapping
- Real blockchain transactions
- Advanced network management
- Gas price intelligence
- Multi-account system
- Icon preservation

🐛 Critical Fixes:
- Blockchain activation fix
- Icon preservation
- Address display fix
- 9 compiler warnings fixed

📊 Statistics:
- 2,000+ lines of new code
- 3 new services
- 0 compiler warnings
- 8 supported blockchains
- 13 critical fixes

For full changelog see CHANGELOG.md"

echo "   ✅ Tag v1.1.0 created"
echo ""

# 5. Show tags
echo "📋 Current tags:"
git tag
echo ""

# 6. Push to GitHub
echo "⬆️  Step 4/5: Pushing to GitHub..."
read -p "Push to GitHub? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    echo "   Pushing commit to main..."
    git push origin main
    
    echo "   Pushing tag v1.1.0..."
    git push origin v1.1.0
    
    echo "   ✅ Pushed to GitHub"
else
    echo "   ⚠️  Skipped push (run manually: git push origin main && git push origin v1.1.0)"
fi
echo ""

# 7. Final instructions
echo "🎉 Step 5/5: Create GitHub Release"
echo ""
echo "Next steps:"
echo "1. Go to: https://github.com/YOUR_USERNAME/wpayin-erc20-ios-app/releases/new"
echo "2. Select tag: v1.1.0"
echo "3. Release title: v1.1.0 - Bitcoin Support, Real Swaps & Transactions 🚀"
echo "4. Copy description from: VERSION_2.0.0_SUMMARY.md"
echo "5. Click 'Publish release'"
echo ""
echo "✨ All done! Your v1.1.0 is ready for GitHub Release!"
echo ""
echo "📚 Documentation:"
echo "   - Full guide: GITHUB_RELEASE_GUIDE.md"
echo "   - Changelog: CHANGELOG.md"
echo "   - Summary: VERSION_2.0.0_SUMMARY.md"
echo ""
