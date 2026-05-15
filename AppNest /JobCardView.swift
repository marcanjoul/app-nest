import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct JobCardView: View {
    let job: JobApplication

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

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // Company avatar — image or letter fallback
            Group {
                #if canImport(UIKit)
                if let data = job.companyLogoImageData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                } else if !job.companyLogoName.isEmpty, UIImage(named: job.companyLogoName) != nil {
                    Image(job.companyLogoName)
                        .resizable()
                        .scaledToFill()
                } else {
                    Text(initial)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(avatarColors.foreground)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(avatarColors.background)
                }
                #else
                Text(initial)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(avatarColors.foreground)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(avatarColors.background)
                #endif
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(job.position)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    
                Text(job.companyName)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if let status = job.status {
                        let style = Theme.style(for: status)
                        StatusPill(text: status.rawValue, background: style.background, foreground: style.foreground)
                    }
                    if let season = job.season {
                        let style = Theme.style(for: season)
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
    }
}

#Preview {
    VStack(spacing: 10) {
        JobCardView(job: JobApplication(
            companyName: "Google",
            companyLogoName: "google",
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
    .modelContainer(for: JobApplication.self, inMemory: true)
}
