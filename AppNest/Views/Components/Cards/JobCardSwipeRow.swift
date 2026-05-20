import SwiftUI

struct JobCardSwipeRow: View {
    let job: JobApplication
    let isEditMode: Bool
    let onDelete: () -> Void

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
            isEditMode: isEditMode
        ) {
            ZStack {
                NavigationLink(destination: JobDetailView(job: job)) { EmptyView() }
                    .opacity(0)
                    .disabled(isEditMode)
                
                DarkJobCardView(job: job)
            }
        }
    }
}
