import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Status Pill

/// Glassmorphic status pill with SF Symbol icon and colored gradient capsule.
struct DarkStatusPill: View {
    let status: ApplicationStatus

    private var style: DarkTheme.StatusStyle { DarkTheme.statusStyle(for: status) }

    private var displayText: String {
        switch status {
        case .interview: return "Interview"
        default:         return status.rawValue
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: style.iconName)
                .font(.system(size: 11, weight: .semibold))
            Text(displayText)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(style.tintColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(style.gradient)
                .overlay(Capsule().strokeBorder(style.borderColor, lineWidth: 0.8))
        )
    }
}

// MARK: - Type Tag

/// Subtle glass capsule tag for displaying job type on cards.
struct DarkTypeTag: View {
    let text: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
            }
            Text(text)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(DarkTheme.textSecondary)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.primary.opacity(0.07))
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5))
        )
    }
}

// MARK: - Stat Chip

/// Glassmorphic card showing a single statistic (number + label).
struct StatChip: View {
    let number: Int
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text("\(number)")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(DarkTheme.textPrimary)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DarkTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .glassCard(cornerRadius: 16, shadowOpacity: 0.08)
    }
}

// MARK: - Job Card

/// Full glassmorphic job application card with avatar, status pill, and type tag.
struct DarkJobCardView: View {
    let job: JobApplication

    private var dateText: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: job.dateApplied, relativeTo: Date())
    }

    private var initial: String { String(job.companyName.prefix(1)).uppercased() }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            avatarView
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.20), radius: 4, y: 2)

            VStack(alignment: .leading, spacing: 5) {
                Text(job.position)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DarkTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(job.companyName)
                    .font(.system(size: 13))
                    .foregroundStyle(DarkTheme.textSecondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let status = job.status {
                        DarkStatusPill(status: status)
                    }
                    if let type = job.jobType {
                        DarkTypeTag(text: type.rawValue, icon: type.iconName)
                    }
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 0) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.quaternary)
                Spacer()
                Text(dateText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: DarkTheme.cardRadius)
    }

    @ViewBuilder
    private var avatarView: some View {
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
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DarkTheme.avatarGradient(for: job.companyName))
        }
        #else
        Text(initial)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DarkTheme.avatarGradient(for: job.companyName))
        #endif
    }
}

// MARK: - Previews

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                ForEach(ApplicationStatus.allCases, id: \.self) { DarkStatusPill(status: $0) }
            }

            HStack(spacing: 8) {
                DarkTypeTag(text: "Internship", icon: "graduationcap.fill")
                DarkTypeTag(text: "Full Time",  icon: "briefcase.fill")
            }

            HStack(spacing: 12) {
                StatChip(number: 12, label: "Applied")
                StatChip(number: 3,  label: "Interview")
                StatChip(number: 1,  label: "Offers")
            }

            DarkJobCardView(job: JobApplication(
                companyName: "Google",
                companyLogoName: "google",
                position: "Software Engineering Intern",
                jobType: .internship,
                status: .applied,
                season: .summer,
                dateApplied: Date()
            ))
        }
        .padding()
    }
    .background(AmbientBackground())
}
