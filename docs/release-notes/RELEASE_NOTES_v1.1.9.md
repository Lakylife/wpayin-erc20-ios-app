# Wpayin Wallet 1.1.9 (Build 6)

Release date: July 15, 2026

## Wallet and asset experience

- Redesigned Deposit as a bottom sheet with asset and network selection,
  network switching, a larger QR code, receiving address copy, and sharing.
- Simplified Withdraw into clear recipient, amount, network-fee, and review
  steps, including saved addresses and reliable keyboard dismissal.
- Improved automatic asset/network matching and fee-aware Max calculations.
- Redesigned asset details with Home-style Receive, Send, and Swap actions,
  network distribution, recent activity, and a balance-history chart.
- Added network and date filters to the complete transaction history.
- Added custom-token discovery by contract address, metadata/icon loading, and
  the ability to remove a token from Your Assets without affecting on-chain
  funds.

## Swap, Bridge, Send, and P2P

- Added searchable token pickers with favorite and network filters.
- Improved compatible destination-asset selection for same-network swaps.
- Improved bridge route review, source/destination status tracking, and
  fee-aware maximum amounts.
- Prevented Max from spending native gas reserves when the fee must come from
  the same balance.
- Added disclosed application-development fee handling to supported Send,
  Swap, Bridge, and P2P operations.
- Improved public and private P2P offers, market pricing, validation,
  simulation, cancellation, and atomic on-chain settlement status.

## Request Payment and WalletConnect

- Added Request Payment QR codes and links containing asset, network, optional
  amount, note, and expiry.
- Added optional wallet-side WalletConnect support through Reown WalletKit.
- Connection proposals show the dApp identity, networks, methods, and events
  before approval.
- Signature and transaction requests require an explicit review screen and
  the configured spending authorization.
- Unsupported JSON-RPC methods are rejected rather than signed silently.
- WalletConnect remains disabled until its public Project ID is supplied by
  the local or release build environment; no private credential is committed.

## Security and privacy

- Face ID or Touch ID now protects transaction signing for Send, Swap, Bridge,
  P2P, WalletConnect, and on-chain P2P cancellation when biometric protection
  is enabled.
- Added automatic iPhone time-zone handling, including daylight-saving
  changes, plus searchable manual selection such as Europe/Prague.
- Added NFT spam filtering using provider classification where available and
  conservative local phishing heuristics as a fallback.
- Suspicious NFTs are hidden from the main gallery but remain reviewable; a
  user can restore a false positive or manually hide an unwanted NFT.
- Hiding an NFT changes only the local UI and never transfers or burns it.
- Sensitive wallet material remains local to the device and is never required
  for Request Payment or WalletConnect configuration.

## Interface, Help, and accessibility

- Refined the launch screen with a slightly longer minimum duration, a subtle
  orbit effect, and no dark tile behind the logo.
- Replaced visible “Syncing” labels with clearer loading and refresh language.
- Expanded Help Center articles across the existing Getting Started, Wallet
  Security, Sending & Receiving, and NFT categories.
- Added a selectable in-app version history under About for versions 1.1.0
  through 1.1.9.
- Added Czech localization for new settings, security, release-history, and
  NFT-spam-protection content, with safe English fallback in other locales.

## Validation

- Generic iOS Simulator build completed successfully with code signing
  disabled.
- NFT spam-filter unit tests cover provider classification, phishing reward
  text, legitimate airdrops, and sparse metadata false positives.
- Localization property lists pass validation.

## Security notice

This project has not received a professional security audit. Use test
accounts and small amounts. Never share a recovery phrase or private key, and
do not connect a wallet or sign a request to claim an unknown NFT reward.
