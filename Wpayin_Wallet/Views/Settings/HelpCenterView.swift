//
//  HelpCenterView.swift
//  Wpayin_Wallet
//
//  Created by AI Assistant on 09.11.2024.
//

import SwiftUI

struct HelpCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedCategory: HelpCategory?
    @State private var selectedArticle: HelpArticle?
    
    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Search Bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(WpayinColors.textSecondary)
                            
                            TextField("Search help articles...", text: $searchText)
                                .foregroundColor(WpayinColors.text)
                        }
                        .padding()
                        .background(WpayinColors.surface)
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        
                        // Categories
                        if searchText.isEmpty {
                            categoriesView
                        } else {
                            searchResultsView
                        }
                        
                        Spacer()
                            .frame(height: 40)
                    }
                }
            }
            .navigationTitle("Help Center")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(WpayinColors.textSecondary)
                    }
                }
            }
            .sheet(item: $selectedArticle) { article in
                HelpArticleDetailView(article: article)
            }
        }
    }
    
    private var categoriesView: some View {
        VStack(spacing: 16) {
            ForEach(HelpCategory.allCategories) { category in
                HelpCategoryCard(category: category) {
                    selectedCategory = category
                }
            }
        }
        .padding(.horizontal, 20)
        .sheet(item: $selectedCategory) { category in
            HelpCategoryDetailView(category: category) { article in
                selectedArticle = article
            }
        }
    }
    
    private var searchResultsView: some View {
        VStack(spacing: 12) {
            let results = searchArticles(query: searchText)
            
            if results.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(WpayinColors.textSecondary)
                    
                    Text("No results found")
                        .font(.wpayinHeadline)
                        .foregroundColor(WpayinColors.text)
                    
                    Text("Try different keywords")
                        .font(.wpayinBody)
                        .foregroundColor(WpayinColors.textSecondary)
                }
                .padding(.top, 60)
            } else {
                ForEach(results) { article in
                    HelpArticleRow(article: article) {
                        selectedArticle = article
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    private func searchArticles(query: String) -> [HelpArticle] {
        let lowercaseQuery = query.lowercased()
        return HelpCategory.allCategories.flatMap { $0.articles }.filter { article in
            article.title.lowercased().contains(lowercaseQuery) ||
            article.content.lowercased().contains(lowercaseQuery)
        }
    }
}

// MARK: - Help Category Card

struct HelpCategoryCard: View {
    let category: HelpCategory
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(category.color.opacity(0.1))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: category.icon)
                        .font(.system(size: 24))
                        .foregroundColor(category.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.title)
                        .font(.wpayinHeadline)
                        .foregroundColor(WpayinColors.text)
                    
                    Text("\(category.articles.count) articles")
                        .font(.wpayinCaption)
                        .foregroundColor(WpayinColors.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(WpayinColors.textSecondary)
            }
            .padding(16)
            .background(WpayinColors.surface)
            .cornerRadius(12)
        }
    }
}

// MARK: - Help Category Detail View

struct HelpCategoryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let category: HelpCategory
    let onArticleSelected: (HelpArticle) -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(category.articles) { article in
                            HelpArticleRow(article: article) {
                                onArticleSelected(article)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(category.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(WpayinColors.textSecondary)
                    }
                }
            }
        }
    }
}

// MARK: - Help Article Row

struct HelpArticleRow: View {
    let article: HelpArticle
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(article.title)
                        .font(.wpayinSubheadline)
                        .foregroundColor(WpayinColors.text)
                        .multilineTextAlignment(.leading)
                    
                    if let preview = article.preview {
                        Text(preview)
                            .font(.wpayinCaption)
                            .foregroundColor(WpayinColors.textSecondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(WpayinColors.textSecondary)
            }
            .padding(16)
            .background(WpayinColors.surface)
            .cornerRadius(12)
        }
    }
}

// MARK: - Help Article Detail View

