import SwiftUI
import SwiftData

struct CycleListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @Query(sort: \JobCycle.createdAt, order: .reverse) private var cycles: [JobCycle]

    var dismissSheet: (() -> Void)? = nil

    @State private var isAddingCycle = false
    @State private var newCycleName  = ""
    @State private var cycleToDelete: JobCycle?
    @State private var cycleToRename: JobCycle?
    @State private var renameText    = ""
    @State private var isDuplicateNameAlertShowing = false
    @State private var duplicateName = ""

    var body: some View {
        ZStack {
            AmbientBackground()

            if cycles.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(Array(cycles.enumerated()), id: \.element.id) { index, cycle in
                        CycleSwipeRow(
                            cycle: cycle,
                            isActive: appState.selectedCycleID == cycle.id,
                            onSelect: { selectCycle(cycle) },
                            onRename: {
                                cycleToRename = cycle
                                renameText = cycle.name
                            },
                            onDelete: { cycleToDelete = cycle }
                        )
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .opacity(appState.cycleListHasAppeared ? 1 : 0)
                        .offset(y: appState.cycleListHasAppeared ? 0 : 12)
                        .animation(.appSmooth.delay(Double(min(index, 8)) * 0.04), value: appState.cycleListHasAppeared)
                    }

                    Color.clear
                        .frame(height: 90)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Job Cycles")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear { appState.cycleListHasAppeared = true }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newCycleName = ""
                    isAddingCycle = true
                } label: {
                    Image(systemName: "plus")
                        .appFont(14, weight: .bold)
                        .foregroundStyle(Color.accentColor)
                }
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
        .alert("Rename Cycle", isPresented: Binding(
            get: { cycleToRename != nil },
            set: { if !$0 { cycleToRename = nil } }
        )) {
            TextField("Cycle name", text: $renameText)
                .autocorrectionDisabled()
            Button("Save") { renameCycle() }
            Button("Cancel", role: .cancel) { cycleToRename = nil }
        } message: {
            Text("Enter a new name for \"\(cycleToRename?.name ?? "")\".")
        }
        .alert("Name Already Taken", isPresented: $isDuplicateNameAlertShowing) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("A cycle named \"\(duplicateName)\" already exists. Please choose a different name.")
        }
        .confirmationDialog(
            "Delete \"\(cycleToDelete?.name ?? "")\"?",
            isPresented: Binding(get: { cycleToDelete != nil }, set: { if !$0 { cycleToDelete = nil } }),
            titleVisibility: .visible
        ) {
            HoldToConfirmButton(title: "Delete Cycle", icon: "trash.fill", color: Theme.destructive) {
                if let cycle = cycleToDelete { deleteCycle(cycle) }
                cycleToDelete = nil
            }
            Button("Cancel", role: .cancel) { cycleToDelete = nil }
        } message: {
            Text("Applications in this cycle will be moved to \"All Applications\".")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray.2.fill")
                .appFont(44)
                .foregroundStyle(Theme.textSecondary.opacity(0.45))
            Text("No cycles yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("Create a cycle to group your applications by season or search.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Button {
                newCycleName = ""
                isAddingCycle = true
            } label: {
                Label("New Cycle", systemImage: "plus")
                    .appFont(14, weight: .semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(Color.accentColor))
            }
            .buttonStyle(PressScaleButtonStyle())
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Actions

    private func selectCycle(_ cycle: JobCycle) {
        appState.selectedCycleID = cycle.id
        AppHaptics.shared.light()
        dismissSheet?()
    }

    private func createCycle() {
        let trimmed = newCycleName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard !cycles.contains(where: { $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) else {
            duplicateName = trimmed
            isDuplicateNameAlertShowing = true
            return
        }
        let cycle = JobCycle(name: trimmed)
        modelContext.insert(cycle)
        appState.selectedCycleID = cycle.id
        AppHaptics.shared.success()
        dismissSheet?()
    }

    private func renameCycle() {
        let trimmed = renameText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let cycle = cycleToRename else { return }
        guard !cycles.contains(where: { $0.id != cycle.id && $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) else {
            duplicateName = trimmed
            isDuplicateNameAlertShowing = true
            return
        }
        cycle.name = trimmed
        try? modelContext.save()
        AppHaptics.shared.success()
        cycleToRename = nil
    }

    private func deleteCycle(_ cycle: JobCycle) {
        if appState.selectedCycleID == cycle.id {
            appState.selectedCycleID = nil
        }
        modelContext.delete(cycle)
        AppHaptics.shared.medium()
    }
}

// MARK: - Cycle Swipe Row

struct CycleSwipeRow: View {
    let cycle: JobCycle
    let isActive: Bool
    let onSelect: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    @State private var swipeJustFired = false

    var body: some View {
        SwipeActionRow(
            leadingActions: [],
            trailingActions: [
                SwipeAction(title: "Rename", icon: "pencil", color: Color.accentColor, action: onRename),
                SwipeAction(title: "Delete", icon: "trash.fill", color: Theme.destructive, action: onDelete)
            ],
            isEditMode: false,
            cornerRadius: 16,
            onActionTriggered: {
                swipeJustFired = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { swipeJustFired = false }
            }
        ) {
            Button {
                guard !swipeJustFired else { return }
                AppHaptics.shared.light()
                onSelect()
            } label: {
                CycleRow(cycle: cycle, isActive: isActive)
            }
            .buttonStyle(CardPressButtonStyle())
        }
    }
}

// MARK: - Cycle Row

struct CycleRow: View {
    let cycle: JobCycle
    let isActive: Bool

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(cycle.name)
                    .appFont(16, weight: .semibold)
                    .foregroundStyle(isActive ? Color.accentColor : Theme.textPrimary)
                    .animation(.appCrisp, value: isActive)
                Text("\(cycle.applications.count) application\(cycle.applications.count == 1 ? "" : "s")")
                    .appFont(12, weight: .medium)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: "checkmark")
                .appFont(12, weight: .bold)
                .foregroundStyle(Color.accentColor)
                .opacity(isActive ? 1 : 0)
                .scaleEffect(isActive ? 1 : 0.9)
                .animation(.appBouncy, value: isActive)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            isActive ? Color.accentColor.opacity(0.45) : Theme.cardBorder,
                            lineWidth: isActive ? 1.5 : 1
                        )
                )
        }
        .animation(.appCrisp, value: isActive)
    }
}

#Preview {
    NavigationStack { CycleListView() }
        .environment(AppState())
        .modelContainer(for: [JobApplication.self, ResumeDocument.self, JobCycle.self], inMemory: true)
}
