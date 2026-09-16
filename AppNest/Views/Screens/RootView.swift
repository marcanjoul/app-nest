import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppState.self) private var appState
    @State private var isKeyboardVisible = false

    var body: some View {
        @Bindable var bindableAppState = appState

        ZStack(alignment: .bottom) {
            // ponytail: was three NavigationStacks stacked with .opacity(0) — every tab's body
            // re-evaluated on every state change. TabView renders only the selected tab and
            // still keeps the others' state; its own bar is hidden in favour of NavigationDock.
            TabView(selection: $bindableAppState.selectedTab) {
                NavigationStack(path: $bindableAppState.navigationPath) {
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
            .animation(.none, value: appState.selectedTab)

            if !appState.isPresentingSheet && !isKeyboardVisible {
                NavigationDock(selectedTab: $bindableAppState.selectedTab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            if appState.showOfferCelebration {
                FullScreenCelebrationView()
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.appCrisp) { isKeyboardVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.appCrisp) { isKeyboardVisible = false }
        }
        .sheet(item: $bindableAppState.selectedJob) { job in
            JobDetailView(job: job, isSheetPresentation: true)
                .presentationDetents([.fraction(0.90)])
                .presentationCornerRadius(28)
                .presentationDragIndicator(.visible)
        }
        .tint(Theme.accent)
        // ponytail: scale + dim only. The 2pt blur forced an offscreen render of the whole app
        // for every frame of the sheet animation and was imperceptible under the dim layer.
        .scaleEffect(appState.isPresentingSheet ? 0.95 : 1.0)
        .overlay {
            if appState.isPresentingSheet {
                Color.black.opacity(0.5)
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
