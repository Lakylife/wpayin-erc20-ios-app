// Autor Lukas Helebrandt, 2026

//
//  WalletView.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI

struct WalletView: View {
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var showDepositSheet = false
    @State private var showWithdrawSheet = false
    @State private var showSwapSheet = false
    @State private var showAddToken = false
    @State private var showBuy = false
    @State private var showCreateWallet = false
    @State private var showImportWallet = false
    @State private var showMenuSheet = false
    @State private var showAllAssets = false
    @State private var selectedToken: Token?
    @State private var showWalletSelector = false
    @State private var showQRScanner = false
    @State private var scannedRecipientAddress = ""

    var body: some View {
        ZStack {
            HomeAmbientBackground()

            VStack(spacing: 0) {
                ModernHeaderView(
                    walletManager: walletManager,
                    onMenuTap: { showMenuSheet = true },
                    onQRTap: { showQRScanner = true },
                    onWalletTap: { showWalletSelector = true }
                )
                .zIndex(1)

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ModernBalanceCardView(
                            balance: totalPortfolioValue,
                            isLoading: walletManager.isLoading
                        )
                        .environmentObject(walletManager)
                        .environmentObject(settingsManager)

                        ModernQuickActionsView(
                            onSend: { showWithdrawSheet = true },
                            onReceive: { showDepositSheet = true },
                            onBuy: { showBuy = true },
                            onSwap: { showSwapSheet = true }
                        )

                        ModernTabsView(
                            tokens: walletManager.visibleGroupedTokens,
                            isLoading: walletManager.isLoading,
                            onTokenTap: { token in
                                selectedToken = token
                            },
                            onViewAllTap: { showAllAssets = true }
                        )
                        .environmentObject(walletManager)
                        .environmentObject(settingsManager)

                        Color.clear.frame(height: 32)
                    }
                }
                .refreshable {
                    await walletManager.refreshWalletData()
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showDepositSheet) {
            DepositView()
                .environmentObject(walletManager)
                .environmentObject(settingsManager)
        }
        .sheet(isPresented: $showWithdrawSheet) {
            WithdrawView(initialRecipientAddress: scannedRecipientAddress)
                .environmentObject(walletManager)
                .environmentObject(settingsManager)
        }
        .sheet(isPresented: $showQRScanner) {
            QRScannerView(scannedAddress: $scannedRecipientAddress) { scannedAddress in
                scannedRecipientAddress = scannedAddress
                showQRScanner = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    showWithdrawSheet = true
                }
            }
        }
        .sheet(isPresented: $showAddToken) {
            AddTokenView()
                .environmentObject(walletManager)
        }
        .sheet(isPresented: $showBuy) {
            BuyView()
                .environmentObject(walletManager)
                .environmentObject(settingsManager)
        }
        .sheet(isPresented: $showSwapSheet) {
            SwapView()
                .environmentObject(walletManager)
                .environmentObject(settingsManager)
        }
        .sheet(isPresented: $showAllAssets) {
            AllAssetsView()
                .environmentObject(walletManager)
                .environmentObject(settingsManager)
        }
        .sheet(item: $selectedToken) { token in
            AssetDetailView(token: token)
                .environmentObject(walletManager)
                .environmentObject(settingsManager)
        }
        .sheet(isPresented: $showWalletSelector) {
            WalletSelectorView()
                .environmentObject(walletManager)
                .environmentObject(settingsManager)
        }
        .sheet(isPresented: $showCreateWallet) {
            CreateWalletFlow()
                .environmentObject(walletManager)
        }
        .sheet(isPresented: $showImportWallet) {
            ImportWalletView()
                .environmentObject(walletManager)
        }
        .confirmationDialog(
            walletManager.hasWallet ? "Wallet Options".localized : "Connect Wallet".localized,
            isPresented: $showMenuSheet,
            titleVisibility: .visible
        ) {
            if walletManager.hasWallet {
                Button("Add Token".localized) { showAddToken = true }
                Button("Manage Wallets".localized) { showWalletSelector = true }
                Button("Cancel".localized, role: .cancel) { }
            } else {
                Button("Create New Wallet".localized) { showCreateWallet = true }
                Button("Import Existing Wallet".localized) { showImportWallet = true }
                Button("Cancel".localized, role: .cancel) { }
            }
        }
        .task {
            if walletManager.walletAddress.isEmpty {
                await walletManager.checkExistingWallet()
            }
        }
    }

    private var totalPortfolioValue: Double {
        walletManager.visibleGroupedTokens.reduce(0) { $0 + $1.totalValue }
    }
}

