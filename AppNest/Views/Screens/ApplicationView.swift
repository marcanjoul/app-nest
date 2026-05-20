import SwiftUI
import SwiftData
import UIKit

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
    @State private var contentAppeared = false
    @State private var searchText: String = ""
    @State private var isPresentingNewApplication = false
    @State private var selectedStatuses: Set<ApplicationStatus> = []
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

    @AppStorage(AppStorageKeys.hideRejected) private var hideRejected: Bool = false

    @State private var isShowingEmailParseSheet = false

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

        if hideRejected {
            result = result.filter { $0.status != .rejected }
        }

        if !selectedStatuses.isEmpty {
            result = result.filter { job in
                job.status.map { selectedStatuses.contains($0) } ?? false
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

            List(selection: $selectedJobIDs) {
                // Header
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("App Nest")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)
                            
                            if !searchText.isEmpty {
                                Text("\(filteredAndSorted.count) results")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Color.accentColor)
                                    .transition(.opacity.combined(with: .move(edge: .leading)))
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.top, 16)
                    
                    cycleSelectorChip
                        .padding(.top, 8)
                }
                .opacity(contentAppeared ? 1 : 0)
                .offset(y: contentAppeared ? 0 : 20)
                .animation(.appSmooth, value: contentAppeared)
                .animation(.appSmooth, value: searchText.isEmpty)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .selectionDisabled() // Header should not be selectable

                // Search + Filter
                searchFilterRow
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 16)
                    .animation(.appSmooth.delay(0.07), value: contentAppeared)
                    .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .selectionDisabled()

                // Stats
                statsSection
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 12)
                    .animation(.appSmooth.delay(0.12), value: contentAppeared)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 14, trailing: 0))
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
                            .listRowInsets(EdgeInsets(top: 4, leading: 24, bottom: 10, trailing: 24))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .selectionDisabled()
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    ForEach(Array(filteredAndSorted.enumerated()), id: \.element.id) { index, job in
                        JobCardSwipeRow(job: job, isEditMode: isEditMode, onDelete: { scheduleDelete(job) })
                            .listRowInsets(EdgeInsets(top: 6, leading: isEditMode ? 4 : 20, bottom: 6, trailing: 20))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .visualEffect { content, proxy in
                                content
                                    .scaleEffect(cardScale(proxy))
                                    .opacity(cardOpacity(proxy))
                            }
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
                                removal: .opacity.combined(with: .scale(scale: 0.9))
                            ))
                            .animation(.appSmooth.delay(Double(min(index, 6)) * 0.05), value: filteredAndSorted.count)
                            .animation(.appSmooth.delay(Double(min(index, 6)) * 0.05), value: contentAppeared)
                    }
                }

                // Attribution Footer
                VStack(spacing: 4) {
                    Text("Logos provided by Logo.dev")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
                .padding(.bottom, 60)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .selectionDisabled()
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .environment(\.editMode, .constant(isEditMode ? .active : .inactive))

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
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.top, 12)
                    .padding(.bottom, 34)
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
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("The application has been deleted.")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        Spacer()
                        Button(action: undoDelete) {
                            Text("Undo")
                                .font(.system(size: 14, weight: .bold))
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
                    .padding(.bottom, 34)
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
        .onAppear {
            contentAppeared = true
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
        .sheet(isPresented: $isShowingEmailParseSheet, onDismiss: {
            appState.pendingEmailText = nil
        }) {
            NavigationStack {
                EmailParserView(initialText: appState.pendingEmailText)
            }
        }
        .onChange(of: appState.pendingEmailText) { _, text in
            guard text != nil else { return }
            isShowingEmailParseSheet = true
        }
        .onChange(of: appState.pendingJobImport) { _, pending in
            guard let pending else { return }
            let job = JobApplication(
                companyName: pending.companyName,
                position: pending.position,
                jobType: pending.jobType,
                status: pending.status ?? .toApply,
                season: pending.season,
                dateApplied: Date(),
                jobURL: pending.sourceURL,
                jobNotes: pending.notes
            )
            modelContext.insert(job)
            try? modelContext.save()
            appState.pendingJobImport = nil
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
                .font(.system(size: 14, weight: .bold))
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
            .font(.system(size: 13, weight: .bold))
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
        let exportable = cycleFiltered.sorted { $0.dateApplied > $1.dateApplied }
        let header = "Company,Position,Type,Status,Season,Date Applied,Compensation,Currency,Resume,Notes\n"
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
                escapeCSV(dateFormatter.string(from: app.dateApplied)),
                escapeCSV(compensation),
                escapeCSV(app.compensationCurrency?.rawValue ?? ""),
                escapeCSV(app.resumeFileName ?? ""),
                escapeCSV(app.jobNotes ?? "")
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
                    .font(.system(size: 15, weight: .medium))

                TextField(isSearchFocused ? "Search company, position..." : "Search...", text: $searchText)
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
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(isSearchFocused ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.08), lineWidth: 1))
            .frame(maxWidth: .infinity)
            .animation(.appBubbly, value: isSearchFocused)

            if !applications.isEmpty && !isSearchFocused {
                HStack(spacing: 8) {
                    // Sort button
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
                                .font(.system(size: 18, weight: .semibold))
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
                    
                    // Export button
                    Button {
                        isShowingExportConfirmation = true
                        AppHaptics.shared.light()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 44, height: 44)
                            .background {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
                            }
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    
                    // Edit button
                    Button {
                        withAnimation(.appSmooth) {
                            isEditMode.toggle()
                            if !isEditMode { selectedJobIDs.removeAll() }
                        }
                        AppHaptics.shared.light()
                    } label: {
                        Image(systemName: isEditMode ? "checkmark" : "pencil")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(isEditMode ? Color.white : Color.accentColor)
                            .frame(width: isEditMode ? 60 : 44, height: 44)
                            .background {
                                if isEditMode {
                                    Capsule()
                                        .fill(Color.accentColor)
                                } else {
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .overlay(Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
                                }
                            }
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
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
        let filterStatuses: [ApplicationStatus] = [.toApply, .applied, .interview, .offer, .rejected]
        
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
            .animation(.appCrisp, value: selectedStatuses)
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

    // MARK: - Cycle Chip

    private var cycleSelectorChip: some View {
        Button { 
            isShowingCyclePicker = true 
            AppHaptics.shared.light()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: appState.selectedCycleID != nil ? "tray.fill" : "tray.2.fill")
                    .font(.system(size: 11, weight: .bold))
                
                Group {
                    if let id = appState.selectedCycleID,
                       let cycle = cycles.first(where: { $0.id == id }) {
                        Text(cycle.name)
                    } else {
                        Text("All Applications")
                    }
                }
                .font(.system(size: 14, weight: .bold))
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .black))
                    .opacity(0.5)
            }
            .foregroundStyle(appState.selectedCycleID != nil ? Color.accentColor : Theme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
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
                .font(.system(size: 52))
                .foregroundStyle(Theme.textSecondary.opacity(0.4))
            
            VStack(spacing: 8) {
                Text("No applications yet")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Track your first job manually, paste a link, or import from a CSV.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)

            emptyStateActions
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var emptyCycleState: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 52))
                .foregroundStyle(Theme.textSecondary.opacity(0.4))
            
            VStack(spacing: 8) {
                Text("No apps in this cycle")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("You haven't added any jobs to this search cycle yet.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)

            emptyStateActions
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var emptyStateActions: some View {
        Button {
            AppHaptics.shared.light()
            appState.selectedTab = 1 // Navigate to Add tab
        } label: {
            Label("Add Job", systemImage: "plus")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .background(Capsule().fill(Color.accentColor))
        }
        .buttonStyle(PressScaleButtonStyle())
        .padding(.top, 10)
    }

    private var noResultsState: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(Theme.textSecondary.opacity(0.5))
            Text("No results for \"\(searchText)\"")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Button("Clear Search") {
                searchText = ""
                AppHaptics.shared.light()
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(0.10))
                    .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.20), lineWidth: 1))
            )
            .buttonStyle(PressScaleButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
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
