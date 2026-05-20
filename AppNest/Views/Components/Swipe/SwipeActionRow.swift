import SwiftUI

struct SwipeAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
}

struct SwipeActionRow<Content: View>: View {
    let leadingActions: [SwipeAction]
    let trailingActions: [SwipeAction]
    let isEditMode: Bool
    @ViewBuilder let content: () -> Content

    @GestureState private var dragOffset: CGFloat = 0
    @State private var isSwiping = false
    
    // Thresholds
    private let actionThreshold: CGFloat = 70
    private let fullSwipeThreshold: CGFloat = 180

    var body: some View {
        ZStack {
            // Background actions
            swipeBackground
            
            // Foreground content
            content()
                .scaleEffect(isSwiping ? 0.98 : 1.0)
                .offset(x: cardOffset(dragOffset))
                .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.85), value: dragOffset)
                .animation(.appCrisp, value: isSwiping)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 28)
                .onChanged { value in
                    guard !isEditMode else { return }
                    let dx = value.translation.width
                    let dy = value.translation.height
                    guard abs(dx) > abs(dy) * 2.0 else { return }
                    isSwiping = true
                }
                .updating($dragOffset) { value, state, _ in
                    guard !isEditMode else { return }
                    let dx = value.translation.width
                    let dy = value.translation.height
                    guard abs(dx) > abs(dy) * 2.0 else { return }
                    
                    if dx > 0 && leadingActions.isEmpty { return }
                    if dx < 0 && trailingActions.isEmpty { return }
                    
                    state = dx
                }
                .onEnded { value in
                    isSwiping = false
                    guard !isEditMode else { return }
                    let dx = value.translation.width
                    
                    if dx > actionThreshold && !leadingActions.isEmpty {
                        triggerAction(on: leadingActions, offset: dx)
                    } else if dx < -actionThreshold && !trailingActions.isEmpty {
                        triggerAction(on: trailingActions, offset: dx)
                    }
                }
        )
    }

    @ViewBuilder
    private var swipeBackground: some View {
        ZStack {
            if dragOffset > 5 && !leadingActions.isEmpty {
                actionLabel(for: leadingActions, offset: dragOffset, alignment: .leading)
            } else if dragOffset < -5 && !trailingActions.isEmpty {
                actionLabel(for: trailingActions, offset: dragOffset, alignment: .trailing)
            }
        }
    }

    @ViewBuilder
    private func actionLabel(for actions: [SwipeAction], offset: CGFloat, alignment: HorizontalAlignment) -> some View {
        let absOffset = abs(offset)
        let isLeading = alignment == .leading
        
        // Multi-stage logic for leading/trailing
        // For now, we follow the "One active action" logic from JobCardSwipeRow
        // But we adapt it to pick from the list based on how far we pull
        let index = min(Int(absOffset / 70), actions.count - 1)
        let action = actions[index]
        
        HStack(spacing: 10) {
            if isLeading { Spacer().frame(width: 14) }
            
            Image(systemName: action.icon).font(.system(size: 18, weight: .bold))
            Text(action.title).font(.system(size: 14, weight: .bold))
            
            if !isLeading { Spacer().frame(width: 14) }
        }
        .foregroundStyle(action.color)
        .padding(isLeading ? .leading : .trailing, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isLeading ? .leading : .trailing)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(action.color.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                        .strokeBorder(action.color.opacity(0.25), lineWidth: 1.5)
                )
        )
        .opacity(min(1.0, absOffset / 40))
        .animation(.appSmooth, value: action.id)
        .onChange(of: index) { old, new in
            if new != old && new >= 0 { AppHaptics.shared.light() }
        }
    }

    private func triggerAction(on actions: [SwipeAction], offset: CGFloat) {
        let absOffset = abs(offset)
        let index = min(Int(absOffset / 70), actions.count - 1)
        actions[index].action()
        AppHaptics.shared.medium()
    }

    private func cardOffset(_ raw: CGFloat) -> CGFloat {
        let maxPull: CGFloat = 160
        let resistance: CGFloat = 0.65
        
        if raw > 0 {
            return maxPull * atan(raw * resistance / maxPull)
        } else if raw < 0 {
            let absRaw = abs(raw)
            let maxNegPull: CGFloat = 120
            return -maxNegPull * atan(absRaw * resistance / maxNegPull)
        }
        return 0
    }
}
