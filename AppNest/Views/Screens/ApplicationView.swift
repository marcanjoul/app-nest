import SwiftUI
import SwiftData
import UIKit

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

enum SortOption: String, CaseIterable {
    case dateNewest = "Newest"
    case dateOldest = "Oldest"
    case companyAZ  = "Company A–Z"
    case companyZA  = "Company Z–A"
}

struct ApplicationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Query(sort: \JobApplication.dateApplied, order: .reverse) private var applications: [JobApplication]
    @Query(sort: \JobCycle.createdAt, order: .reverse) private var cycles: [JobCycle]

    @Namespace private var filterNS
    @FocusState private var isSearchFocused: Bool
    @State private var searchText: String = ""
    @State private var isPresentingNewApplication = false
    @State private var selectedStatuses: Set<ApplicationStatus> = []
    @State private var selectedTypes: Set<ApplicationType> = []
    @State private var selectedSeasons: Set<ApplicationSeason> = []
    @State private var selectedWorkModes: Set<WorkMode> = []
    @State private var isTypePickerExpanded = false
    @State private var isSeasonPickerExpanded = false
    @State private var isWorkModePickerExpanded = false
    @State private var sortOption: SortOption = .dateNewest
    @State private var pendingDeleteJob: JobApplication? = nil
    @State private var undoTask: Task<Void, Never>? = nil
    @State private var toastDragY: CGFloat = 0
    @State private var isShowingCyclePicker = false
    @State private var isAddingFirstCycle = false
    @State private var isAddingCycleFromBulk = false
    @State private var newCycleName = ""
    @State private var selectedJobIDs = Set<PersistentIdentifier>()
    @State private var isEditMode = false
    @State private var isConfirmingBulkDelete = false
    @State private var lastScrollOffset: CGFloat = 0
    @State private var initialScrollOffset: CGFloat? = nil

    // Import / Export
    @State private var csvImportPreview: [CSVImportRow]? = nil
    @State private var isShowingImportPreview = false
    @State private var isImportingCSV = false
    @State private var isShowingImportConfirmation = false
    @State private var isShowingExportConfirmation = false
    @State private var csvFileURL: URL? = nil
    @State private var isShowingShareSheet = false
    @State private var importErrorMessage: String?

    // Cycle-filtered base (before search/status)
    private var cycleFiltered: [JobApplication] {
        let base = applications.filter { $0 !== pendingDeleteJob }
        guard let id = appState.selectedCycleID else { return base }
        return base.filter { $0.cycle?.id == id }
    }

    // Search-only filtered list — used for chip counts so they reflect search but not status filter
    private var searchFiltered: [JobApplication] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base = cycleFiltered
        guard !query.isEmpty else { return base }
        return base.filter {
            $0.position.lowercased().contains(query) ||
            $0.companyName.lowercased().contains(query) ||
            ($0.jobType?.rawValue.lowercased().contains(query) ?? false)
        }
    }

    private var filteredAndSorted: [JobApplication] {
        var result = searchFiltered

        if !selectedStatuses.isEmpty {
            result = result.filter { job in
                job.status.map { selectedStatuses.contains($0) } ?? false
            }
        }
        if !selectedTypes.isEmpty {
            result = result.filter { job in
                job.jobType.map { selectedTypes.contains($0) } ?? false
            }
        }
        if !selectedSeasons.isEmpty {
            result = result.filter { job in
                job.season.map { selectedSeasons.contains($0) } ?? false
            }
        }
        if !selectedWorkModes.isEmpty {
            result = result.filter { job in
                job.workMode.map { selectedWorkModes.contains($0) } ?? false
            }
        }

        switch sortOption {
        case .dateNewest: result.sort { $0.dateApplied > $1.dateApplied }
        case .dateOldest: result.sort { $0.dateApplied < $1.dateApplied }
        case .companyAZ:  result.sort { $0.companyName.localizedCompare($1.companyName) == .orderedAscending }
        case .companyZA:  result.sort { $0.companyName.localizedCompare($1.companyName) == .orderedDescending }
        }

        return result
    }

    var body: some View {
        ZStack {
            // Adaptive ambient gradient background
            AmbientBackground()

            ScrollViewReader { proxy in
            List {
                // Header
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("App Nest")
                            .appFont(40, weight: .bold)
                            .foregroundStyle(Theme.textPrimary)

                        if !searchText.isEmpty {
                            Text("\(filteredAndSorted.count) results")
                                .appFont(13, weight: .bold)
                                .foregroundStyle(Color.accentColor)
                                .transition(.opacity.combined(with: .move(edge: .leading)))
                        }
                    }
                    .padding(.top, 16)

                }
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: geo.frame(in: .global).minY
                            )
                    }
                )
                .opacity(appState.dashboardHasAppeared ? 1 : 0)
                .offset(y: appState.dashboardHasAppeared ? 0 : 20)
                .animation(.appSmooth, value: appState.dashboardHasAppeared)
                .animation(.appSmooth, value: searchText.isEmpty)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .selectionDisabled()
                .id("appListTop")

                // Search + Filter
                searchFilterRow
                    .opacity(appState.dashboardHasAppeared ? 1 : 0)
                    .offset(y: appState.dashboardHasAppeared ? 0 : 16)
                    .animation(.appSmooth.delay(0.07), value: appState.dashboardHasAppeared)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .selectionDisabled()

                // Stats — status chips
                statsSection
                    .opacity(appState.dashboardHasAppeared ? 1 : 0)
                    .offset(y: appState.dashboardHasAppeared ? 0 : 12)
                    .animation(.appSmooth.delay(0.12), value: appState.dashboardHasAppeared)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .selectionDisabled()

                // Filters — type + season expandable tokens
                typeSeasonFilter
                    .opacity(appState.dashboardHasAppeared ? 1 : 0)
                    .offset(y: appState.dashboardHasAppeared ? 0 : 10)
                    .animation(.appSmooth.delay(0.15), value: appState.dashboardHasAppeared)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .selectionDisabled()

                // Cycle chip + actions
                VStack(spacing: 10) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.07))
                        .frame(height: 1)
                    HStack {
                        cycleSelectorChip
                        Spacer()
                        if !applications.isEmpty {
                            headerActionButtons
                        }
                    }
                }
                .opacity(appState.dashboardHasAppeared ? 1 : 0)
                .offset(y: appState.dashboardHasAppeared ? 0 : 8)
                .animation(.appSmooth.delay(0.18), value: appState.dashboardHasAppeared)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .selectionDisabled()

                // Content
                if cycleFiltered.isEmpty && !applications.isEmpty && appState.selectedCycleID != nil {
                    emptyCycleState
                        .transition(.opacity.combined(with: .scale(scale: 0.95)).combined(with: .offset(y: 20)))
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .selectionDisabled()
                } else if applications.isEmpty {
                    emptyState
                        .transition(.opacity.combined(with: .scale(scale: 0.95)).combined(with: .offset(y: 20)))
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .selectionDisabled()
                } else if filteredAndSorted.isEmpty {
                    noResultsState
                        .transition(.opacity.combined(with: .scale(scale: 0.95)).combined(with: .offset(y: 20)))
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .selectionDisabled()
                } else {
                    if isEditMode {
                        selectionToolbar
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .selectionDisabled()
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    ForEach(Array(filteredAndSorted.enumerated()), id: \.element.id) { index, job in
                        JobCardSwipeRow(
                                job: job,
                                isEditMode: isEditMode,
                                isSelected: selectedJobIDs.contains(job.id),
                                onDelete: { scheduleDelete(job) },
                                onToggleSelection: {
                                    withAnimation(.appCrisp) {
                                        if selectedJobIDs.contains(job.id) {
                                            selectedJobIDs.remove(job.id)
                                        } else {
                                            selectedJobIDs.insert(job.id)
                                        }
                                    }
                                    AppHaptics.shared.light()
                                }
                            )
                            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .visualEffect { content, proxy in
                                content
                                    .scaleEffect(cardScale(proxy))
                                    .opacity(cardOpacity(proxy))
                            }
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .offset(y: 10)),
                                removal: .opacity.combined(with: .scale(scale: 0.97))
                            ))
                            .animation(.appSmooth.delay(Double(min(index, 6)) * 0.03), value: appState.dashboardHasAppeared)
                            .animation(.appCrisp, value: filteredAndSorted.count)
                    }
                }

                // Attribution Footer
                VStack(spacing: 4) {
                    Text("Logos provided by Logo.dev")
                        .appFont(10, weight: .semibold)
                        .foregroundStyle(Theme.textTertiary.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
                .padding(.bottom, 100)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .selectionDisabled()
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                if initialScrollOffset == nil {
                    initialScrollOffset = value
                }
                guard let initial = initialScrollOffset else { return }
                let relativeOffset = value - initial
                
                let delta = value - lastScrollOffset
                lastScrollOffset = value
                
                // If near the top, always expand
                if relativeOffset > -15 {
                    if appState.isDockCompact {
                        withAnimation(.appSmooth) {
                            appState.isDockCompact = false
                        }
                    }
                } else if delta < -8 {
                    // Scrolling down: make compact
                    if !appState.isDockCompact {
                        withAnimation(.appSmooth) {
                            appState.isDockCompact = true
                        }
                    }
                } else if delta > 8 {
                    // Scrolling up: make expanded
                    if appState.isDockCompact {
                        withAnimation(.appSmooth) {
                            appState.isDockCompact = false
                        }
                    }
                }
            }
            .onChange(of: appState.scrollToTopTrigger) { _, _ in
                withAnimation(.appSmooth) {
                    proxy.scrollTo("appListTop", anchor: .top)
                }
            }
            } // ScrollViewReader

            // Bulk Actions Bar
            if isEditMode && !selectedJobIDs.isEmpty {
                VStack {
                    Spacer()
                    HStack(spacing: 0) {
                        Button(role: .destructive) {
                            isConfirmingBulkDelete = true
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "trash")
                                Text("Delete")
                            }
                        }
                        .foregroundStyle(Theme.destructive)
                        .frame(maxWidth: .infinity)

                        Button {
                            // Menu handled by overlay
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "folder")
                                Text("Move")
                            }
                        }
                        .foregroundStyle(Color.accentColor)
                        .frame(maxWidth: .infinity)
                        .overlay {
                            Menu {
                                Button {
                                    newCycleName = ""
                                    isAddingCycleFromBulk = true
                                } label: {
                                    Label("New Cycle...", systemImage: "plus")
                                }
                                if !cycles.isEmpty {
                                    Divider()
                                    ForEach(cycles) { cycle in
                                        Button(cycle.name) {
                                            moveSelectedToCycle(cycle)
                                        }
                                    }
                                }
                            } label: {
                                Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                    }
                    .appFont(12, weight: .semibold)
                    .padding(.top, 12)
                    .padding(.bottom, 100)
                    .background(.ultraThinMaterial)
                    .overlay(alignment: .top) {
                        Divider().opacity(0.5)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Undo delete toast
            if let pending = pendingDeleteJob {
                VStack {
                    Spacer()
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Removed \(pending.companyName)")
                                .appFont(15, weight: .semibold)
                                .foregroundStyle(.white)
                            Text("The application has been deleted.")
                                .appFont(13)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        Spacer()
                        Button(action: undoDelete) {
                            Text("Undo")
                                .appFont(14, weight: .bold)
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.white.opacity(0.12)))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background {
                        Capsule()
                            .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
                            .shadow(color: .black.opacity(0.3), radius: 15, y: 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 110)
                    .offset(y: toastDragY)
                    .gesture(
                        DragGesture(minimumDistance: 10)
                            .onChanged { value in
                                if value.translation.height > 0 {
                                    toastDragY = value.translation.height
                                }
                            }
                            .onEnded { value in
                                let velocity = value.predictedEndTranslation.height / 500.0
                                if value.translation.height > 50 || velocity > 0.11 {
                                    undoTask?.cancel()
                                    undoTask = nil
                                    modelContext.delete(pending)
                                    withAnimation(.appSmooth) {
                                        pendingDeleteJob = nil
                                        toastDragY = 0
                                    }
                                    AppHaptics.shared.medium()
                                } else {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        toastDragY = 0
                                    }
                                }
                            }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95)))
                }
                .allowsHitTesting(true)
            }
        }
        .animation(.appSmooth, value: pendingDeleteJob != nil)
        .toolbar(.hidden, for: .navigationBar)
        .dismissKeyboardToolbar()
        .onAppear {
            appState.dashboardHasAppeared = true
        }
        .sheet(isPresented: Binding(
            get: { isShowingCyclePicker },
            set: {
                isShowingCyclePicker = $0
                appState.isPresentingSheet = $0
            }
        )) {            NavigationStack { CyclePickerSheet(isPresented: $isShowingCyclePicker) }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .alert("New Cycle", isPresented: $isAddingFirstCycle) {
            TextField("e.g. Summer 2026", text: $newCycleName)
                .autocorrectionDisabled()
            Button("Create") { createFirstCycle() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Name this job search cycle.")
        }
        .alert("Move to New Cycle", isPresented: $isAddingCycleFromBulk) {
            TextField("e.g. Full Time 2026", text: $newCycleName)
                .autocorrectionDisabled()
            Button("Create & Move") { createBulkCycleAndMove() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a name for the new cycle.")
        }
        .confirmationDialog(
            "Delete \(selectedJobIDs.count) Application\(selectedJobIDs.count == 1 ? "" : "s")?",
            isPresented: $isConfirmingBulkDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { deleteSelected() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove the selected application\(selectedJobIDs.count == 1 ? "" : "s").")
        }
        .fileImporter(
            isPresented: $isImportingCSV,
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { importCSV(at: url) }
            case .failure(let error):
                importErrorMessage = error.localizedDescription
            }
        }
        .sheet(isPresented: Binding(
            get: { isShowingImportPreview },
            set: { 
                isShowingImportPreview = $0 
                appState.isPresentingSheet = $0
            }
        )) {
            if let rows = csvImportPreview {
                CSVImportPreviewSheet(initialRows: rows)
                    .environment(appState)
            }
        }
        .sheet(isPresented: $isShowingShareSheet) {
            if let url = csvFileURL { ShareSheet(activityItems: [url]) }
        }
        .onChange(of: searchText) { _, newValue in
            if !newValue.isEmpty {
                AppHaptics.shared.light()
            }
        }
        .alert("Import CSV", isPresented: $isShowingImportConfirmation) {
            Button("Select File") { isImportingCSV = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Select a CSV file to import your applications.")
        }
        .alert("Export CSV", isPresented: $isShowingExportConfirmation) {
            Button("Export") { exportCSV() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Create a CSV file of your applications to share or backup.")
        }
        .alert("Import Failed", isPresented: Binding(
            get: { importErrorMessage != nil },
            set: { if !$0 { importErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage ?? "")
        }
    }

    // MARK: - List View Helpers

    private var selectionToolbar: some View {
        HStack(spacing: 8) {
            Text("\(selectedJobIDs.count) selected")
                .appFont(14, weight: .bold)
                .foregroundStyle(Theme.textPrimary)
            
            Spacer()
            
            Button(selectedJobIDs.count == filteredAndSorted.count ? "Deselect All" : "Select All") {
                withAnimation(.appCrisp) {
                    if selectedJobIDs.count == filteredAndSorted.count {
                        selectedJobIDs.removeAll()
                    } else {
                        selectedJobIDs = Set(filteredAndSorted.map(\.id))
                    }
                }
                AppHaptics.shared.light()
            }
            .buttonStyle(PressScaleButtonStyle())
            .appFont(13, weight: .bold)
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                Capsule()
                    .fill(Color.accentColor.opacity(0.12))
            }
        }
    }

    private func cardScale(_ proxy: GeometryProxy) -> CGFloat {
        let minY = proxy.frame(in: .global).minY
        let screenHeight = UIScreen.main.bounds.height
        if minY < 100 { return max(0.96, 1.0 - (100 - minY) / 2000) }
        else if minY > screenHeight - 200 { return max(0.96, 1.0 - (minY - (screenHeight - 200)) / 2000) }
        return 1.0
    }

    private func cardOpacity(_ proxy: GeometryProxy) -> Double {
        let minY = proxy.frame(in: .global).minY
        let screenHeight = UIScreen.main.bounds.height
        if minY < 0 { return max(0, 1.0 + minY / 400) }
        else if minY > screenHeight - 100 { return max(0, 1.0 - (minY - (screenHeight - 100)) / 400) }
        return 1.0
    }

    // MARK: - Import / Export

    private func importCSV(at url: URL) {
        let _ = url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let raw = try String(contentsOf: url, encoding: .utf8)
            let rows = CSVImporter.parse(raw)
            guard !rows.isEmpty else {
                importErrorMessage = "No data rows found in this file. Make sure it has a header row and at least one data row."
                return
            }
            csvImportPreview = rows
            isShowingImportPreview = true
        } catch {
            importErrorMessage = "Could not read the file: \(error.localizedDescription)"
        }
    }

    private func exportCSV() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let exportable = filteredAndSorted
        let header = "Company,Position,Type,Status,Season,Work Mode,Location,Date Applied,Compensation,Currency,Resume,Notes,URL\n"
        let rows = exportable.map { app -> String in
            let compensation: String = {
                guard let amount = app.compensationAmount else { return "" }
                let kind = app.compensationKind?.rawValue ?? ""
                let period = app.salaryPeriod.map { "/\($0.rawValue)" } ?? ""
                return "\(amount)\(period.isEmpty ? " \(kind)" : " \(kind)\(period)")"
            }()
            return [
                escapeCSV(app.companyName),
                escapeCSV(app.position),
                escapeCSV(app.jobType?.rawValue ?? ""),
                escapeCSV(app.status?.rawValue ?? ""),
                escapeCSV(app.season?.rawValue ?? ""),
                escapeCSV(app.workMode?.rawValue ?? ""),
                escapeCSV(app.location ?? ""),
                escapeCSV(dateFormatter.string(from: app.dateApplied)),
                escapeCSV(compensation),
                escapeCSV(app.compensationCurrency?.rawValue ?? ""),
                escapeCSV(app.resumeFileName ?? ""),
                escapeCSV(app.jobNotes ?? ""),
                escapeCSV(app.jobURL ?? "")
            ].joined(separator: ",")
        }.joined(separator: "\n")

        let csv = header + rows
        let fileName = "AppNest_Export_\(Date().formatted(.dateTime.year().month().day())).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
            csvFileURL = tempURL
            isShowingShareSheet = true
        } catch {
            importErrorMessage = "Failed to create export file."
        }
    }

    private func escapeCSV(_ str: String) -> String {
        if str.contains(",") || str.contains("\"") || str.contains("\n") {
            return "\"\(str.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return str
    }

    // MARK: - Bulk Actions

    private func deleteSelected() {
        let toDelete = applications.filter { selectedJobIDs.contains($0.id) }
        for job in toDelete {
            modelContext.delete(job)
        }
        try? modelContext.save()
        withAnimation(.appSmooth) {
            isEditMode = false
            selectedJobIDs.removeAll()
        }
        AppHaptics.shared.medium()
    }

    private func moveSelectedToCycle(_ cycle: JobCycle) {
        let toMove = applications.filter { selectedJobIDs.contains($0.id) }
        for job in toMove {
            job.cycle = cycle
        }
        try? modelContext.save()
        withAnimation(.appSmooth) {
            isEditMode = false
            selectedJobIDs.removeAll()
        }
        AppHaptics.shared.success()
    }

    private func createBulkCycleAndMove() {
        let trimmed = newCycleName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let cycle = JobCycle(name: trimmed)
        modelContext.insert(cycle)
        moveSelectedToCycle(cycle)
        newCycleName = ""
    }

    // MARK: - Search + Filter Row

    private var searchFilterRow: some View {
        HStack(spacing: 8) {
            // Glass search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(isSearchFocused ? Color.accentColor : Theme.textSecondary)
                    .appFont(15, weight: .medium)

                TextField("Search company, position...", text: $searchText)
                    .foregroundStyle(Theme.textPrimary)
                    .tint(.accentColor)
                    .focused($isSearchFocused)

                if !searchText.isEmpty || isSearchFocused {
                    Button { 
                        if isSearchFocused && searchText.isEmpty {
                            isSearchFocused = false
                        } else {
                            searchText = ""
                        }
                        AppHaptics.shared.light()
                    } label: {
                        Image(systemName: isSearchFocused && searchText.isEmpty ? "xmark" : "xmark.circle.fill")
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isSearchFocused && searchText.isEmpty ? "Dismiss search" : "Clear search")
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(isSearchFocused ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.08), lineWidth: isSearchFocused ? 2 : 1))
            .frame(maxWidth: .infinity)
            .animation(.appBubbly, value: isSearchFocused)

            if !applications.isEmpty && !isSearchFocused {
                Menu {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button {
                            sortOption = option
                            AppHaptics.shared.light()
                        } label: {
                            HStack {
                                Text(option.rawValue)
                                if sortOption == option { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .appFont(18, weight: .semibold)
                            .foregroundStyle(sortOption == .dateNewest ? Theme.textPrimary : Color.accentColor)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))

                        if sortOption != .dateNewest {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 8, height: 8)
                                .offset(x: -4, y: 4)
                                .transition(.scale(scale: 0.8).combined(with: .opacity))
                        }
                    }
                }
                .buttonStyle(PressScaleButtonStyle())
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .scale(scale: 0.8)).combined(with: .opacity).animation(.appBubbly.delay(0.15)),
                    removal: .move(edge: .trailing).combined(with: .scale(scale: 0.9)).combined(with: .opacity).animation(.appCrisp)
                ))
            }
        }
        .clipped()
        .animation(.appSmooth, value: isSearchFocused)
    }

    private var statsSection: some View {
        let filterStatuses: [ApplicationStatus] = [.toApply, .applied, .interview, .offer, .rejected, .ghosted, .jobRemoved]
        
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // Selected group
                if !selectedStatuses.isEmpty {
                    HStack(spacing: 10) {
                        ForEach(filterStatuses.filter { selectedStatuses.contains($0) }, id: \.self) { status in
                            chipView(for: status)
                                .matchedGeometryEffect(id: status, in: filterNS)
                        }
                    }

                    if selectedStatuses.count < filterStatuses.count {
                        Capsule()
                            .fill(Color.primary.opacity(0.15))
                            .frame(width: 1, height: 22)
                            .padding(.horizontal, 10)
                            .transition(.opacity)
                    }
                }

                // Unselected group
                HStack(spacing: 10) {
                    ForEach(filterStatuses.filter { !selectedStatuses.contains($0) }, id: \.self) { status in
                        chipView(for: status)
                            .matchedGeometryEffect(id: status, in: filterNS)
                    }
                }
            }
            .animation(.appSmooth, value: selectedStatuses)
        }
    }

    private var typeSelectionLabel: String? {
        switch selectedTypes.count {
        case 0: return nil
        case 1: return selectedTypes.first!.rawValue
        default: return "\(selectedTypes.count) Types"
        }
    }

    private var seasonSelectionLabel: String? {
        switch selectedSeasons.count {
        case 0: return nil
        case 1: return selectedSeasons.first!.rawValue
        default: return "\(selectedSeasons.count) Seasons"
        }
    }

    private var workModeSelectionLabel: String? {
        switch selectedWorkModes.count {
        case 0: return nil
        case 1: return selectedWorkModes.first!.rawValue
        default: return "\(selectedWorkModes.count) Modes"
        }
    }

    private var typeSeasonFilter: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Token row
            HStack(spacing: 8) {
                FilterToken(
                    label: "Type",
                    icon: "briefcase.fill",
                    selectionSummary: typeSelectionLabel,
                    isExpanded: isTypePickerExpanded,
                    isActive: !selectedTypes.isEmpty
                ) {
                    withAnimation(.appSmooth) {
                        isTypePickerExpanded.toggle()
                        if isTypePickerExpanded { isSeasonPickerExpanded = false; isWorkModePickerExpanded = false }
                    }
                    AppHaptics.shared.light()
                }

                FilterToken(
                    label: "Season",
                    icon: "leaf.fill",
                    selectionSummary: seasonSelectionLabel,
                    isExpanded: isSeasonPickerExpanded,
                    isActive: !selectedSeasons.isEmpty
                ) {
                    withAnimation(.appSmooth) {
                        isSeasonPickerExpanded.toggle()
                        if isSeasonPickerExpanded { isTypePickerExpanded = false; isWorkModePickerExpanded = false }
                    }
                    AppHaptics.shared.light()
                }

                FilterToken(
                    label: "Location",
                    icon: "mappin.circle.fill",
                    selectionSummary: workModeSelectionLabel,
                    isExpanded: isWorkModePickerExpanded,
                    isActive: !selectedWorkModes.isEmpty
                ) {
                    withAnimation(.appSmooth) {
                        isWorkModePickerExpanded.toggle()
                        if isWorkModePickerExpanded { isTypePickerExpanded = false; isSeasonPickerExpanded = false }
                    }
                    AppHaptics.shared.light()
                }

                Spacer()

                if !selectedTypes.isEmpty || !selectedSeasons.isEmpty || !selectedWorkModes.isEmpty {
                    Button {
                        withAnimation(.appCrisp) {
                            selectedTypes.removeAll()
                            selectedSeasons.removeAll()
                            selectedWorkModes.removeAll()
                            isTypePickerExpanded = false
                            isSeasonPickerExpanded = false
                            isWorkModePickerExpanded = false
                        }
                        AppHaptics.shared.light()
                    } label: {
                        Text("Clear")
                            .appFont(12, weight: .semibold)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }

            // Type grid
            if isTypePickerExpanded {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                    spacing: 8
                ) {
                    ForEach(ApplicationType.allCases, id: \.self) { type in
                        let count = searchFiltered.filter { $0.jobType == type }.count
                        CompactFilterChip(
                            label: type.rawValue,
                            icon: type.iconName,
                            color: type.color,
                            isSelected: selectedTypes.contains(type)
                        ) {
                            withAnimation(.appCrisp) {
                                if selectedTypes.contains(type) { selectedTypes.remove(type) }
                                else { selectedTypes.insert(type) }
                            }
                            AppHaptics.shared.light()
                        }
                        .opacity(count == 0 && !selectedTypes.contains(type) ? 0.4 : 1.0)
                        .frame(maxWidth: .infinity)
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.97, anchor: .top)),
                    removal: .opacity.combined(with: .scale(scale: 0.97, anchor: .top))
                ))
            }

            // Season row
            if isSeasonPickerExpanded {
                HStack(spacing: 8) {
                    ForEach(ApplicationSeason.allCases, id: \.self) { season in
                        let count = searchFiltered.filter { $0.season == season }.count
                        CompactFilterChip(
                            label: season.rawValue,
                            icon: season.iconName,
                            color: season.color,
                            isSelected: selectedSeasons.contains(season)
                        ) {
                            withAnimation(.appCrisp) {
                                if selectedSeasons.contains(season) { selectedSeasons.remove(season) }
                                else { selectedSeasons.insert(season) }
                            }
                            AppHaptics.shared.light()
                        }
                        .opacity(count == 0 && !selectedSeasons.contains(season) ? 0.4 : 1.0)
                        .frame(maxWidth: .infinity)
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.97, anchor: .top)),
                    removal: .opacity.combined(with: .scale(scale: 0.97, anchor: .top))
                ))
            }

            // Work mode row
            if isWorkModePickerExpanded {
                HStack(spacing: 8) {
                    ForEach(WorkMode.allCases, id: \.self) { mode in
                        let count = searchFiltered.filter { $0.workMode == mode }.count
                        CompactFilterChip(
                            label: mode.rawValue,
                            icon: mode.iconName,
                            color: mode.color,
                            isSelected: selectedWorkModes.contains(mode)
                        ) {
                            withAnimation(.appCrisp) {
                                if selectedWorkModes.contains(mode) { selectedWorkModes.remove(mode) }
                                else { selectedWorkModes.insert(mode) }
                            }
                            AppHaptics.shared.light()
                        }
                        .opacity(count == 0 && !selectedWorkModes.contains(mode) ? 0.4 : 1.0)
                        .frame(maxWidth: .infinity)
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.97, anchor: .top)),
                    removal: .opacity.combined(with: .scale(scale: 0.97, anchor: .top))
                ))
            }

        }
    }

    @ViewBuilder
    private func chipView(for status: ApplicationStatus) -> some View {
        let count = searchFiltered.filter { $0.status == status }.count
        StatChip(
            status: status,
            number: count,
            isSelected: selectedStatuses.contains(status),
            action: {
                if selectedStatuses.contains(status) {
                    selectedStatuses.remove(status)
                } else {
                    selectedStatuses.insert(status)
                }
            }
        )
        .opacity(count == 0 && !selectedStatuses.contains(status) ? 0.4 : 1.0)
    }

    // MARK: - Header Action Buttons

    private var headerActionButtons: some View {
        HStack(spacing: 0) {
            exportButton
            divider
            editButton
        }
        .background {
            Capsule()
                .fill(Color.primary.opacity(0.06))
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.09), lineWidth: 1))
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .trailing)))
    }

    private var exportButton: some View {
        Button {
            isShowingExportConfirmation = true
            AppHaptics.shared.light()
        } label: {
            Image(systemName: "square.and.arrow.up")
                .appFont(13, weight: .semibold)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Export applications")
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.12))
            .frame(width: 1, height: 16)
    }

    private var editButton: some View {
        Button {
            withAnimation(.appSmooth) {
                isEditMode.toggle()
                if !isEditMode { selectedJobIDs.removeAll() }
            }
            AppHaptics.shared.light()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isEditMode ? "checkmark" : "pencil")
                    .appFont(13, weight: .semibold)
                if isEditMode {
                    Text("Done")
                        .appFont(12, weight: .semibold)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .foregroundStyle(isEditMode ? Color.accentColor : Theme.textSecondary)
            .frame(minWidth: 44)
            .frame(height: 44)
            .padding(.horizontal, isEditMode ? 4 : 0)
        }
        .buttonStyle(PressScaleButtonStyle())
        .animation(.appCrisp, value: isEditMode)
        .accessibilityLabel(isEditMode ? "Done editing" : "Edit applications")
    }

    // MARK: - Cycle Chip

    private var cycleSelectorChip: some View {
        Button { 
            isShowingCyclePicker = true 
            AppHaptics.shared.light()
        } label: {
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
                .appFont(14, weight: .bold)
                
                Image(systemName: "chevron.down")
                    .appFont(10, weight: .black)
                    .opacity(0.5)
            }
            .foregroundStyle(appState.selectedCycleID != nil ? Color.accentColor : Theme.textSecondary)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background {
                Capsule()
                    .fill(appState.selectedCycleID != nil ? Color.accentColor.opacity(0.12) : Theme.cardFill)
                    .overlay(Capsule().strokeBorder(appState.selectedCycleID != nil ? Color.accentColor.opacity(0.28) : Color.primary.opacity(0.08), lineWidth: 1))
            }
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private func createFirstCycle() {
        let trimmed = newCycleName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let cycle = JobCycle(name: trimmed)
        modelContext.insert(cycle)
        appState.selectedCycleID = cycle.id
        AppHaptics.shared.success()
    }

    // MARK: - Empty States

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray.fill")
                .appFont(48)
                .foregroundStyle(Theme.textSecondary.opacity(0.4))
            
            VStack(spacing: 8) {
                Text("No applications yet")
                    .appFont(20, weight: .bold)
                    .foregroundStyle(Theme.textPrimary)
                Text("Track your first job manually, paste a link, or import from a CSV.")
                    .appFont(14)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)

            emptyStateActions
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.bottom, 120)
    }

    private var emptyCycleState: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.questionmark")
                .appFont(48)
                .foregroundStyle(Theme.textSecondary.opacity(0.4))
            
            VStack(spacing: 8) {
                Text("No apps in this cycle")
                    .appFont(20, weight: .bold)
                    .foregroundStyle(Theme.textPrimary)
                Text("You haven't added any jobs to this search cycle yet.")
                    .appFont(14)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)

            emptyStateActions
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.bottom, 120)
    }
    
    private var emptyStateActions: some View {
        Button {
            AppHaptics.shared.light()
            appState.selectedTab = 1 // Navigate to Add tab
        } label: {
            HStack(spacing: 12) {
                Text("Add a Job")
                    .appFont(15, weight: .bold)
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.16))
                        .frame(width: 24, height: 24)
                    Image(systemName: "plus")
                        .appFont(10, weight: .bold)
                }
            }
            .foregroundStyle(.white)
            .padding(.leading, 18)
            .padding(.trailing, 8)
            .frame(height: 38)
            .background(Capsule().fill(Color.accentColor))
        }
        .buttonStyle(PressScaleButtonStyle())
        .padding(.top, 10)
    }

    private var hasActiveFilters: Bool {
        !selectedStatuses.isEmpty || !selectedTypes.isEmpty || !selectedSeasons.isEmpty || !selectedWorkModes.isEmpty
    }

    private var noResultsState: some View {
        VStack(spacing: 20) {
            if searchText.isEmpty {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .appFont(48)
                    .foregroundStyle(Theme.textSecondary.opacity(0.5))
                Text("No applications match these filters")
                    .appFont(16, weight: .semibold)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Button("Clear Filters") {
                    withAnimation(.appCrisp) {
                        selectedStatuses.removeAll()
                        selectedTypes.removeAll()
                        selectedSeasons.removeAll()
                        selectedWorkModes.removeAll()
                        isTypePickerExpanded = false
                        isSeasonPickerExpanded = false
                        isWorkModePickerExpanded = false
                    }
                    AppHaptics.shared.light()
                }
                .appFont(13, weight: .semibold)
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.accentColor.opacity(0.10))
                        .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.20), lineWidth: 1))
                )
                .buttonStyle(PressScaleButtonStyle())
            } else {
                Image(systemName: "magnifyingglass")
                    .appFont(48)
                    .foregroundStyle(Theme.textSecondary.opacity(0.5))
                Text("No results for \"\(searchText)\"")
                    .appFont(16, weight: .semibold)
                    .foregroundStyle(Theme.textPrimary)
                HStack(spacing: 10) {
                    Button("Clear Search") {
                        searchText = ""
                        AppHaptics.shared.light()
                    }
                    .appFont(13, weight: .semibold)
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.opacity(0.10))
                            .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.20), lineWidth: 1))
                    )
                    .buttonStyle(PressScaleButtonStyle())

                    if hasActiveFilters {
                        Button("Clear Filters") {
                            withAnimation(.appCrisp) {
                                selectedStatuses.removeAll()
                                selectedTypes.removeAll()
                                selectedSeasons.removeAll()
                                isTypePickerExpanded = false
                                isSeasonPickerExpanded = false
                            }
                            AppHaptics.shared.light()
                        }
                        .appFont(13, weight: .semibold)
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.primary.opacity(0.06))
                                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
                        )
                        .buttonStyle(PressScaleButtonStyle())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.bottom, 120)
        .padding(.horizontal, 20)
    }

    // MARK: - Delete with Undo

    private func scheduleDelete(_ job: JobApplication) {
        // Immediately commit any previously-pending delete so it doesn't ghost back
        if let pending = pendingDeleteJob {
            undoTask?.cancel()
            undoTask = nil
            modelContext.delete(pending)
        }
        withAnimation(.appSmooth) {
            pendingDeleteJob = job
            toastDragY = 0
        }
        undoTask = Task {
            do { try await Task.sleep(for: .seconds(4)) } catch { return }
            await MainActor.run {
                modelContext.delete(job)
                withAnimation(.appSmooth) { pendingDeleteJob = nil }
            }
        }
        AppHaptics.shared.medium()
    }

    private func undoDelete() {
        undoTask?.cancel()
        undoTask = nil
        withAnimation(.appSmooth) {
            pendingDeleteJob = nil
            toastDragY = 0
        }
        AppHaptics.shared.light()
    }
}

#Preview {
    let container = try! ModelContainer(
        for: JobApplication.self, ResumeDocument.self, JobCycle.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return NavigationStack { ApplicationView() }
        .environment(AppState())
        .modelContainer(container)
}
