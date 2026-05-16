import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct ProfileStatsView: View {
    @Query(sort: \JobApplication.dateApplied, order: .reverse) private var applications: [JobApplication]
    @Query(sort: \ResumeDocument.createdAt, order: .reverse) private var resumes: [ResumeDocument]

    private var totalApplications: Int {
        applications.count
    }

    private var activeApplications: Int {
        applications.filter { $0.status == .applied || $0.status == .interview }.count
    }

    private var interviewCount: Int {
        count(for: .interview)
    }

    private var offerCount: Int {
        count(for: .offer)
    }

    private var topCompanies: [ProfileCompanyStat] {
        Dictionary(grouping: applications, by: { $0.companyName })
            .map { company, items in
                ProfileCompanyStat(
                    name: company,
                    count: items.count,
                    sample: items.first
                )
            }
            .sorted { $0.count > $1.count }
            .prefix(5)
            .map { $0 }
    }

    private var funnelSteps: [ProfileFunnelStep] {
        [
            ProfileFunnelStep(
                title: "Applied",
                count: count(for: .applied),
                subtitle: totalApplications == 0 ? "No applications yet" : percentString(Double(count(for: .applied)) / Double(totalApplications)),
                progress: totalApplications == 0 ? 0 : Double(count(for: .applied)) / Double(totalApplications),
                tint: Color(red: 0.35, green: 0.65, blue: 0.96)
            ),
            ProfileFunnelStep(
                title: "Interview",
                count: interviewCount,
                subtitle: count(for: .applied) == 0 ? "No applied apps" : percentString(Double(interviewCount) / Double(count(for: .applied))),
                progress: count(for: .applied) == 0 ? 0 : Double(interviewCount) / Double(count(for: .applied)),
                tint: Color(red: 0.96, green: 0.73, blue: 0.28)
            ),
            ProfileFunnelStep(
                title: "Offer",
                count: offerCount,
                subtitle: interviewCount == 0 ? "No interviews yet" : percentString(Double(offerCount) / Double(interviewCount)),
                progress: interviewCount == 0 ? 0 : Double(offerCount) / Double(interviewCount),
                tint: Color(red: 0.30, green: 0.80, blue: 0.45)
            )
        ]
    }

    private var statusRows: [ProfileStatusRowModel] {
        ApplicationStatus.allCases.map { status in
            let count = self.count(for: status)
            return ProfileStatusRowModel(
                status: status,
                count: count,
                progress: totalApplications == 0 ? 0 : Double(count) / Double(totalApplications)
            )
        }
    }

    var body: some View {
        ZStack {
            AmbientBackground()

            ScrollView {
                VStack(spacing: 18) {
                    kpiSection
                    statusBreakdownSection
                    conversionFunnelSection
                    topCompaniesSection
                }
                .padding()
            }
        }
        .navigationTitle("Profile Stats")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var kpiSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(icon: "chart.bar.xaxis", title: "KPI Summary")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ProfileMetricTile(
                    title: "Tracked",
                    value: "\(totalApplications)",
                    systemImage: "tray.full",
                    tint: Color.accentColor,
                    subtitle: "Applications"
                )

                ProfileMetricTile(
                    title: "Active",
                    value: "\(activeApplications)",
                    systemImage: "hourglass.badge.plus",
                    tint: Color(red: 0.35, green: 0.65, blue: 0.96),
                    subtitle: "Applied + interview"
                )

                ProfileMetricTile(
                    title: "Interview rate",
                    value: percentString(interviewCount, over: totalApplications),
                    systemImage: "person.crop.circle.badge.checkmark",
                    tint: Color(red: 0.96, green: 0.73, blue: 0.28),
                    subtitle: "Of tracked apps"
                )

                ProfileMetricTile(
                    title: "Offers",
                    value: "\(offerCount)",
                    systemImage: "hands.sparkles.fill",
                    tint: Color(red: 0.30, green: 0.80, blue: 0.45),
                    subtitle: percentString(offerCount, over: totalApplications)
                )
            }

            Text("\(resumes.count) resume\(resumes.count == 1 ? "" : "s") stored in your profile.")
                .font(.footnote)
                .foregroundStyle(DarkTheme.textSecondary)
        }
        .padding(18)
        .glassCard()
    }

    private var statusBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(icon: "chart.pie.fill", title: "Status Breakdown")

            VStack(spacing: 12) {
                ForEach(statusRows) { row in
                    ProfileStatusBreakdownRow(row: row)
                }
            }
        }
        .padding(18)
        .glassCard()
    }

    private var conversionFunnelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(icon: "arrow.triangle.branch", title: "Conversion Funnel")

            VStack(spacing: 12) {
                ForEach(funnelSteps) { step in
                    ProfileFunnelRow(step: step)
                }
            }
        }
        .padding(18)
        .glassCard()
    }

    private var topCompaniesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(icon: "building.2.fill", title: "Top Companies")

            if topCompanies.isEmpty {
                Text("Add applications to see which companies show up most often.")
                    .font(.footnote)
                    .foregroundStyle(DarkTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 12) {
                    ForEach(topCompanies) { company in
                        ProfileCompanyRow(company: company, totalApplications: totalApplications)
                    }
                }
            }
        }
        .padding(18)
        .glassCard()
    }

    private func count(for status: ApplicationStatus) -> Int {
        applications.filter { $0.status == status }.count
    }

    private func percentString(_ value: Double) -> String {
        String(format: "%.0f%%", max(0, min(1, value)) * 100)
    }

    private func percentString(_ value: Int, over total: Int) -> String {
        percentString(total == 0 ? 0 : Double(value) / Double(total))
    }
}

