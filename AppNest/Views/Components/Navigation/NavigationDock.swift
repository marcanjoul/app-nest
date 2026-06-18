import SwiftUI

@MainActor
struct NavigationDock: View {
    @Binding var selectedTab: Int
    @Environment(AppState.self) private var appState
    @Namespace private var namespace
    
    @AppStorage(AppStorageKeys.avatarData) private var profileAvatarDataBase64: String = ""
    @AppStorage(AppStorageKeys.displayName) private var profileDisplayName: String = ""
    
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
        let isCompact = appState.isDockCompact
        
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
                                    .frame(
                                        width: (index == 1 ? 54 : 44) * (isCompact ? 0.72 : 1.0),
                                        height: (index == 1 ? 54 : 44) * (isCompact ? 0.72 : 1.0)
                                    )
                                    .matchedGeometryEffect(id: "pill", in: namespace)
                            }
                            
                            if index == 2 {
                                profileAvatarView(isCompact: isCompact, isSelected: selectedTab == index)
                            } else {
                                Image(systemName: tab.icon)
                                    .font(.system(size: (index == 1 ? 22 : 18) * (isCompact ? 0.72 : 1.0), weight: .bold))
                                    .foregroundStyle(selectedTab == index ? (index == 1 ? .white : Color.accentColor) : Theme.textSecondary)
                                    .scaleEffect(selectedTab == index ? 1.1 : 1.0)
                            }
                        }
                        .frame(height: isCompact ? 36 : 54)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(BubblyTabButtonStyle())
            }
        }
        .padding(.horizontal, isCompact ? 6 : 10)
        .padding(.vertical, isCompact ? 2 : 8)
        .background {
            ZStack {
                // Solid adaptive background base (fully opaque)
                Capsule()
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                
                // Opaque green tint blend
                Capsule()
                    .fill(Theme.accent.opacity(0.08))
                
                // Liquid gloss highlight (white gradient fading to clear)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.18),
                                .white.opacity(0.03),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                // Soft radial gradient overlay (glow)
                Capsule()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [.white.opacity(0.14), .clear]),
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: isCompact ? 80 : 120
                        )
                    )
            }
            .shadow(
                color: .black.opacity(isCompact ? 0.08 : 0.16),
                radius: isCompact ? 10 : 20,
                x: 0,
                y: isCompact ? 6 : 12
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.45),
                                Theme.accent.opacity(0.12),
                                .black.opacity(0.04),
                                .black.opacity(0.16)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .padding(.horizontal, isCompact ? 104 : 24)
        .padding(.bottom, isCompact ? 2 : 4)
        .scaleEffect(isCompact ? 0.78 : 1.0)
        .onAppear {
            visualSelectedTab = selectedTab
        }
        .onChange(of: selectedTab) { _, newValue in
            if visualSelectedTab != newValue {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.68)) {
                    visualSelectedTab = newValue
                }
            }
        }
    }
    
    private func handleTabTap(at index: Int) {
        let isSameTab = selectedTab == index
        
        // Reset compact state on interaction
        withAnimation(.appSmooth) {
            appState.isDockCompact = false
        }
        
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
            appState.shouldResetAddMenu = true
        }
        
        if !isSameTab {
            AppHaptics.shared.selection()
            selectedTab = index
            withAnimation(.spring(response: 0.35, dampingFraction: 0.68)) {
                visualSelectedTab = index
            }
        }
    }
    
    @ViewBuilder
    private func profileAvatarView(isCompact: Bool, isSelected: Bool) -> some View {
        let size = 22.0 * (isCompact ? 0.72 : 1.0)
        
        Group {
            if !profileAvatarDataBase64.isEmpty,
               let data = Data(base64Encoded: profileAvatarDataBase64),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                ZStack {
                    Circle()
                        .fill(Theme.avatarColor(for: profileDisplayName.isEmpty ? "AppNest" : profileDisplayName).background)
                    
                    let initial = profileDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
                        .first.map { String($0).uppercased() } ?? "?"
                    
                    Text(initial)
                        .font(.system(size: size * 0.55, weight: .bold))
                        .foregroundStyle(Theme.avatarColor(for: profileDisplayName.isEmpty ? "AppNest" : profileDisplayName).foreground)
                }
                .frame(width: size, height: size)
            }
        }
        .overlay(
            Circle()
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
        )
        .scaleEffect(isSelected ? 1.1 : 1.0)
    }
}

struct BubblyTabButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.24, dampingFraction: 0.52), value: configuration.isPressed)
    }
}
