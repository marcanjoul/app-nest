import SwiftUI

/// The job card's status dropdown, drawn over the whole screen: a blur-and-dim scrim with the
/// card itself cut out (it stays sharp), the current pill redrawn in place, and the other
/// statuses dropping out beneath it. Tapping the
/// scrim or the pill closes it. Cards live in a List and can't draw outside their row, so the
/// list owns this and the card only reports where its pill is.
struct StatusDropdownOverlay: View {
    let job: JobApplication
    /// The card's status pill, in global coordinates.
    let anchor: CGRect
    /// The whole card, in global coordinates — left unblurred.
    let card: CGRect
    let onDismiss: () -> Void

    @State private var appeared = false

    private static let rowHeight: CGFloat = 34
    private static let spacing: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            let origin = proxy.frame(in: .global).origin
            let pill = anchor.offsetBy(dx: -origin.x, dy: -origin.y)
            let options = ApplicationStatus.allCases.filter { $0 != job.status }
            // ponytail: list height from a fixed row estimate, only to decide up vs down;
            // measure it if pill sizes change.
            let listHeight = CGFloat(options.count) * (Self.rowHeight + Self.spacing) - Self.spacing
            let opensUp = pill.maxY + Self.spacing + listHeight > proxy.size.height - 16

            ZStack(alignment: .topLeading) {
                // Enough blur and dim that the pills read clearly over any card.
                Rectangle()
                    .fill(.thinMaterial)
                    .overlay(Color.black.opacity(0.28))
                    .mask { cardCutout }
                    .ignoresSafeArea()
                    .onTapGesture(perform: onDismiss)
                    .accessibilityLabel("Close status menu")
                    .accessibilityAddTraits(.isButton)

                if let status = job.status {
                    Button(action: onDismiss) {
                        DarkStatusPill(status: status, isOpen: true)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .offset(x: pill.minX, y: pill.minY)
                }

                VStack(alignment: .leading, spacing: Self.spacing) {
                    ForEach(Array(options.enumerated()), id: \.element) { index, option in
                        Button {
                            // Offer already plays its own success haptic from the card.
                            if option != .offer { AppHaptics.shared.selection() }
                            withAnimation(.appSmooth) { job.status = option }
                            onDismiss()
                        } label: {
                            DarkStatusPill(status: option)
                        }
                        .buttonStyle(PressScaleButtonStyle())
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : (opensUp ? 8 : -8))
                        // Roll out from the pill: nearest option first.
                        .animation(.appSmooth.delay(Double(opensUp ? options.count - 1 - index : index) * 0.03), value: appeared)
                    }
                }
                .offset(x: pill.minX,
                        y: opensUp ? pill.minY - Self.spacing - listHeight : pill.maxY + Self.spacing)
            }
        }
        .onAppear { appeared = true }
    }

    /// Opaque everywhere except a card-shaped hole. Measured in its own space: the scrim
    /// ignores the safe area, so its origin isn't the GeometryReader's.
    private var cardCutout: some View {
        GeometryReader { g in
            let o = g.frame(in: .global).origin
            ZStack(alignment: .topLeading) {
                Rectangle()
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .frame(width: card.width, height: card.height)
                    .offset(x: card.minX - o.x, y: card.minY - o.y)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
        }
    }
}
