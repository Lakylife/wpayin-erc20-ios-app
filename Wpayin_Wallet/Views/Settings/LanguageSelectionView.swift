//
//  LanguageSelectionView.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI
import Combine

struct LanguageSelectionView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                WpayinColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(Language.allCases) { language in
                            LanguageRow(
                                language: language,
                                isSelected: settingsManager.selectedLanguage == language
                            ) {
                                settingsManager.updateLanguage(language)
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
            .navigationTitle(L10n.Settings.language.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.Action.cancel.localized) {
                        dismiss()
                    }
                    .foregroundColor(WpayinColors.text)
                }
            }
        }
    }
}

struct LanguageRow: View {
    let language: Language
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(language.flag)
                    .font(.system(size: 24))
                    .frame(width: 32, alignment: .center)

                VStack(alignment: .leading, spacing: 2) {
                    Text(language.name)
                        .font(.wpayinBody)
                        .foregroundColor(WpayinColors.text)

                    Text(language.rawValue.uppercased())
                        .font(.wpayinCaption)
                        .foregroundColor(WpayinColors.textSecondary)
                }

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
}

#Preview {
    LanguageSelectionView()
        .environmentObject(SettingsManager())
}