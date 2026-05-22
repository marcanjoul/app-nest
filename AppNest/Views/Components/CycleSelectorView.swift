import SwiftUI
import SwiftData

/// Sheet that lets the user switch between job cycles or create a new one.
/// Embed inside a NavigationStack when presenting as a sheet.
struct CyclePickerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Query(sort: \JobCycle.createdAt, order: .reverse) private var cycles: [JobCycle]
    @Query private var applications: [JobApplication]

    @Binding var isPresented: Bool

    @State private var isAddingCycle = false
    @State private var isRenamingCycle = false
    @State private var isConfirmingDelete = false
    @State private var cycleToEdit: JobCycle?
    @State private var newCycleName  = ""

    var body: some View {
        ZStack {
            AmbientBackground()

            List {
                // Section 1: Default View
                Section {
                    allApplicationsRow
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                // Section 2: Custom Cycles
                if !cycles.isEmpty {
                    Section {
                        ForEach(cycles) { cycle in
                            cycleRow(cycle)
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                // Section 3: Add New
                Section {
                    newCycleRow
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .navigationTitle("Job Cycle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(UIColor.systemBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { isPresented = false }
                    .appFont(14, weight: .semibold)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .alert("New Cycle", isPresented: $isAddingCycle) {
            TextField("e.g. Summer 2026", text: $newCycleName)
                .autocorrectionDisabled()
            Button("Create") { createCycle() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Name this job search cycle.")
        }
        .alert("Rename Cycle", isPresented: $isRenamingCycle) {
            TextField("New Name", text: $newCycleName)
                .autocorrectionDisabled()
            Button("Rename") { renameCycle() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a new name for this cycle.")
        }
        .confirmationDialog(
            "Delete \"\(cycleToEdit?.name ?? "")\"?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Cycle", role: .destructive) { deleteCycle() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Any applications in this cycle will be moved to \"All Applications\".")
        }
    }

    // MARK: - Rows

    private var allApplicationsRow: some View {
        let isActive = appState.selectedCycleID == nil
        return Button {
            appState.selectedCycleID = nil
            AppHaptics.shared.light()
            isPresented = false
        } label: {
            pickerRowContent(
                icon: isActive ? "checkmark" : "tray.2.fill",
                iconColor: isActive ? Color.accentColor : Theme.textSecondary,
                circleFill: isActive ? Color.accentColor : Color.primary.opacity(0.08),
                title: "All Applications",
                subtitle: "\(totalCount) app\(totalCount == 1 ? "" : "s")",
                isActive: isActive
            )
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }

    private func cycleRow(_ cycle: JobCycle) -> some View {
        let isActive = appState.selectedCycleID == cycle.id
        return Button {
            appState.selectedCycleID = cycle.id
            AppHaptics.shared.light()
            isPresented = false
        } label: {
            pickerRowContent(
                icon: isActive ? "checkmark" : "tray.fill",
                iconColor: isActive ? Color.accentColor : Theme.textSecondary,
                circleFill: isActive ? Color.accentColor : Color.primary.opacity(0.08),
                title: cycle.name,
                subtitle: "\(cycle.applications.count) app\(cycle.applications.count == 1 ? "" : "s")",
                isActive: isActive
            )
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                cycleToEdit = cycle
                isConfirmingDelete = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                cycleToEdit = cycle
                newCycleName = cycle.name
                isRenamingCycle = true
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            .tint(.orange)
        }
    }

    private var newCycleRow: some View {
        Button {
            newCycleName = ""
            isAddingCycle = true
        } label: {
            pickerRowContent(
                icon: "plus",
                iconColor: Color.accentColor,
                circleFill: Color.accentColor.opacity(0.12),
                title: "New Cycle",
                subtitle: nil,
                titleColor: Color.accentColor,
                isActive: false
            )
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }

    // MARK: - Row Content Builder

    private func pickerRowContent(
        icon: String,
        iconColor: Color,
        circleFill: Color,
        title: String,
        subtitle: String?,
        titleColor: Color = Theme.textPrimary,
        isActive: Bool
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(circleFill)
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .appFont(13, weight: .bold)
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .appFont(15, weight: .semibold)
                    .foregroundStyle(titleColor)
                if let subtitle {
                    Text(subtitle)
                        .appFont(12, weight: .medium)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            isActive ? Color.accentColor.opacity(0.4) : Theme.cardBorder,
                            lineWidth: isActive ? 1.5 : 1
                        )
                )
        }
    }

    // MARK: - Helpers

    private var totalCount: Int { applications.count }

    private func createCycle() {
        let trimmed = newCycleName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let cycle = JobCycle(name: trimmed)
        modelContext.insert(cycle)
        try? modelContext.save()
        appState.selectedCycleID = cycle.id
        AppHaptics.shared.success()
        isPresented = false
    }

    private func renameCycle() {
        guard let cycle = cycleToEdit else { return }
        let trimmed = newCycleName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        cycle.name = trimmed
        try? modelContext.save()
        AppHaptics.shared.success()
        cycleToEdit = nil
    }

    private func deleteCycle() {
        guard let cycle = cycleToEdit else { return }
        if appState.selectedCycleID == cycle.id {
            appState.selectedCycleID = nil
        }
        modelContext.delete(cycle)
        try? modelContext.save()
        AppHaptics.shared.medium()
        cycleToEdit = nil
    }
}
