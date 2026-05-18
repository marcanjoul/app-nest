import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        @Bindable var bindableAppState = appState
        
        TabView(selection: $bindableAppState.selectedTab) {
            NavigationStack {
                ApplicationView()
            }
            .toolbarBackground(Color(UIColor.systemBackground), for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .tabItem {
                Label("Applications", systemImage: "briefcase.fill")
            }
            .tag(0)

            NavigationStack {
                AddMenuView()
            }
            .toolbarBackground(Color(UIColor.systemBackground), for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .tabItem {
                Label("Add Job", systemImage: "plus.circle.fill")
            }
            .tag(1)

            NavigationStack {
                ProfileView()
            }
            .toolbarBackground(Color(UIColor.systemBackground), for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle.fill")
            }
            .tag(2)
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
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: appState.isPresentingSheet)
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
