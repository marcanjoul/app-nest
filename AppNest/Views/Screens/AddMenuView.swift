import SwiftUI

struct AddMenuView: View {
    @Environment(AppState.self) private var appState
    
    @State private var isShowingPasteLink = false
    @State private var pasteLinkURL = ""
    @State private var isParsing = false
    @State private var parsedData: LinkParser.ParsedResult?
    @FocusState private var isTextFieldFocused: Bool
    
    // Presentation States
    @State private var isPresentingManualAdd = false
    @State private var isPresentingParsedJob = false
    @State private var isPresentingImport = false
    @State private var isShowingEmailParse = false
    @State private var showLinkedInError = false
    
    // Email Parse State
    @State private var emailText = ""
    @State private var isEmailParsing = false
    @State private var emailParsedResult: EmailParser.ParsedResult?
    @State private var emailHighlights: [HighlightSpan] = []
    @FocusState private var isEmailEditorFocused: Bool
    
    private let linkParser = LinkParser()
    private let emailParser = EmailParser()
    
    var body: some View {
        ZStack {
            AmbientBackground()
            
            ScrollView {
                VStack(spacing: 32) {
                    header
                    
                    VStack(spacing: 16) {
                        // 1. Paste Link Card
                        pasteLinkCard
                        
                        // 2. Parse Email Card
                        emailParseCard
                        
                        // 3. Import CSV Card
                        actionCard(
                            title: "Import CSV",
                            subtitle: "Bulk upload your job history.",
                            icon: "square.and.arrow.down.fill",
                            color: Color.blue
                        ) {
                            AppHaptics.shared.light()
                            isPresentingImport = true
                        }
                        
                        // 3. Add Manually Card
                        actionCard(
                            title: "Add Manually",
                            subtitle: "Enter application details from scratch.",
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
            CSVImportPreviewSheet(initialRows: [])
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Track a Job")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(DarkTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Choose how you want to add a new application.")
                .font(.subheadline)
                .foregroundStyle(DarkTheme.textSecondary)
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
                        emailText = ""
                        emailParsedResult = nil
                    }
                }
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 48, height: 48)
                        Image(systemName: "envelope.open.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.orange)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Parse Email")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(DarkTheme.textPrimary)
                        Text("Extract job details from a confirmation email.")
                            .font(.system(size: 14))
                            .foregroundStyle(DarkTheme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: isShowingEmailParse ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DarkTheme.textSecondary.opacity(0.6))
                }
                .padding(20)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressScaleButtonStyle())
            
