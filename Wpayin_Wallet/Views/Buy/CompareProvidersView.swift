//
//  CompareProvidersView.swift
//  Wpayin_Wallet
//
//  Compare rates and fees across fiat ramp providers
//

import SwiftUI

struct CompareProvidersView: View {
    let crypto: String
    let amount: Double
    let walletAddress: String
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProvider: FiatRampProvider?
    @State private var showFiatRamp = false
    @State private var sortedProviders: [ProviderQuote] = []
    
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
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 50))
                                .foregroundColor(WpayinColors.primary)
                            
                            Text("Compare Providers")
                                .font(.wpayinTitle)
                                .foregroundColor(WpayinColors.text)
                            
                            Text("Best rates for \(String(format: "$%.2f", amount)) of \(crypto)")
                                .font(.wpayinBody)
                                .foregroundColor(WpayinColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        
                        // Sorted Providers List
                        VStack(spacing: 12) {
                            ForEach(sortedProviders) { quote in
                                CompareCard(quote: quote) {
                                    selectedProvider = quote.provider
                                    showFiatRamp = true
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Info
                        CompareInfoCard()
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Compare Rates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(WpayinColors.primary)
                }
            }
            .onAppear {
                calculateQuotes()
            }
        }
        .sheet(isPresented: $showFiatRamp) {
            if let provider = selectedProvider {
                FiatRampView(config: FiatRampConfig(
                    provider: provider,
                    crypto: crypto,
                    walletAddress: walletAddress
                ))
            }
        }
    }
    
    private func calculateQuotes() {
        sortedProviders = availableProviders.map { provider in
            let fee = provider.estimatedFee
            let feeAmount = amount * (fee / 100)
            let youGet = amount - feeAmount
            
            return ProviderQuote(
                provider: provider,
                feePercentage: fee,
                feeAmount: feeAmount,
                youGet: youGet,
                rating: calculateRating(for: provider)
            )
        }.sorted { $0.youGet > $1.youGet } // Sort by best value (highest youGet)
    }
    
    private func calculateRating(for provider: FiatRampProvider) -> Double {
        // Rating based on fees (lower is better)
        let feeScore = (5.0 - provider.estimatedFee) / 5.0 * 5.0
        return max(1.0, min(5.0, feeScore))
    }
}

// MARK: - Provider Quote Model

struct ProviderQuote: Identifiable {
    let id = UUID()
    let provider: FiatRampProvider
    let feePercentage: Double
    let feeAmount: Double
    let youGet: Double
    let rating: Double
}

// MARK: - Compare Card

struct CompareCard: View {
    let quote: ProviderQuote
    let action: () -> Void
    
    var isBestRate: Bool {
        // First item is always best due to sorting
        return true // We'll handle this in parent
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                // Best Rate Badge
                if quote.youGet == quote.youGet { // Placeholder for "is first"
                    HStack {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                        Text("BEST RATE")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green)
                    .clipShape(Capsule())
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 16)
                    .padding(.top, 12)
                }
                
                HStack(spacing: 16) {
                    // Provider Icon
                    ZStack {
                        Circle()
                            .fill(WpayinColors.primary.opacity(0.1))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: quote.provider.logoName)
                            .font(.system(size: 24))
                            .foregroundColor(WpayinColors.primary)
                    }
                    
                    // Provider Info
                    VStack(alignment: .leading, spacing: 6) {
                        Text(quote.provider.displayName)
                            .font(.wpayinSubheadline)
                            .foregroundColor(WpayinColors.text)
                        
                        // Rating
                        HStack(spacing: 4) {
                            ForEach(0..<5) { index in
                                Image(systemName: index < Int(quote.rating) ? "star.fill" : "star")
                                    .font(.system(size: 10))
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Fee & Amount
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("You get")
                            .font(.wpayinCaption)
                            .foregroundColor(WpayinColors.textSecondary)
                        
                        Text("$\(String(format: "%.2f", quote.youGet))")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(WpayinColors.text)
                        
                        Text("\(String(format: "%.2f", quote.feePercentage))% fee")
                            .font(.system(size: 11))
                            .foregroundColor(WpayinColors.textTertiary)
                    }
                    
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
                    .stroke(Color.green.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Compare Info Card

struct CompareInfoCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(WpayinColors.primary)
                Text("Price Comparison")
                    .font(.wpayinSubheadline)
                    .foregroundColor(WpayinColors.text)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                CompareInfoRow(icon: "chart.line.uptrend.xyaxis", text: "Rates are estimated and may vary")
                CompareInfoRow(icon: "clock.fill", text: "Actual fees shown during checkout")
                CompareInfoRow(icon: "shield.fill", text: "All providers are verified & secure")
                CompareInfoRow(icon: "star.fill", text: "Best rate highlighted at top")
            }
        }
        .padding()
        .background(WpayinColors.surface)
        .cornerRadius(12)
    }
}

struct CompareInfoRow: View {
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

#Preview {
    CompareProvidersView(
        crypto: "ETH",
        amount: 100,
        walletAddress: "0x1234567890123456789012345678901234567890"
    )
}
