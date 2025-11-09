//
//  BuyDebugView.swift
//  Wpayin_Wallet
//
//  Debug view for testing Buy Crypto flow
//

import SwiftUI

struct BuyDebugView: View {
    @EnvironmentObject var walletManager: WalletManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Buy Crypto Debug")
                        .font(.wpayinTitle)
                        .foregroundColor(WpayinColors.text)
                    
                    // Test tokens
                    Text("Available Tokens:")
                        .font(.wpayinHeadline)
                        .foregroundColor(WpayinColors.text)
                    
                    ForEach(walletManager.tokens.prefix(5)) { token in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(token.symbol) - \(token.name)")
                                .font(.wpayinSubheadline)
                                .foregroundColor(WpayinColors.text)
                            
                            Text("Address: \(token.receivingAddress ?? "N/A")")
                                .font(.wpayinCaption)
                                .foregroundColor(WpayinColors.textSecondary)
                            
                            // Test URL generation
                            if let address = token.receivingAddress {
                                let config = FiatRampConfig(
                                    provider: .moonpay,
                                    crypto: token.symbol,
                                    walletAddress: address
                                )
                                
                                if let url = FiatRampService.shared.generateURL(for: config) {
                                    Text("URL: \(url.absoluteString)")
                                        .font(.system(size: 10))
                                        .foregroundColor(.green)
                                        .lineLimit(3)
                                } else {
                                    Text("URL: Failed to generate")
                                        .font(.wpayinCaption)
                                        .foregroundColor(.red)
                                }
                                
                                // Test available providers
                                let providers = FiatRampService.shared.availableProviders(for: token.symbol)
                                Text("Providers: \(providers.map { $0.displayName }.joined(separator: ", "))")
                                    .font(.wpayinCaption)
                                    .foregroundColor(.blue)
                            }
                            
                            Divider()
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
            }
            .background(WpayinColors.background)
        }
    }
}

#Preview {
    BuyDebugView()
        .environmentObject(WalletManager())
}
