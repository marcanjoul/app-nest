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
            actionButtons
                .padding(.top, 4)
        }
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
            removal: .opacity
        ))
    }

    private var header: some View {
        HStack {
            AppLabel("Review & Edit", systemImage: "square.and.pencil")
                .appFont(15, weight: .semibold)
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            let missing = (vm.editCompany.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 1 : 0)
                        + (vm.editPosition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 1 : 0)
            if missing > 0 {
                AppLabel("\(missing) field\(missing == 1 ? "" : "s") need attention", systemImage: "exclamationmark.triangle.fill")
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
                    InitialAvatar(name: vm.editCompany, fontSize: 24)
                        .opacity(vm.fetchedLogoData == nil ? 1 : 0)
                    if let data = vm.fetchedLogoData, let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                            .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    }
                    if vm.isFetchingLogo {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                        ProgressView().tint(.white)
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .background {
                    if vm.isFetchingLogo {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.primary.opacity(0.12))
                    }
                }
                .opacity(vm.isFetchingLogo ? 0.8 : 1.0)
                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
                .overlay(alignment: .bottomTrailing) {
                    ZStack {
                        Circle()
                            .fill(Theme.buttonGreen)
                            .frame(width: 20, height: 20)
                        AppIcon("pencil")
                            .appFont(10, weight: .bold)
                            .foregroundStyle(.white)
                    }
                    .shadow(color: Theme.buttonGreen.opacity(0.28), radius: 4, y: 2)
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
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                EditableFieldRow(icon: "building.2", label: "Company", text: $vm.editCompany, placeholder: "Company name", index: 0)
                EditableFieldRow(icon: "briefcase", label: "Position / Role", text: $vm.editPosition, placeholder: "Job title", index: 1, axis: .vertical)
            }
            .padding(16)
            .surface()

            // Embedded pickers carry 12pt padding of their own; 4 more lands them on the 16pt card grid.
            VStack(spacing: 0) {
                TypePickerSection(type: $vm.editJobType, isEmbedded: true)
                StatusPickerSection(
                    status: Binding(get: { vm.editStatus }, set: { vm.editStatus = $0 ?? .applied }),
                    isEmbedded: true
                )
                if isSeasonAllowed {
                    SeasonPickerSection(seasons: $vm.editSeasons, isEmbedded: true)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.95)),
                            removal: .opacity
                        ))
                }
            }
            .padding(4)
            .surface()

            optionalSections
        }
        .animation(.appSmooth, value: isSeasonAllowed)
        .animation(.appSmooth, value: isInterviewStage)
        .onChange(of: vm.editJobType) { _, _ in
            if !isSeasonAllowed { vm.editSeasons = [] }
        }
        .id(vm.parseCount)
    }

    /// One-line collapsed cards; a section opens by itself only when the parser filled it.
    /// `formFields` is re-identified per parse, so every new parse starts collapsed again.
    private var optionalSections: some View {
        VStack(spacing: 16) {
            CollapsibleSection(icon: "calendar", title: vm.editStatus == .toApply ? "Date to Apply" : "Date Applied",
                               startsExpanded: false) {
                DateAppliedSection(
                    dateApplied: $vm.editDate,
                    status: vm.editStatus,
                    reminderEnabled: $vm.editReminderEnabled,
                    reminderTime: $vm.editReminderTime
                )
            }
            CollapsibleSection(icon: "link", title: "Job Link",
                               startsExpanded: !vm.editJobURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                JobLinkSection(jobURL: $vm.editJobURL)
            }
            CollapsibleSection(icon: "dollarsign.circle", title: "Compensation",
                               startsExpanded: vm.editCompensationKind != nil || vm.editCompensationAmount != nil) {
                CompensationSection(
                    kind: $vm.editCompensationKind,
                    amount: compensationAmountBinding,
                    currency: compensationCurrencyBinding,
                    salaryPeriod: salaryPeriodBinding
                )
            }
            CollapsibleSection(icon: "doc.richtext", title: "Resume", startsExpanded: false) {
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
            }
            CollapsibleSection(icon: "square.and.pencil", title: "Notes",
                               startsExpanded: !vm.editNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                JobNotesSection(jobNotes: $vm.editNotes)
            }
            if isInterviewStage {
                CollapsibleSection(icon: "person.wave.2.fill", title: "Interview Kit", startsExpanded: false) {
                    InterviewKitSection(
                        companyResearch: $vm.editCompanyResearch,
                        interviewNotes: $vm.editInterviewNotes
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // Matches JobDetailView's save bar: same height, type and glass accent, so every
    // primary CTA in the app is the same green.
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: onSave) {
                HStack {
                    Text(vm.saveSuccess ? "Added!" : "Add to Applications")
                        .appFont(14, weight: .bold)
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.16))
                            .frame(width: 28, height: 28)
                        AppIcon(vm.saveSuccess ? "checkmark" : "plus")
                            .appFont(10, weight: .bold)
                    }
                }
                .foregroundStyle(.white)
                .padding(.leading, 20)
                .padding(.trailing, 8)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .glassEffect(.regular.tint(vm.isSaveDisabled ? Color.secondary.opacity(0.3) : Theme.buttonGreen).interactive(), in: .capsule)
            }
            .buttonStyle(.plain)
            .disabled(vm.isSaveDisabled || vm.saveSuccess)

            Button(action: onCancel) {
                Text("Cancel")
                    .appFont(14, weight: .semibold)
                    .foregroundStyle(Theme.destructive)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .glassEffect(.regular.tint(Theme.destructive.opacity(0.12)).interactive(), in: .capsule)
            }
            .buttonStyle(.plain)
        }
    }
}
