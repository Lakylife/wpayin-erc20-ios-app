// Autor Lukas Helebrandt, 2026

import SwiftUI

struct VersionHistoryView: View {
    @State private var selectedVersion = AppReleaseInfo.releases[0].version

    private var selectedRelease: AppReleaseInfo {
        AppReleaseInfo.releases.first { $0.version == selectedVersion } ?? AppReleaseInfo.releases[0]
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [WpayinColors.backgroundGradientStart, WpayinColors.backgroundGradientEnd],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Release Notes".localized)
                            .font(.wpayinTitle)
                            .foregroundColor(WpayinColors.text)

                        Text("Choose a version to see what changed.".localized)
                            .font(.wpayinBody)
                            .foregroundColor(WpayinColors.textSecondary)
                    }

                    versionPicker
                    releaseCard(selectedRelease)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Version History".localized)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var versionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(AppReleaseInfo.releases) { release in
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            selectedVersion = release.version
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if release.isCurrent {
                                Circle()
                                    .fill(selectedVersion == release.version ? Color.white : WpayinColors.success)
                                    .frame(width: 6, height: 6)
                            }

                            Text(release.version)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(selectedVersion == release.version ? .white : WpayinColors.textSecondary)
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                        .background(
                            Capsule()
                                .fill(selectedVersion == release.version ? WpayinColors.primary : WpayinColors.surface)
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            selectedVersion == release.version ? Color.clear : WpayinColors.surfaceBorder,
                                            lineWidth: 1
                                        )
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    private func releaseCard(_ release: AppReleaseInfo) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("Version %@".localized(release.version))
                            .font(.wpayinHeadline)
                            .foregroundColor(WpayinColors.text)

                        if release.isCurrent {
                            Text("CURRENT".localized)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(WpayinColors.success)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(WpayinColors.success.opacity(0.12)))
                        }
                    }

                    Text(release.date.localized)
                        .font(.wpayinCaption)
                        .foregroundColor(WpayinColors.textSecondary)
                }

                Spacer()

                Image(systemName: release.isCurrent ? "sparkles" : "clock.arrow.circlepath")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundColor(WpayinColors.primary)
            }

            Text(release.summary.localized)
                .font(.wpayinBody)
                .foregroundColor(WpayinColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(WpayinColors.surfaceBorder)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(release.changes.enumerated()), id: \.offset) { index, change in
                    HStack(alignment: .top, spacing: 13) {
                        ZStack {
                            Circle()
                                .fill(WpayinColors.primary.opacity(0.12))
                                .frame(width: 30, height: 30)

                            Image(systemName: change.icon)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(WpayinColors.primary)
                        }

                        Text(change.text.localized)
                            .font(.wpayinBody)
                            .foregroundColor(WpayinColors.text)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(index + 1). \(change.text.localized)")
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(WpayinColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                )
        )
    }
}

private struct AppReleaseChange {
    let icon: String
    let text: String
}

private struct AppReleaseInfo: Identifiable {
    let version: String
    let date: String
    let summary: String
    let changes: [AppReleaseChange]
    let isCurrent: Bool

    var id: String { version }

