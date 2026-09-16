import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var bindableAppState = appState

        ZStack(alignment: .bottom) {
            TabView(selection: $bindableAppState.selectedTab) {
                NavigationStack(path: $bindableAppState.navigationPath) {
                    ApplicationView()
                }
                .tabItem { Label("Applications", systemImage: "briefcase") }
                .tag(0)

                NavigationStack {
                    AddMenuView()
                }
                .tabItem { Label("Add", systemImage: "plus") }
                .tag(1)

                NavigationStack {
                    ProfileView()
                }
                .tabItem { Label("Profile", systemImage: "person") }
                .tag(2)
            }
            .animation(.none, value: appState.selectedTab)

            
            if appState.showOfferCelebration {
                FullScreenCelebrationView()
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .sheet(item: $bindableAppState.selectedJob) { job in
            JobDetailView(job: job, isSheetPresentation: true)
                .presentationDetents([.fraction(0.90)])
                .presentationCornerRadius(28)
                .presentationDragIndicator(.visible)
        }
        .tint(Theme.accent)
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