struct HelpArticleDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let article: HelpArticle
    
    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Title
                        Text(article.title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(WpayinColors.text)
                        
                        // Content
                        Text(article.content)
                            .font(.wpayinBody)
                            .foregroundColor(WpayinColors.text)
                            .lineSpacing(6)
                        
                        // Steps if available
                        if !article.steps.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Step by Step:")
                                    .font(.wpayinHeadline)
                                    .foregroundColor(WpayinColors.text)
                                
                                ForEach(Array(article.steps.enumerated()), id: \.offset) { index, step in
                                    HStack(alignment: .top, spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(WpayinColors.primary.opacity(0.1))
                                                .frame(width: 32, height: 32)
                                            
                                            Text("\(index + 1)")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(WpayinColors.primary)
                                        }
                                        
                                        Text(step)
                                            .font(.wpayinBody)
                                            .foregroundColor(WpayinColors.text)
                                    }
                                }
                            }
                            .padding(16)
                            .background(WpayinColors.surface)
                            .cornerRadius(12)
                        }
                        
                        // Related Articles
                        if !article.relatedArticles.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Related Articles:")
                                    .font(.wpayinHeadline)
                                    .foregroundColor(WpayinColors.text)
                                
                                ForEach(article.relatedArticles, id: \.self) { relatedTitle in
                                    HStack {
                                        Image(systemName: "doc.text")
                                            .foregroundColor(WpayinColors.primary)
                                        
                                        Text(relatedTitle)
                                            .font(.wpayinBody)
                                            .foregroundColor(WpayinColors.text)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "arrow.right")
                                            .foregroundColor(WpayinColors.textSecondary)
                                    }
                                    .padding(12)
                                    .background(WpayinColors.surface)
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(WpayinColors.textSecondary)
                    }
                }
            }
        }
    }
}

// MARK: - Data Models

struct HelpCategory: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
    let articles: [HelpArticle]
    
    static let allCategories: [HelpCategory] = [
        HelpCategory(
            title: "Getting Started",
            icon: "play.circle.fill",
            color: .blue,
            articles: HelpArticle.gettingStartedArticles
        ),
        HelpCategory(
            title: "Wallet Security",
            icon: "lock.shield.fill",
            color: .green,
            articles: HelpArticle.securityArticles
        ),
        HelpCategory(
            title: "Sending & Receiving",
            icon: "arrow.left.arrow.right.circle.fill",
            color: .purple,
            articles: HelpArticle.transactionArticles
        ),
        HelpCategory(
            title: "Blockchain Networks",
            icon: "network",
            color: .orange,
            articles: HelpArticle.networkArticles
        ),
        HelpCategory(
            title: "NFTs",
            icon: "photo.stack.fill",
            color: .pink,
            articles: HelpArticle.nftArticles
        ),
        HelpCategory(
            title: "Troubleshooting",
            icon: "wrench.and.screwdriver.fill",
            color: .red,
            articles: HelpArticle.troubleshootingArticles
        )
    ]
}

struct HelpArticle: Identifiable {
    let id = UUID()
    let title: String
    let preview: String?
    let content: String
    let steps: [String]
    let relatedArticles: [String]
    
    init(title: String, preview: String? = nil, content: String, steps: [String] = [], relatedArticles: [String] = []) {
        self.title = title
        self.preview = preview
        self.content = content
        self.steps = steps
        self.relatedArticles = relatedArticles
    }
    
    // MARK: - Getting Started Articles
    
