import SwiftUI

@MainActor
struct JobCardSwipeRow: View {
    let job: JobApplication
    let isEditMode: Bool
    let onDelete: () -> Void
    
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
        SwipeActionRow(
            leadingActions: pipeline,
            trailingActions: trailingActions,
            isEditMode: isEditMode,
            cornerRadius: 16
        ) {
            DarkJobCardView(job: job)
                .contentShape(Rectangle())
                .onTapGesture {
                    if !isEditMode {
                        AppHaptics.shared.light()
                        appState.navigationPath.append(job)
                    }
                }
        }
    }
}
