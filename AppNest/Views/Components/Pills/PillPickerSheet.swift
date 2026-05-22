import SwiftUI

struct PillPickerSheet<T: CaseIterable & RawRepresentable & Hashable>: View
    where T.RawValue == String {

    let current: T?
    let colorFor: (T) -> Color
    let iconFor: (T) -> String
    let onSelect: (T) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.primary.opacity(0.2))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 14)

            // Pills
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                spacing: 8
            ) {
                ForEach(Array(T.allCases), id: \.self) { option in
                    pill(for: option)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }

    @ViewBuilder
    private func pill(for option: T) -> some View {
        let isSelected = current == option
        let color = colorFor(option)
        let icon = iconFor(option)

        Button {
            AppHaptics.shared.light()
            onSelect(option)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                dismiss()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .appFont(14, weight: .bold)
                    .foregroundStyle(isSelected ? .white : color)
                Text(option.rawValue)
                    .font(.system(size: 14, weight: isSelected ? .bold : .semibold))
                    .foregroundStyle(isSelected ? .white : color.opacity(0.88))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark")
                        .appFont(11, weight: .bold)
                        .foregroundStyle(.white.opacity(0.75))
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(isSelected ? color : color.opacity(0.12))
                    .overlay(
                        Capsule().strokeBorder(
                            isSelected ? Color.clear : color.opacity(0.28),
                            lineWidth: 0.8
                        )
                    )
            )
        }
        .buttonStyle(PressScaleButtonStyle())
        .animation(.appCrisp, value: isSelected)
    }
}
