import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// Dedicated insights screen pushed from `ProfileView`. Shows aggregate
/// stats about the user's applications: KPI summary, status breakdown,
/// conversion funnel, and top companies.
struct ProfileStatsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Query(sort: \JobApplication.dateApplied, order: .reverse) private var applications: [JobApplication]
    @Query(sort: \JobCycle.createdAt, order: .reverse) private var cycles: [JobCycle]

    @State private var animateProgress = false

    private var displayedApplications: [JobApplication] {
        guard let id = appState.selectedCycleID else { return applications }
        return applications.filter { $0.cycle?.id == id }
    }

    // MARK: - Computed metrics

    private var totalCount: Int { displayedApplications.count }
    private var appliedCount: Int { count(for: .applied) }
    private var interviewCount: Int { count(for: .interview) }
    private var offerCount: Int { count(for: .offer) }
    private var rejectedCount: Int { count(for: .rejected) }
    private var activeCount: Int { appliedCount + interviewCount }

    /// Anything past the "applied" stage as a percentage of applied.
    private var responseRate: Double {
        guard appliedCount + interviewCount + offerCount + rejectedCount > 0 else { return 0 }
        let responded = interviewCount + offerCount + rejectedCount
        let denom = max(1, appliedCount + interviewCount + offerCount + rejectedCount)
        return Double(responded) / Double(denom)
    }

    private var statusRows: [(ApplicationStatus, Int)] {
        ApplicationStatus.allCases.map { ($0, count(for: $0)) }
    }

    private var maxStatusCount: Int {
        max(1, statusRows.map(\.1).max() ?? 1)
    }

    private var topCompanies: [(name: String, count: Int, sample: JobApplication?)] {
        Dictionary(grouping: displayedApplications, by: { $0.companyName })
            .map { (name: $0.key, count: $0.value.count, sample: $0.value.first) }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count { return lhs.name < rhs.name }
                return lhs.count > rhs.count
            }
            .prefix(5)
            .map { ($0.name, $0.count, $0.sample) }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AmbientBackground()

            ScrollView {
                if displayedApplications.isEmpty {
                    emptyState
                        .padding(.top, 60)
                        .padding(.horizontal, 24)
                } else {
                    VStack(spacing: 18) {
                        summarySection
                        statusBreakdownSection
                        if appliedCount + interviewCount + offerCount > 0 {
                            funnelSection
                        }
                        if !topCompanies.isEmpty {
                            topCompaniesSection
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    .padding(.bottom, 120)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 40, height: 40)
                        .background {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(Circle().strokeBorder(Color.primary.opacity(0.09), lineWidth: 1))
                        }
                }
                .buttonStyle(PressScaleButtonStyle())

                Spacer()

                Text("Insights")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                Color.clear.frame(width: 40, height: 40)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .onAppear {
            // Trigger progress animations on screen entry
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                animateProgress = true
            }
        }
    }

    // MARK: - Sections

    private var summarySection: some View {
        VStack(spacing: 14) {
            HStack {
                Label("Summary", systemImage: "chart.bar.xaxis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
            }

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                StatsKPITile(
                    label: "Total",
                    value: "\(totalCount)",
                    tint: Color.accentColor,
                    icon: "tray.full.fill"
                )
                StatsKPITile(
                    label: "Active",
                    value: "\(activeCount)",
                    tint: Color(red: 0.35, green: 0.65, blue: 0.96),
                    icon: "paperplane.fill"
                )
                StatsKPITile(
                    label: "Offers",
                    value: "\(offerCount)",
                    tint: Color(red: 0.30, green: 0.80, blue: 0.45),
                    icon: "checkmark.seal.fill"
                )
                StatsKPITile(
                    label: "Response Rate",
                    value: appliedCount + interviewCount + offerCount + rejectedCount > 0
                        ? "\(Int((responseRate * 100).rounded()))%"
                        : "—",
                    tint: Color(red: 0.96, green: 0.73, blue: 0.28),
                    icon: "envelope.open.fill"
                )
            }
        }
        .padding(18)
        .glassCard()
    }

    private var statusBreakdownSection: some View {
        VStack(spacing: 14) {
            HStack {
                Label("Status Breakdown", systemImage: "list.bullet.rectangle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
            }

            VStack(spacing: 14) {
                ForEach(statusRows, id: \.0) { status, count in
                    StatusBreakdownRow(
                        status: status,
                        count: count,
                        maxCount: maxStatusCount,
                        animate: animateProgress
                    )
                }
            }
        }
        .padding(18)
        .glassCard()
    }

    private var funnelSection: some View {
        let appliedTotal = max(1, appliedCount + interviewCount + offerCount + rejectedCount)
        let interviewProgress = Double(interviewCount + offerCount) / Double(appliedTotal)
        let offerProgress = Double(offerCount) / Double(appliedTotal)

        return VStack(spacing: 14) {
            HStack {
                Label("Conversion Funnel", systemImage: "arrow.down.right.circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
            }

            VStack(spacing: 0) {
                FunnelRow(
                    title: "Applied",
                    count: appliedTotal,
                    progress: 1.0,
                    tint: Color(red: 0.35, green: 0.65, blue: 0.96),
                    icon: "paperplane.fill",
                    animate: animateProgress,
                    isFirst: true
                )
                
                FunnelConnector(progress: interviewProgress, tint: Color(red: 0.96, green: 0.73, blue: 0.28), animate: animateProgress)
                
                FunnelRow(
                    title: "Interview",
                    count: interviewCount + offerCount,
                    progress: interviewProgress,
                    tint: Color(red: 0.96, green: 0.73, blue: 0.28),
                    icon: "person.2.fill",
                    animate: animateProgress
                )
                
                FunnelConnector(progress: offerProgress, tint: Color(red: 0.30, green: 0.80, blue: 0.45), animate: animateProgress)

                FunnelRow(
                    title: "Offer",
                    count: offerCount,
                    progress: offerProgress,
                    tint: Color(red: 0.30, green: 0.80, blue: 0.45),
                    icon: "checkmark.seal.fill",
                    animate: animateProgress,
                    isLast: true
                )
            }
            .padding(.top, 4)
        }
        .padding(18)
        .glassCard()
    }

    private var topCompaniesSection: some View {
        VStack(spacing: 14) {
            HStack {
                Label("Top Companies", systemImage: "building.2.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
            }

            VStack(spacing: 10) {
                ForEach(Array(topCompanies.enumerated()), id: \.element.name) { index, company in
                    TopCompanyRow(
                        rank: index + 1,
                        name: company.name,
                        count: company.count,
                        sample: company.sample
                    )
                }
            }
        }
        .padding(18)
        .glassCard()
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Theme.textSecondary.opacity(0.5))
            Text("No insights yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("Track a few applications to see your status breakdown, conversion funnel, and top companies here.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func count(for status: ApplicationStatus) -> Int {
        displayedApplications.filter { $0.status == status }.count
    }
}

// MARK: - KPI Tile

private struct StatsKPITile: View {
    let label: String
    let value: String
    let tint: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.5)
            }
            .foregroundStyle(tint)

            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                )
        }
    }
}

