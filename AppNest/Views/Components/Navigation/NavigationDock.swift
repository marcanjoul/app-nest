import SwiftUI

struct NavigationDock: View {
    @Binding var selectedTab: Int
    @Namespace private var namespace
    
    private let tabs: [(icon: String, title: String)] = [
        ("briefcase.fill", "Apps"),
        ("plus", "Add"),
        ("person.fill", "Profile")
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                let tab = tabs[index]
                let isSelected = selectedTab == index
                
                Button {
                    if selectedTab != index {
                        AppHaptics.shared.selection()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedTab = index
                        }
                    }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            if isSelected {
                                Capsule()
                                    .fill(index == 1 ? Color.accentColor : Color.primary.opacity(0.12))
                                    .frame(width: index == 1 ? 54 : 44, height: index == 1 ? 54 : 44)
                                    .matchedGeometryEffect(id: "pill", in: namespace)
                            }
                            
                            Image(systemName: tab.icon)
                                .font(.system(size: index == 1 ? 22 : 18, weight: .bold))
                                .foregroundStyle(isSelected ? (index == 1 ? .white : Color.accentColor) : Theme.textSecondary)
                                .scaleEffect(isSelected ? 1.1 : 1.0)
                        }
                        .frame(height: 54)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                .overlay(
                    Capsule()
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }
}

#Preview {
    ZStack {
        AmbientBackground()
        VStack {
            Spacer()
            NavigationDock(selectedTab: .constant(0))
        }
    }
}
