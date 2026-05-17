import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

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

    @Namespace private var filterNS

    @State private var searchText: String = ""
    @State private var isPresentingNewApplication = false
    @State private var selectedStatuses: Set<ApplicationStatus> = []
    @State private var sortOption: SortOption = .dateNewest
    @State private var contentAppeared = false
    @State private var pendingDeleteJob: JobApplication? = nil
    @State private var undoTask: Task<Void, Never>? = nil

    // Search-only filtered list — used for chip counts so they reflect search but not status filter
    private var searchFiltered: [JobApplication] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base = applications.filter { $0 !== pendingDeleteJob }
        guard !query.isEmpty else { return base }
        return base.filter {
            $0.position.lowercased().contains(query) ||
            $0.companyName.lowercased().contains(query) ||
            ($0.jobType?.rawValue.lowercased().contains(query) ?? false)
        }
    }

    private var filteredAndSorted: [JobApplication] {
        var result = searchFiltered

        if !selectedStatuses.isEmpty {
            result = result.filter { job in
                job.status.map { selectedStatuses.contains($0) } ?? false
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
                VStack(alignment: .leading, spacing: 2) {
                    Text("App Nest")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(DarkTheme.textPrimary)
                    Text("\(applications.count) application\(applications.count == 1 ? "" : "s")")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DarkTheme.textSecondary)
                }
                .opacity(contentAppeared ? 1 : 0)
                .offset(y: contentAppeared ? 0 : 20)
                .animation(.appSmooth, value: contentAppeared)
                .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 8, trailing: 20))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                // Search + Filter
                searchFilterRow
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 16)
                    .animation(.appSmooth.delay(0.07), value: contentAppeared)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                // Stats
                statsSection
                    .opacity(contentAppeared ? 1 : 0)
                    .offset(y: contentAppeared ? 0 : 12)
                    .animation(.appSmooth.delay(0.12), value: contentAppeared)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 14, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                // Content
                if applications.isEmpty {
                    emptyState
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else if filteredAndSorted.isEmpty {
                    noResultsState
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(filteredAndSorted) { job in
                        JobCardSwipeRow(job: job, onDelete: { scheduleDelete(job) })
                            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
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
                                    .shadow(color: Color.accentColor.opacity(0.30), radius: 14, y: 5)
                            }
                    }
                    .buttonStyle(FABStyle())
                    .scaleEffect(contentAppeared ? 1 : 0.75)
                    .opacity(contentAppeared ? 1 : 0)
                    .animation(.appSmooth.delay(0.18), value: contentAppeared)
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }

            // Undo delete toast
            if pendingDeleteJob != nil {
                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(red: 0.93, green: 0.38, blue: 0.44))
                        Text("Application deleted")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DarkTheme.textPrimary)
                        Spacer()
                        Button("Undo") {
                            undoDelete()
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(DarkTheme.cardFill)
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(DarkTheme.cardBorder, lineWidth: 1))
                    )
                    .shadow(color: .black.opacity(0.14), radius: 12, y: 4)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 90)
                    .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95)))
                }
                .allowsHitTesting(true)
            }
        }
        .animation(.appSmooth, value: pendingDeleteJob != nil)
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
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background {
                Capsule()
                    .fill(DarkTheme.cardFill)
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
                    .foregroundStyle(sortOption == .dateNewest ? DarkTheme.textPrimary : Color.accentColor)
                    .frame(width: 44, height: 44)
                    .background {
                        Circle()
                            .fill(DarkTheme.cardFill)
                            .overlay(Circle().strokeBorder(
                                sortOption == .dateNewest ? Color.primary.opacity(0.08) : Color.accentColor.opacity(0.35),
                                lineWidth: sortOption == .dateNewest ? 1 : 1.5
                            ))
                    }
                    .overlay(alignment: .topTrailing) {
                        if sortOption != .dateNewest {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 7, height: 7)
                                .padding(9)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .animation(.appCrisp, value: sortOption)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Stats Section

    private let filterStatuses: [ApplicationStatus] = [.toApply, .applied, .interview, .offer, .rejected]

    private var statsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .center, spacing: 0) {
                // Selected group — tight spacing, visually clustered
                if !selectedStatuses.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(filterStatuses.filter { selectedStatuses.contains($0) }, id: \.self) { status in
                            chipView(for: status)
                                .matchedGeometryEffect(id: status, in: filterNS)
                        }
                    }

                    if selectedStatuses.count < filterStatuses.count {
                        Capsule()
                            .fill(Color.primary.opacity(0.15))
                            .frame(width: 1, height: 22)
                            .padding(.horizontal, 10)
                            .transition(.opacity)
                    }
                }

                // Unselected group
                HStack(spacing: 10) {
                    ForEach(filterStatuses.filter { !selectedStatuses.contains($0) }, id: \.self) { status in
                        chipView(for: status)
                            .matchedGeometryEffect(id: status, in: filterNS)
                    }
                }
            }
            .padding(.horizontal, 20)
            .animation(.appCrisp, value: selectedStatuses)
        }
    }

    @ViewBuilder
    private func chipView(for status: ApplicationStatus) -> some View {
        let count = searchFiltered.filter { $0.status == status }.count
        StatChip(
            status: status,
            number: count,
            isSelected: selectedStatuses.contains(status),
            action: {
                if selectedStatuses.contains(status) {
                    selectedStatuses.remove(status)
                } else {
                    selectedStatuses.insert(status)
                }
            }
        )
        .opacity(count == 0 && !selectedStatuses.contains(status) ? 0.4 : 1.0)
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
                withAnimation(.appSmooth) {
                    searchText = ""
                    selectedStatuses = []
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

    // MARK: - Delete with Undo

    private func scheduleDelete(_ job: JobApplication) {
        withAnimation(.appSmooth) {
            pendingDeleteJob = job
        }
        undoTask?.cancel()
        undoTask = Task {
            do { try await Task.sleep(for: .seconds(4)) } catch { return }
            await MainActor.run {
                modelContext.delete(job)
                withAnimation(.appSmooth) { pendingDeleteJob = nil }
            }
        }
        AppHaptics.shared.medium()
    }

    private func undoDelete() {
        undoTask?.cancel()
        undoTask = nil
        withAnimation(.appSmooth) { pendingDeleteJob = nil }
        AppHaptics.shared.light()
    }
}

private struct FABStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? AppAnimations.pressScale : 1.0)
            .animation(.appFastOut, value: configuration.isPressed)
    }
}