struct ProfileMetricTile: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 18)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DarkTheme.textSecondary)

                Spacer(minLength: 0)
            }

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(DarkTheme.textPrimary)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(DarkTheme.textTertiary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8)
                )
        }
    }
}

private struct ProfileStatusRowModel: Identifiable {
    let id = UUID()
    let status: ApplicationStatus
    let count: Int
    let progress: Double
}

private struct ProfileStatusBreakdownRow: View {
    let row: ProfileStatusRowModel

    private var style: DarkTheme.StatusStyle {
        DarkTheme.statusStyle(for: row.status)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: style.iconName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(style.tintColor)

                Text(row.status.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DarkTheme.textPrimary)

                Spacer()

                Text("\(row.count)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(style.tintColor)
            }

            ProfileProgressBar(progress: row.progress, tint: style.tintColor)
        }
    }
}

private struct ProfileFunnelStep: Identifiable {
    let id = UUID()
    let title: String
    let count: Int
    let subtitle: String
    let progress: Double
    let tint: Color
}

private struct ProfileFunnelRow: View {
    let step: ProfileFunnelStep

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(step.tint)
                    .frame(width: 8, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(step.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DarkTheme.textPrimary)

                    Text(step.subtitle)
                        .font(.caption)
                        .foregroundStyle(DarkTheme.textSecondary)
                }

                Spacer()

                Text("\(step.count)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(step.tint)
            }

            ProfileProgressBar(progress: step.progress, tint: step.tint)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8)
                )
        }
    }
}

private struct ProfileCompanyStat: Identifiable {
    let id: String
    let name: String
    let count: Int
    let sample: JobApplication?

    init(name: String, count: Int, sample: JobApplication?) {
        self.id = name
        self.name = name
        self.count = count
        self.sample = sample
    }
}

private struct ProfileCompanyRow: View {
    let company: ProfileCompanyStat
    let totalApplications: Int

    private var share: Double {
        totalApplications == 0 ? 0 : Double(company.count) / Double(totalApplications)
    }

    private var avatarTint: Color {
        // LinearGradient doesn't expose its colors; pick a stable representative color
        let palette: [Color] = [
            Color(red: 0.35, green: 0.65, blue: 0.96),
            Color(red: 0.96, green: 0.73, blue: 0.28),
            Color(red: 0.30, green: 0.80, blue: 0.45),
            Color.pink,
            Color.purple,
            Color.indigo,
            Color.teal
        ]
        let hash = abs(company.name.hashValue)
        return palette[hash % palette.count]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ProfileCompanyAvatarView(company: company)
                    .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text(company.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DarkTheme.textPrimary)

                    Text(company.sample?.companyLogoName.isEmpty == false ? "Logo asset" : "Company avatar")
                        .font(.caption)
                        .foregroundStyle(DarkTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Text("\(company.count)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(DarkTheme.textPrimary)
            }

            ProfileProgressBar(progress: share, tint: avatarTint)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8)
                )
        }
    }
}

private struct ProfileCompanyAvatarView: View {
    let company: ProfileCompanyStat

    private var initial: String {
        String(company.name.prefix(1)).uppercased()
    }

    var body: some View {
        ZStack {
            if let sample = company.sample, let imageData = sample.companyLogoImageData {
#if canImport(UIKit)
                if let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    fallback
                }
#else
                fallback
#endif
            } else if let sample = company.sample, !sample.companyLogoName.isEmpty {
#if canImport(UIKit)
                if UIImage(named: sample.companyLogoName) != nil {
                    Image(sample.companyLogoName)
                        .resizable()
                        .scaledToFill()
                } else {
                    fallback
                }
#else
                fallback
#endif
            } else {
                fallback
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var fallback: some View {
        Text(initial)
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DarkTheme.avatarGradient(for: company.name))
    }
}

private struct ProfileProgressBar: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.07))

                Capsule()
                    .fill(tint)
                    .frame(width: proxy.size.width * max(0, min(1, progress)))
            }
        }
        .frame(height: 8)
    }
}

#Preview {
    NavigationStack {
        ProfileStatsView()
    }
    .modelContainer(for: [JobApplication.self, ResumeDocument.self], inMemory: true)
}