    static let gettingStartedArticles: [HelpArticle] = [
        HelpArticle(
            title: "What is a Crypto Wallet?",
            preview: "Learn the basics of cryptocurrency wallets",
            content: """
            A crypto wallet is a digital tool that allows you to store, send, and receive cryptocurrencies like Bitcoin and Ethereum. Unlike traditional wallets that hold physical money, crypto wallets store your private keys—the cryptographic codes that prove ownership of your digital assets.
            
            Your wallet is non-custodial and decentralized, meaning only YOU have access to your funds. We never have access to your private keys or seed phrase.
            
            Types of Information Your Wallet Stores:
            • Private Keys: Secret codes that prove you own your crypto
            • Public Addresses: Where others can send you crypto
            • Transaction History: Record of all your sends and receives
            • Token Balances: How much of each cryptocurrency you own
            """,
            relatedArticles: ["How to Create a New Wallet", "What is a Seed Phrase?"]
        ),
        HelpArticle(
            title: "How to Create a New Wallet",
            preview: "Set up your first crypto wallet in minutes",
            content: """
            Creating a new wallet is simple and takes just a few minutes. Your wallet will be generated locally on your device—we never see or store your private keys.
            """,
            steps: [
                "Tap 'Create New Wallet' on the welcome screen",
                "Write down your 12-word recovery phrase on paper (NEVER save digitally)",
                "Verify your recovery phrase by selecting words in order",
                "Set up biometric authentication (Face ID/Touch ID)",
                "Your wallet is ready! You'll see your address and balance"
            ],
            relatedArticles: ["What is a Seed Phrase?", "How to Secure Your Wallet"]
        ),
        HelpArticle(
            title: "What is a Seed Phrase?",
            preview: "Understanding your 12-word recovery phrase",
            content: """
            Your seed phrase (also called recovery phrase or mnemonic) is a 12-word backup of your entire wallet. These words are generated using advanced cryptography and can restore your wallet on any device.
            
            CRITICAL SECURITY RULES:
            • NEVER share your seed phrase with anyone (including support)
            • NEVER type it into websites or apps
            • NEVER take screenshots or save digitally
            • ALWAYS write it on paper and store securely
            • Anyone with your seed phrase can steal ALL your funds
            
            Your seed phrase is the ONLY way to recover your wallet if:
            • You lose your phone
            • You delete the app
            • Your phone breaks or is stolen
            • You switch to a new device
            
            We cannot recover your wallet without your seed phrase—there is NO password reset or customer support that can help if you lose it!
            """,
            relatedArticles: ["How to Store Your Seed Phrase Safely", "What if I Lose My Seed Phrase?"]
        ),
        HelpArticle(
            title: "How to Import an Existing Wallet",
            preview: "Restore your wallet using your seed phrase",
            content: """
            If you already have a wallet and want to use it in this app, you can import it using your 12-word seed phrase.
            """,
            steps: [
                "Tap 'Import Existing Wallet' on the welcome screen",
                "Enter your 12-word seed phrase in the correct order",
                "Verify that the words are spelled correctly",
                "Set up biometric authentication",
                "Your wallet and all balances will appear automatically"
            ],
            relatedArticles: ["What is a Seed Phrase?", "Why Can't I See My Tokens?"]
        )
    ]
    
    // MARK: - Security Articles
    
    static let securityArticles: [HelpArticle] = [
        HelpArticle(
            title: "How to Secure Your Wallet",
            preview: "Best practices for keeping your crypto safe",
            content: """
            Crypto security is YOUR responsibility. Since wallets are decentralized, there's no bank or company that can reverse transactions or recover lost funds.
            
            Essential Security Practices:
            
            1. SEED PHRASE SECURITY
            • Write it on paper, NEVER digitally
            • Store in a safe, fireproof location
            • Consider splitting it between multiple secure locations
            • Never share it with anyone, ever
            
            2. DEVICE SECURITY
            • Enable biometric authentication (Face ID/Touch ID)
            • Use a strong device passcode
            • Keep your phone's OS updated
            • Don't jailbreak/root your device
            
            3. TRANSACTION SECURITY
            • Always verify recipient addresses (double-check!)
            • Start with small test transactions
            • Beware of phishing attempts
            • Never rush transactions
            
            4. NETWORK SECURITY
            • Avoid public WiFi for transactions
            • Use VPN when possible
            • Don't install suspicious apps
            • Keep this app updated
            """,
            relatedArticles: ["What is a Seed Phrase?", "How to Avoid Scams"]
        ),
        HelpArticle(
            title: "What if I Lose My Seed Phrase?",
            preview: "Understanding the risks and consequences",
            content: """
            Unfortunately, if you lose your seed phrase AND lose access to your device, your funds are PERMANENTLY LOST. This is the nature of decentralized crypto—no one can recover it for you.
            
            Why We Can't Help:
            • Your wallet is non-custodial (we never see your keys)
            • The blockchain is immutable (can't be reversed)
            • Cryptography is unbreakable (by design)
            • Decentralization means no central authority
            
            Prevention is the ONLY Solution:
            • Write your seed phrase on paper NOW
            • Store it in multiple secure locations
            • Never rely on memory alone
            • Consider a metal backup for fire protection
            • Tell a trusted person where it's stored (for inheritance)
            
            If you still have access to this app on your device, you can:
            • View your seed phrase in Settings → Wallet → Show Recovery Phrase
            • Export your private key as an additional backup
            • Write it down immediately!
            """,
            relatedArticles: ["How to Store Your Seed Phrase Safely", "What is a Seed Phrase?"]
        ),
        HelpArticle(
            title: "How to Avoid Scams",
            preview: "Recognize and prevent crypto scams",
            content: """
            Crypto scams are common. Here's how to protect yourself:
            
            NEVER:
            • Share your seed phrase or private key
            • Send crypto to "verify" your wallet
            • Click suspicious links in emails/texts
            • Trust "support" that contacts you first
            • Use seed phrases generated by websites
            
            Common Scam Types:
            
            1. FAKE SUPPORT
            Scammers pretending to be customer support asking for your seed phrase. Real support NEVER asks for your seed phrase!
            
            2. PHISHING WEBSITES
            Fake websites that look like real crypto services. Always verify URLs carefully.
            
            3. AIRDROP SCAMS
            Fake tokens sent to your wallet with instructions to "claim" them on a website. These steal your funds!
            
            4. INVESTMENT SCAMS
            "Guaranteed returns" or "doubling" schemes. If it sounds too good to be true, it is.
            
            5. ROMANCE SCAMS
            Online relationships that eventually ask you to invest in crypto. Block and report immediately.
            
            Red Flags:
            • Urgency or pressure
            • Promises of guaranteed profits
            • Requests for seed phrase/private key
            • Unsolicited contact
            • Grammar/spelling errors
            """,
            relatedArticles: ["How to Secure Your Wallet", "How to Verify Transaction Addresses"]
        )
    ]
    
