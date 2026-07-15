# WalletConnect production setup

The app integrates the wallet-side Reown WalletKit SDK. It stays disabled when no public Project ID is configured; Request Payment continues to work without it.

## 1. Reown Cloud

1. Create a project at Reown Cloud and copy its public Project ID.
2. Register the production bundle/app metadata and the native redirect `wpayin://wc`.
3. Keep the website and icon URLs in `WalletConnectService.swift` valid and publicly reachable.

The Project ID identifies the project; it is not a private signing secret. Never put a Reown secret or a wallet private key in build settings.

## 2. Xcode build setting

Set `WALLETCONNECT_PROJECT_ID` for the Release configuration (and Debug when testing). The generated Info.plist exposes it to `AppConfig` as `WALLETCONNECT_PROJECT_ID`.

Local runs may instead set the `WALLETCONNECT_PROJECT_ID` environment variable in the active Xcode scheme.

## 3. App Group and signing

Enable the App Groups capability for the production App ID and provisioning profile, using exactly:

`group.io.noriskservis.standart.Wpayin-Wallet`

The repository already contains this value in `Wpayin_Wallet/Wpayin_Wallet.entitlements`. A signed device/archive build will fail until the group is enabled for the Apple Developer App ID and the provisioning profile is regenerated.

## 4. Required release checks

- Pair through both a WalletConnect QR code and a `wc:`/native deep link.
- Confirm that a connection proposal lists its networks and methods before approval.
- Test `personal_sign`, EIP-712 typed-data signing, and `eth_sendTransaction` on every supported EVM network.
- Confirm unknown origins are visibly warned and invalid/scam verification results cannot be approved.
- Confirm every signature/transaction requires an explicit screen plus the configured spending authorization.
- Disconnect sessions and verify they disappear from Settings > WalletConnect.
- Complete App Store privacy answers for the app's actual data practices; the SDK privacy manifest does not replace the app-level disclosure.

## Scope

This integration intentionally rejects unsupported JSON-RPC methods. It does not silently sign messages, approve token allowances, or execute arbitrary methods outside the explicit allowlist.
