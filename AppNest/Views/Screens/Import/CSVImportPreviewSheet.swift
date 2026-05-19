import SwiftUI
import SwiftData

struct CSVImportPreviewSheet: View {
    let initialRows: [CSVImportRow]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState
    @Query(sort: \JobCycle.createdAt, order: .reverse) private var cycles: [JobCycle]

    @State private var editingRow: CSVImportRow?
    @State private var localRows: [CSVImportRow] = []
    @State private var selectedRows = Set<UUID>()
    @State private var isAddingNewCycle = false
    @State private var newCycleName = ""
    @State private var isConfirmingDelete = false
    @State private var appearedRows = Set<UUID>()
    @State private var activeFilter: ImportPreviewFilter = .all

    private var readyRows: [CSVImportRow] { localRows.filter { $0.isComplete } }
    private var attentionRows: [CSVImportRow] { localRows.filter { !$0.isComplete } }

    private var displayedRows: [CSVImportRow] {
        switch activeFilter {
        case .all: return localRows
        case .ready: return readyRows
        case .attention: return attentionRows
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                AmbientBackground()
                
                VStack(spacing: 0) {
                    if !localRows.isEmpty {
                        filterAndSelectionInfoRow
                            .padding(.vertical, 16)
                    }

                    if localRows.isEmpty {
                        emptyRowsView
                    } else if displayedRows.isEmpty {
                        noFilterResultsView
                    } else {
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(Array(displayedRows.enumerated()), id: \.element.id) { index, row in
                                    if let localIndex = localRows.firstIndex(where: { $0.id == row.id }) {
                                        previewRow(row: $localRows[localIndex], index: index)
                                            .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 100)
                        }
                    }
                }

                if !localRows.isEmpty {
                    importButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                }
            }
            .navigationTitle("Import Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(UIColor.systemBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if !localRows.isEmpty {
                        Button(selectedRows.count == displayedRows.count && !displayedRows.isEmpty
                            ? "Deselect All" : "Select All") {
                            withAnimation(.appCrisp) {
                                if selectedRows.count == displayedRows.count {
                                    selectedRows.removeAll()
                                } else {
                                    selectedRows = Set(displayedRows.map(\.id))
                                }
                            }
                            AppHaptics.shared.light()
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                    }
                }
                
                ToolbarItemGroup(placement: .bottomBar) {
                    if !selectedRows.isEmpty {
                        Button(role: .destructive) { isConfirmingDelete = true } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .foregroundStyle(Color(red: 0.93, green: 0.33, blue: 0.40))
                        
                        Spacer()
                        
                        Menu {
                            Section("Cycle") {
                                Button { isAddingNewCycle = true } label: {
                                    Label("New Cycle...", systemImage: "plus")
                                }
                                ForEach(cycles) { cycle in
                                    Button(cycle.name) {
                                        moveToCycle(cycle)
                                    }
                                }
                            }
                        } label: {
                            Label("Move to Cycle", systemImage: "folder")
                        }
                    }
                }
            }
            .alert("New Cycle", isPresented: $isAddingNewCycle) {
                TextField("Cycle Name", text: $newCycleName)
                Button("Create & Move") {
                    createNewCycleAndMove()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter a name for the new job search cycle.")
            }
            .confirmationDialog(
                "Delete \(selectedRows.count) Row\(selectedRows.count == 1 ? "" : "s")?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { deleteSelected() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The selected row\(selectedRows.count == 1 ? "" : "s") will be removed from this import preview.")
            }
            .onAppear {
                if localRows.isEmpty { localRows = initialRows }
            }
            .sheet(item: $editingRow) { row in
                EditImportRowView(row: row) { updated in
                    if let index = localRows.firstIndex(where: { $0.id == updated.id }) {
                        localRows[index] = updated
                        checkFilterConsistency()
                    }
                }
            }
        }
    }

    private var filterAndSelectionInfoRow: some View {
        VStack(spacing: 12) {
            HStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip(for: .all, count: localRows.count, icon: "tray.2.fill", color: .accentColor)
                        filterChip(for: .ready, count: readyRows.count, icon: "checkmark.circle.fill", color: Color(red: 0.30, green: 0.69, blue: 0.49))
                        filterChip(for: .attention, count: attentionRows.count, icon: "exclamationmark.triangle.fill", color: Color(red: 0.96, green: 0.65, blue: 0.14))
                    }
                    .padding(.horizontal, 20)
                }
            }
            
            if !selectedRows.isEmpty {
                HStack {
                    Text("\(selectedRows.count) selected")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    private func filterChip(for filter: ImportPreviewFilter, count: Int, icon: String, color: Color) -> some View {
        let isSelected = activeFilter == filter
        Button {
            withAnimation(.appCrisp) { activeFilter = filter }
            AppHaptics.shared.light()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isSelected ? .white : color)
                
                Text("\(count)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? .white : Theme.textPrimary)
                
                Text(filter.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? .white.opacity(0.9) : Theme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(isSelected ? AnyShapeStyle(color) : AnyShapeStyle(Theme.cardFill))
                    .overlay {
                        Capsule().strokeBorder(isSelected ? Color.clear : Color.primary.opacity(0.12), lineWidth: 1)
                    }
            }
            .shadow(color: isSelected ? color.opacity(0.25) : .clear, radius: 8, y: 3)
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private var emptyRowsView: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(Theme.textSecondary.opacity(0.4))
            Text("No rows found")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("The file didn't contain any readable data rows.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noFilterResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: activeFilter == .ready ? "checkmark.circle" : "sparkles")
                .font(.system(size: 32))
                .foregroundStyle(Theme.textSecondary.opacity(0.4))
            Text(activeFilter == .ready ? "Nothing to import" : "All rows are ready")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            Button("Show All") {
                withAnimation(.appSmooth) { activeFilter = .all }
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Color.accentColor)
        }
        .frame(maxHeight: .infinity)
    }

    private var importButton: some View {
        Button {
            finalizeImport()
        } label: {
            Text("Import")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(readyRows.isEmpty ? Color.gray.opacity(0.3) : Color.accentColor)
                        .shadow(color: readyRows.isEmpty ? .clear : Color.accentColor.opacity(0.3), radius: 10, y: 4)
                }
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(readyRows.isEmpty)
    }

    @ViewBuilder
    private func previewRow(row: Binding<CSVImportRow>, index: Int) -> some View {
        let r = row.wrappedValue
        let isSelected = selectedRows.contains(r.id)
        
        HStack(spacing: 14) {
            // Selection toggle
            Button {
                withAnimation(.appCrisp) {
                    if isSelected { selectedRows.remove(r.id) }
                    else { selectedRows.insert(r.id) }
                }
                AppHaptics.shared.light()
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Color.accentColor : Theme.textTertiary)
            }
            .buttonStyle(.plain)

            // Logo Preview
            ZStack {
                if let data = r.logoData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.white.opacity(0.05))
                } else {
                    let avatarColors = Theme.avatarColor(for: r.companyName)
                    let initial = String(r.companyName.prefix(1)).uppercased()
                    Circle()
                        .fill(avatarColors.background)
                    Text(initial.isEmpty ? "?" : initial)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(avatarColors.foreground)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            
            // Content
            Button {
                editingRow = r
            } label: {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(r.position.isEmpty ? "Missing Position" : r.position)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(r.position.isEmpty ? .orange : Theme.textPrimary)
                            .lineLimit(1)
                        Text(r.companyName.isEmpty ? "Missing Company" : r.companyName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(r.companyName.isEmpty ? .orange : Theme.textSecondary)
                            .lineLimit(1)
                        
                        HStack(spacing: 5) {
                            if let status = r.status {
                                badge(status.rawValue, color: status.color)
                            }
                            if let type = r.jobType {
                                badge(type.rawValue, color: type.color)
                            }
                            if let cycleID = r.cycleID, let cycle = cycles.first(where: { $0.id == cycleID }) {
                                badge(cycle.name, color: Color.accentColor)
                            }
                        }
                        .padding(.top, 1)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary.opacity(0.6))
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.cardFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(isSelected ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
                }
        }
        .opacity(appearedRows.contains(r.id) ? 1 : 0)
        .offset(y: appearedRows.contains(r.id) ? 0 : 10)
        .onAppear {
            let delay = Double(min(index, 8)) * 0.04
            withAnimation(.appSmooth.delay(delay)) {
                _ = appearedRows.insert(r.id)
            }
        }
        .task(id: r.companyName) {
            guard r.logoData == nil else { return }
            let trimmed = r.companyName.trimmingCharacters(in: .whitespaces)
            guard trimmed.count >= 2 else { return }
            if let data = await LogoFetcher.fetchLogoData(for: trimmed) {
                withAnimation(.appSmooth) {
                    row.logoData.wrappedValue = data
                }
            }
        }
    }

    private func badge(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.12)))
    }

    private func count(for filter: ImportPreviewFilter) -> Int {
        switch filter {
        case .all: return localRows.count
        case .ready: return readyRows.count
        case .attention: return attentionRows.count
        }
    }

    private func checkFilterConsistency() {
        if displayedRows.isEmpty && !localRows.isEmpty {
            withAnimation(.appSmooth) { activeFilter = .all }
        }
    }

    private func deleteSelected() {
        withAnimation(.appSmooth) {
            localRows.removeAll { selectedRows.contains($0.id) }
            selectedRows.removeAll()
            checkFilterConsistency()
        }
        AppHaptics.shared.medium()
    }

    private func moveToCycle(_ cycle: JobCycle) {
        for i in localRows.indices {
            if selectedRows.contains(localRows[i].id) {
                localRows[i].cycleID = cycle.id
            }
        }
        selectedRows.removeAll()
        AppHaptics.shared.success()
    }

    private func createNewCycleAndMove() {
        let name = newCycleName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let cycle = JobCycle(name: name)
        modelContext.insert(cycle)
        moveToCycle(cycle)
        newCycleName = ""
    }

    private func finalizeImport() {
        let defaultCycle = cycles.first(where: { $0.id == appState.selectedCycleID })
        
        for row in readyRows {
            let rowCycle = row.cycleID.flatMap { id in cycles.first(where: { $0.id == id }) }
            let app = JobApplication(
                companyName: row.companyName,
                companyLogoImageData: row.logoData,
                position: row.position,
                jobType: row.jobType,
                status: row.status ?? .applied,
                season: row.season,
                cycle: rowCycle ?? defaultCycle,
                dateApplied: row.dateApplied,
                jobNotes: row.notes,
                compensationKind: row.compensationKind,
                compensationAmount: row.compensationAmount,
                compensationCurrency: row.compensationCurrency,
                salaryPeriod: row.salaryPeriod
            )
            modelContext.insert(app)
        }
        
        try? modelContext.save()
        AppHaptics.shared.success()
        dismiss()
    }
}
