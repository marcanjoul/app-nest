import SwiftUI

@MainActor
struct JobCardSwipeRow: View {
    let job: JobApplication
    let isEditMode: Bool
    let isSelected: Bool
    let onDelete: () -> Void
    let onToggleSelection: () -> Void

    @Environment(AppState.self) private var appState
    @State private var swipeJustFired = false

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
        HStack(spacing: 0) {
            Button { onToggleSelection() } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .appFont(22, weight: .medium)
                    .foregroundStyle(isSelected ? Color.accentColor : Theme.textSecondary.opacity(0.5))
                    .contentTransition(.symbolEffect(.replace.downUp))
                    .animation(.appCrisp, value: isSelected)
            }
            .buttonStyle(.plain)
            .frame(width: 22, height: 22)
            .padding(.trailing, isEditMode ? 10 : 0)
            .frame(width: isEditMode ? 32 : 0)
            .clipped()
            .scaleEffect(isEditMode ? 1 : 0.5)
            .opacity(isEditMode ? 1 : 0)
            .allowsHitTesting(isEditMode)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isEditMode)

            SwipeActionRow(
                leadingActions: [],
                trailingActions: isEditMode ? [] : trailingActions,
                isEditMode: isEditMode,
                cornerRadius: 16,
                onActionTriggered: {
                    swipeJustFired = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        swipeJustFired = false
                    }
                }
            ) {
                Button {
                    if isEditMode {
                        onToggleSelection()
                    } else if !swipeJustFired {
                        AppHaptics.shared.light()
                        appState.selectedJob = job
                    }
                } label: {
                    DarkJobCardView(job: job)
                }
                .buttonStyle(CardPressButtonStyle())
            }
        }
    }
}