    // MARK: - Transaction Articles
    
    static let transactionArticles: [HelpArticle] = [
        HelpArticle(
            title: "How to Send Crypto",
            preview: "Step-by-step guide to sending tokens",
            content: """
            Sending crypto is permanent and irreversible. Always double-check the address!
            """,
            steps: [
                "Go to Wallet tab and select the token you want to send",
                "Tap 'Send' button",
                "Enter or scan the recipient's address",
                "Enter the amount you want to send",
                "Review the network fee (gas fee)",
                "Double-check the recipient address (character by character!)",
                "Tap 'Review Transaction'",
                "Verify all details are correct",
                "Confirm with biometric authentication",
                "Wait for blockchain confirmation (usually 1-5 minutes)"
            ],
            relatedArticles: ["What are Gas Fees?", "How to Verify Transaction Addresses"]
        ),
        HelpArticle(
            title: "How to Receive Crypto",
            preview: "Get your wallet address to receive funds",
            content: """
            Receiving crypto is simple—just share your address with the sender.
            """,
            steps: [
                "Go to Wallet tab",
                "Tap 'Deposit' button",
                "Select the blockchain network you want to receive on",
                "Your address will be displayed with a QR code",
                "Tap 'Copy Address' or let sender scan QR code",
                "Share address with sender",
                "Wait for sender to complete transaction",
                "Tokens will appear in your wallet after blockchain confirmation"
            ],
            relatedArticles: ["Why Do I Have Different Addresses?", "How Long Do Transactions Take?"]
        ),
        HelpArticle(
            title: "What are Gas Fees?",
            preview: "Understanding blockchain transaction costs",
            content: """
            Gas fees are payments made to blockchain validators who process your transactions. These fees are NOT paid to us—they go directly to the network.
            
            Why Gas Fees Exist:
            • Validators need incentive to process transactions
            • Fees prevent spam on the blockchain
            • Higher fees = faster transaction processing
            • Fees vary based on network congestion
            
            Gas Fee Components:
            • Base Fee: Minimum fee required (burned/destroyed)
            • Priority Fee: Optional tip to validators for faster processing
            • Total Fee: Base + Priority
            
            Gas Fee Speeds in This App:
            • 🐢 Slow: ~5 minutes, lowest cost
            • 🐰 Standard: ~2 minutes, moderate cost
            • ⚡ Fast: ~30 seconds, highest cost
            
            Tips to Save on Gas:
            • Use Slow speed when not urgent
            • Send during off-peak hours (weekends, late night UTC)
            • Use Layer 2 networks (Arbitrum, Optimism) for lower fees
            • Batch multiple transactions together when possible
            
            IMPORTANT: You need native tokens (ETH, BTC, etc.) to pay gas fees, even when sending other tokens!
            """,
            relatedArticles: ["How to Send Crypto", "What are Layer 2 Networks?"]
        ),
        HelpArticle(
            title: "How to Verify Transaction Addresses",
            preview: "Avoid sending to wrong addresses",
            content: """
            Crypto transactions are PERMANENT. Sending to wrong address = funds lost forever!
            
            Address Verification Checklist:
            
            ✅ Check First 4 Characters
            ✅ Check Last 4 Characters
            ✅ Verify Middle Characters (sample at least 3 spots)
            ✅ Confirm Network Matches (ETH address for ETH network!)
            ✅ Do Test Transaction First (small amount)
            
            Address Format Examples:
            
            Ethereum (& EVM chains):
            0x742d35Cc6D06b73494d45e5d2b0542f2f...
            (42 characters, starts with 0x)
            
            Bitcoin:
            bc1qw4us8r9ltnf708qj8r2h3x5y2p5r7z9k...
            (starts with bc1, 1, or 3)
            
            Solana:
            7xKXtg2CW87d97TXJSDpbD5jBkheTq...
            (32-44 characters, Base58 format)
            
            WARNING SIGNS:
            ❌ Address format doesn't match network
            ❌ Copy/paste gave different address than shown
            ❌ Address looks suspicious or unusual
            ❌ Sender pressuring you to hurry
            
            BEST PRACTICE:
            Always send a small test transaction first when sending to a new address for the first time!
            """,
            relatedArticles: ["How to Send Crypto", "What if I Send to Wrong Address?"]
        )
    ]
    
