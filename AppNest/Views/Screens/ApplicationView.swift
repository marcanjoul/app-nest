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
    @State private var searchText: String = ""
    @State private var isPresentingNewApplication = false
    @State private var selectedStatuses: Set<ApplicationStatus> = []
    @State private var selectedTypes: Set<ApplicationType> = []
    @State private var selectedSeasons: Set<ApplicationSeason> = []
    @State private var selectedWorkModes: Set<WorkMode> = []
    /// Lowercased — "San Francisco, CA" and "san francisco, ca" are one place.
    @State private var selectedLocations: Set<String> = []
    @State private var sortOption: SortOption = .dateNewest
    @State private var pendingDeleteJob: JobApplication? = nil
    /// Job whose status dropdown is open, with its pill's and card's global frames.
    @State private var statusPicker: (job: JobApplication, anchor: CGRect, card: CGRect)? = nil
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
    @State private var exportFile: ExportFile? = nil
    @State private var isChoosingExportScope = false
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
            ($0.jobType?.rawValue.lowercased().contains(query) ?? false) ||
            ($0.location?.lowercased().contains(query) ?? false)
        }
    }

    private var filteredAndSorted: [JobApplication] {
        var result = searchFiltered

        if !selectedStatuses.isEmpty {
            result = result.filter { job in
                selectedStatuses.contains { Self.status($0, matches: job.status) }
            }
        }
        if !selectedTypes.isEmpty {
            result = result.filter { job in
                job.jobType.map { selectedTypes.contains($0) } ?? false
            }
        }
        if !selectedSeasons.isEmpty {
            result = result.filter { job in
                !selectedSeasons.isDisjoint(with: job.seasons)
            }
        }
        if !selectedWorkModes.isEmpty {
            result = result.filter { job in
                job.workMode.map { selectedWorkModes.contains($0) } ?? false
            }
        }
        if !selectedLocations.isEmpty {
            result = result.filter { job in
                job.location.map { selectedLocations.contains($0.trimmingCharacters(in: .whitespaces).lowercased()) } ?? false
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
                // Zero-height scroll-to-top target.
                Color.clear
                    .frame(height: 0)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .selectionDisabled()
                    .id("appListTop")

                // Stats — status chips
                statsSection
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 0))
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
                    if hasMenuFilters {
                        activeFilterChips
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .animation(.appSmooth, value: hasMenuFilters)
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
                                },
                                isStatusOpen: statusPicker?.job.id == job.id,
                                onStatusTap: { pill, card in
                                    AppHaptics.shared.light()
                                    withAnimation(.appSmooth) { statusPicker = (job, pill, card) }
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
                                .tint(.red)
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
                        .appFont(.caption, weight: .semibold)
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
            // ponytail: lets the header row collapse to 0 when empty, so chips sit 8pt under search
            .environment(\.defaultMinListRowHeight, 0)
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
                        .foregroundStyle(Theme.accent)
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
                    .appFont(.footnote, weight: .semibold)
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
                            .appFont(.body, weight: .semibold)
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Button("Undo", action: undoDelete)
                            .appFont(.body, weight: .bold)
                            .foregroundStyle(Theme.accent)
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

            if let picker = statusPicker {
                StatusDropdownOverlay(job: picker.job, anchor: picker.anchor, card: picker.card) {
                    withAnimation(.appSmooth) { statusPicker = nil }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .animation(.appSmooth, value: pendingDeleteJob != nil)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search company, position...")
        .dismissKeyboardToolbar()
        .sheet(isPresented: Binding(
            get: { isShowingCyclePicker },
            set: {
                isShowingCyclePicker = $0
            }
        )) {            NavigationStack { CyclePickerSheet(isPresented: $isShowingCyclePicker) }
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
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
        // item-driven so the sheet can't open before the file exists (blank first share sheet).
        .sheet(item: $exportFile) { file in
            ShareSheet(activityItems: [file.url])
        }
        .confirmationDialog("Export to CSV", isPresented: $isChoosingExportScope, titleVisibility: .visible) {
            Button("Export \(filteredAndSorted.count) Shown") { exportCSV(filteredAndSorted) }
            Button("Export All \(cycleFiltered.count)") { exportCSV(cycleFiltered) }
        } message: {
            Text("Filters or search are hiding some applications.")
        }
        .alert("Import CSV", isPresented: $isShowingImportConfirmation) {
            Button("Select File") { isImportingCSV = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Select a CSV file to import your applications.")
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
                .appFont(.body, weight: .bold)
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
            }
            .buttonStyle(PressScaleButtonStyle())
            .appFont(.footnote, weight: .bold)
            .foregroundStyle(Theme.buttonGreen)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .glassEffect(.regular.tint(Theme.buttonGreen.opacity(0.12)).interactive(), in: .capsule)
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

    private func exportCSV(_ exportable: [JobApplication]) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
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
                escapeCSV(app.seasons.map(\.rawValue).joined(separator: " / ")),
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
        let fileName = "App Nest Export \(Date().formatted(.dateTime.year().month().day())).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
            exportFile = ExportFile(url: tempURL)
        } catch {
            importErrorMessage = "Failed to create export file."
        }
    }

    private func escapeCSV(_ str: String) -> String {
        // Scalars, not Characters: "\r\n" is one Character and would slip past a Character check.
        if str.unicodeScalars.contains(where: { ",\"\n\r".unicodeScalars.contains($0) }) {
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

    // MARK: - Sort Menu

    private var sortMenu: some View {
        Menu {
            Picker("Sort", selection: $sortOption) {
                ForEach(SortOption.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
        } label: {
            AppIcon("arrow.up.arrow.down")
                .appFont(13, weight: .semibold)
                .foregroundStyle(sortOption != .dateNewest ? Theme.accent : Theme.textSecondary)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("Sort: \(sortOption.rawValue)")
    }

    // MARK: - Filter Menu

    private var filterMenu: some View {
        Menu {
            filterSection("Type", selection: $selectedTypes)
            filterSection("Season", selection: $selectedSeasons)
            filterSection("Work Mode", selection: $selectedWorkModes)
            if !locationOptions.isEmpty {
                Section("City") {
                    Menu(selectedLocations.isEmpty ? "Any City" : "\(selectedLocations.count) Selected") {
                        ForEach(locationOptions, id: \.self) { place in
                            Toggle(place, isOn: Binding(
                                get: { selectedLocations.contains(place.lowercased()) },
                                set: { isOn in
                                    if isOn { selectedLocations.insert(place.lowercased()) } else { selectedLocations.remove(place.lowercased()) }
                                    AppHaptics.shared.light()
                                }
                            ))
                        }
                    }
                }
            }
            if hasMenuFilters {
                Button("Clear Filters", role: .destructive, action: clearMenuFilters)
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                AppIcon("line.3.horizontal.decrease")
                    .appFont(13, weight: .semibold)
                    .foregroundStyle(hasMenuFilters ? Theme.accent : Theme.textSecondary)
                    .frame(width: 44, height: 44)

                if hasMenuFilters {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 8, height: 8)
                        .offset(x: -8, y: 10)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
        }
        .menuActionDismissBehavior(.disabled)
        .accessibilityLabel("Filter")
    }

    private func clearMenuFilters() {
        withAnimation(.appSmooth) {
            selectedTypes.removeAll()
            selectedSeasons.removeAll()
            selectedWorkModes.removeAll()
            selectedLocations.removeAll()
        }
        AppHaptics.shared.light()
    }

    // MARK: - Active Filter Chips

    private struct ActiveFilter: Identifiable {
        let id: String
        let label: String
        let remove: () -> Void
    }

    /// Every menu filter that's on, so each can be removed without reopening the menu.
    private var activeFilters: [ActiveFilter] {
        var filters: [ActiveFilter] = []
        for t in ApplicationType.allCases where selectedTypes.contains(t) {
            filters.append(.init(id: "type-\(t.rawValue)", label: t.rawValue) { selectedTypes.remove(t) })
        }
        for season in ApplicationSeason.allCases where selectedSeasons.contains(season) {
            filters.append(.init(id: "season-\(season.rawValue)", label: season.rawValue) { selectedSeasons.remove(season) })
        }
        for mode in WorkMode.allCases where selectedWorkModes.contains(mode) {
            filters.append(.init(id: "mode-\(mode.rawValue)", label: mode.rawValue) { selectedWorkModes.remove(mode) })
        }
        for key in selectedLocations.sorted() {
            // Stored lowercased; show the spelling the user's applications use.
            let name = locationOptions.first { $0.lowercased() == key } ?? key.capitalized
            filters.append(.init(id: "city-\(key)", label: name) { selectedLocations.remove(key) })
        }
        return filters
    }

    private var activeFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(activeFilters) { filter in
                    Button {
                        AppHaptics.shared.light()
                        withAnimation(.appSmooth) { filter.remove() }
                    } label: {
                        HStack(spacing: 6) {
                            Text(filter.label)
                                .appFont(.footnote, weight: .semibold)
                            AppIcon("xmark")
                                .appFont(9, weight: .bold)
                                .opacity(0.6)
                        }
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(Capsule().fill(Color.primary.opacity(0.06)))
                        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.10), lineWidth: 1))
                        .contentShape(Capsule())
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityLabel("Remove \(filter.label) filter")
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }

                Button("Clear All", action: clearMenuFilters)
                    .appFont(.footnote, weight: .semibold)
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 8)
                    .frame(height: 32)
            }
            .animation(.appSmooth, value: activeFilters.map(\.id))
        }
        .scrollClipDisabled()
    }

    private var hasMenuFilters: Bool {
        !selectedTypes.isEmpty || !selectedSeasons.isEmpty || !selectedWorkModes.isEmpty || !selectedLocations.isEmpty
    }

    /// Distinct places in the current cycle, most-used first. First spelling seen wins.
    private var locationOptions: [String] {
        var counts: [String: (name: String, count: Int)] = [:]
        for place in cycleFiltered.compactMap({ $0.location?.trimmingCharacters(in: .whitespaces) }) where !place.isEmpty {
            counts[place.lowercased(), default: (place, 0)].count += 1
        }
        return counts.values
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
            .map(\.name)
    }

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
        // Empty chips would only lead to an empty list; a selected one stays so it can be cleared.
        let filterStatuses = ([.toApply, .applied, .interview, .offer, .rejected, .ghosted, .jobRemoved] as [ApplicationStatus])
            .filter { chipCount(for: $0) > 0 || selectedStatuses.contains($0) }
        
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

    /// The Applied chip means "submitted": everything that got past To Apply, except a posting
    /// that was taken down. Other chips match their own status only.
    private static func status(_ chip: ApplicationStatus, matches jobStatus: ApplicationStatus?) -> Bool {
        guard chip == .applied else { return jobStatus == chip }
        return [.applied, .interview, .offer, .rejected, .ghosted].contains(jobStatus)
    }

    private func chipCount(for status: ApplicationStatus) -> Int {
        searchFiltered.filter { Self.status(status, matches: $0.status) }.count
    }

    @ViewBuilder
    private func chipView(for status: ApplicationStatus) -> some View {
        let count = chipCount(for: status)
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
    }

    // MARK: - Header Action Buttons

    private var headerActionButtons: some View {
        HStack(spacing: 0) {
            sortMenu
            divider
            filterMenu
            divider
            exportButton
            divider
            editButton
        }
        .glassEffect(in: .capsule)
        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .trailing)))
    }

    private var exportButton: some View {
        Button {
            let shown = filteredAndSorted
            if shown.count < cycleFiltered.count { isChoosingExportScope = true } else { exportCSV(shown) }
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
        } label: {
            // Same 44pt box either way, so pencil ↔ tick swaps in place without resizing the capsule.
            ZStack {
                AppIcon("pencil")
                    .foregroundStyle(Theme.textSecondary)
                    .opacity(isEditMode ? 0 : 1)
                    .scaleEffect(isEditMode ? 0.6 : 1)
                AppIcon("checkmark")
                    .foregroundStyle(Theme.accent)
                    .opacity(isEditMode ? 1 : 0)
                    .scaleEffect(isEditMode ? 1 : 0.6)
            }
            .appFont(13, weight: .semibold)
            .frame(width: 44, height: 44)
        }
        .buttonStyle(PressScaleButtonStyle())
        .animation(.appCrisp, value: isEditMode)
        .accessibilityLabel(isEditMode ? "Done editing" : "Edit applications")
    }

    // MARK: - Cycle Chip

    private var cycleSelectorChip: some View {
        Button { 
            isShowingCyclePicker = true 
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
                .appFont(.body, weight: .bold)
                // The header actions take the rest of the row; truncate rather than wrap in a 44pt chip.
                .lineLimit(1)
                
                AppIcon("chevron.down")
                    .appFont(10, weight: .black)
                    .opacity(0.5)
            }
            .foregroundStyle(appState.selectedCycleID != nil ? Theme.accent : Theme.textSecondary)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .glassEffect(.regular.tint(appState.selectedCycleID != nil ? Theme.accent.opacity(0.12) : nil).interactive(), in: .capsule)
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
                    .appFont(.title, weight: .bold)
                    .foregroundStyle(Theme.textPrimary)
                Text("Track your first job manually, paste a link, or import from a CSV.")
                    .appFont(.body)
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
                    .appFont(.title, weight: .bold)
                    .foregroundStyle(Theme.textPrimary)
                Text("You haven't added any jobs to this search cycle yet.")
                    .appFont(.body)
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
            appState.isShowingAdd = true
        } label: {
            HStack(spacing: 12) {
                Text("Add a Job")
                    .appFont(.body, weight: .bold)
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
            .glassEffect(.regular.tint(Theme.buttonGreen).interactive(), in: .capsule)
        }
        .buttonStyle(PressScaleButtonStyle())
        .padding(.top, 10)
    }

    private var hasActiveFilters: Bool {
        !selectedStatuses.isEmpty || !selectedTypes.isEmpty || !selectedSeasons.isEmpty || !selectedWorkModes.isEmpty || !selectedLocations.isEmpty
    }

    private var noResultsState: some View {
        VStack(spacing: 20) {
            if searchText.isEmpty {
                AppIcon("line.3.horizontal.decrease.circle")
                    .appFont(48)
                    .foregroundStyle(Theme.textSecondary.opacity(0.5))
                Text("No applications match these filters")
                    .appFont(.body, weight: .semibold)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Button("Clear Filters") {
                    withAnimation(.appCrisp) {
                        selectedStatuses.removeAll()
                        selectedTypes.removeAll()
                        selectedSeasons.removeAll()
                        selectedWorkModes.removeAll()
                        selectedLocations.removeAll()
                    }
                }
                .appFont(.footnote, weight: .semibold)
                .foregroundStyle(Theme.buttonGreen)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .glassEffect(.regular.tint(Theme.buttonGreen.opacity(0.10)).interactive(), in: .capsule)
                .buttonStyle(PressScaleButtonStyle())
            } else {
                AppIcon("magnifyingglass")
                    .appFont(48)
                    .foregroundStyle(Theme.textSecondary.opacity(0.5))
                Text("No results for \"\(searchText)\"")
                    .appFont(.body, weight: .semibold)
                    .foregroundStyle(Theme.textPrimary)
                HStack(spacing: 10) {
                    Button("Clear Search") {
                        searchText = ""
                    }
                    .appFont(.footnote, weight: .semibold)
                    .foregroundStyle(Theme.buttonGreen)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassEffect(.regular.tint(Theme.buttonGreen.opacity(0.10)).interactive(), in: .capsule)
                    .buttonStyle(PressScaleButtonStyle())

                    if hasActiveFilters {
                        Button("Clear Filters") {
                            withAnimation(.appCrisp) {
                                selectedStatuses.removeAll()
                                selectedTypes.removeAll()
                                selectedSeasons.removeAll()
                                selectedWorkModes.removeAll()
                                selectedLocations.removeAll()
                            }
                        }
                        .appFont(.footnote, weight: .semibold)
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

private struct ExportFile: Identifiable {
    let url: URL
    var id: URL { url }
}
