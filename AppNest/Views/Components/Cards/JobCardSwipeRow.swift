import SwiftUI

struct JobCardSwipeRow: View {
    let job: JobApplication
    let isEditMode: Bool
    let onDelete: () -> Void

    @GestureState private var dragOffset: CGFloat = 0
    @State private var isSwiping = false

    private let advanceThresholds: [CGFloat] = [65, 130, 200]
    private let deleteThreshold: CGFloat = 80

    private var pipeline: [ApplicationStatus] {
        let all: [ApplicationStatus] = [.toApply, .applied, .interview, .offer]
        guard let s = job.status, let idx = all.firstIndex(of: s) else { return [] }
        return Array(all.dropFirst(idx + 1))
    }

    private func stageFor(_ offset: CGFloat) -> Int {
        var stage = 0
        for (i, threshold) in advanceThresholds.enumerated() {
            guard i < pipeline.count else { break }
            if offset >= threshold { stage = i + 1 }
        }
        return stage
    }

    private var currentStage: Int { dragOffset > 0 ? stageFor(dragOffset) : 0 }

    var body: some View {
        ZStack(alignment: dragOffset < 0 ? .trailing : .leading) {
            swipeBackground
            ZStack {
                NavigationLink(destination: JobDetailView(job: job)) { EmptyView() }
                    .opacity(0)
                    .disabled(isEditMode || isSwiping)
                DarkJobCardView(job: job)
                    .scaleEffect(isSwiping ? 0.98 : 1.0)
                    .animation(.appCrisp, value: isSwiping)
            }
            .offset(x: cardOffset(dragOffset))
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.85), value: dragOffset)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 28) // High threshold to prioritize scroll
                .onChanged { value in
                    guard !isEditMode else { return }
                    let dx = value.translation.width
                    let dy = value.translation.height
                    // Strict directional lock (Emil principle)
                    guard abs(dx) > abs(dy) * 2.0 else { return }
                    isSwiping = true
                }
                .updating($dragOffset) { value, state, _ in
                    guard !isEditMode else { return }
                    let dx = value.translation.width
                    let dy = value.translation.height
                    guard abs(dx) > abs(dy) * 2.0 else { return }

                    if dx > 0, pipeline.isEmpty { return }
                    state = dx
                }
                .onEnded { value in
                    isSwiping = false
                    guard !isEditMode else { return }
                    let dx = value.translation.width
                    if dx > 0 {
                        let stage = stageFor(dx)
                        guard stage > 0, stage - 1 < pipeline.count else { return }
                        withAnimation(.appSmooth) {
                            job.status = pipeline[stage - 1]
                        }
                        AppHaptics.shared.medium()
                    } else if dx < -deleteThreshold {
                        onDelete()
                    }
                }
        )
        .onChange(of: currentStage) { old, new in
            guard new > old, new > 0 else { return }
            AppHaptics.shared.light()
        }
    }

    @ViewBuilder
    private var swipeBackground: some View {
        if dragOffset > 5, !pipeline.isEmpty {
            let idx = max(0, min(currentStage - 1, pipeline.count - 1))
            let target = pipeline[idx]
            let style = DarkTheme.statusStyle(for: target)
            HStack(spacing: 10) {
                Image(systemName: style.iconName).font(.system(size: 18, weight: .bold))
                Text(target.rawValue).font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(style.tintColor)
            .padding(.leading, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DarkTheme.cardRadius, style: .continuous)
                    .fill(style.fillColor)
                    .overlay(RoundedRectangle(cornerRadius: DarkTheme.cardRadius, style: .continuous)
                        .strokeBorder(style.borderColor, lineWidth: 1.5))
            )
            .opacity(min(1.0, dragOffset / advanceThresholds[0]))
            .animation(.appSmooth, value: target)
        } else if dragOffset < -5 {
            let c = Color(red: 0.93, green: 0.33, blue: 0.40) // Softened red
            HStack(spacing: 10) {
                Image(systemName: "trash.fill").font(.system(size: 18, weight: .bold))
                Text("Delete").font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(c)
            .padding(.trailing, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .background(
                RoundedRectangle(cornerRadius: DarkTheme.cardRadius, style: .continuous)
                    .fill(c.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: DarkTheme.cardRadius, style: .continuous)
                        .strokeBorder(c.opacity(0.18), lineWidth: 1.5))
            )
            .opacity(min(1.0, abs(dragOffset) / deleteThreshold))
        }
    }

    private func cardOffset(_ raw: CGFloat) -> CGFloat {
        if raw > 0 {
            let d = raw * 0.70
            return d > 165 ? 165 + (d - 165) * 0.18 : d
        } else if raw < 0 {
            let d = raw * 0.70
            return d < -110 ? -110 + (d + 110) * 0.18 : d
        }
        return 0
    }
}
