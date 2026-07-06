# Security Policy

Wpayin Wallet handles recovery phrases, private keys, addresses, and signed
transactions. Treat changes to key derivation, storage, transaction encoding,
RPC responses, and authentication as security-sensitive.

## Supported version

Security fixes are maintained for the latest release:

| Version | Supported |
| --- | --- |
| 1.1.7 | Yes |
| 1.1.6 and older | No |

## Reporting a vulnerability

Do not disclose a vulnerability, recovery phrase, private key, or API
credential in a public GitHub issue.

Report vulnerabilities through the repository's **Security → Advisories →
New draft security advisory** flow:

https://github.com/Lakylife/wpayin-erc20-ios-app/security/advisories/new

Include affected versions, reproduction steps, impact, and a proposed fix when
available. Use only test wallets and test funds in demonstrations.

## Implemented protections

- Recovery phrases and private keys are stored in the iOS Keychain using
  `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
- Existing Keychain items are migrated to the stricter accessibility class
  when read.
- App lock supports Face ID, Touch ID, and device-passcode fallback.
- The app re-locks after the configured background timeout.
- Bitcoin, Solana, and EVM accounts use chain-appropriate derivation and
  signing through Trust Wallet Core.
- No API key, recovery phrase, private key, or environment file is required in
  the repository.
- Optional provider keys are read from the local Xcode run environment and are
  never printed in request logs.

## Important limitations

- The project has not received a professional independent security audit.
- A secret embedded in an iOS application or supplied to it at runtime can be
  extracted from a compromised device.
- Public RPC and API providers can observe addresses, IP addresses, and
  request metadata.
- Biometric authentication reduces casual access but does not make a
  jailbroken or compromised device trustworthy.
- Users must verify the destination address, network, token, amount, fee, and
  slippage before signing.
- Cross-chain bridge routes and P2P settlement depend on third-party smart
  contracts and provider responses. Verify every review screen and use small
  test amounts before committing significant funds.

## Repository hygiene

Before publishing a change:

1. Build the exact commit intended for release.
2. Review `git diff --cached` and `git ls-files`.
3. Scan tracked text for credentials, private keys, and recovery phrases.
4. Confirm `.env*`, `*.xcconfig`, `Secrets.swift`, `xcuserdata/`, `backups/`,
   and local work artifacts are not tracked.
5. Confirm screenshots contain no sensitive wallet information.
6. Tag only the reviewed release commit.

If a credential or wallet secret is exposed, assume it is compromised. Move
funds to a newly generated wallet when wallet material is involved, rotate
provider credentials, remove the data from the current tree, and review Git
history and release assets for copies.

Last reviewed: 2026-07-06
