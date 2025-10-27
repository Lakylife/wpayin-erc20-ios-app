//
//  DeFiView.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI

struct DeFiView: View {
    @EnvironmentObject var walletManager: WalletManager
    @State private var selectedTab = 0

    private let tabs = ["Overview", "Lending", "Staking", "Yield Farming"]

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Tab Selector
                    DeFiTabSelector(selectedTab: $selectedTab, tabs: tabs)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)

                    // Content
                    TabView(selection: $selectedTab) {
                        DeFiOverviewView()
                            .tag(0)

                        DeFiLendingView()
                            .tag(1)

                        DeFiStakingView()
                            .tag(2)

                        DeFiYieldFarmingView()
                            .tag(3)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                }
            }
            .navigationTitle("DeFi")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct DeFiTabSelector: View {
    @Binding var selectedTab: Int
    let tabs: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                    Button(action: {
                        selectedTab = index
                    }) {
                        Text(tab)
                            .font(.wpayinBody)
                            .foregroundColor(selectedTab == index ? WpayinColors.secondary : WpayinColors.textSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedTab == index ? WpayinColors.primary : WpayinColors.surface)
                            .cornerRadius(20)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 4)
        }
        .animation(.easeInOut(duration: 0.2), value: selectedTab)
    }
}

struct DeFiOverviewView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Portfolio Summary
                DeFiPortfolioCard()

                // Quick Actions
                DeFiQuickActionsView()

                // Market Overview
                DeFiMarketOverview()

                // Recent DeFi Activity
                RecentDeFiActivity()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }
}

struct DeFiPortfolioCard: View {
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Total DeFi Value")
                    .font(.wpayinBody)
                    .foregroundColor(WpayinColors.textSecondary)

                Text("$2,456.78")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(WpayinColors.text)

                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 12))
                        .foregroundColor(WpayinColors.success)

                    Text("+12.5% (24h)")
                        .font(.wpayinCaption)
                        .foregroundColor(WpayinColors.success)
                }
            }

            // Portfolio Breakdown
            VStack(spacing: 12) {
                PortfolioBreakdownRow(
                    title: "Lending",
                    amount: "$1,234.56",
                    percentage: "50.2%",
                    color: WpayinColors.primary
                )

                PortfolioBreakdownRow(
                    title: "Staking",
                    amount: "$789.12",
                    percentage: "32.1%",
                    color: WpayinColors.success
                )

                PortfolioBreakdownRow(
                    title: "Yield Farming",
                    amount: "$433.10",
                    percentage: "17.7%",
                    color: Color.orange
                )
            }
        }
        .padding(24)
        .background(WpayinColors.surface)
        .cornerRadius(20)
    }
}

struct PortfolioBreakdownRow: View {
    let title: String
    let amount: String
    let percentage: String
    let color: Color

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)

                Text(title)
                    .font(.wpayinBody)
                    .foregroundColor(WpayinColors.text)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(amount)
                    .font(.wpayinBody)
                    .foregroundColor(WpayinColors.text)

                Text(percentage)
                    .font(.wpayinCaption)
                    .foregroundColor(WpayinColors.textSecondary)
            }
        }
    }
}

struct DeFiQuickActionsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.wpayinHeadline)
                .foregroundColor(WpayinColors.text)

            HStack(spacing: 12) {
                DeFiActionButton(
                    icon: "banknote",
                    title: "Lend",
                    subtitle: "Earn interest",
                    color: WpayinColors.primary
                ) {
                    // Handle lending action
                }

                DeFiActionButton(
                    icon: "lock.shield",
                    title: "Stake",
                    subtitle: "Secure network",
                    color: WpayinColors.success
                ) {
                    // Handle staking action
                }

                DeFiActionButton(
                    icon: "leaf",
                    title: "Farm",
                    subtitle: "Yield farming",
                    color: Color.orange
                ) {
                    // Handle farming action
                }
            }
        }
    }
}

struct DeFiActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)

                VStack(spacing: 4) {
                    Text(title)
                        .font(.wpayinBody)
                        .foregroundColor(WpayinColors.text)

                    Text(subtitle)
                        .font(.wpayinCaption)
                        .foregroundColor(WpayinColors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(WpayinColors.surface)
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DeFiMarketOverview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Market Overview")
                .font(.wpayinHeadline)
                .foregroundColor(WpayinColors.text)

            VStack(spacing: 12) {
                MarketOverviewRow(
                    protocolName: "Compound",
                    apy: "4.52%",
                    tvl: "$2.1B",
                    change: "+0.12%"
                )

                MarketOverviewRow(
                    protocolName: "Uniswap V3",
                    apy: "12.34%",
                    tvl: "$3.8B",
                    change: "+2.45%"
                )

                MarketOverviewRow(
                    protocolName: "Aave",
                    apy: "3.87%",
                    tvl: "$5.2B",
                    change: "-0.08%"
                )
            }
        }
    }
}

