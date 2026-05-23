import SwiftUI
import SwiftData

@main
struct AppNestApp: App {
    @AppStorage(AppStorageKeys.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @State private var appState = AppState()

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
        }
        .modelContainer(for: [JobApplication.self, ResumeDocument.self, JobCycle.self])
    }
}
