//
//  ProgressBar.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI

struct ProgressBar: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { step in
                RoundedRectangle(cornerRadius: 4)
                    .fill(step <= currentStep ? WpayinColors.primary : WpayinColors.surface)
                    .frame(height: 8)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentStep)
    }
}

#Preview {
    VStack(spacing: 20) {
        ProgressBar(currentStep: 0, totalSteps: 3)
        ProgressBar(currentStep: 1, totalSteps: 3)
        ProgressBar(currentStep: 2, totalSteps: 3)
    }
    .padding()
    .background(WpayinColors.background)
}