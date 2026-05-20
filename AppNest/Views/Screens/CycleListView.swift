import SwiftUI
import SwiftData

struct CycleListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @Query(sort: \JobCycle.createdAt, order: .reverse) private var cycles: [JobCycle]

    var dismissSheet: (() -> Void)? = nil

    @State private var contentAppeared = false
    @State private var isAddingCycle = false
    @State private var newCycleName  = ""
    @State private var cycleToDelete: JobCycle?
    @State private var cycleToRename: JobCycle?
    @State private var renameText    = ""

    var body: some View {
        ZStack {
            AmbientBackground()

            if cycles.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(Array(cycles.enumerated()), id: \.element.id) { index, cycle in
                        CycleRow(
                            cycle: cycle,
                            isActive: appState.selectedCycleID == cycle.id,
                            onSelect: { selectCycle(cycle) }
                        )
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(y: contentAppeared ? 0 : 12)
                        .animation(.appSmooth.delay(Double(min(index, 8)) * 0.04), value: contentAppeared)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                cycleToDelete = cycle
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                cycleToRename = cycle
                                renameText = cycle.name
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            .tint(Color.accentColor)
                        }
                    }

                    Color.clear
                        .frame(height: 20)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Job Cycles")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(UIColor.systemBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear { contentAppeared = true }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newCycleName = ""
                    isAddingCycle = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
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
        .confirmationDialog(
            "Delete \"\(cycleToDelete?.name ?? "")\"?",
            isPresented: Binding(get: { cycleToDelete != nil }, set: { if !$0 { cycleToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete Cycle", role: .destructive) {
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
                .font(.system(size: 44))
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
                    .font(.system(size: 14, weight: .semibold))
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
        let cycle = JobCycle(name: trimmed)
        modelContext.insert(cycle)
        appState.selectedCycleID = cycle.id
        AppHaptics.shared.success()
        dismissSheet?()
    }

    private func renameCycle() {
        let trimmed = renameText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let cycle = cycleToRename else { return }
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

// MARK: - Cycle Row

struct CycleRow: View {
    let cycle: JobCycle
    let isActive: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(cycle.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isActive ? Color.accentColor : Theme.textPrimary)
                        .animation(.appCrisp, value: isActive)
                    Text("\(cycle.applications.count) application\(cycle.applications.count == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                    .opacity(isActive ? 1 : 0)
                    .scaleEffect(isActive ? 1 : 0.9)
                    .animation(.appBouncy, value: isActive)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .background {
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .fill(Theme.cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                            .strokeBorder(
                                isActive ? Color.accentColor.opacity(0.45) : Theme.cardBorder,
                                lineWidth: isActive ? 1.5 : 1
                            )
                    )
            }
        }
        .buttonStyle(PressScaleButtonStyle())
        .animation(.appCrisp, value: isActive)
    }
}

#Preview {
    NavigationStack { CycleListView() }
        .environment(AppState())
        .modelContainer(for: [JobApplication.self, ResumeDocument.self, JobCycle.self], inMemory: true)
}
