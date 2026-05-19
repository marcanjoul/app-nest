import SwiftUI

struct DateAppliedSection: View {
    @Binding var dateApplied: Date
    var status: ApplicationStatus?
    @Binding var reminderEnabled: Bool

    @State private var permissionDenied: Bool = false

    private var isToApply: Bool { status == .toApply }
    private var accent: Color { Color.accentColor }

    private var sectionTitle: String {
        isToApply ? "Date to Apply" : "Date Applied"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(icon: "calendar", title: sectionTitle)

            HStack {
                Spacer()
                if isToApply {
                    DatePicker(
                        "",
                        selection: $dateApplied,
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
                        selection: $dateApplied,
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
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .animation(.appSmooth, value: isToApply)
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
}
