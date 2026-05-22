import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppState.self) private var appState
    @State private var isKeyboardVisible = false

    var body: some View {
        @Bindable var bindableAppState = appState

        ZStack(alignment: .bottom) {
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
            .animation(.none, value: bindableAppState.selectedTab)

            if !appState.isPresentingSheet && !isKeyboardVisible {
                NavigationDock(selectedTab: $bindableAppState.selectedTab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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
