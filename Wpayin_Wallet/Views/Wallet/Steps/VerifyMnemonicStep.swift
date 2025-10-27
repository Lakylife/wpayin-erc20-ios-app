//
//  VerifyMnemonicStep.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI

struct VerifyMnemonicStep: View {
    let mnemonic: String
    @Binding var verificationWords: [String]
    @Binding var selectedVerificationWords: [String]

    private var mnemonicWords: [String] {
        mnemonic.components(separatedBy: " ")
    }

    private var shuffledWords: [String] {
        let fakeWords = ["fake", "decoy", "wrong", "invalid", "test", "dummy", "false", "bogus", "mock"]
        let allWords = mnemonicWords + fakeWords
        return allWords.shuffled()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Text("Verify Your Phrase")
                        .font(.wpayinHeadline)
                        .foregroundColor(WpayinColors.text)

                    Text("Please select the words in the correct order to verify you've written down your recovery phrase correctly.")
                        .font(.wpayinBody)
                        .foregroundColor(WpayinColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                // Selected Words Display
                VStack(alignment: .leading, spacing: 16) {
                    Text("Select these words in order:")
                        .font(.wpayinSubheadline)
                        .foregroundColor(WpayinColors.text)

                    VStack(spacing: 12) {
                        ForEach(Array(verificationWords.enumerated()), id: \.offset) { index, word in
                            HStack {
                                Text("\(getWordPosition(word)). ")
                                    .font(.wpayinCaption)
                                    .foregroundColor(WpayinColors.textSecondary)

                                if selectedVerificationWords.count > index {
                                    Text(selectedVerificationWords[index])
                                        .font(.wpayinBody)
                                        .foregroundColor(
                                            selectedVerificationWords[index] == word ?
                                            WpayinColors.success : WpayinColors.error
                                        )
                                } else {
                                    Text("_____")
                                        .font(.wpayinBody)
                                        .foregroundColor(WpayinColors.textSecondary)
                                }

                                Spacer()

                                if selectedVerificationWords.count > index {
                                    Button(action: {
                                        removeLastWord()
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(WpayinColors.textSecondary)
                                    }
                                }
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(WpayinColors.surfaceLight)
                            .cornerRadius(8)
                        }
                    }
                }

                // Word Selection Grid
                VStack(alignment: .leading, spacing: 16) {
                    Text("Tap the words:")
                        .font(.wpayinSubheadline)
                        .foregroundColor(WpayinColors.text)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                        ForEach(shuffledWords, id: \.self) { word in
                            WordButton(
                                word: word,
                                isSelected: selectedVerificationWords.contains(word),
                                isCorrect: verificationWords.contains(word)
                            ) {
                                selectWord(word)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
        }
    }

    private func selectWord(_ word: String) {
        guard selectedVerificationWords.count < verificationWords.count,
              !selectedVerificationWords.contains(word) else { return }

        selectedVerificationWords.append(word)
    }

    private func removeLastWord() {
        guard !selectedVerificationWords.isEmpty else { return }
        selectedVerificationWords.removeLast()
    }

    private func getWordPosition(_ word: String) -> Int {
        return (mnemonicWords.firstIndex(of: word) ?? -1) + 1
    }
}

struct WordButton: View {
    let word: String
    let isSelected: Bool
    let isCorrect: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(word)
                .font(.wpayinBody)
                .foregroundColor(textColor)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .background(backgroundColor)
                .cornerRadius(8)
        }
        .disabled(isSelected)
        .buttonStyle(PlainButtonStyle())
    }

    private var backgroundColor: Color {
        if isSelected {
            return isCorrect ? WpayinColors.success.opacity(0.2) : WpayinColors.error.opacity(0.2)
        }
        return WpayinColors.surface
    }

    private var textColor: Color {
        if isSelected {
            return isCorrect ? WpayinColors.success : WpayinColors.error
        }
        return WpayinColors.text
    }
}

#Preview {
    VerifyMnemonicStep(
        mnemonic: "abandon ability able about above absent absorb abstract absurd abuse access accident",
        verificationWords: .constant(["abandon", "ability", "able"]),
        selectedVerificationWords: .constant([])
    )
    .background(WpayinColors.background)
}