private struct HomeAmbientBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    WpayinColors.backgroundGradientStart,
                    WpayinColors.background
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(WpayinColors.primary.opacity(0.15))
                .frame(width: 300, height: 300)
                .blur(radius: 90)
                .offset(x: 150, y: -270)

            Circle()
                .fill(WpayinColors.accent.opacity(0.08))
                .frame(width: 240, height: 240)
                .blur(radius: 100)
                .offset(x: -170, y: 260)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct WalletHeaderView: View {
    let address: String
    let totalBalance: Double
    @State private var showFullAddress = false
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        VStack(spacing: 20) {
            // Balance Card
            VStack(spacing: 16) {
                Text(L10n.Wallet.totalBalance.localized)
                    .font(.wpayinBody)
                    .foregroundColor(WpayinColors.textSecondary)

                Text(totalBalance.formatted(as: settingsManager.selectedCurrency))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(WpayinColors.text)

                // Balance change percentage
                if abs(walletManager.balanceChangePercentage) > 0.01 {
                    HStack(spacing: 4) {
                        Image(systemName: walletManager.balanceChangePercentage >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 12, weight: .bold))
                        Text(String(format: "%.2f%%", abs(walletManager.balanceChangePercentage)))
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(walletManager.balanceChangePercentage >= 0 ? WpayinColors.success : WpayinColors.error)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        (walletManager.balanceChangePercentage >= 0 ? WpayinColors.success : WpayinColors.error)
                            .opacity(0.15)
                    )
                    .cornerRadius(12)
                }

                // Address
                Button(action: {
                    showFullAddress.toggle()
                }) {
                    HStack(spacing: 8) {
                        Text(showFullAddress ? address : formatAddress(address))
                            .font(.wpayinCaption)
                            .foregroundColor(WpayinColors.textSecondary)

                        Button(action: {
                            AppToast.copyToClipboard(address)
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 12))
                                .foregroundColor(WpayinColors.primary)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(24)
            .background(WpayinColors.surface)
            .cornerRadius(20)
        }
    }

    private func formatAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        return "\(address.prefix(6))...\(address.suffix(4))"
    }
}

struct ActionButtonsView: View {
    let onDeposit: () -> Void
    let onWithdraw: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            ActionButton(
                icon: "arrow.down.circle.fill",
                title: "Deposit",
                color: WpayinColors.success,
                action: onDeposit
            )

            ActionButton(
                icon: "arrow.up.circle.fill",
                title: "Withdraw",
                color: WpayinColors.primary,
                action: onWithdraw
            )
        }
    }
}

struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)

                Text(title.localized)
                    .font(.wpayinBody)
                    .foregroundColor(WpayinColors.text)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(WpayinColors.surface)
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TokensListView: View {
    let tokens: [Token]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Assets".localized)
                .font(.wpayinHeadline)
                .foregroundColor(WpayinColors.text)

            LazyVStack(spacing: 12) {
                ForEach(tokens) { token in
                    TokenRowView(token: token)
                }
            }
        }
    }
}

struct TokenRowView: View {
    let token: Token
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        HStack(spacing: 16) {
            // Token Icon
            TokenIconView(token: token, size: 44, showNetworkBadge: true)

            // Token Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(token.name)
                        .font(.wpayinBody)
                        .foregroundColor(WpayinColors.text)
                    
                    if let proto = token.tokenProtocol {
                        TokenProtocolBadge(tokenProtocol: proto, size: .small)
                    }
                }

                Text(token.symbol)
                    .font(.wpayinCaption)
                    .foregroundColor(WpayinColors.textSecondary)
            }

            Spacer()

            // Balance and Value
            VStack(alignment: .trailing, spacing: 4) {
                Text(TokenIconHelper.formattedBalance(token.balance))
                    .font(.wpayinBody)
                    .foregroundColor(WpayinColors.text)

                Text(token.totalValue.formatted(as: settingsManager.selectedCurrency))
                    .font(.wpayinCaption)
                    .foregroundColor(WpayinColors.textSecondary)
            }
        }
        .padding(16)
        .background(WpayinColors.surface)
        .cornerRadius(12)
    }
}

