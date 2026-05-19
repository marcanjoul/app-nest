import SwiftUI

// Shared form row components used by both AddMenuView and EmailParserView.

struct EditableFieldRow: View {
    let icon: String
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    let index: Int

    @FocusState private var isFocused: Bool
    @State private var appeared = false

    private var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isEmpty ? .orange : Theme.textSecondary)
                    .frame(width: 14)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                if isEmpty {
                    Text("· Fill in")
                        .font(.caption2)
                        .foregroundStyle(.orange.opacity(0.85))
                }
            }

            TextField(placeholder.isEmpty ? label : placeholder, text: $text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.textPrimary)
                .focused($isFocused)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    isFocused ? Color.accentColor.opacity(0.04) :
                    isEmpty   ? Color.orange.opacity(0.06) :
                    Color.primary.opacity(0.04)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            isFocused ? Color.accentColor.opacity(0.5) :
                            isEmpty   ? Color.orange.opacity(0.28) :
                            Color.primary.opacity(0.07),
                            lineWidth: isFocused ? 1.5 : 1
                        )
                }
        }
        .animation(.appFastOut, value: isFocused)
        .animation(.appFastOut, value: isEmpty)
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -14)
        .onAppear {
            withAnimation(.appSmooth.delay(Double(index) * 0.05)) {
                appeared = true
            }
        }
    }
}

struct JobTypePickerRow: View {
    @Binding var jobType: ApplicationType?
    let index: Int

    @State private var appeared = false

    private var sortedTypes: [ApplicationType] {
        guard let sel = jobType else { return ApplicationType.allCases }
        return [sel] + ApplicationType.allCases.filter { $0 != sel }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 14)
                Text("Job Type")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sortedTypes, id: \.self) { t in
                        SelectablePill(
                            option: t,
                            isSelected: jobType == t,
                            color: t.color,
                            icon: t.iconName,
                            onTap: {
                                withAnimation(.appCrisp) { jobType = jobType == t ? nil : t }
                                AppHaptics.shared.light()
                            }
                        )
                    }
                }
                .padding(.vertical, 2)
                .animation(.appCrisp, value: jobType)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -14)
        .onAppear {
            withAnimation(.appSmooth.delay(Double(index) * 0.05)) { appeared = true }
        }
    }
}

struct StatusPickerRow: View {
    @Binding var status: ApplicationStatus
    let index: Int

    @State private var appeared = false

    private var sortedStatuses: [ApplicationStatus] {
        [status] + ApplicationStatus.allCases.filter { $0 != status }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "rectangle.and.hand.point.up.left.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 14)
                Text("Status")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sortedStatuses, id: \.self) { s in
                        SelectablePill(
                            option: s,
                            isSelected: status == s,
                            color: s.color,
                            icon: s.iconName,
                            onTap: {
                                withAnimation(.appCrisp) { status = s }
                                AppHaptics.shared.light()
                            }
                        )
                    }
                }
                .padding(.vertical, 2)
                .animation(.appCrisp, value: status)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -14)
        .onAppear {
            withAnimation(.appSmooth.delay(Double(index) * 0.05)) { appeared = true }
        }
    }
}

struct SeasonPickerRow: View {
    @Binding var season: ApplicationSeason?
    let index: Int

    @State private var appeared = false

    private var sortedSeasons: [ApplicationSeason] {
        guard let sel = season else { return ApplicationSeason.allCases }
        return [sel] + ApplicationSeason.allCases.filter { $0 != sel }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sun.snow.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 14)
                Text("Season")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sortedSeasons, id: \.self) { s in
                        SelectablePill(
                            option: s,
                            isSelected: season == s,
                            color: s.color,
                            icon: s.iconName,
                            onTap: {
                                withAnimation(.appCrisp) { season = season == s ? nil : s }
                                AppHaptics.shared.light()
                            }
                        )
                    }
                }
                .padding(.vertical, 2)
                .animation(.appCrisp, value: season)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -14)
        .onAppear {
            withAnimation(.appSmooth.delay(Double(index) * 0.05)) { appeared = true }
        }
    }
}

struct DatePickerRow: View {
    @Binding var date: Date
    let index: Int

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 14)
                Text("DATE APPLIED")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(Theme.sectionLabelSpacing)
                    .foregroundStyle(Theme.textSecondary)
            }

            HStack {
                Spacer()
                DatePicker("", selection: $date, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .controlSize(.large)
                    .tint(Color.accentColor)
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.04))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                }
        }
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -14)
        .onAppear {
            withAnimation(.appSmooth.delay(Double(index) * 0.05)) { appeared = true }
        }
    }
}
