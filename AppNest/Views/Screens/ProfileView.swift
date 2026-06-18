import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

struct ProfileView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(sort: \JobApplication.dateApplied, order: .reverse) private var applications: [JobApplication]
    @Query(sort: \ResumeDocument.createdAt, order: .reverse) private var resumes: [ResumeDocument]
    @Query(sort: \JobCycle.createdAt, order: .reverse) private var cycles: [JobCycle]

    @AppStorage(AppStorageKeys.displayName)    private var profileDisplayName: String = ""
    @AppStorage(AppStorageKeys.handle)         private var profileHandle: String = ""
    @AppStorage(AppStorageKeys.bio)            private var profileBio: String = ""
    @AppStorage(AppStorageKeys.avatarData)     private var profileAvatarDataBase64: String = ""
    @AppStorage(AppStorageKeys.hapticsEnabled) private var hapticsEnabled: Bool = true

    @State private var avatarSelection: PhotosPickerItem?
    @State private var isShowingDocumentPicker = false
    @State private var resumePendingDeletion: ResumeDocument?
    @State private var isShowingResumeManager  = false
    @State private var isShowingCyclePicker    = false
    @State private var isShowingResetConfirmation = false
    @State private var fullscreenResume: FullscreenResume?

    @FocusState private var isNameFocused: Bool
    @FocusState private var isHandleFocused: Bool
    @FocusState private var isBioFocused: Bool

    // MARK: - Derived

    private var cycleFilteredApplications: [JobApplication] {
        guard let id = appState.selectedCycleID else { return applications }
        return applications.filter { $0.cycle?.id == id }
    }

    private var orderedResumes: [ResumeDocument] {
        guard let def = resumes.first(where: \.isDefault) else { return resumes }
        return [def] + resumes.filter { $0.id != def.id }
    }

    private var inlineResumes: [ResumeDocument] { Array(orderedResumes.prefix(5)) }

    private var profileAvatarData: Data? {
        guard !profileAvatarDataBase64.isEmpty else { return nil }
        return Data(base64Encoded: profileAvatarDataBase64)
    }

    private var totalCount: Int { cycleFilteredApplications.count }

    private var profileInitial: String {
        let trimmed = profileDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "" }
        return String(first).uppercased()
    }

    private var avatarGradientKey: String {
        let trimmed = profileDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "AppNest" : trimmed
    }

    // MARK: - Pipeline data

    private let pipelineStatuses: [ApplicationStatus] = [.toApply, .applied, .interview, .offer, .rejected, .ghosted, .jobRemoved]

    private func count(for status: ApplicationStatus) -> Int {
        cycleFilteredApplications.filter { $0.status == status }.count
    }

    private func pipelineLabel(for status: ApplicationStatus) -> String {
        switch status {
        case .toApply:    return "To Apply"
        case .applied:    return "Applied"
        case .interview:  return "Interview"
        case .offer:      return "Offers"
        case .rejected:   return "Rejected"
        case .ghosted:    return "Ghosted"
        case .jobRemoved: return "Removed"
        }
    }

    private var pipelineSegments: [PipelineSegmentedBar.Segment] {
        pipelineStatuses.map { PipelineSegmentedBar.Segment(id: $0, count: count(for: $0)) }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AmbientBackground()

            ScrollView {
                VStack(spacing: 0) {
                    identitySection

                    VStack(spacing: 14) {
                        pipelineSection
                        resumeSection
                        activityHeatmapSection
                        settingsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 160)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar(.hidden, for: .navigationBar)
        .dismissKeyboardToolbar()
        .sheet(isPresented: $isShowingDocumentPicker) {
            ProfileDocumentPicker { result in
                if case .success(let picked) = result {
                    savePickedResume(fileName: picked.fileName, bookmark: picked.bookmark)
                }
            }
        }
        .alert("Delete Resume?", isPresented: deletionAlertBinding, presenting: resumePendingDeletion) { resume in
            Button("Cancel", role: .cancel) { resumePendingDeletion = nil }
            Button("Delete", role: .destructive) { deleteResume(resume) }
        } message: { resume in
            let count = attachmentCount(for: resume)
            if count > 0 {
                Text("This resume is attached to \(count) job application\(count == 1 ? "" : "s"). Deleting it will remove it from those applications.")
            } else {
                Text("")
            }
        }
        .alert("Reset All Data?", isPresented: $isShowingResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset Everything", role: .destructive) { resetAllData() }
        } message: {
            Text("This will permanently delete all applications, resumes, and search cycles. This action cannot be undone.")
        }
        .sheet(isPresented: $isShowingResumeManager) {
            ResumeManagerSheet(
                resumes: orderedResumes,
                attachmentCount: attachmentCount,
                onSetDefault: setDefaultResume,
                onRequestDelete: { resumePendingDeletion = $0 },
                onUpload: { isShowingDocumentPicker = true },
                onView: { openFullscreen($0) }
            )
        }
        .fullScreenCover(item: $fullscreenResume) { resume in
            FullscreenResumeViewer(bookmark: resume.bookmark, fileName: resume.fileName)
        }
        .sheet(isPresented: $isShowingCyclePicker) {
            NavigationStack { CyclePickerSheet(isPresented: $isShowingCyclePicker) }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: avatarSelection) { _, newValue in
            guard let newValue else { return }
            Task { await updateProfileAvatar(from: newValue) }
        }
    }

    // MARK: - Identity header

    private var identitySection: some View {
        VStack(spacing: 14) {
            PhotosPicker(selection: $avatarSelection, matching: .images) {
                avatarView
                    .frame(width: 88, height: 88)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.10), lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
                    .overlay(alignment: .bottomTrailing) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 26, height: 26)
                            Image(systemName: "camera.fill")
                                .appFont(11, weight: .bold)
                                .foregroundStyle(.white)
                        }
                        .shadow(color: Color.accentColor.opacity(0.28), radius: 4, y: 2)
                        .offset(x: 2, y: 2)
                    }
            }
            .buttonStyle(.plain)
            .contextMenu {
                if profileAvatarData != nil {
                    Button(role: .destructive) {
                        profileAvatarDataBase64 = ""
                    } label: {
                        Label("Remove Photo", systemImage: "trash")
                    }
                }
            }

            VStack(spacing: 12) {
                // Name
                TextField(
                    "",
                    text: $profileDisplayName,
                    prompt: Text("Your Name").foregroundColor(Theme.textSecondary)
                )
                .appFont(24, weight: .bold)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textPrimary)
                .tint(.accentColor)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($isNameFocused)
                .frame(maxWidth: 260)

                // Handle (@username)
                Group {
                    if isHandleFocused {
                        TextField("username", text: $profileHandle)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($isHandleFocused)
                            .appFont(14, weight: .semibold)
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 150)
                            .tint(.accentColor)
                    } else {
                        Button {
                            isHandleFocused = true
                        } label: {
                            Text(profileHandle.isEmpty ? "@username" : "@\(profileHandle)")
                                .appFont(14, weight: .semibold)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                .offset(y: -4)

                // Bio
                TextField(
                    "",
                    text: $profileBio,
                    prompt: Text("Add a short bio...").foregroundColor(Theme.textTertiary),
                    axis: .vertical
                )
                .appFont(13, weight: .medium)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textSecondary)
                .tint(.accentColor)
                .focused($isBioFocused)
                .lineLimit(3)
                .frame(maxWidth: 280)
                .padding(.horizontal, 10)

                // Cycle selector chip (if any cycles)
                if !cycles.isEmpty {
                    profileCycleChip
                        .padding(.top, 4)
                }

                // Stats Grid
                HStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text("\(totalCount)")
                            .appFont(18, weight: .bold)
                            .foregroundStyle(Theme.textPrimary)
                        Text("Apps")
                            .appFont(11, weight: .bold)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)

                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 1, height: 28)

                    VStack(spacing: 4) {
                        Text("\(count(for: .interview))")
                            .appFont(18, weight: .bold)
                            .foregroundStyle(Theme.textPrimary)
                        Text("Interviews")
                            .appFont(11, weight: .bold)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)

                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 1, height: 28)

                    VStack(spacing: 4) {
                        Text("\(count(for: .offer))")
                            .appFont(18, weight: .bold)
                            .foregroundStyle(Theme.textPrimary)
                        Text("Offers")
                            .appFont(11, weight: .bold)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.cardFill.opacity(0.4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Theme.cardBorder, lineWidth: 1)
                        )
                )
                .frame(maxWidth: 320)
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 36)
        .padding(.bottom, 28)
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var avatarView: some View {
        #if canImport(UIKit)
        if let data = profileAvatarData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            initialAvatar
        }
        #else
        initialAvatar
        #endif
    }

    @ViewBuilder
    private var initialAvatar: some View {
        let colors = Theme.avatarColor(for: avatarGradientKey)
        ZStack {
            colors.background
            if profileInitial.isEmpty {
                Image(systemName: "person.fill")
                    .appFont(34, weight: .bold)
                    .foregroundStyle(colors.foreground)
            } else {
                Text(profileInitial)
                    .appFont(36, weight: .bold)
                    .foregroundStyle(colors.foreground)
            }
        }
    }

    // MARK: - Cycle chip

    private var profileCycleChip: some View {
        Button { isShowingCyclePicker = true } label: {
            HStack(spacing: 6) {
                Image(systemName: appState.selectedCycleID != nil ? "tray.fill" : "tray.2.fill")
                    .appFont(11, weight: .bold)
                Group {
                    if let id = appState.selectedCycleID,
                       let cycle = cycles.first(where: { $0.id == id }) {
                        Text(cycle.name)
                    } else {
                        Text("All Applications")
                    }
                }
                .appFont(13, weight: .bold)
                .lineLimit(1)
                Image(systemName: "chevron.down")
                    .appFont(10, weight: .black)
            }
            .foregroundStyle(appState.selectedCycleID != nil ? Color.accentColor : Theme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(appState.selectedCycleID != nil ? Color.accentColor.opacity(0.11) : Color.primary.opacity(0.07))
                    .overlay(Capsule().strokeBorder(
                        appState.selectedCycleID != nil ? Color.accentColor.opacity(0.28) : Color.primary.opacity(0.08),
                        lineWidth: 1
                    ))
            )
        }
        .buttonStyle(.plain)
        .animation(.appCrisp, value: appState.selectedCycleID)
    }

    // MARK: - Pipeline

    private var pipelineSection: some View {
        NavigationLink(destination: ProfileStatsView()) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    SectionLabel(icon: "chart.bar.fill", title: "Pipeline")
                    Spacer()
                    Text("\(totalCount)")
                        .appFont(15, weight: .bold)
                        .foregroundStyle(Color.accentColor.opacity(0.75))
                    Image(systemName: "chevron.right")
                        .appFont(12, weight: .bold)
                        .foregroundStyle(Theme.textSecondary.opacity(0.6))
                }

                PipelineSegmentedBar(segments: pipelineSegments, total: totalCount)

                HStack(spacing: 0) {
                    ForEach(pipelineStatuses.indices, id: \.self) { i in
                        let status = pipelineStatuses[i]
                        let c = count(for: status)
                        let style = Theme.statusStyle(for: status)
                        
                        VStack(spacing: 8) {
                            Image(systemName: style.iconName)
                                .appFont(10, weight: .black)
                                .foregroundStyle(c > 0 ? style.tintColor : Theme.textTertiary.opacity(0.6))

                            VStack(spacing: 2) {
                                Text("\(c)")
                                    .appFont(20, weight: .bold)
                                    .foregroundStyle(c > 0 ? Theme.textPrimary : Theme.textTertiary)
                                    .contentTransition(.numericText())

                                Text(pipelineLabel(for: status))
                                    .appFont(10, weight: .semibold)
                                    .foregroundStyle(c > 0 ? Theme.textSecondary : Theme.textTertiary.opacity(0.8))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.95)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background {
                            if c > 0 {
                                style.tintColor.opacity(0.04)
                            }
                        }
                        
                        if i < pipelineStatuses.count - 1 {
                            Rectangle()
                                .fill(Color.primary.opacity(0.12))
                                .frame(width: 1, height: 30)
                        }
                    }
                }
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.03))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                        )
                }
            }
            .padding(18)
            .glassCard()
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.18), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Resume Section

    private var resumeSection: some View {
        VStack(spacing: 16) {
            SectionLabel(icon: "doc.richtext.fill", title: "Resumes")

            if resumes.isEmpty {
                HStack {
                    Spacer()
                    ResumePill(title: "Upload Resume", style: .add, isLarge: true) {
                        isShowingDocumentPicker = true
                    }
                    Spacer()
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(inlineResumes, id: \.id) { resume in
                        HStack(spacing: 10) {
                            ResumePill(
                                title: resume.fileName,
                                style: .resume,
                                isDefault: resume.isDefault,
                                isLarge: true,
                                action: { openFullscreen(resume) }
                            ) {
                                AnyView(ResumePreview(bookmark: resume.bookmark, fileName: resume.fileName))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            HStack(spacing: 18) {
                                Button {
                                    setDefaultResume(resume)
                                } label: {
                                    Image(systemName: resume.isDefault ? "star.fill" : "star")
                                        .appFont(16, weight: .semibold)
                                        .foregroundStyle(resume.isDefault ? Color.yellow : Theme.textTertiary)
                                        .frame(width: 34, height: 34)
                                        .background(Circle().fill(Color.primary.opacity(0.06)))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(resume.isDefault ? "Default resume" : "Set as default resume")

                                Button(role: .destructive) {
                                    resumePendingDeletion = resume
                                } label: {
                                    Image(systemName: "trash")
                                        .appFont(14, weight: .semibold)
                                        .foregroundStyle(Theme.destructive)
                                        .frame(width: 34, height: 34)
                                        .background(Circle().fill(Theme.destructive.opacity(0.10)))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Delete resume")
                            }
                        }
                    }

                    HStack(spacing: 14) {
                        ResumePill(title: "Add Resume", style: .add) {
                            isShowingDocumentPicker = true
                        }

                        if resumes.count > 5 {
                            Button { isShowingResumeManager = true } label: {
                                Label("View All", systemImage: "tray.full")
                                    .appFont(13, weight: .semibold)
                                    .foregroundStyle(Color.accentColor)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(Color.accentColor.opacity(0.10))
                                            .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.20), lineWidth: 1))
                                    )
                            }
                            .buttonStyle(PressScaleButtonStyle())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
                }
            }
        }
        .padding(18)
        .glassCard()
    }

    // MARK: - Activity Heatmap

    private var activityHeatmapSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(icon: "calendar.badge.clock", title: "Activity")
            
            ActivityHeatmapView(applications: applications)
        }
        .padding(18)
        .glassCard()
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 16) {
                SectionLabel(icon: "gearshape.fill", title: "Settings")

                Toggle(isOn: $hapticsEnabled) {
                    Label("Haptic Feedback", systemImage: "waveform")
                        .appFont(15, weight: .medium)
                }
                .padding(.vertical, 4)

                let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
                let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
                Text("AppNest \(version) (\(build))")
                    .appFont(11, weight: .medium)
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
            }
            .padding(18)
            .glassCard()

            VStack(alignment: .leading, spacing: 16) {
                SectionLabel(icon: "exclamationmark.triangle.fill", title: "Danger Zone", color: Theme.destructive)

                Button(role: .destructive) {
                    isShowingResetConfirmation = true
                } label: {
                    Label("Reset All Data", systemImage: "trash.fill")
                        .appFont(15, weight: .medium)
                        .foregroundStyle(Theme.destructive)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }
            .padding(18)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.destructive.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Theme.destructive.opacity(0.18), lineWidth: 1)
                    )
            }
        }
    }

    // MARK: - Helpers

    private var deletionAlertBinding: Binding<Bool> {
        Binding(
            get: { resumePendingDeletion != nil },
            set: { if !$0 { resumePendingDeletion = nil } }
        )
    }

    private func attachmentCount(for resume: ResumeDocument) -> Int {
        applications.filter { $0.resumeID == resume.id }.count
    }

    private func setDefaultResume(_ selectedResume: ResumeDocument) {
        for resume in resumes {
            resume.isDefault = resume.id == selectedResume.id
        }
    }

    private func savePickedResume(fileName: String, bookmark: Data) {
        if let existing = resumes.first(where: { $0.fileName == fileName }) {
            existing.bookmark = bookmark
            if !resumes.contains(where: \.isDefault) { setDefaultResume(existing) }
            return
        }
        let resume = ResumeDocument(
            fileName: fileName,
            bookmark: bookmark,
            isDefault: resumes.isEmpty || !resumes.contains(where: \.isDefault)
        )
        modelContext.insert(resume)
    }

    private func deleteResume(_ resume: ResumeDocument) {
        let wasDefault = resume.isDefault
        modelContext.delete(resume)
        resumePendingDeletion = nil
        if wasDefault, let replacement = resumes.first(where: { $0.id != resume.id }) {
            replacement.isDefault = true
        }
    }

    private func openFullscreen(_ resume: ResumeDocument) {
        fullscreenResume = FullscreenResume(id: resume.id, bookmark: resume.bookmark, fileName: resume.fileName)
    }

    private func resetAllData() {
        for app in applications { modelContext.delete(app) }
        for res in resumes { modelContext.delete(res) }
        for cyc in cycles { modelContext.delete(cyc) }
        try? modelContext.save()
        AppHaptics.shared.warning()
    }

    private func updateProfileAvatar(from item: PhotosPickerItem) async {
        if let data = try? await item.loadTransferable(type: Data.self) {
            profileAvatarDataBase64 = data.base64EncodedString()
        }
    }

}

