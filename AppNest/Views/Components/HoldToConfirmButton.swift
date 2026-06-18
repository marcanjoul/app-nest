import SwiftUI

/// A premium "Hold-to-Confirm" button that uses a timed fill effect.
/// Perfect for deliberate destructive actions like deletions.
struct HoldToConfirmButton: View {
    let title: String
    let icon: String
    let color: Color
    let holdDuration: Double = 1.2
    let onConfirm: () -> Void
    
    @State private var isHolding = false
    @State private var timer: Timer?
    @State private var progress: CGFloat = 0
    @State private var lastUpdate: Date = Date()
    @State private var lastHapticProgress: CGFloat = 0
    
    var body: some View {
        Button(action: {}) {
            ZStack(alignment: .leading) {
                // Background
                Capsule()
                    .fill(color.opacity(0.12))
                
                // Progress Fill
                GeometryReader { proxy in
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * progress)
                }
                
                // Label
                HStack(spacing: 10) {
                    Text(title)
                        .appFont(15, weight: .bold)
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(progress > 0.5 ? .white.opacity(0.16) : color.opacity(0.12))
                            .frame(width: 34, height: 34)
                        Image(systemName: icon)
                            .appFont(12, weight: .bold)
                    }
                }
                .foregroundStyle(progress > 0.5 ? .white : color)
                .padding(.leading, 20)
                .padding(.trailing, 8)
                .frame(maxWidth: .infinity)
            }
            .frame(height: 50)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(color.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isHolding {
                        startHolding()
                    }
                }
                .onEnded { _ in
                    stopHolding()
                }
        )
    }
    
    private func startHolding() {
        isHolding = true
        lastUpdate = Date()
        AppHaptics.shared.light()
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            let now = Date()
            let delta = now.timeIntervalSince(lastUpdate)
            lastUpdate = now
            
            withAnimation(.linear(duration: 0.02)) {
                progress += CGFloat(delta / holdDuration)
            }
            
            if progress - lastHapticProgress >= 0.1 {
                AppHaptics.shared.selection()
                lastHapticProgress = progress
            }
            
            if progress >= 1.0 {
                confirm()
            }
        }
    }
    
    private func stopHolding() {
        isHolding = false
        timer?.invalidate()
        timer = nil
        lastHapticProgress = 0
        
        withAnimation(.appCrisp) {
            progress = 0
        }
    }
    
    private func confirm() {
        stopHolding()
        AppHaptics.shared.success()
        onConfirm()
    }
}

#Preview {
    HoldToConfirmButton(title: "Delete Cycle", icon: "trash.fill", color: .red) {
        print("Confirmed!")
    }
    .padding()
}
