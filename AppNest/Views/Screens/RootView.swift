import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var bindableAppState = appState

        ZStack(alignment: .bottom) {
            TabView(selection: $bindableAppState.selectedTab) {
                Tab(value: 0) {
                    NavigationStack(path: $bindableAppState.navigationPath) {
                        ApplicationView()
                    }
                } label: {
                    AppLabel("Applications", systemImage: "briefcase")
                }

                Tab(value: 2) {
                    NavigationStack {
                        ProfileView()
                    }
                } label: {
                    AppLabel("Profile", systemImage: "person")
                }

                // ponytail: borrows the search role purely for its look — iOS draws it as a
                // separate glass circle at the trailing end of the tab bar. Tag stays 1 so
                // `selectedTab = 1` call sites keep working.
                Tab(value: 1, role: .search) {
                    NavigationStack {
                        AddMenuView()
                    }
                } label: {
                    AppLabel("Add", systemImage: "plus")
                        .accessibilityLabel("Add application")
                }
            }
            .animation(.none, value: appState.selectedTab)
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
