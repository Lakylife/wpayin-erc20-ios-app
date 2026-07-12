# Wpayin Wallet 1.1.8

## Send and transaction tracking

- Uses live network gas pricing with Slow, Standard, and Fast choices.
- Allows changing gas speed directly from the final confirmation screen.
- Calculates Max after reserving network gas and any enabled platform fee.
- Simulates EVM transfers before broadcast and applies a safety buffer to the
  estimated gas limit, preventing avoidable on-chain reverts.
- Adds every broadcast transaction to Activity immediately as Pending.
- Shows transaction hash, explorer link, progress, amount, recipient, gas, and
  final Confirmed or Failed status.
- Updates the sending balance immediately and reconciles it with authoritative
  blockchain data after the transaction receipt arrives.

## Wallet reliability

- Restores account-scoped last-known holdings on launch so balances do not
  flash empty during network refreshes.
- Keeps cached balances visible through temporary RPC and API failures.
- Adds a branded launch experience with a deliberate minimum display time.
- Improves wallet switching, price refreshes, transaction history, and
  multi-network data merging.

## Swap, bridge, and P2P

- Improves live swap quotes, fee estimation, approvals, progress, and review.
- Expands cross-chain bridge handling and progress tracking.
- Adds the optional PostgREST-backed public P2P offer board while preserving
  private signed QR/code offers.

## Security and public repository hygiene

- Removes provider endpoints, client keys, and treasury values from source.
- Optional services use runtime environment variables and remain disabled when
  their configuration is absent.
- Excludes local environment files, Xcode user data, backups, build artifacts,
  and AI-assistant work folders from the public repository.

> This project has not received a professional security audit. Use test
> accounts and small amounts only.
