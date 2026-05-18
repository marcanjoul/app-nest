import SwiftUI
import SwiftData

@main
struct AppNestApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    RootView()
                } else {
                    OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                }
            }
            .environment(appState)
            .fontDesign(.rounded)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    if let pending = PendingJobImport.consume() {
                        appState.pendingJobImport = pending
                    }
                }
            }
        }
        .modelContainer(for: [JobApplication.self, ResumeDocument.self, JobCycle.self])
    }
}
