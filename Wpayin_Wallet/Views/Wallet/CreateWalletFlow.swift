//
//  CreateWalletFlow.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI

struct CreateWalletFlow: View {
    @EnvironmentObject var walletManager: WalletManager
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    @State private var termsAccepted = false
    @State private var mnemonic = ""
    @State private var verificationWords: [String] = []
    @State private var selectedVerificationWords: [String] = []
    @State private var showError = false
    @State private var errorMessage = ""

    private let steps = ["Terms", "Generate", "Verify"]

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress Bar
                    ProgressBar(currentStep: currentStep, totalSteps: steps.count)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)

                    // Content
                    switch currentStep {
                    case 0:
                        TermsAndConditionsStep(termsAccepted: $termsAccepted)
                    case 1:
                        GenerateMnemonicStep(mnemonic: $mnemonic)
                    case 2:
                        VerifyMnemonicStep(
                            mnemonic: mnemonic,
                            verificationWords: $verificationWords,
                            selectedVerificationWords: $selectedVerificationWords
                        )
                    default:
                        EmptyView()
                    }

                    Spacer()

                    // Action Buttons
                    VStack(spacing: 12) {
                        WpayinButton(
                            title: nextButtonTitle,
                            style: .primary
                        ) {
                            handleNextStep()
                        }
                        .disabled(!canProceed)

                        if currentStep > 0 {
                            WpayinButton(
                                title: "Back",
                                style: .tertiary
                            ) {
                                currentStep -= 1
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Create Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(WpayinColors.text)
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            generateMnemonic()
        }
    }

    private var nextButtonTitle: String {
        switch currentStep {
        case 0: return "Accept & Continue"
        case 1: return "I've Written it Down"
        case 2: return "Create Wallet"
        default: return "Next"
        }
    }

    private var canProceed: Bool {
        switch currentStep {
        case 0: return termsAccepted
        case 1: return !mnemonic.isEmpty
        case 2: return selectedVerificationWords.count == 3
        default: return false
        }
    }

    private func handleNextStep() {
        if currentStep == steps.count - 1 {
            createWallet()
        } else {
            if currentStep == 1 {
                setupVerification()
            }
            currentStep += 1
        }
    }

    private func generateMnemonic() {
        if let generated = walletManager.generateMnemonic() {
            mnemonic = generated
        } else {
            errorMessage = "Failed to generate a secure recovery phrase. Please try again."
            showError = true
        }
    }

    private func setupVerification() {
        let words = mnemonic.components(separatedBy: " ")
        verificationWords = Array(words.shuffled().prefix(3))
        selectedVerificationWords = []
    }

    private func createWallet() {
        let success = walletManager.createWallet(mnemonic: mnemonic)
        if success {
            dismiss()
        } else {
            errorMessage = "Failed to create wallet. Please try again."
            showError = true
        }
    }
}

#Preview {
    CreateWalletFlow()
        .environmentObject(WalletManager())
}
