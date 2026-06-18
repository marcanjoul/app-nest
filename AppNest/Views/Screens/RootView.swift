import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppState.self) private var appState
    @State private var isKeyboardVisible = false

    var body: some View {
        @Bindable var bindableAppState = appState

        ZStack(alignment: .bottom) {
            ZStack {
                NavigationStack(path: $bindableAppState.navigationPath) {
                    ApplicationView()
                }
                .opacity(appState.selectedTab == 0 ? 1 : 0)
                .disabled(appState.selectedTab != 0)

                NavigationStack {
                    AddMenuView()
                }
                .opacity(appState.selectedTab == 1 ? 1 : 0)
                .disabled(appState.selectedTab != 1)

                NavigationStack {
                    ProfileView()
                }
                .opacity(appState.selectedTab == 2 ? 1 : 0)
                .disabled(appState.selectedTab != 2)
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
        .scaleEffect(appState.isPresentingSheet ? 0.95 : 1.0)
        .blur(radius: appState.isPresentingSheet ? 2 : 0)
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