// MARK: - Activity Heatmap Subview

private struct ActivityHeatmapView: View {
    let applications: [JobApplication]
    
    private var dayStats: [Date: Int] {
        let calendar = Calendar.current
        var counts: [Date: Int] = [:]
        for app in applications {
            let day = calendar.startOfDay(for: app.dateApplied)
            counts[day, default: 0] += 1
        }
        return counts
    }
    
    private var last90Days: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<90).reversed().compactMap { dayOffset in
            calendar.date(byAdding: .day, value: -dayOffset, to: today)
        }
    }
    
    var body: some View {
        let columns = Array(repeating: GridItem(.fixed(10), spacing: 4), count: 7)
        
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(last90Days, id: \.self) { date in
                    let count = dayStats[date, default: 0]
                    RoundedRectangle(cornerRadius: 2)
                        .fill(heatmapColor(for: count))
                        .frame(width: 10, height: 10)
                }
            }
            
            HStack {
                Text("Last 90 days")
                    .appFont(10, weight: .medium)
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
                HStack(spacing: 4) {
                    Text("Less").appFont(8)
                    Rectangle().fill(heatmapColor(for: 0)).frame(width: 8, height: 8).cornerRadius(1)
                    Rectangle().fill(heatmapColor(for: 1)).frame(width: 8, height: 8).cornerRadius(1)
                    Rectangle().fill(heatmapColor(for: 2)).frame(width: 8, height: 8).cornerRadius(1)
                    Rectangle().fill(heatmapColor(for: 3)).frame(width: 8, height: 8).cornerRadius(1)
                    Text("More").appFont(8)
                }
                .foregroundStyle(Theme.textTertiary)
            }
        }
    }
    
    private func heatmapColor(for count: Int) -> Color {
        if count == 0 { return Color.primary.opacity(0.04) }
        if count == 1 { return Color.accentColor.opacity(0.25) }
        if count == 2 { return Color.accentColor.opacity(0.5) }
        if count == 3 { return Color.accentColor.opacity(0.75) }
        return Color.accentColor
    }
}

