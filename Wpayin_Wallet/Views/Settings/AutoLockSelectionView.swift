//
//  AutoLockSelectionView.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI
import Combine

struct AutoLockSelectionView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(AutoLockDuration.allCases) { duration in
                            AutoLockRow(
                                duration: duration,
                                isSelected: settingsManager.autoLockDuration == duration
                            ) {
                                settingsManager.updateAutoLock(duration)
                                dismiss()
                            }
                        }
                    }
                    .background(WpayinColors.surface)
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Auto-Lock")
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
    }
}

struct AutoLockRow: View {
    let duration: AutoLockDuration
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: iconName)
                    .font(.system(size: 20))
                    .foregroundColor(WpayinColors.primary)
                    .frame(width: 24, height: 24)

                Text(duration.displayName)
                    .font(.wpayinBody)
                    .foregroundColor(WpayinColors.text)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(WpayinColors.primary)
                }
            }
            .padding(16)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var iconName: String {
        switch duration {
        case .immediately:
            return "bolt.fill"
        case .after1min, .after5min, .after15min, .after1hour:
            return "clock.fill"
        case .never:
            return "infinity"
        }
    }
}

#Preview {
    AutoLockSelectionView()
        .environmentObject(SettingsManager())
}