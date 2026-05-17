import SwiftUI
import SwiftData

@main
struct AppNestApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    RootView()
                } else {
                    OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                }
            }
            .fontDesign(.rounded)
        }
        .modelContainer(for: [JobApplication.self, ResumeDocument.self])
    }
}
