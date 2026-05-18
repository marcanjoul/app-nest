import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

enum SortOption: String, CaseIterable {
    case dateNewest = "Newest"
    case dateOldest = "Oldest"
    case companyAZ  = "Company A–Z"
    case companyZA  = "Company Z–A"

    var shortLabel: String {
        switch self {
        case .dateNewest: return "Newest"
        case .dateOldest: return "Oldest"
        case .companyAZ:  return "A–Z"
        case .companyZA:  return "Z–A"
        }
    }
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
    @State private var sortOption: SortOption = .dateNewest
    @State private var contentAppeared = false
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
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("App Nest")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(DarkTheme.textPrimary)
                        cycleSelectorChip
                            .padding(.top, 6)
                    }
                    Spacer()
                    HStack(spacing: 10) {
                        Button {
                            exportCSV()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(applications.isEmpty
                                    ? DarkTheme.textTertiary
                                    : DarkTheme.textSecondary)
                                .frame(width: 34, height: 34)
                                .background {
                                    Circle()
                                        .fill(DarkTheme.cardFill)
                                        .overlay(Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
                                }
                                .opacity(applications.isEmpty ? 0.4 : 1)
                        }
                        .buttonStyle(.plain)
                        .disabled(applications.isEmpty)
                        .animation(.appCrisp, value: applications.isEmpty)
                        .padding(.top, 12)

                        if !applications.isEmpty {
                            Button(isEditMode ? "Done" : "Edit") {
                                withAnimation(.appSmooth) {
                                    isEditMode.toggle()
                                    if !isEditMode { selectedJobIDs.removeAll() }
                                }
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                            .padding(.top, 12)
                        }
                    }
                }
                .opacity(contentAppeared ? 1 : 0)
                .offset(y: contentAppeared ? 0 : 20)
                .animation(.appSmooth, value: contentAppeared)
                .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 8, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .selectionDisabled() // Header should not be selectable

                // Search + Filter
                searchFilterRow
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 16)
                    .animation(.appSmooth.delay(0.07), value: contentAppeared)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .selectionDisabled()

                // Stats
                statsSection
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 12)
                    .animation(.appSmooth.delay(0.12), value: contentAppeared)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 14, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .selectionDisabled()

                // Content
                if cycleFiltered.isEmpty && !applications.isEmpty && appState.selectedCycleID != nil {
                    emptyCycleState
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .selectionDisabled()
                } else if applications.isEmpty {
                    emptyState
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .selectionDisabled()
                } else if filteredAndSorted.isEmpty {
                    noResultsState
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .selectionDisabled()
                } else {
                    if isEditMode {
                        HStack {
                            Spacer()
                            Button(selectedJobIDs.count == filteredAndSorted.count ? "Deselect All" : "Select All") {
                                if selectedJobIDs.count == filteredAndSorted.count {
                                    selectedJobIDs.removeAll()
                                } else {
                                    selectedJobIDs = Set(filteredAndSorted.map(\.id))
                                }
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 4, trailing: 24))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .selectionDisabled()
                    }

                    ForEach(filteredAndSorted) { job in
                        JobCardSwipeRow(job: job, isEditMode: isEditMode, onDelete: { scheduleDelete(job) })
                            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }

                Color.clear
                    .frame(height: 100)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .selectionDisabled()
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .environment(\.editMode, .constant(isEditMode ? .active : .inactive))

            // Pill FAB
            if !isEditMode {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            isPresentingNewApplication = true
                        } label: {
                            Label("New", systemImage: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 22)
                                .padding(.vertical, 15)
                                .background {
                                    Capsule()
                                        .fill(Color.accentColor)
                                        .shadow(color: Color.accentColor.opacity(0.30), radius: 14, y: 5)
                                }
                        }
                        .buttonStyle(FABStyle())
                        .scaleEffect(contentAppeared ? 1 : 0.75)
                        .opacity(contentAppeared ? 1 : 0)
                        .animation(.appSmooth.delay(0.18), value: contentAppeared)
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }

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
                        .foregroundStyle(Color.red)
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
                .transition(.move(edge: .bottom))
            }

            // Undo delete toast
            if pendingDeleteJob != nil {
                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(red: 0.93, green: 0.38, blue: 0.44))
                        Text("Application deleted")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DarkTheme.textPrimary)
                        Spacer()
                        Button("Undo") {
                            undoDelete()
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(DarkTheme.cardFill)
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(DarkTheme.cardBorder, lineWidth: 1))
                    )
                    .shadow(color: .black.opacity(0.14), radius: 12, y: 4)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 110)
                    .offset(y: max(0, toastDragY))
                    .opacity(max(0, 1 - toastDragY / 120))
                    .gesture(
                        DragGesture(minimumDistance: 10)
                            .onChanged { value in
                                if value.translation.height > 0 {
                                    toastDragY = value.translation.height
                                }
                            }
                            .onEnded { value in
                                if value.translation.height > 50 {
                                    undoTask?.cancel()
                                    undoTask = nil
                                    if let pending = pendingDeleteJob {
                                        modelContext.delete(pending)
                                    }
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
        .sheet(isPresented: $isPresentingNewApplication) {
            NavigationStack { JobDetailView(job: nil) }
        }
        .sheet(isPresented: $isShowingCyclePicker) {
            NavigationStack { CyclePickerSheet(isPresented: $isShowingCyclePicker) }
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
        .sheet(isPresented: $isShowingImportPreview) {
            if let rows = csvImportPreview {
                CSVImportPreviewSheet(initialRows: rows)
                    .environment(appState)
            }
        }
        .sheet(isPresented: $isShowingShareSheet) {
            if let url = csvFileURL { ShareSheet(activityItems: [url]) }
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
                escapeCSV(app.compensationAmount != nil ? (app.compensationCurrency?.rawValue ?? "") : ""),
                escapeCSV(app.resumeFileName ?? ""),
                escapeCSV(app.jobNotes ?? "")
            ].joined(separator: ",")
        }
        let csv = header + rows.joined(separator: "\n") + "\n"
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppNest_Export_\(dateFormatter.string(from: Date())).csv")
        do {
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
            csvFileURL = tempURL
            isShowingShareSheet = true
        } catch {
            print("CSV export failed: \(error)")
        }
    }

    private func escapeCSV(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
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
        HStack(spacing: 10) {
            // Glass search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DarkTheme.textSecondary)
                    .font(.system(size: 15, weight: .medium))

                TextField("Search applications…", text: $searchText)
                    .foregroundStyle(DarkTheme.textPrimary)
                    .tint(.accentColor)

                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(DarkTheme.textSecondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background {
                Capsule()
                    .fill(DarkTheme.cardFill)
                    .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
            }

            // Sort menu
            Menu {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button {
                        sortOption = option
                    } label: {
                        HStack {
                            Text(option.rawValue)
                            if sortOption == option { Image(systemName: "checkmark") }
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(sortOption == .dateNewest ? DarkTheme.textPrimary : Color.accentColor)
                    .frame(width: 44, height: 44)
                    .background {
                        Circle()
                            .fill(DarkTheme.cardFill)
                            .overlay(Circle().strokeBorder(
                                sortOption == .dateNewest ? Color.primary.opacity(0.08) : Color.accentColor.opacity(0.35),
                                lineWidth: sortOption == .dateNewest ? 1 : 1.5
                            ))
                    }
                    .overlay(alignment: .topTrailing) {
                        if sortOption != .dateNewest {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 7, height: 7)
                                .padding(9)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .animation(.appCrisp, value: sortOption)
            }

            // Import button
            Button {
                isImportingCSV = true
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DarkTheme.textPrimary)
                    .frame(width: 44, height: 44)
                    .background {
                        Circle()
                            .fill(DarkTheme.cardFill)
                            .overlay(Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Stats Section

    private let filterStatuses: [ApplicationStatus] = [.toApply, .applied, .interview, .offer, .rejected]

    private var statsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .center, spacing: 0) {
                // Selected group — tight spacing, visually clustered
                if !selectedStatuses.isEmpty {
                    HStack(spacing: 4) {
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
            .padding(.horizontal, 20)
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

    // MARK: - Empty States

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray.fill")
                .font(.system(size: 48))
                .foregroundStyle(DarkTheme.textSecondary.opacity(0.5))
            Text("No applications yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(DarkTheme.textPrimary)
            Text("Tap New to add your first application,\nor import from a CSV file.")
                .font(.subheadline)
                .foregroundStyle(DarkTheme.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                isImportingCSV = true
            } label: {
                Label("Import from CSV", systemImage: "square.and.arrow.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DarkTheme.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(Color.primary.opacity(0.07))
                            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.10), lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var noResultsState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(DarkTheme.textSecondary.opacity(0.5))
            Text("No results")
                .font(.title3.weight(.semibold))
                .foregroundStyle(DarkTheme.textPrimary)
            Text("Try a different search or filter.")
                .font(.subheadline)
                .foregroundStyle(DarkTheme.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                withAnimation(.appSmooth) {
                    searchText = ""
                    selectedStatuses = []
                }
            } label: {
                Text("Clear filters")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.accentColor.opacity(0.12)))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Cycle Selector

    @ViewBuilder
    private var cycleSelectorChip: some View {
        if cycles.isEmpty {
            Button {
                newCycleName = ""
                isAddingFirstCycle = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Start a job cycle")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.accentColor.opacity(0.11))
                        .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 1))
                )
            }
            .buttonStyle(.plain)
        } else {
            Button { isShowingCyclePicker = true } label: {
                HStack(spacing: 5) {
                    Image(systemName: appState.selectedCycleID != nil ? "tray.fill" : "tray.2.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Group {
                        if let id = appState.selectedCycleID,
                           let cycle = cycles.first(where: { $0.id == id }) {
                            Text(cycle.name)
                        } else {
                            Text("All Applications")
                        }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(appState.selectedCycleID != nil ? Color.accentColor : DarkTheme.textSecondary)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
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
    }

    private var emptyCycleState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray.fill")
                .font(.system(size: 48))
                .foregroundStyle(DarkTheme.textSecondary.opacity(0.5))
            Text("No applications in this cycle")
                .font(.title3.weight(.semibold))
                .foregroundStyle(DarkTheme.textPrimary)
            Text("Add applications or switch to a different cycle.")
                .font(.subheadline)
                .foregroundStyle(DarkTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func createFirstCycle() {
        let trimmed = newCycleName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let cycle = JobCycle(name: trimmed)
        modelContext.insert(cycle)
        appState.selectedCycleID = cycle.id
        AppHaptics.shared.success()
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

private struct FABStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? AppAnimations.pressScale : 1.0)
            .animation(.appFastOut, value: configuration.isPressed)
    }
}

// MARK: - Progressive Swipe Row

private struct JobCardSwipeRow: View {
    let job: JobApplication
    let isEditMode: Bool
    let onDelete: () -> Void

    @GestureState private var dragOffset: CGFloat = 0

    private let advanceThresholds: [CGFloat] = [65, 130, 200]
    private let deleteThreshold: CGFloat = 80

    private var pipeline: [ApplicationStatus] {
        let all: [ApplicationStatus] = [.toApply, .applied, .interview, .offer]
        guard let s = job.status, let idx = all.firstIndex(of: s) else { return [] }
        return Array(all.dropFirst(idx + 1))
    }

    private func stageFor(_ offset: CGFloat) -> Int {
        var stage = 0
        for (i, threshold) in advanceThresholds.enumerated() {
            guard i < pipeline.count else { break }
            if offset >= threshold { stage = i + 1 }
        }
        return stage
    }

    private var currentStage: Int { dragOffset > 0 ? stageFor(dragOffset) : 0 }

    var body: some View {
        ZStack(alignment: dragOffset < 0 ? .trailing : .leading) {
            swipeBackground
            ZStack {
                NavigationLink(destination: JobDetailView(job: job)) { EmptyView() }
                    .opacity(0)
                    .disabled(isEditMode)
                DarkJobCardView(job: job)
            }
            .offset(x: cardOffset(dragOffset))
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.85), value: dragOffset)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 12)
                .updating($dragOffset) { value, state, _ in
                    guard !isEditMode else { return }
                    let dx = value.translation.width
                    guard abs(dx) > abs(value.translation.height) else { return }
                    if dx > 0, pipeline.isEmpty { return }
                    state = dx
                }
                .onEnded { value in
                    guard !isEditMode else { return }
                    let dx = value.translation.width
                    if dx > 0 {
                        let stage = stageFor(dx)
                        guard stage > 0, stage - 1 < pipeline.count else { return }
                        withAnimation(.appSmooth) {
                            job.status = pipeline[stage - 1]
                        }
                        AppHaptics.shared.medium()
                    } else if dx < -deleteThreshold {
                        onDelete()
                    }
                }
        )
        .onChange(of: currentStage) { old, new in
            guard new > old, new > 0 else { return }
            AppHaptics.shared.light()
        }
    }

    @ViewBuilder
    private var swipeBackground: some View {
        if dragOffset > 5, !pipeline.isEmpty {
            let idx = max(0, min(currentStage - 1, pipeline.count - 1))
            let target = pipeline[idx]
            let style = DarkTheme.statusStyle(for: target)
            HStack(spacing: 8) {
                Image(systemName: style.iconName).font(.system(size: 16, weight: .bold))
                Text(target.rawValue).font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(style.tintColor)
            .padding(.leading, 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DarkTheme.cardRadius, style: .continuous)
                    .fill(style.fillColor)
                    .overlay(RoundedRectangle(cornerRadius: DarkTheme.cardRadius, style: .continuous)
                        .strokeBorder(style.borderColor, lineWidth: 1))
            )
            .opacity(min(1.0, dragOffset / advanceThresholds[0]))
            .animation(.appFastOut, value: target)
        } else if dragOffset < -5 {
            let c = Color(red: 0.93, green: 0.38, blue: 0.44)
            HStack(spacing: 8) {
                Image(systemName: "trash.fill").font(.system(size: 16, weight: .bold))
                Text("Delete").font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(c)
            .padding(.trailing, 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .background(
                RoundedRectangle(cornerRadius: DarkTheme.cardRadius, style: .continuous)
                    .fill(c.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: DarkTheme.cardRadius, style: .continuous)
                        .strokeBorder(c.opacity(0.28), lineWidth: 1))
            )
            .opacity(min(1.0, abs(dragOffset) / deleteThreshold))
        }
    }

    private func cardOffset(_ raw: CGFloat) -> CGFloat {
        if raw > 0 {
            let d = raw * 0.70
            return d > 165 ? 165 + (d - 165) * 0.18 : d
        } else if raw < 0 {
            let d = raw * 0.70
            return d < -110 ? -110 + (d + 110) * 0.18 : d
        }
        return 0
    }
}

#Preview {
    let container = try! ModelContainer(
        for: JobApplication.self, ResumeDocument.self, JobCycle.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let ctx = container.mainContext
    let samples: [(String, String, ApplicationType, ApplicationStatus, ApplicationSeason, Int)] = [
        ("Meta",      "Software Engineering Intern",  .internship, .applied,   .summer, 5),
        ("Uber",      "iOS Engineer Intern",          .internship, .interview, .summer, 8),
        ("JPMorgan",  "Software Engineer Intern",     .internship, .applied,   .summer, 10),
        ("Honeywell", "Embedded Systems Intern",      .internship, .rejected,  .summer, 12),
        ("Google",    "SWE Intern – iOS",             .internship, .offer,     .summer, 20),
        ("Amazon",    "SDE Intern",                   .internship, .applied,   .summer, 22),
        ("Netflix",   "Mobile Engineering Intern",    .internship, .toApply,   .summer, 24),
    ]
    for (company, position, type, status, season, days) in samples {
        ctx.insert(JobApplication(
            companyName: company, position: position,
            jobType: type, status: status, season: season,
            dateApplied: Date().addingTimeInterval(-86_400 * Double(days))
        ))
    }
    return NavigationStack { ApplicationView() }
        .environment(AppState())
        .modelContainer(container)
}
