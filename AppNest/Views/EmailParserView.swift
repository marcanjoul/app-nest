import SwiftUI
import SwiftData

struct EmailParserView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ResumeDocument.createdAt, order: .reverse) private var resumes: [ResumeDocument]

    // Input state
    @State private var emailText        = ""
    @State private var isParsing        = false
    @State private var isEmailExpanded  = true
    @State private var isButtonPressed  = false
    @FocusState private var isEditorFocused: Bool

    // Editable extracted fields
    @State private var hasResult     = false
    @State private var editCompany   = ""
    @State private var editPosition  = ""
    @State private var editJobType: ApplicationType? = nil
    @State private var editStatus    = ApplicationStatus.applied
    @State private var editDate      = Date()

    @State private var cardAppeared  = false

    private let parser = EmailParser()

    private var defaultResume: ResumeDocument? { resumes.first(where: \.isDefault) }

    private var isParseDisabled: Bool {
        emailText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isParsing
    }

    private var isSaveDisabled: Bool {
        editCompany.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        editPosition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            AmbientBackground()

            ScrollView {
                VStack(spacing: 16) {
                    inputCard
                    if hasResult { resultsCard }
                }
                .padding()
                .animation(.spring(response: 0.45, dampingFraction: 0.8), value: hasResult)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Parse Email")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    #if canImport(UIKit)
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    #endif
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.1)) {
                cardAppeared = true
            }
        }
    }

    // MARK: - Input Card

    @ViewBuilder
    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header row — always visible
            HStack(alignment: .center) {
                Label("Paste Email", systemImage: "envelope.open.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DarkTheme.textPrimary)

                Spacer()

                if hasResult {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            isEmailExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(isEmailExpanded ? "Collapse" : "Edit email")
                                .font(.caption.weight(.medium))
                            Image(systemName: isEmailExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Color.accentColor)
                    }
                } else if !emailText.isEmpty {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            emailText = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(DarkTheme.textSecondary)
                    }
                }
            }

            if isEmailExpanded {
                Text("Paste a job application email and AppNest extracts the details automatically.")
                    .font(.subheadline)
                    .foregroundStyle(DarkTheme.textSecondary)
                    .padding(.top, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))

                ZStack(alignment: .topLeading) {
                    if emailText.isEmpty {
                        Text("Paste your email here…")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                    }
                    TextEditor(text: $emailText)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .frame(minHeight: hasResult ? 90 : 180)
                        .font(.subheadline)
                        .focused($isEditorFocused)
                }
                .padding(12)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    isEditorFocused
                                        ? Color.accentColor.opacity(0.55)
                                        : Color.primary.opacity(0.08),
                                    lineWidth: isEditorFocused ? 1.5 : 1
                                )
                        )
                }
                .animation(.easeInOut(duration: 0.2), value: isEditorFocused)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: hasResult)
                .padding(.top, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { isButtonPressed = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { isButtonPressed = false }
                    }
                    parseEmail()
                } label: {
                    HStack(spacing: 8) {
                        if isParsing {
                            ProgressView().tint(.white)
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            Image(systemName: hasResult ? "arrow.clockwise.circle.fill" : "sparkles")
                                .transition(.scale.combined(with: .opacity))
                        }
                        Text(isParsing ? "Parsing…" : hasResult ? "Re-parse" : "Parse Email")
                            .font(.system(size: 16, weight: .semibold))
                            .animation(.none, value: isParsing)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background {
                        Capsule()
                            .fill(isParseDisabled ? Color.secondary.opacity(0.3) : Color.accentColor)
                            .overlay {
                                LinearGradient(
                                    colors: [Color.white.opacity(0.20), Color.clear],
                                    startPoint: .top, endPoint: .center
                                )
                                .clipShape(Capsule())
                            }
                            .shadow(color: isParseDisabled ? .clear : Color.accentColor.opacity(0.27), radius: 10, y: 3)
                    }
                }
                .scaleEffect(isButtonPressed ? 0.96 : 1.0)
                .disabled(isParseDisabled)
                .padding(.top, 12)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(18)
        .glassCard()
        .opacity(cardAppeared ? 1 : 0)
        .offset(y: cardAppeared ? 0 : 20)
    }

    // MARK: - Results Card

    @ViewBuilder
    private var resultsCard: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Header
            HStack {
                Label("Review & Edit", systemImage: "square.and.pencil")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DarkTheme.textPrimary)

                Spacer()

                let missing = (editCompany.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 1 : 0)
                            + (editPosition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 1 : 0)
                if missing > 0 {
                    Label("\(missing) field\(missing == 1 ? "" : "s") need attention", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                }
            }

            // Editable fields
            VStack(spacing: 8) {
                EditableFieldRow(
                    icon: "building.2",
                    label: "Company",
                    text: $editCompany,
                    placeholder: "Company name",
                    index: 0
                )
                EditableFieldRow(
                    icon: "briefcase",
                    label: "Position / Role",
                    text: $editPosition,
                    placeholder: "Job title",
                    index: 1
                )
                JobTypePickerRow(jobType: $editJobType, index: 2)
                StatusPickerRow(status: $editStatus, index: 3)
                DatePickerRow(date: $editDate, index: 4)
            }

            Divider().opacity(0.4)

            Button { saveApplication() } label: {
                Label("Add to Applications", systemImage: "plus.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background {
                        let c: Color = isSaveDisabled ? .secondary.opacity(0.3) : Color.accentColor
                        Capsule()
                            .fill(c)
                            .overlay {
                                LinearGradient(
                                    colors: [Color.white.opacity(0.20), Color.clear],
                                    startPoint: .top, endPoint: .center
                                )
                                .clipShape(Capsule())
                            }
                            .shadow(color: isSaveDisabled ? .clear : c.opacity(0.27), radius: 10, y: 3)
                    }
            }
            .disabled(isSaveDisabled)
        }
        .padding(18)
        .glassCard()
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
        ))
    }

    // MARK: - Actions

    private func parseEmail() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isParsing = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let result = parser.parse(emailText)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                editCompany     = result.companyName ?? ""
                editPosition    = result.position    ?? ""
                editJobType     = result.jobType
                editStatus      = result.status      ?? .applied
                editDate        = result.dateApplied ?? Date()
                isParsing       = false
                hasResult       = true
                isEmailExpanded = false
            }
        }
    }

    private func saveApplication() {
        let attached = defaultResume
        modelContext.insert(JobApplication(
            companyName: editCompany.isEmpty  ? "Unknown Company"  : editCompany,
            position:    editPosition.isEmpty ? "Unknown Position" : editPosition,
            jobType:     editJobType,
            status:      editStatus,
            dateApplied: editDate,
            resumeFileName: attached?.fileName,
            resumeBookmark: attached?.bookmark,
            resumeID: attached?.id
        ))
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            emailText       = ""
            hasResult       = false
            editCompany     = ""
            editPosition    = ""
            editJobType     = nil
            editStatus      = .applied
            editDate        = Date()
            isEmailExpanded = true
        }
    }
}

