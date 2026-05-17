import SwiftUI
import SwiftData

enum SortOption: String, CaseIterable {
    case dateNewest = "Newest"
    case dateOldest = "Oldest"
    case companyAZ  = "Company A–Z"
    case companyZA  = "Company Z–A"
}

struct ApplicationView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JobApplication.dateApplied, order: .reverse) private var applications: [JobApplication]

    @State private var searchText: String = ""
    @State private var isPresentingNewApplication = false
    @State private var selectedStatus: ApplicationStatus? = nil
    @State private var sortOption: SortOption = .dateNewest
    @State private var contentAppeared = false

    private var filteredAndSorted: [JobApplication] {
        var result = applications

        if let status = selectedStatus {
            result = result.filter { $0.status == status }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            result = result.filter {
                $0.position.lowercased().contains(query) ||
                $0.companyName.lowercased().contains(query) ||
                ($0.jobType?.rawValue.lowercased().contains(query) ?? false)
            }
        }

        switch sortOption {
        case .dateNewest: result.sort { $0.dateApplied > $1.dateApplied }
        case .dateOldest: result.sort { $0.dateApplied < $1.dateApplied }
        case .companyAZ:  result.sort { $0.companyName.localizedCompare($1.companyName) == .orderedAscending }
        case .companyZA:  result.sort { $0.companyName.localizedCompare($1.companyName) == .orderedDescending }
        }

        return result
    }

    var body: some View {
        ZStack {
            // Adaptive ambient gradient background
            AmbientBackground()

            List {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("App Nest")
                        .font(.system(size: 40, weight: .bold, design: .default))
                        .foregroundStyle(DarkTheme.textPrimary)
                }
                .opacity(contentAppeared ? 1 : 0)
                .offset(y: contentAppeared ? 0 : 20)
                .animation(.spring(response: 0.55, dampingFraction: 0.82), value: contentAppeared)
                .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 8, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                // Search + Filter
                searchFilterRow
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 16)
                    .animation(.spring(response: 0.55, dampingFraction: 0.82).delay(0.07), value: contentAppeared)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                // Stats
                statsSection
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 12)
                    .animation(.spring(response: 0.55, dampingFraction: 0.82).delay(0.12), value: contentAppeared)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 14, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                // Content
                if applications.isEmpty {
                    emptyState
                        .transition(.opacity)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else if filteredAndSorted.isEmpty {
                    noResultsState
                        .transition(.opacity)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(filteredAndSorted) { job in
                        ZStack {
                            NavigationLink(destination: JobDetailView(job: job)) { EmptyView() }
                                .opacity(0)
                            DarkJobCardView(job: job)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { modelContext.delete(job) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }

                Color.clear
                    .frame(height: 100)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            // Pill FAB
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        isPresentingNewApplication = true
                    } label: {
                        Label("New", systemImage: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 15)
                            .background {
                                Capsule()
                                    .fill(Color.accentColor)
                                    .overlay {
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.25), Color.clear],
                                            startPoint: .top, endPoint: .center
                                        )
                                        .clipShape(Capsule())
                                    }
                                    .shadow(color: Color.accentColor.opacity(0.30), radius: 14, y: 5)
                            }
                    }
                    .buttonStyle(FABStyle())
                    .opacity(contentAppeared ? 1 : 0)
                    .animation(.spring(response: 0.55, dampingFraction: 0.82).delay(0.18), value: contentAppeared)
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            contentAppeared = true
        }
        .sheet(isPresented: $isPresentingNewApplication) {
            NavigationStack { JobDetailView(job: nil) }
        }
    }

    // MARK: - Search + Filter Row

    private var searchFilterRow: some View {
        HStack(spacing: 10) {
            // Glass search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DarkTheme.textSecondary)
                    .font(.system(size: 15, weight: .medium))

                TextField("Search applications…", text: $searchText)
                    .foregroundStyle(DarkTheme.textPrimary)
                    .tint(.accentColor)

                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(DarkTheme.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
            }

            // Sort menu
            Menu {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button {
                        sortOption = option
                    } label: {
                        HStack {
                            Text(option.rawValue)
                            if sortOption == option { Image(systemName: "checkmark") }
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DarkTheme.textPrimary)
                    .frame(width: 44, height: 44)
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
                    }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Stats Section

    private var orderedFilterStatuses: [ApplicationStatus] {
        let base: [ApplicationStatus] = [.applied, .interview, .offer, .rejected]
        if let selected = selectedStatus, base.contains(selected) {
            return [selected] + base.filter { $0 != selected }
        }
        return base
    }

    private var statsSection: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(orderedFilterStatuses, id: \.self) { status in
                        StatChip(
                            status: status,
                            number: applications.filter { $0.status == status }.count,
                            isSelected: selectedStatus == status,
                            action: {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                                    selectedStatus = (selectedStatus == status) ? nil : status
                                }
                            }
                        )
                        .id(status)
                    }
                }
                .padding(.horizontal, 20)
            }
            .onChange(of: selectedStatus) { _, _ in
                if let first = orderedFilterStatuses.first {
                    withAnimation(.smooth) { proxy.scrollTo(first, anchor: .leading) }
                }
            }
        }
    }

    // MARK: - Empty States

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray.fill")
                .font(.system(size: 48))
                .foregroundStyle(DarkTheme.textSecondary.opacity(0.5))
            Text("No applications yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(DarkTheme.textPrimary)
            Text("Tap New to add your first application.")
                .font(.subheadline)
                .foregroundStyle(DarkTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var noResultsState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(DarkTheme.textSecondary.opacity(0.5))
            Text("No results")
                .font(.title3.weight(.semibold))
                .foregroundStyle(DarkTheme.textPrimary)
            Text("Try a different search or filter.")
                .font(.subheadline)
                .foregroundStyle(DarkTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

private struct FABStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: JobApplication.self, ResumeDocument.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let ctx = container.mainContext
    let samples: [(String, String, String, ApplicationType, ApplicationStatus, ApplicationSeason, Int)] = [
        ("Meta",         "meta",          "Software Engineering Intern",  .internship, .applied,   .summer, 5),
        ("Uber",         "uber",          "iOS Engineer Intern",          .internship, .interview, .summer, 8),
        ("JPMorgan",     "jpmorganchase", "Software Engineer Intern",     .internship, .applied,   .summer, 10),
        ("Honeywell",    "honeywell",     "Embedded Systems Intern",      .internship, .rejected,  .summer, 12),
        ("Google",       "google",        "SWE Intern – iOS",             .internship, .offer,     .summer, 20),
        ("Amazon",       "amazon",        "SDE Intern",                   .internship, .applied,   .summer, 22),
        ("Netflix",      "netflix",       "Mobile Engineering Intern",    .internship, .toApply,   .summer, 24),
    ]
    for (company, logo, position, type, status, season, days) in samples {
        ctx.insert(JobApplication(
            companyName: company, companyLogoName: logo, position: position,
            jobType: type, status: status, season: season,
            dateApplied: Date().addingTimeInterval(-86_400 * Double(days))
        ))
    }
    return NavigationStack { ApplicationView() }.modelContainer(container)
}
