import SwiftUI

@MainActor
struct NavigationDock: View {
    @Binding var selectedTab: Int
    @Environment(AppState.self) private var appState
    @Namespace private var namespace
    
    /// Local state to drive the pill animation independently of the heavy content switch.
    @State private var visualSelectedTab: Int
    
    init(selectedTab: Binding<Int>) {
        self._selectedTab = selectedTab
        self._visualSelectedTab = State(initialValue: selectedTab.wrappedValue)
    }
    
    private let tabs: [(icon: String, title: String)] = [
        ("briefcase.fill", "Apps"),
        ("plus", "Add"),
        ("person.fill", "Profile")
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                let tab = tabs[index]
                let isSelected = visualSelectedTab == index
                
                Button {
                    handleTabTap(at: index)
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
                                .foregroundStyle(selectedTab == index ? (index == 1 ? .white : Color.accentColor) : Theme.textSecondary)
                                .scaleEffect(selectedTab == index ? 1.1 : 1.0)
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
        .onAppear {
            visualSelectedTab = selectedTab
        }
        .onChange(of: selectedTab) { _, newValue in
            // Sync visual state if selectedTab changes externally
            if visualSelectedTab != newValue {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    visualSelectedTab = newValue
                }
            }
        }
    }
    
    private func handleTabTap(at index: Int) {
        let isSameTab = selectedTab == index
        
        // 1. Perform the 'Exit' logic (pop to root or reset states)
        if index == 0 {
            if !appState.navigationPath.isEmpty {
                AppHaptics.shared.medium()
                withAnimation(.appSmooth) {
                    appState.navigationPath.removeLast(appState.navigationPath.count)
                }
            } else if isSameTab {
                appState.scrollToTopTrigger += 1
                AppHaptics.shared.light()
            }
        } else if index == 1 {
            // Exit logic for Add tab
            appState.shouldResetAddMenu = true
        }
        
        // 2. Perform tab switch if needed
        if !isSameTab {
            AppHaptics.shared.selection()
            selectedTab = index
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                visualSelectedTab = index
            }
        }
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
