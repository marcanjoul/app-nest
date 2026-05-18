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

            ScrollView {
                VStack(spacing: 8) {
                    allApplicationsRow

                    if !cycles.isEmpty {
                        divider
                        ForEach(cycles) { cycle in
                            cycleRow(cycle)
                        }
                    }

                    divider
                    newCycleRow
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("Job Cycle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(UIColor.systemBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { isPresented = false }
                    .font(.system(size: 14, weight: .semibold))
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
        return pickerRow(
            icon: isActive ? "checkmark" : "tray.2.fill",
            iconColor: isActive ? Color.accentColor : DarkTheme.textSecondary,
            circleFill: isActive ? Color.accentColor : Color.primary.opacity(0.08),
            title: "All Applications",
            subtitle: "\(totalCount) app\(totalCount == 1 ? "" : "s")",
            isActive: isActive,
            chevron: false
        ) {
            appState.selectedCycleID = nil
            AppHaptics.shared.light()
            isPresented = false
        }
    }

    private func cycleRow(_ cycle: JobCycle) -> some View {
        let isActive = appState.selectedCycleID == cycle.id
        return pickerRow(
            icon: isActive ? "checkmark" : "tray.fill",
            iconColor: isActive ? Color.accentColor : DarkTheme.textSecondary,
            circleFill: isActive ? Color.accentColor : Color.primary.opacity(0.08),
            title: cycle.name,
            subtitle: "\(cycle.applications.count) app\(cycle.applications.count == 1 ? "" : "s")",
            isActive: isActive,
            chevron: false
        ) {
            appState.selectedCycleID = cycle.id
            AppHaptics.shared.light()
            isPresented = false
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                cycleToEdit = cycle
                isConfirmingDelete = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
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
        pickerRow(
            icon: "plus",
            iconColor: Color.accentColor,
            circleFill: Color.accentColor.opacity(0.12),
            title: "New Cycle",
            subtitle: nil,
            titleColor: Color.accentColor,
            isActive: false,
            chevron: false
        ) {
            newCycleName = ""
            isAddingCycle = true
        }
    }

    // MARK: - Row builder

    @ViewBuilder
    private func pickerRow(
        icon: String,
        iconColor: Color,
        circleFill: Color,
        title: String,
        subtitle: String?,
        titleColor: Color = DarkTheme.textPrimary,
        isActive: Bool,
        chevron: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            rowContent(
                icon: icon,
                iconColor: iconColor,
                circleFill: circleFill,
                title: title,
                subtitle: subtitle,
                titleColor: titleColor,
                isActive: isActive,
                chevron: chevron
            )
        }
        .buttonStyle(.plain)
    }

    private func rowContent(
        icon: String,
        iconColor: Color,
        circleFill: Color,
        title: String,
        subtitle: String?,
        titleColor: Color,
        isActive: Bool,
        chevron: Bool
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(circleFill)
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(titleColor)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DarkTheme.textSecondary)
                }
            }

            Spacer()

            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DarkTheme.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DarkTheme.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            isActive ? Color.accentColor.opacity(0.4) : DarkTheme.cardBorder,
                            lineWidth: isActive ? 1.5 : 1
                        )
                )
        }
        .animation(.appCrisp, value: isActive)
    }

    private var divider: some View {
        Divider().opacity(0.3).padding(.horizontal, 4)
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
