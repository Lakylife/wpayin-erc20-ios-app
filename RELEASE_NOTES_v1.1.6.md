# Release Notes — v1.1.6 (Build 4)

## 🔐 Security

- **Keychain hardening**: Seed phrase and private key are now stored with
  `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — secrets never leave the
  device via backup/restore. Existing items are migrated automatically.
- **Face ID / Touch ID app lock is now actually enforced.** New
  `AppLockManager` + `LockScreenView`: the app locks on cold start and after
  the configured **Auto Lock** timeout when returning from background
  (with device-passcode fallback so users are never locked out).
- Added missing `NSFaceIDUsageDescription` (Face ID would fail on device
  without it).
- Fixed the Face ID toggle in Settings not persisting across launches.
- Removed hardcoded provider credentials and all configuration example files.
  The app now builds with public RPC defaults; optional Alchemy, Etherscan, and
  CoinGecko keys can be supplied only through the local Xcode run environment.

## 🛠 Transactions (Withdraw / Swap / Deposit / Buy)

- **EVM signing rewritten on WalletCore `AnySigner`** (TransactionService &
  SwapService). The previous hand-rolled RLP encoder produced intermittently
  invalid transactions (non-canonical r/s integer encoding).
- **Swap was fundamentally broken and is now functional**: router calldata was
  missing the path array, recipient and deadline (every swap would revert
  on-chain). Now uses correct Uniswap V2 ABI encoding, real on-chain quotes
  via `getAmountsOut`, and a real ERC-20 allowance check + `approve` flow.
- **Bitcoin send implemented** (was a stub that broadcast an empty string):
  proper UTXO fetching, WalletCore transaction planning, BIP84 SegWit signing.
- Swap errors and success are now shown to the user (previously only logged).
- Nonce fetching uses `pending` so queued transactions (approve + swap) don't
  collide.
- Withdraw recipient validation now accepts Bitcoin addresses.

## 👛 Multi-wallet

- **Critical: Solana addresses were derived with the wrong curve (secp256k1
  instead of ed25519)** — deposits to such an address would be unrecoverable.
  Address derivation is now per-coin correct (ed25519 for Solana, BIP84 bech32
  for Bitcoin, BIP44 for EVM) and consistent with the paths used for spending.
- Fixed `main_seed` / `main-seed` identifier mismatch that made a newly
  created account reuse the main wallet's address (index 0). Stored wallets
  are migrated automatically.
- Signing services now spend from the **active** account (persisted
  `ActiveAccountIndex`), matching the balances shown in the UI.
- Solana native balance now fetched via Solana RPC `getBalance`
  (previously `eth_getBalance` was sent to the Solana RPC and always failed).
- Active wallet selection, enabled blockchains and settings persist across
  app launches.

## 🔔 Notifications

- Push notifications now respect the in-app **Notifications** toggle
  (previously they fired even when disabled).
- Notification permission is requested when the user enables the toggle,
  not eagerly at app launch.

## 🎨 Icons

- Buy screen now uses the same Solana / USDT / USDC / Polygon icon marks as
  the rest of the app.
- Verified all bundled icon assets referenced in code exist in the catalog.

## 📦 Distribution

- Updated README and security policy for v1.1.6.
- Removed obsolete release/helper scripts, personal Xcode data, and local work
  artifacts from the published repository.
- Refreshed the GitHub screenshots from the v1.1.6 simulator build.
