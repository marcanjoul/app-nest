import SwiftUI
import SwiftData
import PhotosUI

struct EditImportRowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \JobCycle.createdAt, order: .reverse) private var cycles: [JobCycle]
    @State var row: CSVImportRow
    var onSave: (CSVImportRow) -> Void

    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var reminderEnabled = false
    @State private var keyboardIsVisible = false
    @State private var reminderTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()

    private var isSeasonAllowed: Bool {
        let allowed: [ApplicationType] = [.partTime, .internship, .temporary, .Co_op]
        return row.jobType.map { allowed.contains($0) } ?? false
    }

    var body: some View {
        ZStack {
            AmbientBackground()

            ScrollView {
                VStack(spacing: 16) {
                    JobInfoSection(
                        companyName: $row.companyName,
                        companyLogoImageData: $row.logoData,
                        position: $row.position,
                        pickerItem: $pickerItem
                    )
                    TypePickerSection(type: $row.jobType)
                    StatusPickerSection(status: $row.status)
                    if isSeasonAllowed {
                        SeasonPickerSection(season: $row.season)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.95)),
                                removal: .opacity
                            ))
                    }
                    DateAppliedSection(
                        dateApplied: dateAppliedBinding,
                        status: row.status,
                        reminderEnabled: $reminderEnabled,
                        reminderTime: $reminderTime
                    )
                    CompensationSection(
                        kind: $row.compensationKind,
                        amount: compensationAmountBinding,
                        currency: compensationCurrencyBinding,
                        salaryPeriod: salaryPeriodBinding
                    )
                    cycleCard
                    JobNotesSection(jobNotes: $row.notes)
                }
                .onChange(of: row.jobType) { _, _ in
                    if !isSeasonAllowed { row.season = nil }
                }
                .animation(.appSmooth, value: isSeasonAllowed)
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            floatingNavBar
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !keyboardIsVisible { saveBar }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.appCrisp) { keyboardIsVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.appCrisp) { keyboardIsVisible = false }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    UIApplication.shared.dismissKeyboard()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                }
                .accessibilityLabel("Dismiss keyboard")
            }
        }
    }

    // MARK: - Floating nav bar

    private var floatingNavBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 44, height: 44)
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(Circle().strokeBorder(Color.primary.opacity(0.09), lineWidth: 1))
                    }
            }
            .buttonStyle(PressScaleButtonStyle())
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    // MARK: - Save bar

    private var saveBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.4)
            HStack {
                Button {
                    onSave(row)
                    AppHaptics.shared.success()
                    dismiss()
                } label: {
                    Text("Save Changes")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background {
                            Capsule()
                                .fill(Color.accentColor)
                        }
                }
                .buttonStyle(PressScaleButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemBackground))
        }
    }

    // MARK: - Cycle

    private var cycleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(icon: "tray.fill", title: "Cycle")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    cycleChip(name: "None", id: nil)
                    ForEach(cycles) { cycle in
                        cycleChip(name: cycle.name, id: cycle.id)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }
        }
        .padding(16)
        .glassCard()
    }

    @ViewBuilder
    private func cycleChip(name: String, id: UUID?) -> some View {
        let isSelected = row.cycleID == id
        Button {
            withAnimation(.appCrisp) { row.cycleID = id }
            AppHaptics.shared.light()
        } label: {
            Text(name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? Color.accentColor : Theme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    Capsule()
                        .fill(isSelected ? Color.accentColor.opacity(0.13) : Color.primary.opacity(0.06))
                        .overlay(
                            Capsule().strokeBorder(
                                isSelected ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.09),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                        )
                }
        }
        .buttonStyle(.plain)
        .animation(.appCrisp, value: isSelected)
    }

    // MARK: - Date binding

    private var dateAppliedBinding: Binding<Date?> {
        Binding(
            get: { row.dateApplied },
            set: { row.dateApplied = $0 ?? Date() }
        )
    }

    // MARK: - Compensation bindings

    private var compensationAmountBinding: Binding<String> {
        Binding(
            get: {
                guard let v = row.compensationAmount else { return "" }
                return v.truncatingRemainder(dividingBy: 1) == 0
                    ? String(Int(v)) : String(v)
            },
            set: { row.compensationAmount = Double($0) }
        )
    }

    private var compensationCurrencyBinding: Binding<Currency> {
        Binding(
            get: { row.compensationCurrency ?? .usd },
            set: { row.compensationCurrency = $0 }
        )
    }

    private var salaryPeriodBinding: Binding<SalaryPeriod> {
        Binding(
            get: { row.salaryPeriod ?? .yearly },
            set: { row.salaryPeriod = $0 }
        )
    }
}