// MARK: - Modern Components

struct ModernHeaderView: View {
    @ObservedObject var walletManager: WalletManager
    let onMenuTap: () -> Void
    let onQRTap: () -> Void
    let onWalletTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HeaderIconButton(
                    icon: "line.3.horizontal",
                    action: onMenuTap
                )

                Button(action: onWalletTap) {
                    HStack(spacing: 10) {
                        WpayinLogoView(size: 30)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(walletName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(WpayinColors.text)
                                .lineLimit(1)

                            Text(formattedAddress)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(WpayinColors.textSecondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 4)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(WpayinColors.textTertiary)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(
                        Capsule()
                            .fill(WpayinColors.surfaceLight)
                            .overlay(
                                Capsule()
                                    .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(WpayinPressableStyle())
                .contextMenu {
                    Button {
                        AppToast.copyToClipboard(walletManager.walletAddress)
                    } label: {
                        Label(L10n.Action.copy.localized, systemImage: "doc.on.doc")
                    }
                    .disabled(walletManager.walletAddress.isEmpty)
                }

                HeaderIconButton(
                    icon: "qrcode.viewfinder",
                    action: onQRTap
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .background(
            LinearGradient(
                colors: [
                    WpayinColors.background.opacity(0.92),
                    WpayinColors.background.opacity(0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var walletName: String {
        (walletManager.activeWallet?.name ?? L10n.Wallet.mainWallet).localized
    }

    private var formattedAddress: String {
        let address = walletManager.walletAddress
        guard !address.isEmpty else { return "—" }
        guard address.count > 10 else { return address }
        return "\(address.prefix(6))...\(address.suffix(4))"
    }
}

private struct HeaderIconButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(WpayinColors.text)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(WpayinColors.surfaceLight)
                        .overlay(
                            Circle()
                                .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(WpayinPressableStyle())
    }
}

struct ModernBalanceCardView: View {
    let balance: Double
    let isLoading: Bool
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var isBalanceHidden = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label {
                    Text(L10n.Wallet.totalBalance.localized)
                        .font(.system(size: 13, weight: .semibold))
                } icon: {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(WpayinColors.primary)
                }
                .foregroundColor(WpayinColors.textSecondary)

                Spacer()

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: WpayinColors.primary))
                        .scaleEffect(0.75)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isBalanceHidden.toggle()
                    }
                } label: {
                    Image(systemName: isBalanceHidden ? "eye.slash" : "eye")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(WpayinColors.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.white.opacity(0.05)))
                }
                .buttonStyle(WpayinPressableStyle())
                .accessibilityLabel(L10n.Wallet.totalBalance.localized)
            }

            Text(isBalanceHidden ? "••••••" : balance.formatted(as: settingsManager.selectedCurrency))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(WpayinColors.text)
                .lineLimit(1)
                .minimumScaleFactor(0.55)

            HStack(spacing: 10) {
                if abs(walletManager.balanceChangePercentage) > 0.01 {
                    HStack(spacing: 4) {
                        Image(systemName: walletManager.balanceChangePercentage >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))

                        Text(String(format: "%.2f%%", abs(walletManager.balanceChangePercentage)))
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(walletManager.balanceChangePercentage >= 0 ? WpayinColors.success : WpayinColors.error)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(
                                (walletManager.balanceChangePercentage >= 0 ? WpayinColors.success : WpayinColors.error)
                                    .opacity(0.12)
                            )
                    )
                }

                if !isBalanceHidden,
                   balance > 0,
                   let ethToken = walletManager.visibleTokens.first(where: { $0.symbol == "ETH" }),
                   ethToken.price > 0 {
                    Text(String(format: "≈ %.4f ETH", balance / ethToken.price))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(WpayinColors.textSecondary)
                } else {
                    Text(isLoading ? L10n.Wallet.syncing.localized : L10n.Wallet.portfolioUpToDate.localized)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(WpayinColors.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.085),
                                Color.white.opacity(0.035)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .fill(WpayinColors.primary.opacity(0.20))
                    .frame(width: 150, height: 150)
                    .blur(radius: 45)
                    .offset(x: 50, y: -70)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.16),
                                WpayinColors.primary.opacity(0.10),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        )
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 22)
    }
}

