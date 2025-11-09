//
//  TestBuyView.swift
//  Wpayin_Wallet
//
//  Simple test view to debug Buy flow
//

import SwiftUI

struct TestBuyView: View {
    @EnvironmentObject var walletManager: WalletManager
    @State private var showWidget = false
    
    var testAddress: String {
        // Use first available address
        if !walletManager.walletAddress.isEmpty {
            return walletManager.walletAddress
        }
        // Fallback test address
        return "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Text("Buy Crypto Test")
                        .font(.wpayinTitle)
                        .foregroundColor(WpayinColors.text)
                    
                    Text("Address: \(testAddress.prefix(20))...")
                        .font(.wpayinCaption)
                        .foregroundColor(WpayinColors.textSecondary)
                    
                    // Test buttons for each provider
                    VStack(spacing: 16) {
                        TestProviderButton(name: "MoonPay", crypto: "ETH", address: testAddress)
                        TestProviderButton(name: "Transak", crypto: "ETH", address: testAddress)
                        TestProviderButton(name: "Ramp", crypto: "ETH", address: testAddress)
                        TestProviderButton(name: "Banxa", crypto: "ETH", address: testAddress)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct TestProviderButton: View {
    let name: String
    let crypto: String
    let address: String
    @State private var showWidget = false
    
    private var provider: FiatRampProvider {
        switch name {
        case "MoonPay": return .moonpay
        case "Transak": return .transak
        case "Ramp": return .ramp
        case "Banxa": return .banxa
        default: return .moonpay
        }
    }
    
    var body: some View {
        Button {
            print("🧪 Testing \(name)")
            showWidget = true
        } label: {
            HStack {
                Image(systemName: provider.logoName)
                    .font(.system(size: 20))
                Text("Test \(name)")
                    .font(.wpayinSubheadline)
                Spacer()
                Image(systemName: "chevron.right")
            }
            .padding()
            .background(WpayinColors.surface)
            .cornerRadius(12)
        }
        .sheet(isPresented: $showWidget) {
            let config = FiatRampConfig(
                provider: provider,
                crypto: crypto,
                walletAddress: address
            )
            
            FiatRampView(config: config)
                .onAppear {
                    if let url = FiatRampService.shared.generateURL(for: config) {
                        print("✅ Generated URL: \(url.absoluteString)")
                    } else {
                        print("❌ Failed to generate URL for \(name)")
                    }
                }
        }
    }
}

#Preview {
    TestBuyView()
        .environmentObject(WalletManager())
}
