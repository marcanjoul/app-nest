import SwiftUI
import SwiftData

@main
struct AppNestApp: App {
    @AppStorage(AppStorageKeys.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    /// Built once, by hand, so a store that won't open is something the app can react to.
    /// `.modelContainer(for:)` handles the same failure by trapping, which tells the user
    /// nothing and leaves the old store at the mercy of whatever opens it next.
    private let container: Result<ModelContainer, Error>
    private let brokenStoreURL: URL?

    init() {
        let opened = Result {
            try ModelContainer(for: JobApplication.self, ResumeDocument.self, JobCycle.self)
        }
        // Move the unreadable store aside before anything else gets the chance to replace it.
        brokenStoreURL = opened.isFailure ? StoreBackup.preserveBroken() : nil
        container = opened

        // Native nav bar titles follow the type scale: DM Sans for large (title) and inline (headline).
        let metrics = { (style: UIFont.TextStyle, font: UIFont?) in font.map { UIFontMetrics(forTextStyle: style).scaledFont(for: $0) } }
        if let large = metrics(.largeTitle, Theme.displayUIFont(size: AppTextStyle.largeTitle.size, weight: .bold)),
           let inline = metrics(.headline, Theme.displayUIFont(size: AppTextStyle.headline.size, weight: .semibold)) {
            UINavigationBar.appearance().largeTitleTextAttributes = [.font: large]
            UINavigationBar.appearance().titleTextAttributes = [.font: inline]
        }
    }

    var body: some Scene {
        WindowGroup {
            switch container {
            case .success(let container):
                Group {
                    if hasCompletedOnboarding {
                        RootView()
                    } else {
                        OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    }
                }
                .environment(appState)
                .modelContainer(container)
                .task { StoreBackup.snapshotIfPopulated(container) }
                // The Share extension opens appnest://share; checking on every activation also
                // catches shares saved while iOS refused to open the app.
                .onOpenURL { _ in openSharedItem() }
                .onChange(of: scenePhase, initial: true) { _, phase in
                    if phase == .active { openSharedItem() }
                }

            case .failure(let error):
                StoreRecoveryView(error: error, brokenStoreURL: brokenStoreURL)
            }
        }
    }
}

extension AppNestApp {
    private func openSharedItem() {
        guard let text = ShareInbox.take() else { return }
        appState.selectedJob = nil
        appState.sharedText = text
        appState.isShowingAdd = true
    }
}

private extension Result {
    var isFailure: Bool {
        if case .failure = self { return true }
        return false
    }
}
