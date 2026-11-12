# Wpayin Wallet for iOS 1.2.0

Version 1.2.0, build 8. Released 2026-11-10.

## Changes

- Add the Quintium network (QU on mainnet, chain ID 52401; tQU on testnet, chain ID 52402).
- Show the Quintium balance, send QU/tQU and load transaction history from the node's own index (`aether_addressTxs`).
- Add Settings → Quintium to select mainnet or testnet, set the node RPC and explorer URLs and test the connection (chain ID and latest block).
- Add the Quintium QU/tQU logo to asset lists, token details and network pickers, with English and Czech translations.
- Never fall back to an Ethereum node for Quintium: without a configured node no Quintium transaction is signed or broadcast.
- Show an error instead of crashing when a network's RPC address is empty or invalid.
- Keep the original token symbol case (tQU) and the correct network icon in the grouped Home asset list.

There is no public Quintium RPC node yet; enter your own node in Settings → Quintium.
The Quintium testnet is running; mainnet starts on 1 January 2027 (00:00 UTC).

## Verification and distribution

- iOS Simulator build (`CODE_SIGNING_ALLOWED=NO`): succeeded.
- Unit tests (`Wpayin_WalletTests`, iPhone 17 Pro simulator): 14 passed, 0 failed.
- New README screenshots were taken in the simulator from the credential-free DEBUG fixture.
- Sending and history against a live Quintium node, UI tests and on-device Face ID / passcode checks were not run for this release.

No signed IPA is included; build from source with your own signing team.
Optional API keys and Quintium node URLs are read from environment variables or in-app settings and are not part of this repository.

Android is versioned independently in
[its own repository](https://github.com/Lakylife/wpayin-erc20-android-app).
