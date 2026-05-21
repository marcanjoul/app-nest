import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct JobCardView: View {
    let job: JobApplication
    let isEditMode: Bool = false

    private var appliedRelativeText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: job.dateApplied, relativeTo: Date())
    }
    
    private var avatarColors: (background: Color, foreground: Color) {
        Theme.avatarColor(for: job.companyName)
    }
    
    private var initial: String {
        String(job.companyName.prefix(1)).uppercased()
    }

    private var showReminderBadge: Bool {
        job.status == .toApply && job.reminderEnabled
    }

    private var reminderBadgeColor: Color {
        job.dateApplied <= Date() ? .orange : Color.accentColor
    }

    @State private var isFetchingLogo = false

    var body: some View {
        NavigationLink(destination: JobDetailView(job: job)) {
            HStack(alignment: .center, spacing: 16) {
            // Company avatar — image or letter fallback
            Group {
                #if canImport(UIKit)
                if let data = job.companyLogoImageData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                } else {
                    Text(initial)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(avatarColors.foreground)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(avatarColors.background)
                }
                #else
                Text(initial)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(avatarColors.foreground)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(avatarColors.background)
                #endif
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .background {
                if isFetchingLogo {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.primary.opacity(0.12))
                        .shimmer()
                }
            }
            .opacity(isFetchingLogo ? 0.8 : 1.0)
            .overlay(alignment: .bottomTrailing) {
                if showReminderBadge {
                    ZStack {
                        Circle()
                            .fill(reminderBadgeColor)
                            .frame(width: 20, height: 20)
                        Image(systemName: "bell.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 4, y: 4)
                    .transition(.scale.combined(with: .opacity))
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(job.position)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    
                Text(job.companyName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if let status = job.status {
                        let style = Theme.tagStyle(for: status)
                        StatusPill(text: status.rawValue, background: style.background, foreground: style.foreground)
                    }
                    if let season = job.season {
                        let style = Theme.tagStyle(for: season)
                        StatusPill(text: season.rawValue, background: style.background, foreground: style.foreground)
                    }
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.quaternary)
                
                Spacer()
                
                Text(appliedRelativeText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
        )
        .animation(.appCrisp, value: showReminderBadge)
        .animation(.appSmooth, value: isFetchingLogo)
        .task(id: job.companyName) {
            guard job.companyLogoImageData == nil else { return }
            let trimmed = job.companyName.trimmingCharacters(in: .whitespaces)
            guard trimmed.count >= 2 else { return }
            
            isFetchingLogo = true
            if let data = await LogoFetcher.fetchLogoData(for: trimmed) {
                await MainActor.run {
                    withAnimation(.appSmooth) {
                        job.companyLogoImageData = data
                        isFetchingLogo = false
                    }
                }
            } else {
                isFetchingLogo = false
            }
            }
        }
    }
}

#Preview {
    VStack(spacing: 10) {
        JobCardView(job: JobApplication(
            companyName: "Google",
            position: "Software Engineering Intern - 2026",
            jobType: .internship,
            status: .applied,
            season: .summer,
            dateApplied: Date().addingTimeInterval(-86_400 * 10)
        ))
        JobCardView(job: JobApplication(
            companyName: "Apple",
            position: "iOS Engineer Intern",
            jobType: .internship,
            status: .interview,
            season: .summer,
            dateApplied: Date().addingTimeInterval(-86_400 * 5)
        ))
        JobCardView(job: JobApplication(
            companyName: "Meta",
            position: "SDE Intern",
            jobType: .internship,
            status: .rejected,
            season: .summer,
            dateApplied: Date().addingTimeInterval(-86_400 * 20)
        ))
    }
    .padding()
    .background(Color(.systemGroupedBackground))
    .modelContainer(for: [JobApplication.self, ResumeDocument.self], inMemory: true)
}