// MARK: - Pipeline Segmented Bar

private struct PipelineSegmentedBar: View {
    struct Segment: Identifiable {
        let id: ApplicationStatus
        let count: Int
        var color: Color { Theme.statusStyle(for: id).tintColor }
    }

    let segments: [Segment]
    let total: Int

    private var active: [Segment] { segments.filter { $0.count > 0 } }

    var body: some View {
        if total == 0 || active.isEmpty {
            Capsule()
                .fill(Color.primary.opacity(0.07))
                .frame(maxWidth: .infinity)
                .frame(height: 8)
        } else {
            GeometryReader { geo in
                let spacing: CGFloat = 2
                let available = geo.size.width - spacing * CGFloat(active.count - 1)
                HStack(spacing: spacing) {
                    ForEach(active.indices, id: \.self) { i in
                        active[i].color
                            .frame(width: max(6, available * CGFloat(active[i].count) / CGFloat(total)))
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Resume Manager Sheet

private struct ResumeManagerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let resumes: [ResumeDocument]
    let attachmentCount: (ResumeDocument) -> Int
    let onSetDefault: (ResumeDocument) -> Void
    let onRequestDelete: (ResumeDocument) -> Void
    let onUpload: () -> Void
    let onView: (ResumeDocument) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(resumes, id: \.id) { resume in
                            row(for: resume)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("All Resumes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: onUpload)
                    } label: {
                        Image(systemName: "plus")
                            .appFont(14, weight: .bold)
                    }
                    .accessibilityLabel("Upload resume")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func row(for resume: ResumeDocument) -> some View {
        HStack(spacing: 10) {
            ResumePill(
                title: resume.fileName,
                style: .resume,
                isDefault: resume.isDefault,
                isLarge: true,
                action: { onView(resume) }
            ) {
                AnyView(ResumePreview(bookmark: resume.bookmark, fileName: resume.fileName))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button { onSetDefault(resume) } label: {
                Image(systemName: resume.isDefault ? "star.fill" : "star")
                    .appFont(16, weight: .semibold)
                    .foregroundStyle(resume.isDefault ? Color.yellow : Theme.textTertiary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .disabled(resume.isDefault)
            .accessibilityLabel(resume.isDefault ? "Default resume" : "Set as default")

            Button(role: .destructive) { onRequestDelete(resume) } label: {
                Image(systemName: "trash")
                    .appFont(14, weight: .semibold)
                    .foregroundStyle(Theme.destructive)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Theme.destructive.opacity(0.10)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete resume")
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
        }
    }
}

// MARK: - Document Picker

private struct ProfileDocumentPicker: UIViewControllerRepresentable {
    struct PickedFile { let fileName: String; let bookmark: Data }
    var completion: (Result<PickedFile, Error>) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.pdf, .plainText, .rtf, .data], asCopy: true
        )
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let completion: (Result<PickedFile, Error>) -> Void
        init(completion: @escaping (Result<PickedFile, Error>) -> Void) { self.completion = completion }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            do {
                let _ = url.startAccessingSecurityScopedResource()
                defer { url.stopAccessingSecurityScopedResource() }
                let bookmark = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                completion(.success(PickedFile(fileName: url.lastPathComponent, bookmark: bookmark)))
            } catch { completion(.failure(error)) }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
    }
}

#Preview {
    NavigationStack { ProfileView() }
        .environment(AppState())
        .modelContainer(for: [JobApplication.self, ResumeDocument.self, JobCycle.self], inMemory: true)
}
