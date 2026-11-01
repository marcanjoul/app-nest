import SwiftUI
import SwiftData
import MapKit

struct LocationSection: View {
    @Binding var workMode: WorkMode?
    @Binding var location: String

    @Query private var applications: [JobApplication]
    @State private var completer = CityCompleter()
    @FocusState private var isFocused: Bool

    private var showLocationField: Bool {
        workMode == .hybrid || workMode == .onSite
    }

    /// Places from the user's own applications first (same spelling as last time), then Apple Maps cities. Max 5.
    private var suggestions: [String] {
        let query = location.trimmingCharacters(in: .whitespaces)
        guard isFocused, !query.isEmpty else { return [] }
        var seen = Set<String>()
        let existing = applications
            .compactMap { $0.location?.trimmingCharacters(in: .whitespaces) }
            .filter { $0.localizedCaseInsensitiveContains(query) && seen.insert($0.lowercased()).inserted }
        let cities = completer.results
            .filter { seen.insert($0.lowercased()).inserted }
        let all = Array((existing + cities).prefix(5))
        // Already typed in full — nothing left to suggest.
        if all.count == 1, all[0].lowercased() == query.lowercased() { return [] }
        return all
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(icon: "mappin.circle.fill", title: "Location")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(WorkMode.allCases, id: \.self) { mode in
                        SelectablePill(
                            option: mode,
                            isSelected: workMode == mode,
                            color: mode.color,
                            icon: mode.iconName,
                            onTap: {
                                withAnimation(.appCrisp) {
                                    let next: WorkMode? = workMode == mode ? nil : mode
                                    workMode = next
                                    if next == .remote || next == nil {
                                        location = ""
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }

            if showLocationField {
                TextField("City, state, or country", text: $location)
                    .appFont(.body)
                    .foregroundStyle(Theme.textPrimary)
                    .tint(Theme.accent)
                    .textInputAutocapitalization(.words)
                    .focused($isFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                            }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .onChange(of: location) { _, new in
                        if isFocused { completer.search(new.trimmingCharacters(in: .whitespaces)) }
                    }

                if !suggestions.isEmpty {
                    suggestionList
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .animation(.appCrisp, value: showLocationField)
        .animation(.appFastOut, value: suggestions)
        .padding(16)
        .surface()
    }

    private var suggestionList: some View {
        VStack(spacing: 0) {
            ForEach(Array(suggestions.enumerated()), id: \.element) { index, suggestion in
                if index > 0 { Divider().opacity(0.4).padding(.leading, 40) }
                Button {
                    AppHaptics.shared.selection()
                    location = suggestion
                    isFocused = false
                } label: {
                    HStack(spacing: 12) {
                        AppIcon("mappin")
                            .appFont(12, weight: .semibold)
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 16)
                        Text(suggestion)
                            .appFont(.body, weight: .medium)
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressScaleButtonStyle())
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                }
        }
    }
}

/// City-level Apple Maps autocomplete. Free, no API key, and debounced by MapKit itself.
@Observable
private final class CityCompleter: NSObject, MKLocalSearchCompleterDelegate {
    private(set) var results: [String] = []
    @ObservationIgnored private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.resultTypes = .address
        completer.addressFilter = MKAddressFilter(including: .locality)
        completer.delegate = self
    }

    func search(_ query: String) {
        guard query.count >= 2 else { completer.cancel(); results = []; return }
        completer.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        // "San Francisco" + "CA, United States" → "San Francisco, CA".
        // ponytail: assumes region-first subtitles; reshape here if a locale formats them otherwise.
        results = completer.results.map { r in
            if r.title.contains(",") { return r.title }
            let region = r.subtitle.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
            return region.isEmpty ? r.title : "\(r.title), \(region)"
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        results = []
    }
}
