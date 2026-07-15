// Autor Lukas Helebrandt, 2026

import SwiftUI

struct TimeZoneSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsManager: SettingsManager
    @State private var searchText = ""

    private static let pragueIdentifier = "Europe/Prague"
    private static let allIdentifiers = TimeZone.knownTimeZoneIdentifiers.sorted {
        SettingsManager.cityName(for: $0).localizedCaseInsensitiveCompare(
            SettingsManager.cityName(for: $1)
        ) == .orderedAscending
    }

    private var currentSystemIdentifier: String {
        TimeZone.autoupdatingCurrent.identifier
    }

    private var suggestedIdentifiers: [String] {
        let identifiers = [currentSystemIdentifier, Self.pragueIdentifier]
        var seen = Set<String>()
        return identifiers.filter { seen.insert($0).inserted }
    }

    private var displayedIdentifiers: [String] {
        let suggested = Set(suggestedIdentifiers)
        let remaining = Self.allIdentifiers.filter { !suggested.contains($0) }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return remaining }

        return Self.allIdentifiers.filter { identifier in
            let timeZone = TimeZone(identifier: identifier)
            let name = SettingsManager.cityName(for: identifier)
            let localizedName = timeZone?.localizedName(
                for: .standard,
                locale: Locale(identifier: settingsManager.selectedLanguage.rawValue)
            ) ?? ""
            return identifier.localizedCaseInsensitiveContains(query)
                || name.localizedCaseInsensitiveContains(query)
                || localizedName.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationView {
            List {
                if searchText.isEmpty {
                    Section("Automatic") {
                        automaticRow
                    }

                    Section("Suggested") {
                        ForEach(suggestedIdentifiers, id: \.self) { identifier in
                            timeZoneRow(identifier)
                        }
                    }
                }

                Section(searchText.isEmpty ? "All Time Zones" : "Search Results") {
                    ForEach(displayedIdentifiers, id: \.self) { identifier in
                        timeZoneRow(identifier)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackgroundHiddenIfAvailable()
            .background(WpayinColors.background.ignoresSafeArea())
            .searchable(text: $searchText, prompt: "City or time zone")
            .navigationTitle("Time Zone".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.Action.done.localized) { dismiss() }
                        .foregroundColor(WpayinColors.primary)
                }
            }
        }
    }

    private var automaticRow: some View {
        Button {
            settingsManager.updateTimeZone(identifier: SettingsManager.automaticTimeZoneIdentifier)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(WpayinColors.primary)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Use iPhone Time Zone".localized)
                        .foregroundColor(WpayinColors.text)
                    Text("\(SettingsManager.cityName(for: currentSystemIdentifier)) · \(offsetText(for: currentSystemIdentifier))")
                        .font(.wpayinCaption)
                        .foregroundColor(WpayinColors.textSecondary)
                }

                Spacer()
                selectionMark(settingsManager.usesAutomaticTimeZone)
            }
        }
        .buttonStyle(.plain)
        .listRowBackground(WpayinColors.surface)
    }

    private func timeZoneRow(_ identifier: String) -> some View {
        Button {
            settingsManager.updateTimeZone(identifier: identifier)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: identifier == Self.pragueIdentifier ? "building.2.fill" : "clock.fill")
                    .font(.system(size: 16))
                    .foregroundColor(WpayinColors.primary)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 3) {
                    Text(SettingsManager.cityName(for: identifier))
                        .foregroundColor(WpayinColors.text)
                    Text("\(identifier) · \(offsetText(for: identifier))")
                        .font(.wpayinCaption)
                        .foregroundColor(WpayinColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()
                selectionMark(!settingsManager.usesAutomaticTimeZone && settingsManager.selectedTimeZoneIdentifier == identifier)
            }
        }
        .buttonStyle(.plain)
        .listRowBackground(WpayinColors.surface)
    }

    private func selectionMark(_ isSelected: Bool) -> some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .foregroundColor(isSelected ? WpayinColors.primary : WpayinColors.textTertiary)
    }

    private func offsetText(for identifier: String) -> String {
        guard let timeZone = TimeZone(identifier: identifier) else { return "" }
        return SettingsManager.utcOffset(for: timeZone)
    }
}

private extension View {
    @ViewBuilder
    func scrollContentBackgroundHiddenIfAvailable() -> some View {
        if #available(iOS 16.0, *) {
            scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}