// MARK: - Editable Field Row

private struct EditableFieldRow: View {
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
                    .foregroundStyle(isEmpty ? .orange : DarkTheme.textSecondary)
                    .frame(width: 14)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(DarkTheme.textSecondary)
                if isEmpty {
                    Text("· Fill in")
                        .font(.caption2)
                        .foregroundStyle(.orange.opacity(0.85))
                }
            }

            TextField(placeholder.isEmpty ? label : placeholder, text: $text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(DarkTheme.textPrimary)
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
        .animation(.easeInOut(duration: 0.18), value: isFocused)
        .animation(.easeInOut(duration: 0.18), value: isEmpty)
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -14)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.72).delay(Double(index) * 0.07)) {
                appeared = true
            }
        }
    }
}

// MARK: - Job Type Picker Row

private struct JobTypePickerRow: View {
    @Binding var jobType: ApplicationType?
    let index: Int

    @State private var appeared = false

    private let types = ApplicationType.allCases

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "tag")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DarkTheme.textSecondary)
                    .frame(width: 14)
                Text("Job Type")
                    .font(.caption)
                    .foregroundStyle(DarkTheme.textSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(types, id: \.self) { t in
                        let isSelected = jobType == t
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                jobType = isSelected ? nil : t
                            }
                        } label: {
                            Text(t.rawValue)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(isSelected ? .white : DarkTheme.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background {
                                    Capsule()
                                        .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.07))
                                        .overlay {
                                            Capsule()
                                                .strokeBorder(
                                                    isSelected ? Color.clear : Color.primary.opacity(0.12),
                                                    lineWidth: 1
                                                )
                                        }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -14)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.72).delay(Double(index) * 0.07)) {
                appeared = true
            }
        }
    }
}

// MARK: - Status Picker Row

private struct StatusPickerRow: View {
    @Binding var status: ApplicationStatus
    let index: Int

    @State private var appeared = false

    private let statuses: [ApplicationStatus] = [.applied, .interview, .offer, .rejected]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "flag")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DarkTheme.textSecondary)
                    .frame(width: 14)
                Text("Status")
                    .font(.caption)
                    .foregroundStyle(DarkTheme.textSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(statuses, id: \.self) { s in
                        let style = DarkTheme.statusStyle(for: s)
                        SelectablePill(
                            option: s,
                            isSelected: status == s,
                            color: style.tintColor,
                            icon: style.iconName
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                status = s
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -14)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.72).delay(Double(index) * 0.07)) {
                appeared = true
            }
        }
    }
}

// MARK: - Date Picker Row

private struct DatePickerRow: View {
    @Binding var date: Date
    let index: Int

    @State private var appeared = false

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DarkTheme.textSecondary)
                    .frame(width: 14)
                Text("Date Applied")
                    .font(.caption)
                    .foregroundStyle(DarkTheme.textSecondary)
            }
            Spacer()
            DatePicker("", selection: $date, displayedComponents: .date)
                .labelsHidden()
                .tint(Color.accentColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                }
        }
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -14)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.72).delay(Double(index) * 0.07)) {
                appeared = true
            }
        }
    }
}
