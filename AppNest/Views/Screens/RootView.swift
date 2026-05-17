import SwiftUI
import SwiftData

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack {
                ApplicationView()
            }
            .toolbarBackground(Color(UIColor.systemBackground), for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .tabItem {
                Label("Applications", systemImage: "briefcase.fill")
            }

            NavigationStack {
                EmailParserView()
            }
            .toolbarBackground(Color(UIColor.systemBackground), for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .tabItem {
                Label("Email", systemImage: "envelope.open.fill")
            }

            NavigationStack {
                ProfileView()
            }
            .toolbarBackground(Color(UIColor.systemBackground), for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle.fill")
            }
        }
        .tint(.accentColor)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: JobApplication.self, ResumeDocument.self, JobCycle.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let ctx = container.mainContext
    let samples: [(String, String, ApplicationType, ApplicationStatus, ApplicationSeason, Int)] = [
        ("Meta",    "Software Engineering Intern", .internship, .applied,   .summer, 5),
        ("Uber",    "iOS Engineer Intern",         .internship, .interview, .summer, 8),
        ("Google",  "SWE Intern, iOS",             .internship, .offer,     .summer, 20),
        ("Amazon",  "SDE Intern",                  .internship, .applied,   .summer, 22),
        ("Netflix", "Mobile Engineering Intern",   .internship, .toApply,   .summer, 24),
    ]
    for (company, position, type, status, season, days) in samples {
        ctx.insert(JobApplication(
            companyName: company, position: position,
            jobType: type, status: status, season: season,
            dateApplied: Date().addingTimeInterval(-86_400 * Double(days))
        ))
    }
    return RootView()
        .environment(AppState())
        .modelContainer(container)
}
