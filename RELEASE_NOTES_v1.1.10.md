# Wpayin Wallet for iOS 1.1.10

Version 1.1.10, build 7. Released 2026-10-26.

## Changes

- Require fresh device authentication before exporting recovery phrases or private keys.
- Clear sensitive export screens when backgrounded or when the wallet changes.
- Keep secret clipboard copies on this device and expire them after 30 seconds.
- Honor the configured Auto-Lock interval and support device-passcode fallback.
- Export private keys using the active account derivation.
- Reject delayed balances, transaction history, NFT and price responses after wallet changes.
- Improve fee-aware swap/bridge flows, P2P review, multi-wallet/asset handling and notification settings.
- Keep the default Solana derivation aligned with the displayed receiving address.

## Verification and distribution

- iOS Simulator build (`CODE_SIGNING_ALLOWED=NO`): succeeded.
- Unit tests (`Wpayin_WalletTests`, iPhone 17 Pro simulator): 13 passed, 0 failed.
- UI tests and on-device Face ID / passcode checks were not run for this release.

No signed IPA is included; build from source with your own signing team.
Optional API keys are read from environment variables and are not part of this repository.

Android is versioned independently in
[its own repository](https://github.com/Lakylife/wpayin-erc20-android-app).