struct ModernQuickActionsView: View {
    let onSend: () -> Void
    let onReceive: () -> Void
    let onBuy: () -> Void
    let onSwap: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            QuickActionButton(
                icon: "arrow.up",
                title: L10n.Action.send.localized,
                action: onSend
            )

            QuickActionButton(
                icon: "arrow.down",
                title: L10n.Action.receive.localized,
                action: onReceive
            )

            QuickActionButton(
                icon: "plus.circle",
                title: L10n.Action.buy.localized,
                action: onBuy
            )

            QuickActionButton(
                icon: "arrow.left.arrow.right",
                title: L10n.Action.swap.localized,
                action: onSwap
            )
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 22)
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 9) {
                Circle()
                    .fill(WpayinColors.surfaceLight)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(WpayinColors.primary)
                    )

                Text(title.localized)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(WpayinColors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(WpayinPressableStyle())
    }
}

struct ModernTabsView: View {
    let tokens: [Token]
    let isLoading: Bool
    let onTokenTap: (Token) -> Void
    let onViewAllTap: () -> Void
    @EnvironmentObject var walletManager: WalletManager
    @State private var selectedTab = 0
    @State private var selectedNFT: NFT?

    private var tabs: [String] {
        [L10n.Tokens.title.localized, L10n.Tokens.defi.localized, L10n.Tokens.nfts.localized]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                    TabButton(
                        title: tab,
                        isSelected: selectedTab == index,
                        onTap: {
                            withAnimation(.easeOut(duration: 0.2)) {
                                selectedTab = index
                            }
                        }
                    )
                }
            }
            .padding(4)
            .background(
                Capsule()
                    .fill(WpayinColors.surface)
                    .overlay(
                        Capsule()
                            .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                )
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            LazyVStack(spacing: 16) {
                if selectedTab == 0 {
                    TokensTabContent(tokens: tokens, onTokenTap: onTokenTap, onViewAllTap: onViewAllTap)
                } else if selectedTab == 2 {
                    NFTTabContent(nfts: walletManager.nfts, onNFTTap: { nft in selectedNFT = nft })
                } else {
                    EmptyTabContent(title: tabs[selectedTab])
                }
            }
            .padding(.top, 16)
            .padding(.horizontal, 20)
        }
        .sheet(item: $selectedNFT) { nft in
            NFTDetailView(nft: nft)
        }
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title.localized)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(isSelected ? WpayinColors.primary : WpayinColors.textTertiary)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    Capsule()
                        .fill(isSelected ? WpayinColors.primary.opacity(0.14) : Color.clear)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TokensTabContent: View {
    let tokens: [Token]
    let onTokenTap: (Token) -> Void
    let onViewAllTap: () -> Void
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var settingsManager: SettingsManager

    private var favoriteTokens: [Token] {
        tokens.filter { settingsManager.favoriteTokenSymbols.contains($0.symbol) }
    }

    private var regularTokens: [Token] {
        tokens.filter { !settingsManager.favoriteTokenSymbols.contains($0.symbol) }
    }

    var body: some View {
        VStack(spacing: 14) {
            if !favoriteTokens.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(WpayinColors.warning)

                    Text("Favorites".localized)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(WpayinColors.text)

                    Spacer()
                }

                tokenList(favoriteTokens)
                    .padding(.bottom, 8)
            }

            HStack {
                Text(L10n.Wallet.yourAssets.localized)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(WpayinColors.text)

                Spacer()

                Button(action: onViewAllTap) {
                    HStack(spacing: 4) {
                        Text(L10n.Wallet.viewAll.localized)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(WpayinColors.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(WpayinColors.primary.opacity(0.10))
                    )
                }
                .buttonStyle(WpayinPressableStyle())
            }

            if tokens.isEmpty {
                VStack(spacing: 20) {
                    Circle()
                        .fill(WpayinColors.surface)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(WpayinColors.primary)
                        )

                    VStack(spacing: 8) {
                        Text("No Tokens Found".localized)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(WpayinColors.text)

                        Text("Add tokens to get started with your wallet".localized)
                            .font(.system(size: 14))
                            .foregroundColor(WpayinColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    Button("Load All Tokens".localized) {
                        // This will trigger auto token discovery
                        Task {
                            await walletManager.refreshWalletData()
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(WpayinColors.primary)
                    .cornerRadius(12)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                tokenList(regularTokens)
            }
        }
    }

    @ViewBuilder
    private func tokenList(_ listTokens: [Token]) -> some View {
        switch settingsManager.assetListStyle {
        case .cards:
            LazyVStack(spacing: 10) {
                ForEach(listTokens) { token in
                    ExpandableTokenCard(
                        token: token,
                        onTokenTap: { selectedToken in onTokenTap(selectedToken) },
                        onNetworkTokenTap: { networkToken in onTokenTap(networkToken) }
                    )
                }
            }
        case .compact:
            VStack(spacing: 1) {
                ForEach(listTokens) { token in
                    CompactTokenRow(token: token, onTap: { onTokenTap(token) })
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(WpayinColors.surface)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
            )
        }
    }
}


struct NFTTabContent: View {
    let nfts: [NFT]
    let onNFTTap: (NFT) -> Void

    var body: some View {
        VStack(spacing: 16) {
            if nfts.isEmpty {
                EmptyTabContent(title: "NFTs")
            } else {
                HStack {
                    Text("Your NFTs".localized)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(WpayinColors.text)

                    Spacer()

                    Text("%d items".localized(nfts.count))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(WpayinColors.textSecondary)
                }
                .padding(.horizontal, 4)

                NFTGridView(nfts: nfts, onNFTTap: onNFTTap)
                    .padding(.horizontal, -20) // Counteract parent padding
            }
        }
    }
}

struct EmptyTabContent: View {
    let title: String

    var body: some View {
        VStack(spacing: 20) {
            Circle()
                .fill(WpayinColors.surface)
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: title == "DeFi" ? "building.columns" : "photo")
                        .font(.system(size: 40))
                        .foregroundColor(WpayinColors.textTertiary.opacity(0.5))
                )

            VStack(spacing: 8) {
                Text("%@ Portfolio".localized(title.localized))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(WpayinColors.textSecondary)

                Text(title == "DeFi" ? "Connect to DeFi protocols".localized : "Your %@ will appear here".localized(title.localized.lowercased()))
                    .font(.system(size: 14))
                    .foregroundColor(WpayinColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
}

// MARK: - Legacy Components (keeping for compatibility)

struct EnhancedWalletHeaderView: View {
    let address: String
    let totalBalance: Double
    let isLoading: Bool
    let hasAssets: Bool
    let onReceive: () -> Void
    let onSend: () -> Void
    let onSwap: () -> Void
    let onConnect: () -> Void
    @State private var showFullAddress = false
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 20) {
                // Enhanced header with performance indicator
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "chart.pie.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(WpayinColors.primary)

                            Text("Total Portfolio".localized)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(WpayinColors.text)
                        }

                        if totalBalance > 0 {
                            HStack(spacing: 6) {
                                Text("24H")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(WpayinColors.textSecondary)

                                HStack(spacing: 4) {
                                    Image(systemName: portfolioChange.isPositive ? "arrow.up.right" : "arrow.down.right")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(portfolioChange.color)

                                    Text(portfolioChange.formatted)
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundColor(portfolioChange.color)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(portfolioChange.color.opacity(0.12))
                                )
                            }
                        }
                    }

                    Spacer()

                    if isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: WpayinColors.primary))
                                .scaleEffect(0.7)

                            Text("Syncing...".localized)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(WpayinColors.textSecondary)
                        }
                    }
                }

                // Enhanced balance display with better typography
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(formattedBalance)
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .foregroundColor(WpayinColors.text)
                        .shadow(color: WpayinColors.primary.opacity(0.1), radius: 8, x: 0, y: 4)

                    if totalBalance > 0 {
                        Text(settingsManager.selectedCurrency.rawValue)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(WpayinColors.textSecondary)
                            .offset(y: -8)
                    }
                }

                if !status.text.isEmpty {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(status.color.opacity(0.15))
                                .frame(width: 20, height: 20)

                            Image(systemName: status.icon)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(status.color)
                        }

                        Text(status.text)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(status.color)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(status.background)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(status.color.opacity(0.2), lineWidth: 0.5)
                            )
                    )
                }
            }

            if address.isEmpty {
                WpayinButton(
                    title: "Connect Wallet",
                    style: .primary,
                    action: onConnect
                )
            } else {
                VStack(spacing: 20) {
                    Button(action: { showFullAddress.toggle() }) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                WpayinColors.primary.opacity(0.15),
                                                WpayinColors.primary.opacity(0.08)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 36, height: 36)

                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(WpayinColors.primary.opacity(0.25), lineWidth: 0.5)
                                    .frame(width: 36, height: 36)

                                Image(systemName: "wallet.pass.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(WpayinColors.primary)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Wallet Address".localized)
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(WpayinColors.textSecondary)
                                    .textCase(.uppercase)

                                Text(showFullAddress ? address : formatAddress(address))
                                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                                    .foregroundColor(WpayinColors.text)
                            }

                            Spacer()

                            Button(action: {
                                AppToast.copyToClipboard(address)
                            }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(WpayinColors.primary.opacity(0.1))
                                        .frame(width: 32, height: 32)

                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(WpayinColors.primary)
                                }
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Elegant separator
                    RoundedRectangle(cornerRadius: 1)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.clear,
                                    WpayinColors.borderElegant.opacity(0.3),
                                    Color.clear
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 1)

                    HStack(spacing: 12) {
                        ElegantActionButton(
                            icon: "arrow.down.circle.fill",
                            title: "Receive",
                            color: WpayinColors.success,
                            isEnabled: !isLoading,
                            action: onReceive
                        )

                        ElegantActionButton(
                            icon: "arrow.up.circle.fill",
                            title: "Send",
                            color: WpayinColors.primary,
                            isEnabled: !isLoading && hasAssets,
                            action: onSend
                        )

                        ElegantActionButton(
                            icon: "arrow.triangle.2.circlepath",
                            title: "Swap",
                            color: WpayinColors.primary,
                            isEnabled: !isLoading && hasAssets,
                            action: onSwap
                        )
                    }
                }
            }
        }
        .padding(28)
        .background(
            ZStack {
                // Main background with subtle gradient
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                WpayinColors.surfaceElegant,
                                WpayinColors.surfaceElegant.opacity(0.85)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Subtle inner shadow effect
                RoundedRectangle(cornerRadius: 28)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                WpayinColors.borderElegant.opacity(0.6),
                                WpayinColors.borderElegant.opacity(0.2)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }
        )
        .cornerRadius(28)
        .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 8)
    }

    private var formattedBalance: String {
        totalBalance.formatted(as: settingsManager.selectedCurrency)
    }

    private var portfolioChange: (isPositive: Bool, formatted: String, color: Color) {
        // Real portfolio change would be calculated based on historical data
        let changePercent = 0.0 // TODO: implement real calculation
        let isPositive = true // Since changePercent is 0.0, always positive
        let color = WpayinColors.success
        let formatted = String(format: "%.1f%%", abs(changePercent))

        return (isPositive: isPositive, formatted: formatted, color: color)
    }

    private var status: (text: String, icon: String, color: Color, background: Color) {
        if isLoading {
            let color = WpayinColors.primary
            return (
                text: "Syncing latest balances...",
                icon: "arrow.triangle.2.circlepath",
                color: color,
                background: color.opacity(0.15)
            )
        }

        if address.isEmpty {
            let color = WpayinColors.error
            return (
                text: "No wallet connected",
                icon: "exclamationmark.triangle.fill",
                color: color,
                background: color.opacity(0.15)
            )
        }

        if hasAssets {
            let color = WpayinColors.success
            return (
                text: "Portfolio is up to date",
                icon: "checkmark.circle.fill",
                color: color,
                background: color.opacity(0.15)
            )
        }

        let color = WpayinColors.textSecondary
        return (
            text: "No assets detected yet",
            icon: "tray",
            color: color,
            background: color.opacity(0.12)
        )
    }

    private func formatAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        return "\(address.prefix(6))...\(address.suffix(4))"
    }
}

