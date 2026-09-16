import SwiftUI

@MainActor
struct JobCardSwipeRow: View {
    let job: JobApplication
    let isEditMode: Bool
    let isSelected: Bool
    let onToggleSelection: () -> Void

    @Environment(AppState.self) private var appState

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

            // ponytail: delete lives on List's own .swipeActions at the call site. The custom
            // DragGesture this replaced fought the scroll gesture and needed a 0.4s window that
            // swallowed taps after any swipe.
            Button {
                if isEditMode {
                    onToggleSelection()
                } else {
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