struct MarketOverviewRow: View {
    let protocolName: String
    let apy: String
    let tvl: String
    let change: String

    private var isPositive: Bool {
        change.hasPrefix("+")
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(protocolName)
                    .font(.wpayinBody)
                    .foregroundColor(WpayinColors.text)

                Text("APY: \(apy)")
                    .font(.wpayinCaption)
                    .foregroundColor(WpayinColors.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(tvl)
                    .font(.wpayinBody)
                    .foregroundColor(WpayinColors.text)

                Text(change)
                    .font(.wpayinCaption)
                    .foregroundColor(isPositive ? WpayinColors.success : WpayinColors.error)
            }
        }
        .padding(16)
        .background(WpayinColors.surface)
        .cornerRadius(12)
    }
}

struct RecentDeFiActivity: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Activity")
                .font(.wpayinHeadline)
                .foregroundColor(WpayinColors.text)

            VStack(spacing: 12) {
                DeFiActivityRow(
                    action: "Staked ETH",
                    amount: "2.5 ETH",
                    protocolName: "Ethereum 2.0",
                    time: "2h ago",
                    type: .stake
                )

                DeFiActivityRow(
                    action: "Provided Liquidity",
                    amount: "1,000 USDC",
                    protocolName: "Uniswap V3",
                    time: "1d ago",
                    type: .liquidity
                )

                DeFiActivityRow(
                    action: "Claimed Rewards",
                    amount: "45.67 COMP",
                    protocolName: "Compound",
                    time: "3d ago",
                    type: .reward
                )
            }
        }
    }
}

struct DeFiActivityRow: View {
    let action: String
    let amount: String
    let protocolName: String
    let time: String
    let type: DeFiActivityType

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(type.color.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: type.icon)
                    .font(.system(size: 20))
                    .foregroundColor(type.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(action)
                    .font(.wpayinBody)
                    .foregroundColor(WpayinColors.text)

                Text(protocolName)
                    .font(.wpayinCaption)
                    .foregroundColor(WpayinColors.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(amount)
                    .font(.wpayinBody)
                    .foregroundColor(WpayinColors.text)

                Text(time)
                    .font(.wpayinCaption)
                    .foregroundColor(WpayinColors.textSecondary)
            }
        }
        .padding(16)
        .background(WpayinColors.surface)
        .cornerRadius(12)
    }
}

enum DeFiActivityType {
    case stake
    case liquidity
    case reward
    case unstake

    var icon: String {
        switch self {
        case .stake:
            return "lock.shield"
        case .liquidity:
            return "drop"
        case .reward:
            return "gift"
        case .unstake:
            return "lock.open"
        }
    }

    var color: Color {
        switch self {
        case .stake:
            return WpayinColors.success
        case .liquidity:
            return WpayinColors.primary
        case .reward:
            return Color.orange
        case .unstake:
            return WpayinColors.error
        }
    }
}

struct DeFiLendingView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Lending Protocols")
                    .font(.wpayinHeadline)
                    .foregroundColor(WpayinColors.text)

                Text("DeFi lending features coming soon...")
                    .font(.wpayinBody)
                    .foregroundColor(WpayinColors.textSecondary)
                    .padding(.top, 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }
}

struct DeFiStakingView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Staking Opportunities")
                    .font(.wpayinHeadline)
                    .foregroundColor(WpayinColors.text)

                Text("Staking features coming soon...")
                    .font(.wpayinBody)
                    .foregroundColor(WpayinColors.textSecondary)
                    .padding(.top, 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }
}

struct DeFiYieldFarmingView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Yield Farming")
                    .font(.wpayinHeadline)
                    .foregroundColor(WpayinColors.text)

                Text("Yield farming features coming soon...")
                    .font(.wpayinBody)
                    .foregroundColor(WpayinColors.textSecondary)
                    .padding(.top, 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }
}

#Preview {
    DeFiView()
        .environmentObject(WalletManager())
}