//
//  BuyView.swift
//  Wpayin_Wallet
//
//  Created by AI Assistant on 03.11.2025.
//

import SwiftUI

struct BuyView: View {
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss
    @State private var showCardBuy = false
    @State private var showBankTransfer = false
    @State private var showP2PTrading = false
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        WpayinColors.backgroundGradientStart,
                        WpayinColors.backgroundGradientEnd
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "creditcard.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(WpayinColors.primary)
                            
                            Text("Buy Crypto")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(WpayinColors.text)
                            
                            Text("Choose your preferred payment method")
                                .font(.system(size: 16))
                                .foregroundColor(WpayinColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        
                        // Buy Options
                        VStack(spacing: 16) {
                            BuyMethodCard(
                                icon: "creditcard.fill",
                                title: "Buy with Card",
                                subtitle: "Purchase crypto instantly with debit or credit card",
                                badge: "Instant",
                                badgeColor: .green,
                                action: {
                                    showCardBuy = true
                                }
                            )
                            
                            BuyMethodCard(
                                icon: "building.columns.fill",
                                title: "Bank Transfer",
                                subtitle: "Transfer funds directly from your bank account",
                                badge: "Low Fees",
                                badgeColor: .blue,
                                action: {
                                    showBankTransfer = true
                                }
                            )
                            
                            BuyMethodCard(
                                icon: "arrow.left.arrow.right.circle.fill",
                                title: "P2P Trading",
                                subtitle: "Buy directly from other users with flexible payment",
                                badge: "Best Rates",
                                badgeColor: .orange,
                                action: {
                                    showP2PTrading = true
                                }
                            )
                        }
                        
                        // Info Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Why Buy Crypto?")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(WpayinColors.text)
                            
                            InfoRow(icon: "lock.shield.fill", text: "Secure transactions with bank-level encryption")
                            InfoRow(icon: "bolt.fill", text: "Fast processing and instant delivery")
                            InfoRow(icon: "checkmark.seal.fill", text: "Regulated and compliant platform")
                            InfoRow(icon: "star.fill", text: "24/7 customer support")
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(WpayinColors.surface.opacity(0.5))
                        )
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(WpayinColors.text)
                }
            }
        }
        .sheet(isPresented: $showCardBuy) {
            CardBuyView()
                .environmentObject(walletManager)
                .environmentObject(settingsManager)
        }
        .sheet(isPresented: $showBankTransfer) {
            BankTransferView()
                .environmentObject(walletManager)
                .environmentObject(settingsManager)
        }
        .sheet(isPresented: $showP2PTrading) {
            P2PBuyView()
                .environmentObject(walletManager)
                .environmentObject(settingsManager)
        }
    }
}

struct BuyMethodCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let badge: String
    let badgeColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(WpayinColors.primary.opacity(0.15))
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: icon)
                            .font(.system(size: 26))
                            .foregroundColor(WpayinColors.primary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(title)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(WpayinColors.text)
                            
                            Spacer()
                            
                            Text(badge)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(badgeColor)
                                .cornerRadius(6)
                        }
                        
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundColor(WpayinColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(20)
                
                Divider()
                    .background(WpayinColors.textTertiary.opacity(0.2))
                
                HStack {
                    Text("Learn More")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(WpayinColors.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(WpayinColors.primary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(WpayinColors.surface)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct InfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(WpayinColors.primary)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(WpayinColors.text)
            
            Spacer()
        }
    }
}

// Placeholder views for Card and Bank Transfer
struct CardBuyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 60))
                        .foregroundColor(WpayinColors.primary)
                    
                    Text("Buy with Card")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(WpayinColors.text)
                    
                    Text("Coming Soon")
                        .font(.system(size: 16))
                        .foregroundColor(WpayinColors.textSecondary)
                    
                    Text("This feature will allow you to purchase cryptocurrency using your debit or credit card instantly.")
                        .font(.system(size: 14))
                        .foregroundColor(WpayinColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(WpayinColors.text)
                }
            }
        }
    }
}

struct BankTransferView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 60))
                        .foregroundColor(WpayinColors.primary)
                    
                    Text("Bank Transfer")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(WpayinColors.text)
                    
                    Text("Coming Soon")
                        .font(.system(size: 16))
                        .foregroundColor(WpayinColors.textSecondary)
                    
                    Text("This feature will allow you to purchase cryptocurrency via direct bank transfer with lower fees.")
                        .font(.system(size: 14))
                        .foregroundColor(WpayinColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(WpayinColors.text)
                }
            }
        }
    }
}

#Preview {
    BuyView()
        .environmentObject(WalletManager())
        .environmentObject(SettingsManager())
}
