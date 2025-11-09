//
//  BuyView.swift
//  Wpayin_Wallet
//
//  SIMPLE working buy view
//

import SwiftUI
import WebKit

struct BuyView: View {
    @EnvironmentObject var walletManager: WalletManager
    @State private var selectedCrypto: String = ""
    @State private var showWidget = false
    
    let cryptos = ["BTC", "ETH", "USDT", "USDC", "BNB", "MATIC", "AVAX", "SOL"]
    
    var walletAddress: String {
        walletManager.walletAddress // No hardcoded fallback
    }
    
    private func addressFor(_ crypto: String) -> String {
        // Prefer derived token-specific receiving address
        if let token = walletManager.tokens.first(where: { $0.symbol.uppercased() == crypto.uppercased() }) {
            let addr = walletManager.depositAddress(for: token)
            if isValidAddress(addr, for: crypto) { return addr }
        }
        // Use main wallet address only for EVM assets when available (no hardcoded samples)
        if ["ETH","USDT","USDC","BNB","MATIC"].contains(crypto.uppercased()) && !walletManager.walletAddress.isEmpty {
            return walletManager.walletAddress
        }
        // Otherwise, require proper derivation (empty string blocks UI)
        return ""
    }
    
    private func isValidAddress(_ address: String, for crypto: String) -> Bool {
        if address.isEmpty { return false }
        switch crypto.uppercased() {
        case "BTC": return address.lowercased().hasPrefix("bc1") || address.lowercased().hasPrefix("1") || address.lowercased().hasPrefix("3")
        case "ETH", "USDT", "USDC", "BNB", "MATIC": return address.lowercased().hasPrefix("0x") && address.count == 42
        default: return true
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "creditcard.and.123")
                                .font(.system(size: 60))
                                .foregroundColor(WpayinColors.primary)
                            
                            Text("Buy Crypto")
                                .font(.wpayinTitle)
                                .foregroundColor(WpayinColors.text)
                            
                            Text("Purchase cryptocurrency with your card or bank account")
                                .font(.wpayinBody)
                                .foregroundColor(WpayinColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.top, 20)
                        
                        // Crypto buttons
                        VStack(spacing: 12) {
                            ForEach(cryptos, id: \.self) { crypto in
                                Button {
                                    let addr = addressFor(crypto)
                                    print("🔵 Buying \(crypto) using address: \(addr)")
                                    selectedCrypto = crypto
                                    showWidget = true
                                } label: {
                                    HStack {
                                        // Token icon
                                        Group {
                                            if let asset = iconAssetName(for: crypto) {
                                                Image(asset)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 32, height: 32)
                                            } else {
                                                placeholderIcon(for: crypto)
                                            }
                                        }
                                        .frame(width: 40)
                                        
                                        VStack(alignment: .leading) {
                                            Text(crypto)
                                                .font(.wpayinHeadline)
                                                .foregroundColor(WpayinColors.text)
                                            Text(getCryptoName(crypto))
                                                .font(.wpayinCaption)
                                                .foregroundColor(WpayinColors.textSecondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Text("Buy")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 8)
                                            .background(WpayinColors.primary)
                                            .cornerRadius(20)
                                    }
                                    .padding()
                                    .background(WpayinColors.surface)
                                    .cornerRadius(12)
                                    .overlay(
                                        Group {
                                            if addressFor(crypto).isEmpty {
                                                Text("No address")
                                                    .font(.wpayinCaption)
                                                    .foregroundColor(.red)
                                                    .padding(6)
                                            }
                                        }, alignment: .bottomTrailing
                                    )
                                }
                                .disabled(addressFor(crypto).isEmpty)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Buy")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showWidget) {
            if !selectedCrypto.isEmpty {
                ProviderSelectionView(
                    crypto: selectedCrypto,
                    walletAddress: addressFor(selectedCrypto)
                )
            }
        }
    }
    
    private func iconAssetName(for crypto: String) -> String? {
        let assetMap: [String: String] = [
            "BTC": "bitcoin",
            "ETH": "ethereum_trx_32",
            "BNB": "binance-smart-chain_trx_32",
            "MATIC": "polygon-pos_trx_32",
            "AVAX": "avalanche_trx_32",
            "SOL": "solana_trx_32"
        ]
        return assetMap[crypto]
    }
    
    @ViewBuilder
    private func placeholderIcon(for crypto: String) -> some View {
        ZStack {
            Circle()
                .fill(tokenColor(for: crypto))
                .frame(width: 32, height: 32)
            
            Text(tokenSymbol(for: crypto))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    private func tokenColor(for crypto: String) -> Color {
        switch crypto {
        case "USDT": return Color(red: 0.20, green: 0.63, blue: 0.54)
        case "USDC": return Color(red: 0.16, green: 0.52, blue: 0.95)
        case "DAI": return Color(red: 0.96, green: 0.68, blue: 0.20)
        default: return WpayinColors.primary
        }
    }
    
    private func tokenSymbol(for crypto: String) -> String {
        switch crypto {
        case "USDT": return "₮"
        case "USDC": return "C"
        case "DAI": return "DAI"
        default: return String(crypto.prefix(1))
        }
    }
    
    private func getCryptoName(_ crypto: String) -> String {
        switch crypto {
        case "BTC": return "Bitcoin"
        case "ETH": return "Ethereum"
        case "USDT": return "Tether"
        case "USDC": return "USD Coin"
        case "BNB": return "Binance Coin"
        case "MATIC": return "Polygon"
        case "AVAX": return "Avalanche"
        case "SOL": return "Solana"
        default: return crypto
        }
    }
}

// MARK: - Simple WebView

struct SimpleWebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.backgroundColor = .systemBackground
        webView.isOpaque = true
        
        print("🌐 Creating WebView for: \(url.absoluteString)")
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url == nil {
            let request = URLRequest(url: url)
            webView.load(request)
            print("📥 Loading URL: \(url.absoluteString)")
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: SimpleWebView
        
        init(_ parent: SimpleWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            print("🔄 Navigation started")
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            print("✅ Navigation finished: \(webView.url?.absoluteString ?? "unknown")")
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            print("❌ Navigation failed: \(error.localizedDescription)")
        }
    }
}

#Preview {
    BuyView()
        .environmentObject(WalletManager())
}