// MARK: - Breakdown Row

private struct StatusBreakdownRow: View {
    let status: ApplicationStatus
    let count: Int
    let maxCount: Int
    var animate: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(status.rawValue)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.05))
                    Capsule()
                        .fill(status.color)
                        .frame(width: animate ? geo.size.width * CGFloat(count) / CGFloat(maxCount) : 0)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Funnel Row

private struct FunnelRow: View {
    let title: String
    let count: Int
    let progress: Double
    let tint: Color
    let icon: String
    var animate: Bool = false
    var isFirst: Bool = false
    var isLast: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(tint)
            }
            .background {
                VStack(spacing: 0) {
                    if !isFirst {
                        Rectangle().fill(tint.opacity(0.08)).frame(width: 2)
                    } else {
                        Color.clear.frame(height: 16)
                    }
                    if !isLast {
                        Rectangle().fill(tint.opacity(0.08)).frame(width: 2)
                    } else {
                        Color.clear.frame(height: 16)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text("\(count)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.05))
                        Capsule()
                            .fill(tint)
                            .frame(width: animate ? geo.size.width * CGFloat(progress) : 0)
                            .shadow(color: tint.opacity(0.15), radius: 4, y: 2)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(.vertical, 8)
    }
}

private struct FunnelConnector: View {
    let progress: Double
    let tint: Color
    let animate: Bool
    
    var body: some View {
        HStack {
            Spacer().frame(width: 15)
            Rectangle()
                .fill(tint.opacity(0.08))
                .frame(width: 2, height: 12)
            Spacer()
        }
    }
}

// MARK: - Top Company Row

private struct TopCompanyRow: View {
    let rank: Int
    let name: String
    let count: Int
    let sample: JobApplication?

    private var initial: String {
        String(name.prefix(1)).uppercased()
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .frame(width: 14)

            avatar
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)

            Spacer()

            Text("\(count) app\(count == 1 ? "" : "s")")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.primary.opacity(0.07)))
        }
    }

    @ViewBuilder
    private var avatar: some View {
        #if canImport(UIKit)
        if let sample, let data = sample.companyLogoImageData, let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            initialAvatar
        }
        #else
        initialAvatar
        #endif
    }

    private var initialAvatar: some View {
        ZStack {
            Theme.avatarFill(for: name)
            Text(initial)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    NavigationStack {
        ProfileStatsView()
    }
    .environment(AppState())
    .modelContainer(for: [JobApplication.self, ResumeDocument.self, JobCycle.self], inMemory: true)
}