struct ElegantActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let isEnabled: Bool
    let action: () -> Void

    init(
        icon: String,
        title: String,
        color: Color,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.color = color
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    // Subtle gradient background
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [
                                color.opacity(0.08),
                                color.opacity(0.03)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 48, height: 48)

                    // Subtle inner border
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.15), lineWidth: 0.5)
                        .frame(width: 48, height: 48)

                    // Icon
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(color)
                }

                Text(title.localized)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(WpayinColors.text)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.clear)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(WpayinColors.surface.opacity(0.3))
                            .blur(radius: 0.5)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                WpayinColors.borderElegant.opacity(0.4),
                                WpayinColors.borderElegant.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.45)
        .scaleEffect(isEnabled ? 1.0 : 0.97)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
}

struct WalletEmptyStateView: View {
    let isLoading: Bool
    let onReceive: () -> Void
    let onRefresh: () -> Void
    let onConnect: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Circle()
                .fill(WpayinColors.surfaceElegant)
                .frame(width: 88, height: 88)
                .overlay(
                    Image(systemName: "tray")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(WpayinColors.textSecondary)
                )

            VStack(spacing: 8) {
                Text("No assets yet".localized)
                    .font(.wpayinHeadline)
                    .foregroundColor(WpayinColors.text)

                Text("Connect a wallet or receive funds to populate your portfolio.".localized)
                    .font(.wpayinBody)
                    .foregroundColor(WpayinColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                WpayinButton(
                    title: "Receive Crypto",
                    style: .primary,
                    action: onReceive
                )

                WpayinButton(
                    title: isLoading ? "Refreshing..." : "Refresh Portfolio",
                    style: .secondary,
                    action: onRefresh
                )
                .disabled(isLoading)

                WpayinButton(
                    title: "Use a Different Wallet",
                    style: .tertiary,
                    action: onConnect
                )
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(WpayinColors.surfaceLight)
        .cornerRadius(20)
    }
}

struct WalletActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(color)