    // MARK: - Network Articles
    
    static let networkArticles: [HelpArticle] = [
        HelpArticle(
            title: "What are Blockchain Networks?",
            preview: "Understanding different blockchains",
            content: """
            Different blockchains are like different countries—each has its own currency, rules, and features.
            
            Supported Networks:
            
            🔹 ETHEREUM (Layer 1)
            • Most popular for DeFi and NFTs
            • Native token: ETH
            • Higher gas fees but most secure
            
            ⚡ ARBITRUM (Layer 2)
            • Ethereum scaling solution
            • 10x cheaper gas fees
            • Compatible with Ethereum apps
            
            🔴 OPTIMISM (Layer 2)
            • Another Ethereum Layer 2
            • Fast and cheap transactions
            • Growing ecosystem
            
            🔵 BASE (Layer 2)
            • Coinbase's Layer 2 network
            • Low fees, fast transactions
            • Easy fiat on-ramps
            
            🟣 POLYGON
            • Ethereum sidechain
            • Very low fees
            • Popular for gaming and NFTs
            
            🟡 BSC (Binance Smart Chain)
            • Binance's blockchain
            • Low fees, fast
            • Native token: BNB
            
            🔶 AVALANCHE
            • High-speed blockchain
            • Sub-second finality
            • Native token: AVAX
            
            🟠 BITCOIN
            • First cryptocurrency
            • Most secure network
            • Digital gold, store of value
            
            Key Point: Tokens on one network cannot be directly sent to another network! Always verify the network before sending.
            """,
            relatedArticles: ["How to Enable/Disable Networks", "What are Layer 2 Networks?"]
        ),
        HelpArticle(
            title: "How to Enable/Disable Networks",
            preview: "Manage which blockchains you use",
            content: """
            You can customize which blockchain networks appear in your wallet.
            """,
            steps: [
                "Go to Settings tab",
                "Tap 'Manage Networks'",
                "Toggle networks on/off",
                "Enabled networks will show in your wallet",
                "Tokens on disabled networks are hidden (but NOT deleted)"
            ],
            relatedArticles: ["What are Blockchain Networks?", "Why Can't I See My Tokens?"]
        ),
        HelpArticle(
            title: "What are Layer 2 Networks?",
            preview: "Understanding Ethereum scaling solutions",
            content: """
            Layer 2 (L2) networks are built on top of Ethereum to make transactions faster and cheaper while maintaining security.
            
            How They Work:
            • Process transactions off main Ethereum chain
            • Bundle many transactions together
            • Submit final state to Ethereum
            • Inherit Ethereum's security
            
            Benefits:
            • 10-100x lower fees
            • Faster confirmation times
            • Same addresses as Ethereum
            • Can bridge assets to/from Ethereum
            
            Supported L2s in This App:
            • Arbitrum
            • Optimism
            • Base
            
            Important: Your Ethereum address works on all L2s, but tokens on L2 are separate from Ethereum mainnet. You need to "bridge" to move between networks.
            """,
            relatedArticles: ["What are Blockchain Networks?", "How to Bridge Between Networks"]
        )
    ]
    
