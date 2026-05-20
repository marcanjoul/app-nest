import SwiftUI

struct DateAppliedSection: View {
    @Binding var dateApplied: Date?
    var status: ApplicationStatus?
    @Binding var reminderEnabled: Bool
    @Binding var reminderTime: Date
    /// When true, renders with a compact row background instead of a standalone glass card.
    /// Use this when embedding inside another card (e.g. EmailParseResultsCard).
    var isEmbedded: Bool = false

    @State private var permissionDenied: Bool = false

    private var isToApply: Bool { status == .toApply }
    private var accent: Color { Color.accentColor }

    private var sectionTitle: String {
        isToApply ? "Date to Apply" : "Date Applied"
    }

    var body: some View {
        Group {
            if isEmbedded {
                contentStack
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                            }
                    }
            } else {
                contentStack
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()
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

            HStack {
                Spacer()
                if dateApplied == nil {
                    Button {
                        withAnimation(.appSmooth) { dateApplied = Date() }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Select a date")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundStyle(accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(accent.opacity(0.10))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(accent.opacity(0.22), lineWidth: 1)
                                }
                        }
                    }
                    .buttonStyle(PressScaleButtonStyle())
                } else if isToApply {
                    DatePicker(
                        "",
                        selection: Binding(get: { dateApplied ?? Date() }, set: { dateApplied = $0 }),
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .controlSize(.large)
                    .tint(accent)
                } else {
                    DatePicker(
                        "",
                        selection: Binding(get: { dateApplied ?? Date() }, set: { dateApplied = $0 }),
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .controlSize(.large)
                    .tint(accent)
                }
                Spacer()
            }
            .padding(.vertical, 2)

            if isToApply {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: $reminderEnabled) {
                        HStack(spacing: 8) {
                            Image(systemName: "bell.badge.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Remind me to apply")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Theme.textPrimary)
                                Text("We'll send a notification on this date so you don't forget.")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Theme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .tint(accent)

                    if reminderEnabled && !permissionDenied {
                        HStack(spacing: 10) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(accent)
                                .frame(width: 16)
                            Text("Remind me at")
                                .font(.system(size: 14, weight: .medium))
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
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.orange)
                            Text("Enable notifications in Settings to receive reminders.")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.95)))
                .onChange(of: reminderEnabled) { _, newValue in
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
}