                Text(title.localized)
                    .font(.wpayinCaption)
                    .foregroundColor(WpayinColors.text)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(WpayinColors.surfaceLight)
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EnhancedTokensListView: View {
    let tokens: [Token]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("My Assets".localized)
                    .font(.wpayinHeadline)
                    .foregroundColor(WpayinColors.text)

                Spacer()

                Text("\(tokens.count) tokens")
                    .font(.wpayinCaption)
                    .foregroundColor(WpayinColors.textSecondary)
            }

            LazyVStack(spacing: 16) {
                ForEach(tokens) { token in
                    NavigationLink(destination: AssetDetailView(token: token)) {
                        EnhancedTokenRow(token: token)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}

struct EnhancedTokenRow: View {
    let token: Token
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        HStack(spacing: 16) {
            // Token Icon with network badge for non-native tokens
            TokenIconView(token: token, size: 40, showNetworkBadge: true)

            // Token Info - simplified
            VStack(alignment: .leading, spacing: 4) {
                Text(token.symbol)
                    .font(.wpayinSubheadline)
                    .foregroundColor(WpayinColors.text)

                Text(token.name)
                    .font(.wpayinCaption)
                    .foregroundColor(WpayinColors.textSecondary)
            }

            Spacer()

            // Balance and Value
            VStack(alignment: .trailing, spacing: 4) {
                Text(TokenIconHelper.formattedBalance(token.balance))
                    .font(.wpayinSubheadline)
                    .foregroundColor(WpayinColors.text)

                Text(token.totalValue.formatted(as: settingsManager.selectedCurrency))
                    .font(.wpayinCaption)
                    .foregroundColor(WpayinColors.textSecondary)
            }

            // Arrow indicator
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(WpayinColors.textSecondary)
        }
        .padding(20)
        .background(WpayinColors.surfaceElegant)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(WpayinColors.borderElegant, lineWidth: 1)
        )
        .cornerRadius(16)
    }

    private func blockchainColor(_ blockchain: BlockchainType) -> Color {
        switch blockchain {
        case .ethereum:
            return Color.blue
        case .bitcoin:
            return Color.orange
        case .litecoin:
            return Color(red: 0.2, green: 0.38, blue: 0.62)
        case .bitcoinCash:
            return Color.green
        case .dash:
            return Color.blue
        case .solana:
            return Color.purple
        case .polygon:
            return Color.indigo
        case .bsc:
            return Color.yellow
        case .arbitrum:
            return Color.cyan
        case .optimism:
            return Color.red
        case .avalanche:
            return Color(red: 0.91, green: 0.24, blue: 0.20)
        case .base:
            return Color(red: 0.0, green: 0.46, blue: 0.87)
        default:
            return Color.gray
        }
    }

    private func blockchainSymbol(_ blockchain: BlockchainType) -> String {
        switch blockchain {
        case .ethereum:
            return "Ξ"
        case .bitcoin:
            return "₿"
        case .litecoin:
            return "Ł"
        case .solana:
            return "S"
        default:
            return String(blockchain.nativeToken.prefix(1))
        }
    }
}

// MARK: - Blockchain Switcher

struct BlockchainSwitcherView: View {
    let selectedBlockchains: Set<BlockchainPlatform>
    let onBlockchainsChanged: (Set<BlockchainPlatform>) -> Void

