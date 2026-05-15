import SwiftUI
import SwiftData

@main
struct AppNestApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                RootView()
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            }
        }
        .modelContainer(for: JobApplication.self)
    }
}