// MARK: - Progressive Swipe Row

private struct JobCardSwipeRow: View {
    let job: JobApplication
    let onDelete: () -> Void

    @GestureState private var dragOffset: CGFloat = 0

    private let advanceThresholds: [CGFloat] = [65, 130, 200]
    private let deleteThreshold: CGFloat = 80

    private var pipeline: [ApplicationStatus] {
        let all: [ApplicationStatus] = [.toApply, .applied, .interview, .offer]
        guard let s = job.status, let idx = all.firstIndex(of: s) else { return [] }
        return Array(all.dropFirst(idx + 1))
    }

    private func stageFor(_ offset: CGFloat) -> Int {
        var stage = 0
        for (i, threshold) in advanceThresholds.enumerated() {
            guard i < pipeline.count else { break }
            if offset >= threshold { stage = i + 1 }
        }
        return stage
    }

    private var currentStage: Int { dragOffset > 0 ? stageFor(dragOffset) : 0 }

    var body: some View {
        ZStack(alignment: dragOffset < 0 ? .trailing : .leading) {
            swipeBackground
            ZStack {
                NavigationLink(destination: JobDetailView(job: job)) { EmptyView() }
                    .opacity(0)
                DarkJobCardView(job: job)
            }
            .offset(x: cardOffset(dragOffset))
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.85), value: dragOffset)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 12)
                .updating($dragOffset) { value, state, _ in
                    let dx = value.translation.width
                    guard abs(dx) > abs(value.translation.height) else { return }
                    if dx > 0, pipeline.isEmpty { return }
                    state = dx
                }
                .onEnded { value in
                    let dx = value.translation.width
                    if dx > 0 {
                        let stage = stageFor(dx)
                        guard stage > 0, stage - 1 < pipeline.count else { return }
                        withAnimation(.appSmooth) {
                            job.status = pipeline[stage - 1]
                        }
                        AppHaptics.shared.medium()
                    } else if dx < -deleteThreshold {
                        onDelete()
                    }
                }
        )
        .onChange(of: currentStage) { old, new in
            guard new > old, new > 0 else { return }
            AppHaptics.shared.light()
        }
    }

    @ViewBuilder
    private var swipeBackground: some View {
        if dragOffset > 5, !pipeline.isEmpty {
            let idx = max(0, min(currentStage - 1, pipeline.count - 1))
            let target = pipeline[idx]
            let style = DarkTheme.statusStyle(for: target)
            HStack(spacing: 8) {
                Image(systemName: style.iconName).font(.system(size: 16, weight: .bold))
                Text(target.rawValue).font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(style.tintColor)
            .padding(.leading, 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DarkTheme.cardRadius, style: .continuous)
                    .fill(style.fillColor)
                    .overlay(RoundedRectangle(cornerRadius: DarkTheme.cardRadius, style: .continuous)
                        .strokeBorder(style.borderColor, lineWidth: 1))
            )
            .opacity(min(1.0, dragOffset / advanceThresholds[0]))
            .animation(.appFastOut, value: target)
        } else if dragOffset < -5 {
            let c = Color(red: 0.93, green: 0.38, blue: 0.44)
            HStack(spacing: 8) {
                Image(systemName: "trash.fill").font(.system(size: 16, weight: .bold))
                Text("Delete").font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(c)
            .padding(.trailing, 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .background(
                RoundedRectangle(cornerRadius: DarkTheme.cardRadius, style: .continuous)
                    .fill(c.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: DarkTheme.cardRadius, style: .continuous)
                        .strokeBorder(c.opacity(0.28), lineWidth: 1))
            )
            .opacity(min(1.0, abs(dragOffset) / deleteThreshold))
        }
    }

    private func cardOffset(_ raw: CGFloat) -> CGFloat {
        if raw > 0 {
            let d = raw * 0.70
            return d > 165 ? 165 + (d - 165) * 0.18 : d
        } else if raw < 0 {
            let d = raw * 0.70
            return d < -110 ? -110 + (d + 110) * 0.18 : d
        }
        return 0
    }
}

#Preview {
    let container = try! ModelContainer(
        for: JobApplication.self, ResumeDocument.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let ctx = container.mainContext
    let samples: [(String, String, ApplicationType, ApplicationStatus, ApplicationSeason, Int)] = [
        ("Meta",      "Software Engineering Intern",  .internship, .applied,   .summer, 5),
        ("Uber",      "iOS Engineer Intern",          .internship, .interview, .summer, 8),
        ("JPMorgan",  "Software Engineer Intern",     .internship, .applied,   .summer, 10),
        ("Honeywell", "Embedded Systems Intern",      .internship, .rejected,  .summer, 12),
        ("Google",    "SWE Intern – iOS",             .internship, .offer,     .summer, 20),
        ("Amazon",    "SDE Intern",                   .internship, .applied,   .summer, 22),
        ("Netflix",   "Mobile Engineering Intern",    .internship, .toApply,   .summer, 24),
    ]
    for (company, position, type, status, season, days) in samples {
        ctx.insert(JobApplication(
            companyName: company, position: position,
            jobType: type, status: status, season: season,
            dateApplied: Date().addingTimeInterval(-86_400 * Double(days))
        ))
    }
    return NavigationStack { ApplicationView() }.modelContainer(container)
}
