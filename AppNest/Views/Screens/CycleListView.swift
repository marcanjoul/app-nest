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

    var body: some View {
        ZStack {
            AmbientBackground()

            if cycles.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(cycles) { cycle in
                            CycleRow(
                                cycle: cycle,
                                isActive: appState.selectedCycleID == cycle.id,
                                onSelect: { selectCycle(cycle) },
                                onDelete: { deleteCycle(cycle) }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("All Cycles")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(UIColor.systemBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
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
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray.2.fill")
                .font(.system(size: 44))
                .foregroundStyle(DarkTheme.textSecondary.opacity(0.45))
            Text("No cycles yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(DarkTheme.textPrimary)
            Text("Create a cycle to group your applications by season or search.")
                .font(.subheadline)
                .foregroundStyle(DarkTheme.textSecondary)
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
                    .background(Capsule().fill(Color.accentColor)
                        .shadow(color: Color.accentColor.opacity(0.28), radius: 8, y: 3))
            }
            .buttonStyle(.plain)
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
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onSelect) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(isActive ? Color.accentColor : Color.primary.opacity(0.08))
                            .frame(width: 34, height: 34)
                        Image(systemName: isActive ? "checkmark" : "tray.fill")
                            .font(.system(size: isActive ? 12 : 11, weight: .bold))
                            .foregroundStyle(isActive ? .white : DarkTheme.textSecondary)
                    }
                    .animation(.appCrisp, value: isActive)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(cycle.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DarkTheme.textPrimary)
                        Text("\(cycle.applications.count) app\(cycle.applications.count == 1 ? "" : "s")")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DarkTheme.textSecondary)
                    }

                    Spacer()
                }
            }
            .buttonStyle(.plain)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.red)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.red.opacity(0.10)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(DarkTheme.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            isActive ? Color.accentColor.opacity(0.45) : DarkTheme.cardBorder,
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
