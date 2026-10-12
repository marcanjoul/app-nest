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
    @State private var searchText: String = ""
    @State private var isPresentingNewApplication = false
    @State private var selectedStatuses: Set<ApplicationStatus> = []
    @State private var selectedTypes: Set<ApplicationType> = []
    @State private var selectedSeasons: Set<ApplicationSeason> = []
    @State private var selectedWorkModes: Set<WorkMode> = []
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
        // ponytail: filter+sort is O(n log n) — bind once per body pass, not once per use site
        let rows = filteredAndSorted

        ZStack {
            // Shared background
            AmbientBackground()

            List {
                // Header
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        if !searchText.isEmpty {
                            Text("\(rows.count) results")
                                .appFont(13, weight: .bold)
                                .foregroundStyle(Color.accentColor)
                                .transition(.opacity.combined(with: .move(edge: .leading)))
                        }
                    }
                    .padding(.top, 16)

                }
                .animation(.appSmooth, value: searchText.isEmpty)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .selectionDisabled()
                .id("appListTop")

                // Search + Filter
                searchFilterRow
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .selectionDisabled()

                // Stats — status chips
                statsSection
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 0))
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
                } else if rows.isEmpty {
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

                    ForEach(rows) { job in
                        JobCardSwipeRow(
                                job: job,
                                isEditMode: isEditMode,
                                isSelected: selectedJobIDs.contains(job.id),
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
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    scheduleDelete(job)
                                } label: {
                                    AppLabel("Delete", systemImage: "trash.fill")
                                }
                            }
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .offset(y: 10)),
                                removal: .opacity.combined(with: .scale(scale: 0.97))
                            ))
                            .animation(.appCrisp, value: rows.count)
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
                .padding(.bottom, 24)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .selectionDisabled()
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)

            // Bulk Actions Bar
            if isEditMode && !selectedJobIDs.isEmpty {
                VStack {
                    Spacer()
                    HStack(spacing: 0) {
                        Button(role: .destructive) {
                            isConfirmingBulkDelete = true
                        } label: {
                            VStack(spacing: 4) {
                                AppIcon("trash")
                                Text("Delete")
                            }
                        }
                        .foregroundStyle(Theme.destructive)
                        .frame(maxWidth: .infinity)

                        Button {
                            // Menu handled by overlay
                        } label: {
                            VStack(spacing: 4) {
                                AppIcon("folder")
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
                                    AppLabel("New Cycle...", systemImage: "plus")
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
                    .padding(.vertical, 10)
                    .glassEffect(in: .capsule)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Undo delete toast
            if let pending = pendingDeleteJob {
                VStack {
                    Spacer()
                    HStack(spacing: 14) {
                        Text("Deleted \(pending.companyName)")
                            .appFont(15, weight: .semibold)
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Button("Undo", action: undoDelete)
                            .appFont(15, weight: .bold)
                            .foregroundStyle(Color.accentColor)
                            .frame(minHeight: 44)
                    }
                    .padding(.leading, 20)
                    .padding(.trailing, 16)
                    .glassEffect(in: .capsule)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
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
        .sheet(isPresented: Binding(
            get: { isShowingCyclePicker },
            set: {
                isShowingCyclePicker = $0
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
            .glassEffect(.regular.tint(Color.accentColor.opacity(0.12)).interactive(), in: .capsule)
        }
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
                AppIcon("magnifyingglass")
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
                        AppIcon(isSearchFocused && searchText.isEmpty ? "xmark" : "xmark.circle.fill")
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
            .glassEffect(.regular.tint(isSearchFocused ? Color.accentColor.opacity(0.12) : nil), in: .capsule)
            .frame(maxWidth: .infinity)
            .animation(.appBubbly, value: isSearchFocused)

            if !applications.isEmpty && !isSearchFocused {
                Menu {
                    Section("Sort") {
                        Picker("Sort", selection: $sortOption) {
                            ForEach(SortOption.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                    }
                    filterSection("Type", selection: $selectedTypes)
                    filterSection("Season", selection: $selectedSeasons)
                    filterSection("Location", selection: $selectedWorkModes)
                    if hasMenuFilters {
                        Button("Clear Filters", role: .destructive) {
                            selectedTypes.removeAll()
                            selectedSeasons.removeAll()
                            selectedWorkModes.removeAll()
                        }
                    }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        AppIcon("line.3.horizontal.decrease.circle")
                            .appFont(18, weight: .semibold)
                            .foregroundStyle(isMenuCustomized ? Color.accentColor : Theme.textPrimary)
                            .frame(width: 44, height: 44)
                            .glassEffect(.regular.interactive(), in: .circle)

                        if isMenuCustomized {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 8, height: 8)
                                .offset(x: -4, y: 4)
                                .transition(.scale(scale: 0.8).combined(with: .opacity))
                        }
                    }
                }
                .menuActionDismissBehavior(.disabled)
                .buttonStyle(PressScaleButtonStyle())
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .scale(scale: 0.8)).combined(with: .opacity).animation(.appBubbly.delay(0.15)),
                    removal: .move(edge: .trailing).combined(with: .scale(scale: 0.9)).combined(with: .opacity).animation(.appCrisp)
                ))
            }
        }
        .animation(.appSmooth, value: isSearchFocused)
    }

    private var hasMenuFilters: Bool {
        !selectedTypes.isEmpty || !selectedSeasons.isEmpty || !selectedWorkModes.isEmpty
    }

    private var isMenuCustomized: Bool { hasMenuFilters || sortOption != .dateNewest }

    private func filterSection<T: Hashable & CaseIterable & RawRepresentable>(_ title: String, selection: Binding<Set<T>>) -> some View where T.AllCases: RandomAccessCollection, T.RawValue == String {
        Section(title) {
            ForEach(T.allCases, id: \.self) { option in
                Toggle(option.rawValue, isOn: Binding(
                    get: { selection.wrappedValue.contains(option) },
                    set: { isOn in
                        if isOn { selection.wrappedValue.insert(option) } else { selection.wrappedValue.remove(option) }
                        AppHaptics.shared.light()
                    }
                ))
            }
        }
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
        .scrollClipDisabled()
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
        .glassEffect(in: .capsule)
        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .trailing)))
    }

    private var exportButton: some View {
        Button {
            isShowingExportConfirmation = true
            AppHaptics.shared.light()
        } label: {
            AppIcon("square.and.arrow.up")
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
                AppIcon(isEditMode ? "checkmark" : "pencil")
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
                AppIcon(appState.selectedCycleID != nil ? "tray.fill" : "tray.2.fill")
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
                
                AppIcon("chevron.down")
                    .appFont(10, weight: .black)
                    .opacity(0.5)
            }
            .foregroundStyle(appState.selectedCycleID != nil ? Color.accentColor : Theme.textSecondary)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .glassEffect(.regular.tint(appState.selectedCycleID != nil ? Color.accentColor.opacity(0.12) : nil).interactive(), in: .capsule)
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
            AppIcon("tray.fill")
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
            AppIcon("folder.badge.questionmark")
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
                    AppIcon("plus")
                        .appFont(10, weight: .bold)
                }
            }
            .foregroundStyle(.white)
            .padding(.leading, 18)
            .padding(.trailing, 8)
            .frame(height: 38)
            .glassEffect(.regular.tint(Color.accentColor).interactive(), in: .capsule)
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
                AppIcon("line.3.horizontal.decrease.circle")
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
                    }
                    AppHaptics.shared.light()
                }
                .appFont(13, weight: .semibold)
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .glassEffect(.regular.tint(Color.accentColor.opacity(0.10)).interactive(), in: .capsule)
                .buttonStyle(PressScaleButtonStyle())
            } else {
                AppIcon("magnifyingglass")
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
                    .glassEffect(.regular.tint(Color.accentColor.opacity(0.10)).interactive(), in: .capsule)
                    .buttonStyle(PressScaleButtonStyle())

                    if hasActiveFilters {
                        Button("Clear Filters") {
                            withAnimation(.appCrisp) {
                                selectedStatuses.removeAll()
                                selectedTypes.removeAll()
                                selectedSeasons.removeAll()
                            }
                            AppHaptics.shared.light()
                        }
                        .appFont(13, weight: .semibold)
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .glassEffect(.regular.interactive(), in: .capsule)
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
