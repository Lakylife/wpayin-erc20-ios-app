# Wpayin Wallet 1.4.0 (build 13)

Date: 2026-11-13

## Changes

- Quintium is now called **Quinvium**. Only the visible name changed. The coin
  (QU, testnet tQU), chain IDs 52401 and 52402, addresses, saved node settings
  and stored data stay the same.
- Plain `http://` is blocked for every network except local addresses and the
  Quinvium node set in Settings → Quinvium.
- Adding a Quinvium token that is not listed in the network's token registry
  shows a warning.

## Kept on purpose

Swift type names (`QuintiumNetwork`, `QuintiumSettings`), UserDefaults keys
(`Quintium.*`), Info.plist keys (`QUINTIUM_*`), asset names and the stored raw
value `quintium` keep the old name so existing settings and data load unchanged.
