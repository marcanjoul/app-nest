import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        @Bindable var bindableAppState = appState
        
        ZStack(alignment: .bottom) {
            TabView(selection: $bindableAppState.selectedTab) {
                NavigationStack {
                    ApplicationView()
                }
                .toolbar(.hidden, for: .tabBar)
                .tag(0)

                NavigationStack {
                    AddMenuView()
                }
                .toolbar(.hidden, for: .tabBar)
                .tag(1)

                NavigationStack {
                    ProfileView()
                }
                .toolbar(.hidden, for: .tabBar)
                .tag(2)
            }
            
            if !appState.isPresentingSheet {
                NavigationDock(selectedTab: $bindableAppState.selectedTab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .tint(.accentColor)
        .scaleEffect(appState.isPresentingSheet ? 0.95 : 1.0)
        .blur(radius: appState.isPresentingSheet ? 2 : 0)
        .overlay {
            if appState.isPresentingSheet {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
            }
        }
        .animation(.appSmooth, value: appState.isPresentingSheet)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: JobApplication.self, ResumeDocument.self, JobCycle.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return RootView()
        .environment(AppState())
        .modelContainer(container)
}