    // MARK: - NFT Articles
    
    static let nftArticles: [HelpArticle] = [
        HelpArticle(
            title: "What are NFTs?",
            preview: "Understanding Non-Fungible Tokens",
            content: """
            NFTs (Non-Fungible Tokens) are unique digital items stored on the blockchain. Unlike cryptocurrencies where each token is identical, each NFT is one-of-a-kind.
            
            Common NFT Types:
            • Digital Art
            • Profile Pictures (PFPs)
            • Collectibles
            • Gaming Items
            • Virtual Land
            • Membership Passes
            • Domain Names
            
            Key Features:
            • Provable ownership on blockchain
            • Cannot be duplicated
            • Can be bought, sold, or transferred
            • Metadata stored on-chain or IPFS
            • Royalties can go to creators
            
            This wallet displays NFTs from:
            • Ethereum
            • Polygon
            • Arbitrum
            • Optimism
            • Base
            """,
            relatedArticles: ["How to Send NFTs", "How to View NFT Details"]
        ),
        HelpArticle(
            title: "How to Send NFTs",
            preview: "Transfer your NFTs to another wallet",
            content: """
            NFTs can be sent to other wallets just like regular tokens.
            """,
            steps: [
                "Go to NFTs tab",
                "Tap on the NFT you want to send",
                "Tap 'Send NFT' button",
                "Enter recipient's address",
                "Verify the address carefully",
                "Review gas fee",
                "Tap 'Review Transaction'",
                "Confirm transaction details",
                "Confirm with biometric authentication",
                "NFT will be transferred after confirmation"
            ],
            relatedArticles: ["What are NFTs?", "What are Gas Fees?"]
        ),
        HelpArticle(
            title: "Why Can't I See My NFTs?",
            preview: "Troubleshooting missing NFTs",
            content: """
            If your NFTs are missing, try these solutions:
            
            1. CHECK NETWORK
            Make sure the blockchain network is enabled in Settings → Manage Networks.
            
            2. REFRESH WALLET
            Pull down on the NFTs tab to refresh. NFT data can take time to load.
            
            3. VERIFY BLOCKCHAIN
            NFTs on one blockchain won't show on another. Check where your NFT actually exists.
            
            4. CHECK CONTRACT TYPE
            Some old or non-standard NFTs may not display properly. The NFT still exists in your wallet.
            
            5. API ISSUES
            If our NFT provider has issues, NFTs may temporarily not display. They're still in your wallet!
            
            Your NFTs are Safe:
            Even if they don't display in the app, they exist on the blockchain at your address. You can always verify on a blockchain explorer.
            """,
            relatedArticles: ["What are NFTs?", "How to Enable/Disable Networks"]
        )
    ]
    
    // MARK: - Troubleshooting Articles
    
