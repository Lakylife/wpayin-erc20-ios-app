# Wpayin Wallet for iOS 1.3.0

Version 1.3.0, build 9. Released 2026-11-12.

## Changes

- Add Quintium Swap on the Quintium testnet (router `0xfee495049060F02Fc9Ef91e179fF48E8a7471E95`, wrapped native coin WAET). Token ↔ token swaps are routed through WAET.
- Add Quintium to the All Assets network filter and to the Swap network list.
- Select the native coin (tQU) first when Swap opens on Quintium, and keep the lowercase `t` in Quintium testnet symbols.
- Show tQU as one grouped asset with the Quintium icon; Quintium assets are never priced by symbol against unrelated market coins.
- Fill in the block explorer address automatically from the node's RPC address (the explorer built into the node) when the explorer field is left empty.
- Explain in Settings → Quintium how to reach your node: the local address at home, the public IP address of your connection away from home.
- Show a note in Bridge and P2P that they are not available on Quintium yet (Bridge needs independent validators, P2P needs the swap contract on the network).
- The Quintium testnet was restarted (testnet-4). The app ships no preset Quintium tokens; add your own with Add Token.

There is still no public Quintium RPC node; enter your own node in Settings → Quintium.
Quintium Swap is available on the testnet only; mainnet starts on 1 January 2027 (00:00 UTC).

## Verification and distribution

- iOS Simulator build (`CODE_SIGNING_ALLOWED=NO`): succeeded.
- Unit tests (`Wpayin_WalletTests`, iPhone 17 Pro simulator): 14 passed, 0 failed.
- New README screenshots were taken in the simulator from the credential-free DEBUG fixture.
- Swaps against a live Quintium node, UI tests and on-device Face ID / passcode checks were not run for this release.

No signed IPA is included; build from source with your own signing team.
Optional API keys and Quintium node URLs are read from environment variables or in-app settings and are not part of this repository.

Android is versioned independently in
[its own repository](https://github.com/Lakylife/wpayin-erc20-android-app).
