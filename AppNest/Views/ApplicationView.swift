import SwiftUI
import SwiftData

enum SortOption: String, CaseIterable {
    case dateNewest = "Newest"
    case dateOldest = "Oldest"
    case companyAZ  = "Company A–Z"
    case companyZA  = "Company Z–A"

    var shortLabel: String {
        switch self {
        case .dateNewest: return "Newest"
        case .dateOldest: return "Oldest"
        case .companyAZ:  return "A–Z"
        case .companyZA:  return "Z–A"
        }
    }
}

struct ApplicationView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JobApplication.dateApplied, order: .reverse) private var applications: [JobApplication]

    @State private var searchText: String = ""
    @State private var isPresentingNewApplication = false
    @State private var selectedStatus: ApplicationStatus? = nil
    @State private var sortOption: SortOption = .dateNewest
    @State private var contentAppeared = false

    // Search-only filtered list — used for chip counts so they reflect search but not status filter
    private var searchFiltered: [JobApplication] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return applications }
        return applications.filter {
            $0.position.lowercased().contains(query) ||
            $0.companyName.lowercased().contains(query) ||
            ($0.jobType?.rawValue.lowercased().contains(query) ?? false)
        }
    }

    private var filteredAndSorted: [JobApplication] {
        var result = searchFiltered

        if let status = selectedStatus {
            result = result.filter { $0.status == status }
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
                VStack(alignment: .leading, spacing: 2) {
                    Text("App Nest")
                        .font(.system(size: 40, weight: .bold, design: .default))
                        .foregroundStyle(DarkTheme.textPrimary)
                    Text("\(applications.count) application\(applications.count == 1 ? "" : "s")")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DarkTheme.textSecondary)
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
                        JobCardSwipeRow(job: job)
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
            .scrollDismissesKeyboard(.interactively)

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
                    .scaleEffect(contentAppeared ? 1 : 0.75)
                    .opacity(contentAppeared ? 1 : 0)
                    .animation(.spring(response: 0.55, dampingFraction: 0.75).delay(0.18), value: contentAppeared)
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
                VStack(spacing: 2) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(sortOption == .dateNewest ? DarkTheme.textPrimary : Color.accentColor)
                    if sortOption != .dateNewest {
                        Text(sortOption.shortLabel)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .frame(width: 44, height: 44)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().strokeBorder(
                            sortOption == .dateNewest ? Color.primary.opacity(0.08) : Color.accentColor.opacity(0.35),
                            lineWidth: sortOption == .dateNewest ? 1 : 1.5
                        ))
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Stats Section

    private var orderedFilterStatuses: [ApplicationStatus] {
        let base: [ApplicationStatus] = [.toApply, .applied, .interview, .offer, .rejected]
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
                        let count = searchFiltered.filter { $0.status == status }.count
                        StatChip(
                            status: status,
                            number: count,
                            isSelected: selectedStatus == status,
                            action: {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                                    selectedStatus = (selectedStatus == status) ? nil : status
                                }
                            }
                        )
                        .id(status)
                        .opacity(count == 0 && selectedStatus != status ? 0.4 : 1.0)
                        .animation(.spring(response: 0.28, dampingFraction: 0.7), value: count)
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
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    searchText = ""
                    selectedStatus = nil
                }
            } label: {
                Text("Clear filters")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.accentColor.opacity(0.12)))
            }
            .buttonStyle(.plain)
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

// MARK: - Progressive Swipe Row

private struct JobCardSwipeRow: View {
    let job: JobApplication

    @GestureState private var dragX: CGFloat = 0

    private let thresholds: [CGFloat] = [65, 130, 200]

    private var pipeline: [ApplicationStatus] {
        let all: [ApplicationStatus] = [.toApply, .applied, .interview, .offer]
        guard let s = job.status, let idx = all.firstIndex(of: s) else { return [] }
        return Array(all.dropFirst(idx + 1))
    }

    private func stageFor(_ offset: CGFloat) -> Int {
        var stage = 0
        for (i, threshold) in thresholds.enumerated() {
            guard i < pipeline.count else { break }
            if offset >= threshold { stage = i + 1 }
        }
        return stage
    }

    private var currentStage: Int { stageFor(dragX) }

    var body: some View {
        ZStack(alignment: .leading) {
            swipeBackground
            ZStack {
                NavigationLink(destination: JobDetailView(job: job)) { EmptyView() }
                    .opacity(0)
                DarkJobCardView(job: job)
            }
            .offset(x: cardOffset(dragX))
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.85), value: dragX)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 12)
                .updating($dragX) { value, state, _ in
                    let dx = value.translation.width
                    guard dx > 0, dx > abs(value.translation.height) else { return }
                    state = dx
                }
                .onEnded { value in
                    let dx = max(0, value.translation.width)
                    let stage = stageFor(dx)
                    guard stage > 0, stage - 1 < pipeline.count else { return }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        job.status = pipeline[stage - 1]
                    }
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    #endif
                }
        )
        .onChange(of: currentStage) { old, new in
            guard new > old, new > 0 else { return }
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        }
    }

    @ViewBuilder
    private var swipeBackground: some View {
        if !pipeline.isEmpty {
            let displayedIdx = max(0, min(currentStage - 1, pipeline.count - 1))
            let displayed = pipeline[displayedIdx]
            let style = DarkTheme.statusStyle(for: displayed)
            let revealProgress = min(1.0, dragX / thresholds[0])

            HStack(spacing: 8) {
                Image(systemName: style.iconName)
                    .font(.system(size: 16, weight: .bold))
                Text(displayed.rawValue)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(style.tintColor)
            .padding(.leading, 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DarkTheme.cardRadius, style: .continuous)
                    .fill(style.fillColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: DarkTheme.cardRadius, style: .continuous)
                            .strokeBorder(style.borderColor, lineWidth: 1)
                    )
            )
            .opacity(revealProgress)
            .animation(.easeOut(duration: 0.12), value: displayed)
        }
    }

    private func cardOffset(_ raw: CGFloat) -> CGFloat {
        guard raw > 0 else { return 0 }
        let damped = raw * 0.70
        let limit: CGFloat = 165
        guard damped > limit else { return damped }
        return limit + (damped - limit) * 0.18
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