            if isShowingEmailParse {
                VStack(spacing: 12) {
                    Divider().opacity(0.4)
                    
                    if emailParsedResult == nil {
                        VStack(spacing: 16) {
                            TextEditor(text: $emailText)
                                .focused($isEmailEditorFocused)
                                .font(.system(size: 14))
                                .padding(12)
                                .frame(minHeight: 180)
                                .background(Color.primary.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(isEmailEditorFocused ? Color.orange.opacity(0.5) : Color.primary.opacity(0.08), lineWidth: 1)
                                )
                                .overlay(alignment: .topLeading) {
                                    if emailText.isEmpty {
                                        Text("Paste the job application or confirmation email here...")
                                            .font(.system(size: 14))
                                            .foregroundStyle(DarkTheme.textSecondary.opacity(0.6))
                                            .padding(.horizontal, 16)
                                            .padding(.top, 20)
                                            .allowsHitTesting(false)
                                    }
                                }
                            
                            Button {
                                parseEmail()
                            } label: {
                                Group {
                                    if isEmailParsing {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("Parse Email")
                                    }
                                }
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(emailText.isEmpty ? Color.secondary.opacity(0.3) : Color.orange)
                                .clipShape(Capsule())
                            }
                            .disabled(emailText.isEmpty || isEmailParsing)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        .padding(.top, 12)
                    } else {
                        // Result UI (Simplified)
                        VStack(spacing: 20) {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.green)
                                Text("Email Parsed Successfully")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(DarkTheme.textPrimary)
                            }
                            .padding(.top, 8)
                            
                            // Show the extracted info or buttons to continue
                            VStack(spacing: 12) {
                                Button {
                                    isPresentingEmailParse = true // Re-using state to trigger sheet if we want the full editor
                                } label: {
                                    Text("Review & Add Job")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 48)
                                        .background(Color.accentColor)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(PressScaleButtonStyle())
                                
                                HStack(spacing: 12) {
                                    Button {
                                        withAnimation(.appSmooth) {
                                            emailParsedResult = nil
                                            emailText = ""
                                            isEmailEditorFocused = true
                                        }
                                    } label: {
                                        Text("Parse New Email")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(DarkTheme.textPrimary)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 44)
                                            .background(Color.primary.opacity(0.06))
                                            .clipShape(Capsule())
                                    }
                                    
                                    Button {
                                        withAnimation(.appSmooth) {
                                            isShowingEmailParse = false
                                            emailParsedResult = nil
                                            emailText = ""
                                        }
                                    } label: {
                                        Text("Done")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(DarkTheme.textPrimary)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 44)
                                            .background(Color.primary.opacity(0.06))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        .padding(.top, 12)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .glassCard(cornerRadius: DarkTheme.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DarkTheme.cardRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(isShowingEmailParse ? 0.15 : 0.0), lineWidth: 1)
        )
        .animation(.appSmooth, value: isShowingEmailParse)
        .animation(.appSmooth, value: emailParsedResult == nil)
    }
    
    private func actionCard(title: String, subtitle: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DarkTheme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(DarkTheme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DarkTheme.textSecondary.opacity(0.4))
            }
            .padding(20)
            .contentShape(Rectangle())
            .glassCard(cornerRadius: DarkTheme.cardRadius)
        }
        .buttonStyle(PressScaleButtonStyle())
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
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.15))
                            .frame(width: 48, height: 48)
                        Image(systemName: "link")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.purple)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Paste Job Link")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(DarkTheme.textPrimary)
                        Text("Auto-extract company and role.")
                            .font(.system(size: 14))
                            .foregroundStyle(DarkTheme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: isShowingPasteLink ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DarkTheme.textSecondary.opacity(0.6))
                }
                .padding(20)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressScaleButtonStyle())
            
            if isShowingPasteLink {
                VStack(spacing: 12) {
                    Divider().opacity(0.4)
                    
                    HStack(spacing: 12) {
                        TextField("https://...", text: $pasteLinkURL)
                            .focused($isTextFieldFocused)
                            .font(.system(size: 15))
                            .foregroundStyle(DarkTheme.textPrimary)
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
                                    .foregroundStyle(DarkTheme.textPrimary)
                                Text("LinkedIn obscures job details in their URLs. Please open the actual application link or add manually.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(DarkTheme.textSecondary)
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
        .glassCard(cornerRadius: DarkTheme.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DarkTheme.cardRadius, style: .continuous)
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
        withAnimation(.appFastOut) {
            isParsing = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let result = linkParser.parse(pasteLinkURL)
            withAnimation(.appSmooth) {
                isParsing = false
                
                if result.isLinkedIn {
                    showLinkedInError = true
                } else {
                    parsedData = result
                    isPresentingParsedJob = true
                    
                    // Reset states after presenting
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        pasteLinkURL = ""
                        isShowingPasteLink = false
                    }
                }
            }
        }
    }

    private func parseEmail() {
        guard !emailText.isEmpty else { return }
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
        
        AppHaptics.shared.medium()
        withAnimation(.appFastOut) {
            isEmailParsing = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            let result = emailParser.parse(emailText)
            withAnimation(.appSmooth) {
                isEmailParsing = false
                emailParsedResult = result
            }
        }
    }
}
