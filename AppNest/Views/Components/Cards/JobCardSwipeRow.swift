import SwiftUI

@MainActor
struct JobCardSwipeRow: View {
    let job: JobApplication
    let isEditMode: Bool
    let isSelected: Bool
    let onDelete: () -> Void
    let onToggleSelection: () -> Void

    @Environment(AppState.self) private var appState

    @State private var isSwiping = false

    private var pipeline: [SwipeAction] {
        let all: [ApplicationStatus] = [.toApply, .applied, .interview, .offer]
        guard let s = job.status, let idx = all.firstIndex(of: s) else { return [] }
        let remaining = Array(all.dropFirst(idx + 1))
        
        return remaining.map { status in
            let style = Theme.statusStyle(for: status)
            return SwipeAction(
                title: status.rawValue,
                icon: style.iconName,
                color: style.tintColor
            ) {
                withAnimation(.appSmooth) {
                    job.status = status
                }
            }
        }
    }

    private var trailingActions: [SwipeAction] {
        [
            SwipeAction(
                title: "Delete",
                icon: "trash.fill",
                color: Theme.destructive,
                action: onDelete
            )
        ]
    }

    var body: some View {
        HStack(spacing: 10) {
            // Fixed-size container — layout never changes, only opacity+scale animate.
            // Avoids per-card layout recalculation when edit mode toggles.
            Button { onToggleSelection() } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : Theme.textSecondary.opacity(0.5))
                    .contentTransition(.symbolEffect(.replace.downUp))
                    .animation(.appCrisp, value: isSelected)
            }
            .buttonStyle(.plain)
            .frame(width: 22, height: 22)
            .scaleEffect(isEditMode ? 1 : 0.5)
            .opacity(isEditMode ? 1 : 0)
            .allowsHitTesting(isEditMode)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isEditMode)

            SwipeActionRow(
                leadingActions: isEditMode ? [] : pipeline,
                trailingActions: isEditMode ? [] : trailingActions,
                isEditMode: isEditMode,
                cornerRadius: 16
            ) {
                DarkJobCardView(job: job)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isEditMode {
                            onToggleSelection()
                        } else {
                            AppHaptics.shared.light()
                            appState.navigationPath.append(job)
                        }
                    }
            }
        }
    }
}
