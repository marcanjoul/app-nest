import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct AddMenuView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    @Query(sort: \ResumeDocument.createdAt, order: .reverse) private var resumes: [ResumeDocument]
    @Query(sort: \JobCycle.createdAt, order: .reverse) private var cycles: [JobCycle]
    
    // UI Navigation State
    @State private var isShowingPasteLink = false
    @State private var pasteLinkURL = ""
    @State private var isParsing = false
    @State private var parsedData: LinkParser.ParsedResult?
    @FocusState private var isTextFieldFocused: Bool
    
    // Presentation States
    @State private var isPresentingManualAdd = false
    @State private var isPresentingParsedJob = false
    @State private var isSelectingCSVFile = false
    @State private var csvImportRows: [CSVImportRow] = []
    @State private var isPresentingImport = false
    @State private var isShowingEmailParse = false
    @State private var showLinkedInError = false
    
    // Email Parse State
    @State private var emailText        = ""
    @State private var isEmailParsing   = false
    @State private var isEmailExpanded    = true
    @State private var isButtonPressed    = false
    @FocusState private var isEmailEditorFocused: Bool

    // Editable extracted fields
    @State private var hasResult     = false
    @State private var editCompany   = ""
    @State private var editPosition  = ""
    @State private var editJobType: ApplicationType?   = nil
    @State private var editStatus    = ApplicationStatus.applied
    @State private var editSeason: ApplicationSeason?  = nil
    @State private var editDate      = Date()
    @State private var editCompensationKind: CompensationKind? = nil
    @State private var editCompensationAmount: Double? = nil
    @State private var editCompensationCurrency: Currency? = .usd
    @State private var editSalaryPeriod: SalaryPeriod? = .yearly
    @State private var editNotes     = ""
    @State private var editAttachedResume: ResumeDocument? = nil

    @State private var parseCount      = 0
    @State private var saveSuccess     = false
    @State private var fetchedLogoData: Data? = nil
    @State private var isFetchingLogo       = false
    @State private var highlights: [HighlightSpan] = []
    @State private var isHighlightExpanded  = false
    @State private var pickerItem: PhotosPickerItem? = nil

    private let linkParser = LinkParser()
    private let emailParser = EmailParser()

    private var defaultResume: ResumeDocument? { resumes.first(where: \.isDefault) }

    private var isParseDisabled: Bool {
        emailText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isEmailParsing
    }

    private var isSaveDisabled: Bool {
        editCompany.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        editPosition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            AmbientBackground()
            
            ScrollView {
                VStack(spacing: 32) {
                    header
                    
                    VStack(spacing: 16) {
                        pasteLinkCard
                        emailParseCard
                            .padding(.horizontal, isShowingEmailParse ? -16 : 0)
                            .animation(.appSmooth, value: isShowingEmailParse)

                        actionCard(
                            title: "Import CSV",
                            subtitle: "Bulk upload applications.",
                            icon: "square.and.arrow.down.fill",
                            color: Color.blue
                        ) {
                            AppHaptics.shared.light()
                            isSelectingCSVFile = true
                        }
                        
                        actionCard(
                            title: "Add Manually",
                            subtitle: "Enter details from scratch.",
                            icon: "square.and.pencil",
                            color: Color.accentColor
                        ) {
                            AppHaptics.shared.light()
                            isPresentingManualAdd = true
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .padding(.bottom, 40)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .navigationTitle("Add Job")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(UIColor.systemBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: Binding(
            get: { isPresentingManualAdd },
            set: { isPresentingManualAdd = $0; appState.isPresentingSheet = $0 }
        )) {
            NavigationStack { JobDetailView(job: nil) }
        }
        .sheet(isPresented: Binding(
            get: { isPresentingParsedJob },
            set: { isPresentingParsedJob = $0; appState.isPresentingSheet = $0 }
        )) {
            NavigationStack {
                JobDetailView(
                    job: nil,
                    prefillCompany: parsedData?.companyName ?? "",
                    prefillPosition: parsedData?.position ?? "",
                    prefillURL: parsedData?.jobURL ?? ""
                )
            }
        }
        .sheet(isPresented: Binding(
            get: { isPresentingImport },
            set: { isPresentingImport = $0; appState.isPresentingSheet = $0 }
        )) {
            CSVImportPreviewSheet(initialRows: csvImportRows)
        }
        .fileImporter(
            isPresented: $isSelectingCSVFile,
            allowedContentTypes: [.commaSeparatedText, .text],
            allowsMultipleSelection: false
        ) { result in
            guard let url = try? result.get().first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
            csvImportRows = CSVImporter.parse(content)
            isPresentingImport = true
            appState.isPresentingSheet = true
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
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Track a Job")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Choose how you want to add a new application.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
    }
    
    @ViewBuilder
    private var emailParseCard: some View {
        VStack(spacing: 0) {
            Button {
                AppHaptics.shared.light()
                withAnimation(.appSmooth) {
                    isShowingEmailParse.toggle()
                    if isShowingEmailParse {
                        isEmailEditorFocused = true
                    } else {
                        isEmailEditorFocused = false
                        resetParser()
                    }
                }
            } label: {
                CardRowHeader(
                    icon: "envelope.open.fill",
                    iconColor: .orange,
                    title: "Parse Email",
                    subtitle: "Extract details from an email."
                ) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary.opacity(0.6))
                        .rotationEffect(.degrees(isShowingEmailParse ? -180 : 0))
                }
            }
            .buttonStyle(PressScaleButtonStyle())
            
            if isShowingEmailParse {
                VStack(spacing: 16) {
                    Divider().opacity(0.4)
                    
                    VStack(alignment: .leading, spacing: 0) {
                        if !isEmailExpanded && !emailText.isEmpty && !highlights.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                if isHighlightExpanded {
                                    Text(buildHighlightedString(emailText, spans: highlights))
                                        .font(.system(size: 13))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .foregroundStyle(Theme.textSecondary)
                                } else {
                                    Text(buildHighlightedString(emailText, spans: highlights))
                                        .font(.system(size: 13))
                                        .lineLimit(3)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .foregroundStyle(Theme.textSecondary)
                                        .mask(LinearGradient(colors: [.black, .black, .clear], startPoint: .top, endPoint: .bottom))
                                }

                                Button {
                                    withAnimation(.appCrisp) { isHighlightExpanded.toggle() }
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
                            .padding(.bottom, 12)
                        }

                        if isEmailExpanded {
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
                                    .focused($isEmailEditorFocused)
                            }
                            .padding(12)
                            .background {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.primary.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(isEmailEditorFocused ? Color.orange.opacity(0.55) : Color.primary.opacity(0.08), lineWidth: isEmailEditorFocused ? 1.5 : 1)
                                    )
                            }
                            .padding(.bottom, 12)

                            Button {
                                withAnimation(.appFastOut) { isButtonPressed = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                    withAnimation(.appFastOut) { isButtonPressed = false }
                                }
                                parseEmail()
                            } label: {
                                HStack(spacing: 8) {
                                    if isEmailParsing {
                                        ProgressView().tint(.white)
                                    } else {
                                        Image(systemName: hasResult ? "arrow.clockwise.circle.fill" : "sparkles")
                                    }
                                    Text(isEmailParsing ? "Parsing…" : hasResult ? "Re-parse" : "Parse Email")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background {
                                    Capsule()
                                        .fill(isParseDisabled ? Color.secondary.opacity(0.3) : Color.orange)
                                        .shadow(color: isParseDisabled ? .clear : Color.orange.opacity(0.27), radius: 10, y: 3)
                                }
                            }
                            .scaleEffect(isButtonPressed ? AppAnimations.pressScale : 1.0)
                            .disabled(isParseDisabled)
                            .padding(.bottom, 20)
                        } else if hasResult {
                            Button {
                                withAnimation(.appCrisp) { isEmailExpanded = true }
                            } label: {
                                Label("Edit Email Text", systemImage: "pencil.circle.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.orange)
                            }
                            .padding(.bottom, 8)
                        }
                    }
                    .padding(.horizontal, 20)

                    if hasResult {
                        resultsCard
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                    }
                    
                    if saveSuccess {
                         VStack(spacing: 12) {
                             HStack(spacing: 12) {
                                 Button {
                                     resetParser()
                                     isEmailEditorFocused = true
                                 } label: {
                                     Text("Parse New Email")
                                         .font(.system(size: 14, weight: .semibold))
                                         .foregroundStyle(Theme.textPrimary)
                                         .frame(maxWidth: .infinity)
                                         .frame(height: 44)
                                         .background(Color.primary.opacity(0.06))
                                         .clipShape(Capsule())
                                 }
                                 
                                 Button {
                                     withAnimation(.appSmooth) {
                                         isShowingEmailParse = false
                                         resetParser()
                                     }
                                 } label: {
                                     Text("Done")
                                         .font(.system(size: 14, weight: .semibold))
                                         .foregroundStyle(Theme.textPrimary)
                                         .frame(maxWidth: .infinity)
                                         .frame(height: 44)
                                         .background(Color.primary.opacity(0.06))
                                         .clipShape(Capsule())
                                 }
                             }
                         }
                         .padding(.horizontal, 20)
                         .padding(.bottom, 20)
                         .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
        .glassCard(cornerRadius: Theme.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(isShowingEmailParse ? 0.15 : 0.0), lineWidth: 1)
        )
        .animation(.appSmooth, value: isShowingEmailParse)
        .animation(.appSmooth, value: hasResult)
        .animation(.appSmooth, value: isEmailExpanded)
    }

    @ViewBuilder
    private var pasteLinkCard: some View {
        VStack(spacing: 0) {
            Button {
                AppHaptics.shared.light()
                withAnimation(.appSmooth) {
                    isShowingPasteLink.toggle()
                    if isShowingPasteLink {
                        isTextFieldFocused = true
                    } else {
                        isTextFieldFocused = false
                        pasteLinkURL = ""
                    }
                }
            } label: {
                CardRowHeader(
                    icon: "link",
                    iconColor: .purple,
                    title: "Paste Job Link",
                    subtitle: "Auto-extract company and role."
                ) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary.opacity(0.6))
                        .rotationEffect(.degrees(isShowingPasteLink ? -180 : 0))
                }
            }
            .buttonStyle(PressScaleButtonStyle())
            
            if isShowingPasteLink {
                VStack(spacing: 12) {
                    Divider().opacity(0.4)
                    
                    HStack(spacing: 12) {
                        TextField("https://...", text: $pasteLinkURL)
                            .focused($isTextFieldFocused)
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.textPrimary)
                            .padding(12)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(isTextFieldFocused ? Color.purple.opacity(0.5) : Color.primary.opacity(0.08), lineWidth: 1)
                            )
                            .onChange(of: pasteLinkURL) { _, _ in
                                withAnimation(.appFastOut) { showLinkedInError = false }
                            }
                        
                        Button {
                            parseLink()
                        } label: {
                            Group {
                                if isParsing {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Parse")
                                }
                            }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 72, height: 44)
                            .background(pasteLinkURL.isEmpty ? Color.secondary.opacity(0.3) : Color.purple)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .disabled(pasteLinkURL.isEmpty || isParsing)
                        .scaleEffect(isParsing ? 0.95 : 1.0)
                        .animation(.appFastOut, value: pasteLinkURL.isEmpty)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, showLinkedInError ? 12 : 20)
                    .padding(.top, 12)
                    
                    if showLinkedInError {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.orange)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("LinkedIn Links Not Supported")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Theme.textPrimary)
                                Text("LinkedIn obscures job details in their URLs. Please open the actual application link or add manually.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textSecondary)
                                    .lineSpacing(2)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.orange.opacity(0.2), lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .glassCard(cornerRadius: Theme.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(isShowingPasteLink ? 0.15 : 0.0), lineWidth: 1)
        )
        .animation(.appSmooth, value: isShowingPasteLink)
    }

    private func parseLink() {
        guard !pasteLinkURL.isEmpty else { return }
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
        AppHaptics.shared.medium()
        withAnimation(.appFastOut) { isParsing = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let result = linkParser.parse(pasteLinkURL)
            withAnimation(.appSmooth) {
                isParsing = false
                if result.isLinkedIn {
                    showLinkedInError = true
                } else {
                    parsedData = result
                    isPresentingParsedJob = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        pasteLinkURL = ""
                        isShowingPasteLink = false
                    }
                }
            }
        }
    }

    private func parseEmail() {
        guard !emailText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
        AppHaptics.shared.medium()
        withAnimation(.appSmooth) { isEmailParsing = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let result = emailParser.parse(emailText)
            withAnimation(.appSmooth) {
                editCompany     = result.companyName ?? ""
                editPosition    = result.position    ?? ""
                editJobType     = result.jobType
                editStatus      = result.status      ?? .applied
                editSeason      = nil
                editDate        = result.dateApplied ?? Date()
                editCompensationKind = nil
                editCompensationAmount = nil
                editNotes       = ""
                editAttachedResume = defaultResume
                isEmailParsing  = false
                hasResult       = true
                isEmailExpanded = false
                parseCount     += 1
                highlights      = result.highlights
                isHighlightExpanded = false
            }
        }
    }

    private func actionCard(title: String, subtitle: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            CardRowHeader(icon: icon, iconColor: color, title: title, subtitle: subtitle) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary.opacity(0.4))
            }
            .glassCard(cornerRadius: Theme.cardRadius)
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private var resultsCard: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Header
            HStack {
                Label("Review & Edit", systemImage: "square.and.pencil")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                let missing = (editCompany.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 1 : 0)
                            + (editPosition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 1 : 0)
                if missing > 0 {
                    Label("\(missing) field\(missing == 1 ? "" : "s") need attention", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                }
            }

            // Company avatar with PhotosPicker
            HStack {
                Spacer()
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Theme.avatarGradient(for: editCompany.isEmpty ? "?" : editCompany))
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
                .onChange(of: pickerItem) { _, newValue in
                    guard let newValue else { return }
                    Task {
                        if let data = try? await newValue.loadTransferable(type: Data.self) {
                            withAnimation(.appSmooth) { fetchedLogoData = data }
                        }
                    }
                }
                .animation(.appSmooth, value: fetchedLogoData == nil)
                .animation(.appFastOut, value: isFetchingLogo)
                Spacer()
            }

            // Editable fields
            VStack(spacing: 12) {
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
                
                // Added Compensation, Resume and Notes
                Group {
                    CompensationSection(
                        kind: $editCompensationKind,
                        amount: compensationAmountBinding,
                        currency: compensationCurrencyBinding,
                        salaryPeriod: salaryPeriodBinding
                    )
                    
                    resumeSection
                    
                    JobNotesSection(jobNotes: $editNotes)
                }
                .padding(.top, 4)
            }
            .id(parseCount)

            Divider().opacity(0.4)

            VStack(spacing: 12) {
                Button { saveApplication() } label: {
                    Label(
                        saveSuccess ? "Added!" : "Add to Applications",
                        systemImage: saveSuccess ? "checkmark.circle.fill" : "plus.circle.fill"
                    )
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background {
                        let c: Color = isSaveDisabled ? .secondary.opacity(0.3)
                                     : saveSuccess    ? Color.green
                                     : Color.accentColor
                        Capsule()
                            .fill(c)
                            .shadow(color: isSaveDisabled ? .clear : c.opacity(0.25), radius: 10, y: 3)
                    }
                    .animation(.appSmooth, value: saveSuccess)
                }
                .buttonStyle(PressScaleButtonStyle())
                .scaleEffect(saveSuccess ? 1.02 : 1.0)
                .animation(.appBouncy, value: saveSuccess)
                .disabled(isSaveDisabled || saveSuccess)

                Button { resetParser() } label: {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background {
                            Capsule()
                                .fill(Color(red: 0.93, green: 0.33, blue: 0.40))
                                .shadow(color: Color(red: 0.93, green: 0.33, blue: 0.40).opacity(0.2), radius: 8, y: 3)
                        }
                }
                .buttonStyle(PressScaleButtonStyle())
            }
        }
        .padding(18)
        .glassCard()
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
            removal: .opacity
        ))
    }
    private var resumeSection: some View {
        ResumeSection(
            resumes: resumes,
            attachedResume: editAttachedResume,
            legacyResumeFileName: nil,
            attachedResumeWasDeleted: false,
            onSelectResume: { editAttachedResume = $0 },
            onViewAll: {}, 
            onPick: { /* File picker handled by resumes query and internal pills */ },
            onClear: { editAttachedResume = nil }
        )
    }
    private var compensationAmountBinding: Binding<String> {
        Binding(
            get: {
                guard let v = editCompensationAmount else { return "" }
                return v.truncatingRemainder(dividingBy: 1) == 0
                    ? String(Int(v)) : String(v)
            },
            set: { editCompensationAmount = Double($0) }
        )
    }
    private var compensationCurrencyBinding: Binding<Currency> {
        Binding(
            get: { editCompensationCurrency ?? .usd },
            set: { editCompensationCurrency = $0 }
        )
    }
    private var salaryPeriodBinding: Binding<SalaryPeriod> {
        Binding(
            get: { editSalaryPeriod ?? .yearly },
            set: { editSalaryPeriod = $0 }
        )
    }
    private func resetParser() {
        AppHaptics.shared.light()
        withAnimation(.appSmooth) {
            emailText       = ""
            hasResult       = false
            editCompany     = ""
            editPosition    = ""
            editJobType     = nil
            editStatus      = .applied
            editSeason      = nil
            editDate        = Date()
            editCompensationKind = nil
            editCompensationAmount = nil
            editNotes       = ""
            editAttachedResume = nil
            isEmailExpanded = true
            fetchedLogoData     = nil
            isFetchingLogo      = false
            highlights          = []
            isHighlightExpanded = false
            saveSuccess = false
        }
    }
    private func saveApplication() {
        let attached = editAttachedResume
        let selectedCycle = appState.selectedCycleID.flatMap { id in cycles.first { $0.id == id } }
        modelContext.insert(JobApplication(
            companyName: editCompany.isEmpty  ? "Unknown Company"  : editCompany,
            companyLogoImageData: fetchedLogoData,
            position:    editPosition.isEmpty ? "Unknown Position" : editPosition,
            jobType:     editJobType,
            status:      editStatus,
            season:      editSeason,
            cycle:       selectedCycle,
            dateApplied: editDate,
            jobNotes:    editNotes,
            resumeFileName: attached?.fileName,
            resumeBookmark: attached?.bookmark,
            resumeID: attached?.id,
            compensationKind: editCompensationKind,
            compensationAmount: editCompensationAmount,
            compensationCurrency: editCompensationCurrency,
            salaryPeriod: editSalaryPeriod
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
                editCompensationKind = nil
                editCompensationAmount = nil
                editNotes       = ""
                editAttachedResume = nil
                fetchedLogoData     = nil
                isFetchingLogo      = false
                highlights          = []
                isHighlightExpanded = false
                isShowingEmailParse = false
            }
        }
    }
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
                    result[lo..<hi].font = Font.system(size: 14, weight: .bold)
                }
                searchStart = found.location + found.length
            }
        }
        return result
    }
}

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
private struct DatePickerRow: View {
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
            withAnimation(.appSmooth.delay(Double(index) * 0.05)) {
                appeared = true
            }
        }
    }
}
