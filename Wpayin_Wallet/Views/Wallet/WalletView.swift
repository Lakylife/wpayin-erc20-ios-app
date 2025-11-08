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

    var body: some View {
        ZStack {
            // Background gradient matching mockup
            LinearGradient(
                gradient: Gradient(colors: [
                    WpayinColors.backgroundGradientStart,
                    WpayinColors.backgroundGradientEnd
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(.all)

            VStack(spacing: 0) {
                // Fixed Header at top - completely from top
                ModernHeaderView(
                    walletManager: walletManager,
                    onMenuTap: { showMenuSheet = true },
                    onQRTap: { showDepositSheet = true },
                    onWalletTap: { showWalletSelector = true }
                )
                .ignoresSafeArea(.all, edges: .top)
                .zIndex(1)

                // Scrollable content area
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Balance Card
                        ModernBalanceCardView(
                            balance: totalPortfolioValue,
                            isLoading: walletManager.isLoading,
                            walletAddress: walletManager.walletAddress
                        )
                        .environmentObject(walletManager)
                        .environmentObject(settingsManager)

                        // Quick Actions
                        ModernQuickActionsView(
                            onSend: { showWithdrawSheet = true },
                            onReceive: { showDepositSheet = true },
                            onBuy: { showBuy = true },
                            onSwap: { showSwapSheet = true }
                        )

                        // Tabs and Content
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

                        // Bottom padding to account for bottom navigation
                        Spacer()
                            .frame(height: 100)
                    }
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
            WithdrawView()
                .environmentObject(walletManager)
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
            walletManager.hasWallet ? "Wallet Options" : "Connect Wallet",
            isPresented: $showMenuSheet,
            titleVisibility: .visible
        ) {
            if walletManager.hasWallet {
                Button("Add Token") { showAddToken = true }
                Button("Manage Wallets") { showWalletSelector = true }
                Button("Cancel", role: .cancel) { }
            } else {
                Button("Create New Wallet") { showCreateWallet = true }
                Button("Import Existing Wallet") { showImportWallet = true }
                Button("Cancel", role: .cancel) { }
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
                            UIPasteboard.general.string = address
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

                Text(title)
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
            Text("Assets")
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
            Circle()
                .fill(WpayinColors.primary)
                .frame(width: 44, height: 44)
                .overlay(
                    Text(token.symbol.prefix(1))
                        .font(.wpayinSubheadline)
                        .foregroundColor(.white)
                )

            // Token Info
            VStack(alignment: .leading, spacing: 4) {
                Text(token.name)
                    .font(.wpayinBody)
                    .foregroundColor(WpayinColors.text)

                Text(token.symbol)
                    .font(.wpayinCaption)
                    .foregroundColor(WpayinColors.textSecondary)
            }

            Spacer()

            // Balance and Value
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.4f", token.balance))
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
    @State private var showWalletDropdown = false

    var body: some View {
        VStack(spacing: 0) {
            // Header background with gradient - starts from very top including safe area
            LinearGradient(
                gradient: Gradient(colors: [
                    WpayinColors.headerBackground,
                    Color.clear
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 140)
            .overlay(
                VStack(spacing: 0) {
                    // Top safe area spacer
                    Spacer()
                        .frame(height: 50)

                    HStack(spacing: 12) {
                        // Hamburger Menu Button
                        Button(action: onMenuTap) {
                            Circle()
                                .fill(WpayinColors.buttonBackground)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(WpayinColors.buttonBorder, lineWidth: 1)
                                )
                                .overlay(
                                    Image(systemName: "line.3.horizontal")
                                        .foregroundColor(WpayinColors.text)
                                        .font(.system(size: 16, weight: .medium))
                                )
                        }

                        // Wallet Selector
                        Button(action: onWalletTap) {
                            HStack(spacing: 8) {
                                // Wallet Avatar
                                WpayinLogoView(size: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Main Wallet")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(WpayinColors.text)

                                    Text(formatAddress(walletManager.walletAddress))
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundColor(WpayinColors.textSecondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(WpayinColors.textSecondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 100)
                                    .fill(WpayinColors.buttonBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 100)
                                            .stroke(WpayinColors.buttonBorder, lineWidth: 1)
                                    )
                            )
                        }

                        // QR Button
                        Button(action: onQRTap) {
                            Circle()
                                .fill(WpayinColors.buttonBackground)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(WpayinColors.buttonBorder, lineWidth: 1)
                                )
                                .overlay(
                                    Image(systemName: "qrcode.viewfinder")
                                        .foregroundColor(WpayinColors.text)
                                        .font(.system(size: 16))
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                }
            )
        }
    }

    private func formatAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        return "\(address.prefix(6))...\(address.suffix(4))"
    }
}

struct ModernBalanceCardView: View {
    let balance: Double
    let isLoading: Bool
    let walletAddress: String
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        VStack(spacing: 12) {
            // Balance Label
            Text(L10n.Wallet.totalBalance.localized)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(WpayinColors.textSecondary)
                .textCase(.uppercase)

            // Main Balance with gradient text
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(balance.formatted(as: settingsManager.selectedCurrency))
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                WpayinColors.text,
                                WpayinColors.textSecondary
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: WpayinColors.primary))
                        .scaleEffect(0.7)
                }
            }

            // ETH Balance equivalent
            if balance > 0, let ethToken = walletManager.visibleTokens.first(where: { $0.symbol == "ETH" }), ethToken.price > 0 {
                Text(String(format: "%.4f ETH", balance / ethToken.price))
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(WpayinColors.textTertiary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 30)
    }
}

struct ModernQuickActionsView: View {
    let onSend: () -> Void
    let onReceive: () -> Void
    let onBuy: () -> Void
    let onSwap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
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
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Circle()
                    .fill(WpayinColors.buttonBackground)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .stroke(WpayinColors.buttonBorder, lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 16))
                            .foregroundColor(WpayinColors.text)
                    )

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(WpayinColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(WpayinColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
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
            // Sticky tabs container
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                        TabButton(
                            title: tab,
                            isSelected: selectedTab == index,
                            onTap: { selectedTab = index }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

                Rectangle()
                    .fill(WpayinColors.surfaceBorder)
                    .frame(height: 1)
            }
            .background(WpayinColors.background)

            // Content area - no ScrollView here since parent handles scrolling
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
            VStack(spacing: 0) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? WpayinColors.text : WpayinColors.textTertiary)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(isSelected ? WpayinColors.text : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TokensTabContent: View {
    let tokens: [Token]
    let onTokenTap: (Token) -> Void
    let onViewAllTap: () -> Void
    @EnvironmentObject var walletManager: WalletManager

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(L10n.Wallet.yourAssets.localized)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(WpayinColors.text)

                Spacer()

                Button(L10n.Wallet.viewAll.localized, action: onViewAllTap)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(WpayinColors.primary)
            }
            .padding(.horizontal, 4)

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
                        Text("No Tokens Found")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(WpayinColors.text)

                        Text("Add tokens to get started with your wallet")
                            .font(.system(size: 14))
                            .foregroundColor(WpayinColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    Button("Load All Tokens") {
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
                LazyVStack(spacing: 16) {
                    ForEach(walletManager.visibleGroupedTokens) { token in
                        ExpandableTokenCard(
                            token: token,
                            onTokenTap: { selectedToken in onTokenTap(selectedToken) },
                            onNetworkTokenTap: { networkToken in onTokenTap(networkToken) }
                        )
                    }
                }
            }
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
                    Text("Your NFTs")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(WpayinColors.text)

                    Spacer()

                    Text("\(nfts.count) items")
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
                Text("\(title) Portfolio")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(WpayinColors.textSecondary)

                Text(title == "DeFi" ? "Connect to DeFi protocols" : "Your \(title.lowercased()) will appear here")
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

                            Text("Total Portfolio")
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

                            Text("Syncing...")
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
                        Text("USD")
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
                                Text("Wallet Address")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(WpayinColors.textSecondary)
                                    .textCase(.uppercase)

                                Text(showFullAddress ? address : formatAddress(address))
                                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                                    .foregroundColor(WpayinColors.text)
                            }

                            Spacer()

                            Button(action: {
                                UIPasteboard.general.string = address
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
        let changePercent = 0.0 // Placeholder - implement real calculation
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

                Text(title)
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
                Text("No assets yet")
                    .font(.wpayinHeadline)
                    .foregroundColor(WpayinColors.text)

                Text("Connect a wallet or receive funds to populate your portfolio.")
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

                Text(title)
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
                Text("My Assets")
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
            // Token Icon - simplified
            TokenIconView(symbol: token.symbol, blockchain: token.blockchain)

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
                Text(String(format: "%.4f", token.balance))
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
        }
    }

    private func blockchainSymbol(_ blockchain: BlockchainType) -> String {
        switch blockchain {
        case .ethereum:
            return "E"
        case .bitcoin:
            return "₿"
        case .solana:
            return "◎"
        case .polygon:
            return "⬟"
        case .bsc:
            return "▲"
        case .arbitrum:
            return "A"
        case .optimism:
            return "O"
        case .avalanche:
            return "V"
        case .base:
            return "B"
        }
    }
}

struct TokenIconView: View {
    let symbol: String
    let blockchain: BlockchainType

    init(symbol: String, blockchain: BlockchainType = .ethereum) {
        self.symbol = symbol
        self.blockchain = blockchain
    }

    var body: some View {
        Circle()
            .fill(tokenColor)
            .frame(width: 40, height: 40)
            .overlay(
                Text(symbol.prefix(1))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            )
    }

    private var tokenColor: Color {
        switch symbol.uppercased() {
        case "ETH":
            return Color.blue
        case "BTC":
            return Color.orange
        case "MATIC":
            return Color.purple
        case "BNB":
            return Color.yellow
        default:
            return WpayinColors.primary
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
            Text("Active Blockchains")
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
                            Circle()
                                .fill(blockchain.color)
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Image(systemName: blockchain.iconName)
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundColor(.white)
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
            .navigationTitle("Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
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
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(WpayinColors.text)

                    Text(subtitle)
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
