//
//  TermsAndConditionsStep.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI

struct TermsAndConditionsStep: View {
    @Binding var termsAccepted: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Terms & Conditions")
                        .font(.wpayinHeadline)
                        .foregroundColor(WpayinColors.text)

                    Text("Please read and accept our terms to continue")
                        .font(.wpayinBody)
                        .foregroundColor(WpayinColors.textSecondary)
                }

                VStack(alignment: .leading, spacing: 16) {
                    TermsSection(
                        icon: "shield.fill",
                        title: "Security",
                        description: "Your wallet is secured with military-grade encryption. We never store your private keys."
                    )

                    TermsSection(
                        icon: "key.fill",
                        title: "Your Responsibility",
                        description: "You are solely responsible for keeping your seed phrase secure. We cannot recover lost wallets."
                    )

                    TermsSection(
                        icon: "exclamationmark.triangle.fill",
                        title: "Risk Warning",
                        description: "Cryptocurrency investments carry high risk. Only invest what you can afford to lose."
                    )

                    TermsSection(
                        icon: "doc.text.fill",
                        title: "Agreement",
                        description: "By using Wpayin Wallet, you agree to our Terms of Service and Privacy Policy."
                    )
                }
                .padding(.top, 20)

                // Acceptance Checkbox
                HStack(spacing: 12) {
                    Button(action: {
                        termsAccepted.toggle()
                    }) {
                        Image(systemName: termsAccepted ? "checkmark.square.fill" : "square")
                            .font(.system(size: 20))
                            .foregroundColor(termsAccepted ? WpayinColors.primary : WpayinColors.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("I have read and agree to the")
                            .font(.wpayinCaption)
                            .foregroundColor(WpayinColors.textSecondary)

                        HStack(spacing: 4) {
                            Button("Terms of Service") {
                                // Open terms
                            }
                            .foregroundColor(WpayinColors.primary)

                            Text("and")
                                .foregroundColor(WpayinColors.textSecondary)

                            Button("Privacy Policy") {
                                // Open privacy policy
                            }
                            .foregroundColor(WpayinColors.primary)
                        }
                        .font(.wpayinCaption)
                    }

                    Spacer()
                }
                .padding(.top, 20)
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
        }
    }
}

struct TermsSection: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(WpayinColors.primary)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.wpayinSubheadline)
                    .foregroundColor(WpayinColors.text)

                Text(description)
                    .font(.wpayinBody)
                    .foregroundColor(WpayinColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    TermsAndConditionsStep(termsAccepted: .constant(false))
        .background(WpayinColors.background)
}