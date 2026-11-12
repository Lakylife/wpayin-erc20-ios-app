# Wpayin Wallet for iOS 1.3.1

Version 1.3.1, build 10. Released 2026-11-12.

## Changes

- Add P2P trading on the Quintium testnet. Offers settle atomically through
  AirSwap SwapERC20 v4.3 at `0x60FD058c896B7E039363F07485016116f915ae02`
  (bytecode of the official 4.3.1 release, EIP-712 domain `SWAP_ERC20` / `4.3`,
  chain ID 52402). The protocol fee on this deployment is zero.
- tQU is wrapped to WQU (`0xae0000000000000000000000000000000000000a`)
  automatically, 1:1, when it is sold or used to pay in a P2P offer.
- P2P on Quintium follows the active Quintium network: mainnet has no P2P
  contract yet, so Quintium is not offered there. The "not available" note was
  removed from P2P; Bridge still shows it.
- Fix a crash when adding a custom token whose balance is above about 9.2
  tokens (18 decimals). Hex balances are converted with arbitrary precision.
- Custom tokens show the balance of the active account. Before, they kept the
  balance stored when the token was added, also in other accounts.
- The "You receive" amount in P2P Sell can be typed again, so the seller can
  set a custom price (the field was read-only).

There is still no public Quintium RPC node; enter your own node in
Settings → Quintium. Mainnet starts on 1 January 2027 (00:00 UTC).

## Verification and distribution

- iOS Simulator build (`CODE_SIGNING_ALLOWED=NO`): succeeded.
- Unit tests (`Wpayin_WalletTests`, iPhone 17 Pro simulator): 16 passed,
  0 failed, including new tests for the Quintium P2P configuration (testnet
  contract and WQU, nothing on mainnet) and for large hex balances.
- Live P2P test in the simulator against a temporary local Quintium testnet-4
  node, with two throwaway wallets created in the app: the seller sold 1 tQU
  (auto-wrapped to WQU, approve) for 10 test tokens; the buyer pasted the
  offer code, the app verified it on-chain and settled it with `swapAnySender`.
  Balances changed on both sides as offered, and pasting the same offer again
  was rejected as already used. Offer cancellation was not tested live.
- UI tests and on-device Face ID / passcode checks were not run for this
  release.

No signed IPA is included; build from source with your own signing team.
Optional API keys and Quintium node URLs are read from environment variables
or in-app settings and are not part of this repository.

Android is versioned independently in
[its own repository](https://github.com/Lakylife/wpayin-erc20-android-app).
