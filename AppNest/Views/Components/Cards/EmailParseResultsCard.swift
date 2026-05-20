import SwiftUI
import PhotosUI

/// Shared results card used by both AddMenuView (inline) and EmailParserView (standalone sheet).
/// Pass the ViewModel and view-specific save/cancel callbacks.
struct EmailParseResultsCard: View {
    @Bindable var vm: EmailParseViewModel
    let resumes: [ResumeDocument]
    let onSave: () -> Void
    let onCancel: () -> Void

    private var compensationAmountBinding: Binding<String> {
        Binding(
            get: {
                guard let v = vm.editCompensationAmount else { return "" }
                return v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(v)
            },
            set: { vm.editCompensationAmount = Double($0) }
        )
    }

    private var compensationCurrencyBinding: Binding<Currency> {
        Binding(
            get: { vm.editCompensationCurrency ?? .usd },
            set: { vm.editCompensationCurrency = $0 }
        )
    }

    private var salaryPeriodBinding: Binding<SalaryPeriod> {
        Binding(
            get: { vm.editSalaryPeriod ?? .yearly },
            set: { vm.editSalaryPeriod = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            companyAvatar
            formFields
            Divider().opacity(0.4)
            actionButtons
        }
        .padding(18)
        .glassCard()
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
            removal: .opacity
        ))
    }

    private var header: some View {
        HStack {
            Label("Review & Edit", systemImage: "square.and.pencil")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            let missing = (vm.editCompany.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 1 : 0)
                        + (vm.editPosition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 1 : 0)
            if missing > 0 {
                Label("\(missing) field\(missing == 1 ? "" : "s") need attention", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
            }
        }
    }

    private var companyAvatar: some View {
        HStack {
            Spacer()
            PhotosPicker(selection: $vm.pickerItem, matching: .images) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.avatarFill(for: vm.editCompany.isEmpty ? "?" : vm.editCompany))
                    let initial = vm.editCompany.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? "?"
                    Text(initial)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .opacity(vm.fetchedLogoData == nil ? 1 : 0)
                    if let data = vm.fetchedLogoData, let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                            .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    }
                    if vm.isFetchingLogo {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                        ProgressView().tint(.white)
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
                .overlay(alignment: .bottomTrailing) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 20, height: 20)
                        Image(systemName: "pencil")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: Color.accentColor.opacity(0.28), radius: 4, y: 2)
                    .offset(x: 2, y: 2)
                }
            }
            .buttonStyle(.plain)
            .onChange(of: vm.pickerItem) { _, newValue in
                guard let newValue else { return }
                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self) {
                        withAnimation(.appSmooth) { vm.fetchedLogoData = data }
                    }
                }
            }
            .animation(.appSmooth, value: vm.fetchedLogoData == nil)
            .animation(.appFastOut, value: vm.isFetchingLogo)
            Spacer()
        }
    }

    private var isSeasonAllowed: Bool {
        let allowed: [ApplicationType] = [.partTime, .internship, .temporary, .Co_op]
        return vm.editJobType.map { allowed.contains($0) } ?? false
    }

    private var isInterviewStage: Bool {
        vm.editStatus == .interview || vm.editStatus == .offer
    }

    private var formFields: some View {
        VStack(spacing: 12) {
            EditableFieldRow(icon: "building.2", label: "Company", text: $vm.editCompany, placeholder: "Company name", index: 0)
            EditableFieldRow(icon: "briefcase", label: "Position / Role", text: $vm.editPosition, placeholder: "Job title", index: 1)
            TypePickerSection(type: $vm.editJobType, isEmbedded: true)
            StatusPickerSection(
                status: Binding(get: { vm.editStatus }, set: { vm.editStatus = $0 ?? .applied }),
                isEmbedded: true
            )
            if isSeasonAllowed {
                SeasonPickerSection(season: $vm.editSeason, isEmbedded: true)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.95)),
                        removal: .opacity
                    ))
            }
            DateAppliedSection(
                dateApplied: $vm.editDate,
                status: vm.editStatus,
                reminderEnabled: $vm.editReminderEnabled,
                reminderTime: $vm.editReminderTime,
                isEmbedded: true
            )
            JobLinkSection(jobURL: $vm.editJobURL, isEmbedded: true)

            Group {
                CompensationSection(
                    kind: $vm.editCompensationKind,
                    amount: compensationAmountBinding,
                    currency: compensationCurrencyBinding,
                    salaryPeriod: salaryPeriodBinding
                )
                ResumeSection(
                    resumes: resumes,
                    attachedResume: vm.editAttachedResume,
                    legacyResumeFileName: nil,
                    attachedResumeWasDeleted: false,
                    onSelectResume: { vm.editAttachedResume = $0 },
                    onViewAll: {},
                    onPick: {},
                    onClear: { vm.editAttachedResume = nil }
                )
                JobNotesSection(jobNotes: $vm.editNotes)
                if isInterviewStage {
                    InterviewKitSection(
                        companyResearch: $vm.editCompanyResearch,
                        interviewNotes: $vm.editInterviewNotes,
                        isEmbedded: true
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.96, anchor: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .top))
                    ))
                }
            }
            .padding(.top, 4)
        }
        .animation(.appSmooth, value: isSeasonAllowed)
        .animation(.appSmooth, value: isInterviewStage)
        .onChange(of: vm.editJobType) { _, _ in
            if !isSeasonAllowed { vm.editSeason = nil }
        }
        .id(vm.parseCount)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: onSave) {
                Label(
                    vm.saveSuccess ? "Added!" : "Add to Applications",
                    systemImage: vm.saveSuccess ? "checkmark.circle.fill" : "plus.circle.fill"
                )
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background {
                    let c: Color = vm.isSaveDisabled ? .secondary.opacity(0.3)
                                 : vm.saveSuccess    ? Color.green
                                 : Color.accentColor
                    Capsule()
                        .fill(c)
                }
                .animation(.appSmooth, value: vm.saveSuccess)
            }
            .buttonStyle(PressScaleButtonStyle())
            .scaleEffect(vm.saveSuccess ? 1.02 : 1.0)
            .animation(.appBouncy, value: vm.saveSuccess)
            .disabled(vm.isSaveDisabled || vm.saveSuccess)

            Button(action: onCancel) {
                Text("Cancel")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background {
                        Capsule()
                            .fill(Theme.destructive)
                    }
            }
            .buttonStyle(PressScaleButtonStyle())
        }
    }
}
