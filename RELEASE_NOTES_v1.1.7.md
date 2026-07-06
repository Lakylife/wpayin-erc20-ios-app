# Release Notes — v1.1.7 (Build 5)

## 🔧 Reliability and fixes

### Build and signing

- Removed the duplicate `SettingsManager 2.swift` declaration that prevented
  compilation.
- Removed the iCloud capability from the default build because personal Apple
  development teams do not support it. Device signing works without the
  capability; the prepared CloudKit entitlement remains available for paid
  developer accounts.

### RPC and balances

- Replaced unavailable or authenticated-by-default RPC endpoints with verified
  PublicNode endpoints.
- Centralized RPC lists in `NetworkManager` and added automatic endpoint
  failover to swap and native-balance requests.
- A failed native-balance request now preserves the last known value instead
  of replacing it with zero.

### User-facing transaction errors

- Replaced raw provider errors such as insufficient gas-fund messages with
  clear user-facing explanations.
- Added the new transaction and P2P messages to all eight bundled languages:
  Czech, English, German, Spanish, French, Japanese, Korean, and Chinese.

### Network-aware activity

- Transactions now retain their originating network.
- Added network filters and network icons to Activity.
- Token details show activity only for the token's selected network, so assets
  with the same symbol on different chains are no longer mixed.
- Explorer links now use the correct destination for each network, including
  Arbiscan and Basescan.

## ✨ New features

### Cross-chain bridge

- Added a **Swap | Bridge** mode switch with a matching review flow.
- Bridges assets between Ethereum, Arbitrum, Base, Optimism, Polygon, BNB
  Chain, and Avalanche through the LI.FI route aggregator.
- Shows the selected bridge route, estimated execution time, expected output,
  and guaranteed minimum before signing.

### Atomic P2P trading

- Replaced the non-functional Buy flow with signed P2P offers.
- Sellers can create an offer and share it by QR code or the iOS share sheet;
  buyers verify and accept the signed payload.
- Settlement uses AirSwap contracts so the two assets transfer atomically or
  the trade fails without a partial exchange.
- Before submission, the app checks balances, approvals, signature, expiry,
  fees, and on-chain nonce state, then simulates the fill with `eth_call`.
- Sellers can cancel offers on-chain and track Active, Completed, and Expired
  states.
- Supports ERC-20 tokens and wrapped Bitcoin assets such as WBTC, cbBTC, BTCB,
  and BTC.b. Native EVM assets are wrapped 1:1 when needed.
- Native BTC and SOL are not supported because they cannot settle atomically
  through an EVM contract.
- The CloudKit public-offer board is implemented but disabled by default. It
  requires the paid Apple Developer Program and iCloud capability.

### Live market data

- Refreshes token prices every 60 seconds.
- Adds real green/red 24-hour change badges to wallet and asset lists.
- Removes the previous synthetic percentage change derived from a token hash.

### Optional platform fee

- Adds a configurable platform fee to sends and P2P trades, defaulting to
  25 basis points (0.25%).
- Validation, review screens, and Max calculations include the fee.
- Fee collection remains disabled until `PLATFORM_FEE_RECIPIENT` contains a
  valid EVM address.

### Interface updates

- Added an orbital launch animation featuring BTC, ETH, SOL, BNB, Arbitrum,
  and Base.
- Redesigned slippage tolerance as a medium sheet with presets, custom input,
  and a warning for values of 3% or higher.

## Configuration notes

1. Set `PLATFORM_FEE_RECIPIENT` in the Xcode scheme environment to enable the
   platform fee.
2. For physical-device signing, add the Apple ID in **Xcode → Settings →
   Accounts**, then restart Xcode if signing state remains stale.
3. To enable the public P2P board, join the paid Apple Developer Program, add
   the prepared iCloud/CloudKit capability, and set
   `p2pOfferBoardEnabled = true` in `Config.swift`.
4. Test P2P settlement with a small amount between accounts you control before
   using meaningful funds.