    let availableBlockchains: [BlockchainPlatform] = [.ethereum, .arbitrum, .bsc, .polygon, .base, .optimism]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Blockchains".localized)
                .font(.wpayinSubheadline)
                .foregroundColor(WpayinColors.text)

            Menu {
                ForEach(availableBlockchains, id: \.self) { blockchain in
                    Button(action: {
                        var newSelection = selectedBlockchains
                        if newSelection.contains(blockchain) {
                            newSelection.remove(blockchain)
                        } else {
                            newSelection.insert(blockchain)
                        }
                        onBlockchainsChanged(newSelection)
                    }) {
                        HStack {
                            Circle()
                                .fill(blockchain.color)
                                .frame(width: 12, height: 12)
                            Text(blockchain.name)
                            Spacer()
                            if selectedBlockchains.contains(blockchain) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    HStack(spacing: -4) {
                        ForEach(Array(selectedBlockchains.prefix(3)), id: \.self) { blockchain in
                            PlatformIconView(platform: blockchain, size: 20)
                                .overlay(
                                    Circle()
                                        .stroke(WpayinColors.surfaceElegant, lineWidth: 1.5)
                                )
                        }
                    }

                    Text("\(selectedBlockchains.count) blockchains active")
                        .font(.wpayinBody)
                        .foregroundColor(WpayinColors.text)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(WpayinColors.textSecondary)
                }
                .padding(16)
                .background(WpayinColors.surfaceElegant)
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Wallet Menu Sheet

struct WalletMenuSheet: View {
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss
    let onAddToken: () -> Void
    let onManageWallets: () -> Void

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    // Menu Items
                    VStack(spacing: 0) {
                        MenuButton(
                            icon: "plus.circle.fill",
                            title: "Add Token",
                            subtitle: "Add custom ERC-20 tokens",
                            color: WpayinColors.primary
                        ) {
                            onAddToken()
                        }

                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.horizontal, 20)

                        MenuButton(
                            icon: "wallet.pass.fill",
                            title: "Manage Wallets",
                            subtitle: "Switch or create wallets",
                            color: WpayinColors.success
                        ) {
                            onManageWallets()
                        }

                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.horizontal, 20)

                        NavigationLink(destination: SettingsView()
                            .environmentObject(walletManager)
                            .environmentObject(settingsManager)
                        ) {
                            MenuButton(
                                icon: "gearshape.fill",
                                title: "Settings",
                                subtitle: "App preferences & security",
                                color: WpayinColors.textSecondary,
                                showChevron: true
                            ) {}
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(WpayinColors.surface)
                    )
                    .padding(.horizontal, 20)

                    Spacer()
                }
                .padding(.top, 24)
            }
            .navigationTitle("Menu".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.Action.done.localized) {
                        dismiss()
                    }
                    .foregroundColor(WpayinColors.primary)
                }
            }
        }
    }
}

struct MenuButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    var showChevron: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 22))
                            .foregroundColor(color)
                    )

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(title.localized)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(WpayinColors.text)

                    Text(subtitle.localized)
                        .font(.system(size: 14))
                        .foregroundColor(WpayinColors.textSecondary)
                }

                Spacer()

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(WpayinColors.textTertiary)
                }
            }
            .padding(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    let walletManager = WalletManager()
    walletManager.hasWallet = true
    walletManager.walletAddress = "0x742d35Cc6D06b73494d45e5d2b0542f2f"

    return WalletView()
        .environmentObject(walletManager)
}