    static let releases: [AppReleaseInfo] = [
        AppReleaseInfo(
            version: "1.4.1",
            date: "2026-11-14",
            summary: "New Quinvium logo and mainnet by default.",
            changes: [
                .init(icon: "hexagon", text: "Quinvium has a new logo: the letter Q as a hexagon in Quinvium yellow."),
                .init(icon: "network", text: "Quinvium mainnet (QU, chain ID 52401) is live; the wallet connects to rpc.quinvium.com and explorer.quinvium.com.")
            ],
            isCurrent: true
        ),
        AppReleaseInfo(
            version: "1.4.0",
            date: "2026-11-13",
            summary: "Quintium is now called Quinvium.",
            changes: [
                .init(icon: "textformat", text: "Quintium is now called Quinvium. The coin, addresses and your node settings stay the same."),
                .init(icon: "lock.shield", text: "Plain http is blocked except for local addresses and your own Quinvium node."),
                .init(icon: "exclamationmark.triangle", text: "Adding a Quinvium token that is not on the token registry shows a warning.")
            ],
            isCurrent: false
        ),
        AppReleaseInfo(
            version: "1.3.2",
            date: "2026-11-12",
            summary: "Your own Quintium node can be reached over http.",
            changes: [
                .init(icon: "network", text: "A Quintium node address starting with http:// now works, also on mobile data with a public IP address."),
                .init(icon: "lock.open", text: "Settings → Quintium warns when the node connection is not encrypted.")
            ],
            isCurrent: false
        ),
        AppReleaseInfo(
            version: "1.3.1",
            date: "2026-11-12",
            summary: "Added P2P trading on the Quintium testnet.",
            changes: [
                .init(icon: "person.2.fill", text: "P2P trading now works on the Quintium testnet."),
                .init(icon: "gift", text: "tQU is wrapped to WQU automatically (1:1) when you trade it."),
                .init(icon: "percent", text: "The P2P contract on Quintium charges no protocol fee."),
                .init(icon: "wrench.and.screwdriver", text: "Fixed a crash when adding a token with a large balance, and custom tokens now show the balance of the active account.")
            ],
            isCurrent: false
        ),
        AppReleaseInfo(
            version: "1.3.0",
            date: "2026-11-12",
            summary: "Added Quintium Swap on testnet and Quintium in network filters.",
            changes: [
                .init(icon: "arrow.triangle.2.circlepath", text: "Added Quintium Swap on the Quintium testnet."),
                .init(icon: "line.3.horizontal.decrease.circle", text: "Added Quintium to the All Assets network filter and the Swap network list."),
                .init(icon: "safari", text: "The explorer address is filled in automatically from your node address."),
                .init(icon: "network", text: "Settings → Quintium explains how to connect to your node from outside your home network.")
            ],
            isCurrent: false
        ),
        AppReleaseInfo(
            version: "1.2.0",
            date: "2026-11-10",
            summary: "Added the Quintium network with your own node, balance, sending and history.",
            changes: [
                .init(icon: "pentagon.fill", text: "Added Quintium (QU, testnet tQU) with balance, sending and transaction history from the node."),
                .init(icon: "server.rack", text: "Added Settings → Quintium to choose the network, set your node and test the connection."),
                .init(icon: "checkmark.shield.fill", text: "Quintium never falls back to an Ethereum node, and an empty RPC address no longer crashes the app."),
                .init(icon: "globe", text: "Added the QU/tQU logo and English and Czech translations.")
            ],
            isCurrent: false
        ),
        AppReleaseInfo(
            version: "1.1.10",
            date: "2026-10-25",
            summary: "Improved wallet security, account handling and transaction review.",
            changes: [
                .init(icon: "faceid", text: "Added fresh device authentication for wallet secret export."),
                .init(icon: "doc.on.clipboard", text: "Secret clipboard copies stay on this device and expire after 30 seconds."),
                .init(icon: "lock.fill", text: "Corrected Auto-Lock timing and active-account private-key export."),
                .init(icon: "arrow.clockwise", text: "Prevented delayed network responses from changing another wallet.")
            ],
            isCurrent: false
        ),
        AppReleaseInfo(
            version: "1.1.9",
            date: "July 15, 2026",
            summary: "A major wallet experience update focused on clearer flows, safer signing and better multi-network control.",
            changes: [
                .init(icon: "arrow.down.circle", text: "Redesigned Deposit and Receive with asset and network selection, a larger QR code and shareable receiving details."),
                .init(icon: "arrow.up.circle", text: "Simplified Withdraw with separate recipient, amount and network-fee steps, improved MAX handling and keyboard dismissal."),
                .init(icon: "arrow.triangle.2.circlepath", text: "Improved Swap and Bridge asset filtering, network selection, route review and fee-aware maximum amounts."),
                .init(icon: "chart.xyaxis.line", text: "Redesigned asset details with a balance-history chart and network-aware transaction history with date filters."),
                .init(icon: "plus.circle", text: "Added custom-token metadata loading and the option to remove assets from Your Assets without affecting blockchain funds."),
                .init(icon: "qrcode", text: "Added Request Payment links and QR codes with asset, network, amount, note and expiry."),
                .init(icon: "link", text: "Added WalletConnect for reviewing dApp connections, signatures and transaction requests."),
                .init(icon: "faceid", text: "Added Face ID verification for transaction signing, selectable time zones and a refined launch experience."),
                .init(icon: "checkmark.shield.fill", text: "Added NFT spam filtering with a reviewable hidden folder and manual hide or restore controls.")
            ],
            isCurrent: false
        ),
        AppReleaseInfo(
            version: "1.1.8",
            date: "July 12, 2026",
            summary: "This release made sends and transaction tracking more reliable while improving wallet restoration.",
            changes: [
                .init(icon: "fuelpump.fill", text: "Added live network fees with Slow, Standard and Fast choices plus fee-aware MAX calculations."),
                .init(icon: "checkmark.shield.fill", text: "Added EVM transaction simulation and safer gas-limit estimation before broadcast."),
                .init(icon: "clock.fill", text: "Newly sent transactions appear immediately in Activity and update automatically to Confirmed or Failed."),
                .init(icon: "externaldrive.fill", text: "Restored last-known balances on launch and preserved cached balances through temporary provider failures."),
                .init(icon: "arrow.triangle.branch", text: "Improved Swap, Bridge, P2P, wallet switching and multi-network reliability.")
            ],
            isCurrent: false
        ),
        AppReleaseInfo(
            version: "1.1.7",
            date: "July 6, 2026",
            summary: "Cross-chain bridging, atomic P2P trading and network-aware activity arrived in this release.",
            changes: [
                .init(icon: "point.3.connected.trianglepath.dotted", text: "Added cross-chain bridging through LI.FI across major EVM networks."),
                .init(icon: "person.2.fill", text: "Replaced Buy with signed atomic P2P token offers, including QR sharing, verification and cancellation."),
                .init(icon: "network", text: "Added RPC failover and prevented failed requests from replacing known balances with zero."),
                .init(icon: "line.3.horizontal.decrease.circle", text: "Added network filters, icons and correct explorer links to Activity."),
                .init(icon: "chart.line.uptrend.xyaxis", text: "Added live token prices and real 24-hour price-change indicators.")
            ],
            isCurrent: false
        ),
        AppReleaseInfo(
            version: "1.1.6",
            date: "July 2, 2026",
            summary: "A security and signing release that hardened private-key storage and repaired core transaction flows.",
            changes: [
                .init(icon: "lock.shield.fill", text: "Hardened Keychain storage so recovery phrases and private keys remain tied to the device."),
                .init(icon: "faceid", text: "Enforced Face ID or Touch ID app locking with device-passcode fallback."),
                .init(icon: "signature", text: "Reworked EVM and Bitcoin transaction signing with Trust Wallet Core."),
                .init(icon: "arrow.triangle.2.circlepath", text: "Fixed ERC-20 allowance, approval, quote and swap transaction handling."),
                .init(icon: "wallet.pass.fill", text: "Fixed EVM, Bitcoin and Solana address derivation and active-account spending.")
            ],
            isCurrent: false
        ),
        AppReleaseInfo(
            version: "1.1.5",
            date: "June 9, 2026",
            summary: "This update polished network-aware wallet flows, token icons and wallet restoration.",
            changes: [
                .init(icon: "photo.fill", text: "Fixed WETH, Solana, USDT and USDC icons across wallet and asset selectors."),
                .init(icon: "network", text: "Made Send, Receive and Swap resolve the correct chain, fees and token set."),
                .init(icon: "arrow.clockwise", text: "Improved wallet import, relogin and restoration of addresses and chain state."),
                .init(icon: "qrcode.viewfinder", text: "Added camera QR scanning for recipient addresses."),
                .init(icon: "rectangle.3.group.fill", text: "Refined bottom navigation, wallet controls and asset-row spacing.")
            ],
            isCurrent: false
        ),
        AppReleaseInfo(
            version: "1.1.4",
            date: "November 9, 2025",
            summary: "The first in-app Help Center and a broader network-icon system were introduced here.",
            changes: [
                .init(icon: "questionmark.circle.fill", text: "Added the searchable in-app Help Center with articles grouped by topic."),
                .init(icon: "photo.fill", text: "Added higher-quality blockchain network icons with reliable fallbacks."),
                .init(icon: "network", text: "Improved network selectors in Settings and Swap."),
                .init(icon: "wrench.and.screwdriver.fill", text: "Improved asset loading priority and missing-icon error handling.")
            ],
            isCurrent: false
        ),
        AppReleaseInfo(
            version: "1.1.0",
            date: "November 9, 2025",
            summary: "This foundational multi-chain release introduced Bitcoin, real DEX swaps and multi-account wallets.",
            changes: [
                .init(icon: "bitcoinsign.circle.fill", text: "Added native Bitcoin SegWit addresses, balances, sending and receiving."),
                .init(icon: "arrow.triangle.2.circlepath", text: "Added real on-chain DEX swaps with quotes, slippage protection and gas estimation."),
                .init(icon: "paperplane.fill", text: "Added native-token and ERC-20 transaction signing and sending."),
                .init(icon: "network", text: "Added multi-network RPC management and EIP-1559 fee support."),
                .init(icon: "person.crop.circle.badge.plus", text: "Added HD multi-account wallets with independent blockchain addresses.")
            ],
            isCurrent: false
        )
    ]
}