    static let troubleshootingArticles: [HelpArticle] = [
        HelpArticle(
            title: "Why Can't I See My Tokens?",
            preview: "Troubleshooting missing balances",
            content: """
            If your tokens are missing or showing zero balance, try these steps:
            
            1. CHECK NETWORK SETTINGS
            Go to Settings → Manage Networks and verify the correct blockchain is enabled.
            
            2. REFRESH YOUR WALLET
            Pull down on the Wallet tab to manually refresh balances.
            
            3. VERIFY CORRECT WALLET
            Make sure you're using the same wallet address where you received tokens.
            
            4. CHECK BLOCKCHAIN EXPLORER
            Verify your tokens exist on a blockchain explorer (Etherscan, etc.)
            
            5. WAIT FOR SYNC
            Sometimes it takes a few minutes for balances to update from the blockchain.
            
            6. CHECK CUSTOM TOKENS
            If it's a custom token, you may need to manually add it.
            
            Important: Your tokens are stored on the blockchain, not in the app. Even if the app doesn't display them, they still exist at your address!
            """,
            relatedArticles: ["How to Enable/Disable Networks", "How to Add Custom Tokens"]
        ),
        HelpArticle(
            title: "Transaction is Stuck or Pending",
            preview: "What to do when transactions don't confirm",
            content: """
            If your transaction is stuck in "Pending" status:
            
            Common Causes:
            • Gas fee too low
            • Network congestion
            • Nonce issues
            • Blockchain delays
            
            What to Do:
            
            1. WAIT
            Most transactions confirm within 30 minutes. During high network usage, it can take hours.
            
            2. CHECK GAS FEE
            If you used "Slow" speed during high network activity, it might take longer.
            
            3. VERIFY ON BLOCKCHAIN
            Check the transaction on Etherscan or other explorer. It will show actual status.
            
            4. DON'T RESEND
            Sending the same transaction again creates duplicate, wasting gas fees.
            
            5. SPEED UP (Advanced)
            Some blockchains allow speeding up transactions by replacing with higher gas. This feature coming soon to this wallet.
            
            Prevention:
            • Use "Standard" or "Fast" gas speeds for important transactions
            • Check network status before sending
            • Avoid sending during NFT mints or major events
            """,
            relatedArticles: ["What are Gas Fees?", "How to Send Crypto"]
        ),
        HelpArticle(
            title: "What if I Send to Wrong Address?",
            preview: "Understanding irreversible transactions",
            content: """
            Unfortunately, blockchain transactions are PERMANENT and IRREVERSIBLE.
            
            The Reality:
            • No "undo" button exists
            • No customer support can reverse it
            • Blockchain is designed to be immutable
            • Sent to wrong address = funds are gone
            
            Possible (but unlikely) Recovery:
            
            1. IF YOU OWN BOTH WALLETS
            If you accidentally sent to your own other wallet, you can access it with that wallet's seed phrase.
            
            2. IF RECIPIENT IS KNOWN
            If you know the recipient, you can ask them to send it back (they're not obligated to).
            
            3. IF ADDRESS DOESN'T EXIST
            On some blockchains, sending to invalid address will fail and funds return (rare).
            
            What You Cannot Do:
            ❌ Contact blockchain support (doesn't exist)
            ❌ Reverse the transaction
            ❌ Recover from exchange if wrong network
            ❌ Recover from wrong contract address
            
            PREVENTION IS EVERYTHING:
            • Always verify address character by character
            • Send small test transaction first
            • Use address book for frequent recipients
            • Double-check network matches
            • Never rush transactions
            """,
            relatedArticles: ["How to Verify Transaction Addresses", "How to Send Crypto"]
        ),
        HelpArticle(
            title: "How to Contact Support",
            preview: "Get help with your wallet",
            content: """
            Need help? Here's how to get support:
            
            1. CHECK THIS HELP CENTER FIRST
            Most questions are answered here. Use the search function.
            
            2. EMAIL SUPPORT
            support@wpayin.com
            • Include your wallet address (NOT seed phrase!)
            • Describe the issue clearly
            • Include screenshots if helpful
            • Response time: 24-48 hours
            
            3. COMMUNITY
            Join our Telegram or Discord for community support (links in Settings → About)
            
            SECURITY REMINDER:
            ⚠️ Real support will NEVER:
            • Ask for your seed phrase
            • Ask for your private key
            • Ask you to send crypto to "verify"
            • Contact you first via DM
            • Request remote access to your device
            
            If someone claims to be support and asks for any of the above, it's a SCAM!
            
            What Support Can Help With:
            ✅ App bugs and crashes
            ✅ Feature requests
            ✅ General crypto questions
            ✅ Understanding how to use features
            
            What Support Cannot Help With:
            ❌ Recover lost seed phrases
            ❌ Reverse transactions
            ❌ Access your wallet
            ❌ Reset passwords (we don't have your data!)
            """,
            relatedArticles: ["How to Avoid Scams", "What if I Lose My Seed Phrase?"]
        )
    ]
}

#Preview {
    HelpCenterView()
}
