import SwiftUI
import SwiftData

struct EmailParserView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
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
    @State private var editJobType: ApplicationType?   = nil
    @State private var editStatus    = ApplicationStatus.applied
    @State private var editSeason: ApplicationSeason?  = nil
    @State private var editDate      = Date()

    @State private var cardAppeared    = false
    @State private var parseCount      = 0
    @State private var saveSuccess     = false
    @State private var scrollToResults = false
    @State private var fetchedLogoData: Data? = nil
    @State private var isFetchingLogo       = false
    @State private var highlights: [HighlightSpan] = []
    @State private var isHighlightExpanded  = false

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

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        inputCard
                        if hasResult { resultsCard.id("results") }
                    }
                    .padding()
                    .animation(.appSmooth, value: hasResult)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: scrollToResults) { _, newValue in
                    guard newValue else { return }
                    scrollToResults = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        withAnimation(.appSmooth) {
                            proxy.scrollTo("results", anchor: .top)
                        }
                    }
                }
            }
        }
        .navigationTitle("Parse Email")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(UIColor.systemBackground), for: .navigationBar)
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
            withAnimation(.appSmooth.delay(0.1)) {
                cardAppeared = true
            }
        }
        .task(id: editCompany) {
            fetchedLogoData = nil
            isFetchingLogo  = false
            let trimmed = editCompany.trimmingCharacters(in: .whitespaces)
            guard trimmed.count >= 2 else { return }
            do { try await Task.sleep(for: .milliseconds(600)) } catch { return }
            guard !Task.isCancelled else { return }
            withAnimation(.appFastOut) { isFetchingLogo = true }
            fetchedLogoData = await LogoFetcher.fetchLogoData(for: trimmed, darkMode: colorScheme == .dark)
            withAnimation(.appFastOut) { isFetchingLogo = false }
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
                        withAnimation(.appCrisp) {
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
                        withAnimation(.appCrisp) {
                            emailText = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(DarkTheme.textSecondary)
                    }
                }
            }

            if !isEmailExpanded && !emailText.isEmpty && !highlights.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    if isHighlightExpanded {
                        Text(buildHighlightedString(emailText, spans: highlights))
                            .font(.system(size: 12))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(DarkTheme.textSecondary)
                    } else {
                        Text(buildHighlightedString(emailText, spans: highlights))
                            .font(.system(size: 12))
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(DarkTheme.textSecondary)
                            .mask(
                                LinearGradient(
                                    colors: [.black, .black, .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }

                    Button {
                        withAnimation(.appCrisp) {
                            isHighlightExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(isHighlightExpanded ? "Show less" : "Show full email")
                                .font(.caption.weight(.medium))
                            Image(systemName: isHighlightExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(Color.accentColor.opacity(0.85))
                    }
                }
                .padding(.top, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if isEmailExpanded {
                if emailText.isEmpty {
                    Text("Paste a job application email to have its details extracted.")
                        .font(.subheadline)
                        .foregroundStyle(DarkTheme.textSecondary)
                        .padding(.top, 10)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

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
                .animation(.appFastOut, value: isEditorFocused)
                .animation(.appCrisp, value: hasResult)
                .padding(.top, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))

                Button {
                    withAnimation(.appFastOut) { isButtonPressed = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        withAnimation(.appFastOut) { isButtonPressed = false }
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
                            .shadow(color: isParseDisabled ? .clear : Color.accentColor.opacity(0.27), radius: 10, y: 3)
                    }
                }
                .scaleEffect(isButtonPressed ? AppAnimations.pressScale : 1.0)
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

            // Company avatar
            HStack {
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(DarkTheme.avatarGradient(for: editCompany.isEmpty ? "?" : editCompany))
                    let initial = editCompany.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? "?"
                    Text(initial)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .opacity(fetchedLogoData == nil ? 1 : 0)
                    if let data = fetchedLogoData, let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                            .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    }
                    if isFetchingLogo {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                        ProgressView().tint(.white)
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
                .animation(.appSmooth, value: fetchedLogoData == nil)
                .animation(.appFastOut, value: isFetchingLogo)
                Spacer()
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
                SeasonPickerRow(season: $editSeason, index: 4)
                DatePickerRow(date: $editDate, index: 5)
            }
            .id(parseCount)

            Divider().opacity(0.4)

            Button { saveApplication() } label: {
                Label(
                    saveSuccess ? "Added!" : "Add to Applications",
                    systemImage: saveSuccess ? "checkmark.circle.fill" : "plus.circle.fill"
                )
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background {
                    let c: Color = isSaveDisabled ? .secondary.opacity(0.3)
                                 : saveSuccess    ? Color.green
                                 : Color.accentColor
                    Capsule()
                        .fill(c)
                        .shadow(color: isSaveDisabled ? .clear : c.opacity(0.27), radius: 10, y: 3)
                }
                .animation(.appSmooth, value: saveSuccess)
            }
            .scaleEffect(saveSuccess ? 1.02 : 1.0)
            .animation(.appBouncy, value: saveSuccess)
            .disabled(isSaveDisabled || saveSuccess)
        }
        .padding(18)
        .glassCard()
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
            removal: .opacity
        ))
    }

    // MARK: - Actions

    private func parseEmail() {
        AppHaptics.shared.medium()
        withAnimation(.appSmooth) { isParsing = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let result = parser.parse(emailText)
            withAnimation(.appSmooth) {
                editCompany     = result.companyName ?? ""
                editPosition    = result.position    ?? ""
                editJobType     = result.jobType
                editStatus      = result.status      ?? .applied
                editSeason      = nil
                editDate        = result.dateApplied ?? Date()
                isParsing       = false
                hasResult       = true
                isEmailExpanded     = false
                parseCount         += 1
                highlights          = result.highlights
                isHighlightExpanded = false
            }
            scrollToResults = true
        }
    }

    private func saveApplication() {
        let attached = defaultResume
        modelContext.insert(JobApplication(
            companyName: editCompany.isEmpty  ? "Unknown Company"  : editCompany,
            companyLogoImageData: fetchedLogoData,
            position:    editPosition.isEmpty ? "Unknown Position" : editPosition,
            jobType:     editJobType,
            status:      editStatus,
            season:      editSeason,
            dateApplied: editDate,
            resumeFileName: attached?.fileName,
            resumeBookmark: attached?.bookmark,
            resumeID: attached?.id
        ))
        AppHaptics.shared.success()
        withAnimation(.appSmooth) {
            saveSuccess = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.appSmooth) {
                saveSuccess     = false
                emailText       = ""
                hasResult       = false
                editCompany     = ""
                editPosition    = ""
                editJobType     = nil
                editStatus      = .applied
                editSeason      = nil
                editDate        = Date()
                isEmailExpanded = true
                fetchedLogoData     = nil
                isFetchingLogo      = false
                highlights          = []
                isHighlightExpanded = false
            }
        }
    }

    // MARK: - Highlight helpers

    private func highlightColor(for field: HighlightField) -> Color {
        switch field {
        case .company:  return Color.accentColor
        case .position: return Color(red: 0.96, green: 0.73, blue: 0.28)
        case .status:   return Color(red: 0.30, green: 0.80, blue: 0.45)
        case .date:     return Color(red: 0.62, green: 0.52, blue: 0.96)
        }
    }

    private func buildHighlightedString(_ raw: String, spans: [HighlightSpan]) -> AttributedString {
        var result = AttributedString(raw)
        let nsRaw = raw as NSString
        for span in spans {
            let color = highlightColor(for: span.field)
            var searchStart = 0
            while searchStart < nsRaw.length {
                let searchRange = NSRange(location: searchStart, length: nsRaw.length - searchStart)
                let found = nsRaw.range(of: span.text, options: .caseInsensitive, range: searchRange)
                guard found.location != NSNotFound else { break }
                if let swiftRange = Range(found, in: raw) {
                    let lo = result.index(result.startIndex, offsetByCharacters: raw.distance(from: raw.startIndex, to: swiftRange.lowerBound))
                    let hi = result.index(result.startIndex, offsetByCharacters: raw.distance(from: raw.startIndex, to: swiftRange.upperBound))
                    result[lo..<hi].foregroundColor = color
                    result[lo..<hi].font = Font.system(size: 12, weight: .semibold)
                }
                searchStart = found.location + found.length
            }
        }
        return result
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

// MARK: - Job Type Picker Row

private struct JobTypePickerRow: View {
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
                    ForEach(sortedTypes, id: \.self) { t in
                        SelectablePill(
                            option: t,
                            isSelected: jobType == t,
                            color: t.color,
                            icon: t.iconName,
                            onTap: {
                                withAnimation(.appCrisp) {
                                    jobType = jobType == t ? nil : t
                                }
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
            withAnimation(.appSmooth.delay(Double(index) * 0.05)) {
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

    private var sortedStatuses: [ApplicationStatus] {
        [status] + ApplicationStatus.allCases.filter { $0 != status }
    }

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
                    ForEach(sortedStatuses, id: \.self) { s in
                        SelectablePill(
                            option: s,
                            isSelected: status == s,
                            color: s.color,
                            icon: s.iconName,
                            onTap: {
                                withAnimation(.appCrisp) {
                                    status = s
                                }
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
            withAnimation(.appSmooth.delay(Double(index) * 0.05)) {
                appeared = true
            }
        }
    }
}

// MARK: - Season Picker Row

private struct SeasonPickerRow: View {
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
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DarkTheme.textSecondary)
                    .frame(width: 14)
                Text("Season")
                    .font(.caption)
                    .foregroundStyle(DarkTheme.textSecondary)
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
                                withAnimation(.appCrisp) {
                                    season = season == s ? nil : s
                                }
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
            withAnimation(.appSmooth.delay(Double(index) * 0.05)) {
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
            withAnimation(.appSmooth.delay(Double(index) * 0.05)) {
                appeared = true
            }
        }
    }
}
