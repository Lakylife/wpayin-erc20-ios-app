//
//  ProviderSelectionView.swift
//  Wpayin_Wallet
//
//  View for selecting fiat ramp provider
//

import SwiftUI

struct ProviderSelectionView: View {
    let crypto: String
    let walletAddress: String
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProvider: FiatRampProvider?
    @State private var showFiatRamp = false
    @State private var showCompare = false
    
    private var availableProviders: [FiatRampProvider] {
        FiatRampService.shared.availableProviders(for: crypto)
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
                                .font(.system(size: 50))
                                .foregroundColor(WpayinColors.primary)
                            
                            Text("Choose Payment Provider")
                                .font(.wpayinTitle)
                                .foregroundColor(WpayinColors.text)
                            
                            Text("Select how you want to buy \(crypto)")
                                .font(.wpayinBody)
                                .foregroundColor(WpayinColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        
                        // Compare Rates Button
                        if !availableProviders.isEmpty {
                            Button {
                                showCompare = true
                            } label: {
                                HStack {
                                    Image(systemName: "chart.bar.xaxis")
                                        .font(.system(size: 16))
                                    Text("Compare rates from \(availableProviders.count) providers")
                                        .font(.wpayinSubheadline)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                }
                                .foregroundColor(WpayinColors.primary)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(WpayinColors.primary.opacity(0.1))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                        
                        // Providers List
                        VStack(spacing: 16) {
                            ForEach(availableProviders) { provider in
                                ProviderCard(
                                    provider: provider,
                                    isRecommended: provider == FiatRampService.shared.recommendedProvider(for: crypto)
                                ) {
                                    print("👆 Selected provider: \(provider.displayName)")
                                    selectedProvider = provider
                                    showFiatRamp = true
                                }
                            }
                        }
                        .padding(.horizontal)
                        .onAppear {
                            print("🔍 ProviderSelectionView loaded")
                            print("💰 Crypto: \(crypto)")
                            print("📍 Wallet: \(walletAddress)")
                            print("🏪 Available providers: \(availableProviders.map { $0.displayName })")
                        }
                        
                        if availableProviders.isEmpty {
                            VStack(spacing: 16) {
                                ErrorView(message: "No payment providers are currently configured for \(crypto). API keys are required for most providers.")
                                    .padding(.horizontal)
                                
                                Text("Available once configured: MoonPay, Transak, Ramp, Banxa")
                                    .font(.wpayinCaption)
                                    .foregroundColor(WpayinColors.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                        } else {
                            // Info
                            InfoCard()
                                .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Buy \(crypto)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(WpayinColors.primary)
                }
            }
        }
        .sheet(isPresented: $showFiatRamp) {
            if let provider = selectedProvider {
                FiatRampView(config: FiatRampConfig(
                    provider: provider,
                    crypto: crypto,
                    walletAddress: walletAddress,
                    action: .buy
                ))
            }
        }
        .sheet(isPresented: $showCompare) {
            CompareProvidersView(
                crypto: crypto,
                amount: 100, // Default $100
                walletAddress: walletAddress
            )
        }
    }
}

// MARK: - Provider Card

struct ProviderCard: View {
    let provider: FiatRampProvider
    let isRecommended: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                if isRecommended {
                    HStack {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                        Text("RECOMMENDED")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(WpayinColors.primary)
                    .clipShape(Capsule())
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 16)
                    .padding(.top, 12)
                }
                
                HStack(spacing: 16) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(WpayinColors.primary.opacity(0.1))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: provider.logoName)
                            .font(.system(size: 24))
                            .foregroundColor(WpayinColors.primary)
                    }
                    
                    // Info
                    VStack(alignment: .leading, spacing: 6) {
                        Text(provider.displayName)
                            .font(.wpayinSubheadline)
                            .foregroundColor(WpayinColors.text)
                        
                        Text(provider.description)
                            .font(.wpayinCaption)
                            .foregroundColor(WpayinColors.textSecondary)
                            .lineLimit(1)
                        
                        Text("Fee: \(provider.feeRange)")
                            .font(.system(size: 11))
                            .foregroundColor(WpayinColors.primary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(WpayinColors.textTertiary)
                }
                .padding()
            }
            .background(WpayinColors.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isRecommended ? WpayinColors.primary.opacity(0.3) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Info Card

struct InfoCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(WpayinColors.primary)
                Text("Important Information")
                    .font(.wpayinSubheadline)
                    .foregroundColor(WpayinColors.text)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ProviderInfoRow(icon: "checkmark.circle", text: "Purchases are processed by third-party providers")
                ProviderInfoRow(icon: "checkmark.circle", text: "Crypto will be sent directly to your wallet")
                ProviderInfoRow(icon: "checkmark.circle", text: "Processing time: 5-30 minutes")
                ProviderInfoRow(icon: "shield.checkered", text: "Providers may require KYC verification")
            }
        }
        .padding()
        .background(WpayinColors.surface)
        .cornerRadius(12)
    }
}

struct ProviderInfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(WpayinColors.primary)
                .frame(width: 16)
            
            Text(text)
                .font(.wpayinCaption)
                .foregroundColor(WpayinColors.textSecondary)
        }
    }
}
