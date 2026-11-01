import SwiftUI

struct DateAppliedSection: View {
    @Binding var dateApplied: Date?
    var status: ApplicationStatus?
    @Binding var reminderEnabled: Bool
    @Binding var reminderTime: Date
    /// When true, renders with a compact row background instead of a standalone surface.
    /// Use this when embedding inside another card (e.g. EmailParseResultsCard).
    var isEmbedded: Bool = false

    @State private var permissionDenied: Bool = false
    @State private var isShowingPicker = false

    private var isToApply: Bool { status == .toApply }
    private var accent: Color { Theme.accent }
    /// Date chips and their calendar use the Offer pill's green.
    private var chipColor: Color { ApplicationStatus.offer.color }

    private var sectionTitle: String {
        isToApply ? "Date to Apply" : "Date Applied"
    }

    private var quickDates: [QuickDate] { isToApply ? QuickDate.future : QuickDate.past }

    /// The chip whose day matches the current date, if any — first wins when two land on one day.
    private var selectedQuickDate: QuickDate? {
        guard let dateApplied else { return nil }
        return quickDates.first { Calendar.current.isDate($0.date(), inSameDayAs: dateApplied) }
    }

    private static let chipDateFormat: Date.FormatStyle = .dateTime.month(.abbreviated).day()

    /// The fourth chip: "Select a date", or the picked date once it isn't a shortcut.
    private var customLabel: String {
        guard let dateApplied, selectedQuickDate == nil else { return "Select a date" }
        return dateApplied.formatted(Self.chipDateFormat)
    }

    var body: some View {
        Group {
            if isEmbedded {
                contentStack
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                            .overlay {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                            }
                    }
            } else {
                contentStack
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .surface()
            }
        }
        .animation(.appSmooth, value: isToApply)
        .animation(.appSmooth, value: reminderEnabled)
        .animation(.appFastOut, value: permissionDenied)
        .task(id: isToApply) {
            guard isToApply else { return }
            let denied = await NotificationManager.isDenied()
            await MainActor.run {
                permissionDenied = denied
                if denied { reminderEnabled = false }
            }
        }
    }

    private var contentStack: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(icon: "calendar", title: sectionTitle)

            // Shortcuts for the dates people actually log, plus the calendar as the fourth chip.
            // A 2×2 grid of equal widths so nothing runs past the card edge.
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    quickChip(quickDates[0])
                    quickChip(quickDates[1])
                }
                GridRow {
                    quickChip(quickDates[2])
                    dateChip(customLabel, icon: "calendar", isSelected: dateApplied != nil && selectedQuickDate == nil) {
                        isShowingPicker = true
                    }
                    .popover(isPresented: $isShowingPicker) {
                        DatePicker(
                            "",
                            selection: Binding(get: { dateApplied ?? Date() }, set: { dateApplied = $0 }),
                            in: isToApply ? Date()...Date.distantFuture : Date.distantPast...Date(),
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        .datePickerStyle(.graphical)
                        .tint(chipColor)
                        .padding()
                        .frame(width: 340)
                        .presentationCompactAdaptation(.popover)
                    }
                }
            }
            .animation(.appCrisp, value: selectedQuickDate)

            if isToApply {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: $reminderEnabled) {
                        HStack(spacing: 8) {
                            AppIcon("bell.badge.fill")
                                .appFont(13, weight: .semibold)
                                .foregroundStyle(accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Remind me to apply")
                                    .appFont(.body, weight: .semibold)
                                    .foregroundStyle(Theme.textPrimary)
                                Text("We'll send a notification on this date so you don't forget.")
                                    .appFont(.caption, weight: .medium)
                                    .foregroundStyle(Theme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .tint(accent)

                    if reminderEnabled && !permissionDenied {
                        HStack(spacing: 10) {
                            AppIcon("clock.fill")
                                .appFont(13, weight: .semibold)
                                .foregroundStyle(accent)
                                .frame(width: 16)
                            Text("Remind me at")
                                .appFont(.body, weight: .medium)
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            DatePicker("", selection: $reminderTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .tint(accent)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.95)))
                    }

                    if permissionDenied {
                        HStack(spacing: 6) {
                            AppIcon("exclamationmark.triangle.fill")
                                .appFont(11, weight: .semibold)
                                .foregroundStyle(Color.orange)
                            Text("Enable notifications in Settings to receive reminders.")
                                .appFont(.caption, weight: .medium)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.95)))
                .onChange(of: reminderEnabled) { old, newValue in
                    guard newValue else { return }
                    Task {
                        let granted = await NotificationManager.requestAuthorization()
                        await MainActor.run {
                            if granted {
                                permissionDenied = false
                            } else {
                                permissionDenied = true
                                reminderEnabled = false
                            }
                        }
                    }
                }
            }
        }
    }

    private func quickChip(_ quick: QuickDate) -> some View {
        dateChip(quick.rawValue, icon: nil, isSelected: quick == selectedQuickDate) {
            withAnimation(.appCrisp) { dateApplied = quick.date() }
        }
    }

    /// Equal-width capsule, SelectablePill's shape in the Offer green.
    private func dateChip(_ title: String, icon: String?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    AppIcon(icon)
                        .appFont(12, weight: .bold)
                }
                Text(title)
                    .appFont(.footnote, weight: isSelected ? .bold : .semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(isSelected ? .white : chipColor.opacity(0.88))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(isSelected ? chipColor : chipColor.opacity(0.12))
                    .overlay(Capsule().strokeBorder(isSelected ? .clear : chipColor.opacity(0.28), lineWidth: 0.8))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
