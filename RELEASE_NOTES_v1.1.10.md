# Wpayin Wallet for iOS 1.1.10

Release candidate — build 7. Prepared 2026-10-25; not yet published.

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

Swift syntax checks pass. The local Xcode build exits with code 132 before compilation;
full compilation, tests and device authentication checks are not yet verified.
No signed IPA is included. Do not mark this candidate as a stable release until the
exact release commit builds and its required tests pass.

Android is versioned independently in
[its own repository](https://github.com/Lakylife/wpayin-erc20-android-app).
