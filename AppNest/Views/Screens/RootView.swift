import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppState.self) private var appState

    /// Distance from the safe-area bottom to the "+" button's bottom edge. Negative: the
    /// system tab bar dips below the safe area, and the button centres on the same line.
    private static let addButtonBottomOffset: CGFloat = -12

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
            }
            // ponytail: hand-placed beside the system tab bar — iOS 27 keeps a `role: .search`
            // tab inside the bar, so the separate circle has to be ours. The bottom offset is
            // tuned to the tab bar's centre line on iPhone; re-check it if Apple moves the bar.
            .overlay(alignment: .bottomTrailing) {
                Button {
                    AppHaptics.shared.light()
                    appState.isShowingAdd = true
                } label: {
                    AppIcon("plus")
                        .appFont(22, weight: .semibold)
                        .foregroundStyle(.white)
                        .frame(width: 62, height: 62)
                        .glassEffect(.regular.tint(Theme.buttonGreen).interactive(), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add application")
                .padding(.trailing, 20)
                .padding(.bottom, Self.addButtonBottomOffset)
            }
            .ignoresSafeArea(.keyboard)
            .animation(.none, value: appState.selectedTab)
        }
        .sheet(isPresented: $bindableAppState.isShowingAdd) {
            NavigationStack {
                AddMenuView()
            }
            .presentationDragIndicator(.hidden)
        }
        .sheet(item: $bindableAppState.selectedJob) { job in
            JobDetailView(job: job, isSheetPresentation: true)
                .presentationDetents([.fraction(0.90)])
                .presentationCornerRadius(28)
                .presentationDragIndicator(.hidden)
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
