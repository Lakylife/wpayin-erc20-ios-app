//
//  FiatRampView.swift
//  Wpayin_Wallet
//
//  Fiat Ramp widget view for buying crypto
//

import SwiftUI

struct FiatRampView: View {
    let config: FiatRampConfig
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()
                
                if let url = FiatRampService.shared.generateURL(for: config) {
                    WebView(url: url, isLoading: $isLoading) { finalURL in
                        // Handle navigation changes
                        checkForSuccessURL(finalURL)
                    }
                    .ignoresSafeArea(edges: .bottom)
                    .onAppear {
                        print("🔗 FiatRampView - Loading URL: \(url.absoluteString)")
                        print("💳 Provider: \(config.provider.displayName)")
                        print("💰 Crypto: \(config.crypto)")
                        print("📍 Address: \(config.walletAddress)")
                    }
                } else {
                    ErrorView(message: "\(config.provider.displayName) requires API key configuration. Please use Mt Pelerin or contact support.")
                        .onAppear {
                            print("❌ FiatRampView - Failed to generate URL")
                            print("💳 Provider: \(config.provider.displayName)")
                            print("💰 Crypto: \(config.crypto)")
                        }
                }
                
                if isLoading {
                    LoadingOverlay()
                }
            }
            .navigationTitle("Buy \(config.crypto)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(WpayinColors.primary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showProviderInfo()
                        } label: {
                            Label("About \(config.provider.displayName)", systemImage: "info.circle")
                        }
                        
                        Button(role: .destructive) {
                            dismiss()
                        } label: {
                            Label("Cancel Purchase", systemImage: "xmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(WpayinColors.primary)
                    }
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func checkForSuccessURL(_ url: URL?) {
        // Check if user completed the purchase
        // Different providers have different success URLs
        guard let url = url else { return }
        
        if url.absoluteString.contains("success") || 
           url.absoluteString.contains("completed") {
            // Purchase likely completed
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                dismiss()
            }
        }
    }
    
    private func showProviderInfo() {
        errorMessage = config.provider.description
        showError = true
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("Loading...")
                    .foregroundColor(.white)
                    .font(.wpayinSubheadline)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(WpayinColors.surface)
            )
        }
    }
}

// MARK: - Error View

struct ErrorView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Configuration Required")
                .font(.wpayinTitle)
                .foregroundColor(WpayinColors.text)
            
            Text(message)
                .font(.wpayinBody)
                .foregroundColor(WpayinColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Text("Mt Pelerin is available and doesn't require API keys")
                .font(.wpayinCaption)
                .foregroundColor(WpayinColors.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WpayinColors.background)
    }
}
