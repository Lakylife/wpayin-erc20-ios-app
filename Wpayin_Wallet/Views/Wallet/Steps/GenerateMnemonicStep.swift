//
//  GenerateMnemonicStep.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI

struct GenerateMnemonicStep: View {
    @Binding var mnemonic: String
    @State private var isBlurred = true
    @State private var copied = false

    private var mnemonicWords: [String] {
        mnemonic.components(separatedBy: " ")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Text("Your Recovery Phrase")
                        .font(.wpayinHeadline)
                        .foregroundColor(WpayinColors.text)

                    Text("Write down these 12 words in the exact order shown. This phrase is the only way to recover your wallet.")
                        .font(.wpayinBody)
                        .foregroundColor(WpayinColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                // Warning Box
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(WpayinColors.error)
                        .font(.system(size: 20))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Keep it secure!")
                            .font(.wpayinSubheadline)
                            .foregroundColor(WpayinColors.error)

                        Text("Never share your recovery phrase with anyone. Store it in a safe place.")
                            .font(.wpayinCaption)
                            .foregroundColor(WpayinColors.textSecondary)
                    }

                    Spacer()
                }
                .padding(16)
                .background(WpayinColors.surface)
                .cornerRadius(12)

                // Mnemonic Display
                VStack(spacing: 16) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(Array(mnemonicWords.enumerated()), id: \.offset) { index, word in
                            HStack {
                                Text("\(index + 1).")
                                    .font(.wpayinCaption)
                                    .foregroundColor(WpayinColors.textSecondary)
                                    .frame(width: 20, alignment: .leading)

                                Text(word)
                                    .font(.wpayinBody)
                                    .foregroundColor(WpayinColors.text)

                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(WpayinColors.surfaceLight)
                            .cornerRadius(8)
                            .blur(radius: isBlurred ? 4 : 0)
                        }
                    }

                    // Reveal/Hide Button
                    WpayinButton(
                        title: isBlurred ? "Tap to Reveal" : "Hide",
                        style: .secondary
                    ) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isBlurred.toggle()
                        }
                    }
                }
                .padding(20)
                .background(WpayinColors.surface)
                .cornerRadius(16)

                // Copy Button
                WpayinButton(
                    title: copied ? "Copied!" : "Copy to Clipboard",
                    style: .tertiary
                ) {
                    copyToClipboard()
                }
                .disabled(isBlurred)
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
        }
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = mnemonic
        copied = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copied = false
        }
    }
}

#Preview {
    GenerateMnemonicStep(mnemonic: .constant("abandon ability able about above absent absorb abstract absurd abuse access accident"))
        .background(WpayinColors.background)
}