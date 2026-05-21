import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Status Pill

/// Glassmorphic status pill with SF Symbol icon and colored gradient capsule.
struct DarkStatusPill: View {
    let status: ApplicationStatus

    private var style: Theme.StatusStyle { Theme.statusStyle(for: status) }

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
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(style.tintColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(style.fillColor)
                .overlay(Capsule().strokeBorder(style.borderColor, lineWidth: 0.8))
        )
    }
}

// MARK: - Type Tag

/// Subtle glass capsule tag for displaying job type on cards.
struct DarkTypeTag: View {
    let text: String
    var icon: String? = nil
    var color: Color = Theme.textSecondary

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
            }
            Text(text)
                .font(.system(size: 11, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(color.opacity(0.08))
                .overlay(Capsule().strokeBorder(color.opacity(0.15), lineWidth: 0.5))
        )
    }
}

// MARK: - Stat Pill

/// Tappable status-tinted pill that shows a count and acts as a filter toggle.
struct StatChip: View {
    let status: ApplicationStatus
    let number: Int
    var isSelected: Bool = false
    var action: (() -> Void)? = nil

    private var style: Theme.StatusStyle { Theme.statusStyle(for: status) }

    private var label: String {
        switch status {
        case .toApply:    return "To Apply"
        case .applied:    return "Applied"
        case .interview:  return "Interview"
        case .offer:      return "Offers"
        case .rejected:   return "Rejected"
        case .ghosted:    return "Ghosted"
        case .jobRemoved: return "Removed"
        }
    }

    var body: some View {
        Button {
            AppHaptics.shared.light()
            action?()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: style.iconName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isSelected ? Color.white : style.tintColor)

                Text("\(number)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? Color.white : Theme.textPrimary)
                    .contentTransition(.numericText())
                    .animation(.appCrisp, value: number)

                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.88) : Theme.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isSelected ? AnyShapeStyle(style.tintColor) : AnyShapeStyle(style.fillColor))
                    .overlay(
                        Capsule().strokeBorder(
                            isSelected ? Color.clear : style.borderColor,
                            lineWidth: isSelected ? 0 : 0.8
                        )
                    )
            )
        }
        .buttonStyle(PressScaleButtonStyle())
        .animation(.appCrisp, value: isSelected)
    }
}

// MARK: - Sparkle Animation

struct SparkleView: View {
    @State private var animate = false
    @State private var offsets: [(CGFloat, CGFloat)] = []
    @State private var sizes: [CGFloat] = []
    let color: Color

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                if i < offsets.count {
                    Image(systemName: "sparkles")
                        .font(.system(size: sizes[i]))
                        .foregroundStyle(color)
                        .offset(x: animate ? offsets[i].0 : 0,
                                y: animate ? offsets[i].1 : 0)
                        .scaleEffect(animate ? 0.2 : 1.2)
                        .opacity(animate ? 0 : 1)
                        .rotationEffect(.degrees(Double(i) * 60))
                }
            }
        }
        .onAppear {
            offsets = (0..<6).map { _ in (CGFloat.random(in: -30...30), CGFloat.random(in: -30...30)) }
            sizes   = (0..<6).map { _ in CGFloat.random(in: 12...20) }
            withAnimation(.easeOut(duration: 1.2)) { animate = true }
        }
    }
}

// MARK: - Dark Job Card View

/// Full glassmorphic job application card with avatar and status pill.
struct DarkJobCardView: View {
    let job: JobApplication
    @State private var showCelebration = false

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private var dateText: String {
        Self.relativeDateFormatter.localizedString(for: job.dateApplied, relativeTo: Date())
    }

    private var initial: String { String(job.companyName.prefix(1)).uppercased() }

    private var subtitleText: String {
        guard let type = job.jobType else { return job.companyName }
        return "\(job.companyName)  ·  \(type.rawValue)"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            avatarView
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.20), radius: 4, y: 2)
                .overlay {
                    if showCelebration {
                        SparkleView(color: Color(red: 0.30, green: 0.80, blue: 0.45))
                            .onAppear {
                                // Automatically reset after animation to prevent repetitive triggers
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    showCelebration = false
                                }
                            }
                    }
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(job.position)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack {
                    Text(job.companyName)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    Text(dateText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    if let status = job.status {
                        DarkStatusPill(status: status)
                    }
                    if let type = job.jobType {
                        DarkTypeTag(text: type.rawValue, icon: type.iconName, color: type.color)
                    }
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .glassCard(cornerRadius: Theme.cardRadius)
        .task(id: job.companyName) {
            guard job.companyLogoImageData == nil else { return }
            let trimmed = job.companyName.trimmingCharacters(in: .whitespaces)
            guard trimmed.count >= 2 else { return }
            
            // Fetch logo
            if let data = await LogoFetcher.fetchLogoData(for: trimmed) {
                await MainActor.run {
                    withAnimation(.appSmooth) {
                        job.companyLogoImageData = data
                    }
                }
            }
        }
        .onChange(of: job.status) { old, new in
            if new == .offer && old != .offer {
                showCelebration = true
                AppHaptics.shared.success()
            }
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        #if canImport(UIKit)
        if let data = job.companyLogoImageData, let ui = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white.opacity(0.05))
        } else {
            Text(initial)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.avatarFill(for: job.companyName))
        }
        #else
        Text(initial)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.avatarFill(for: job.companyName))
        #endif
    }
}

#Preview {
    ZStack {
        AmbientBackground()
        VStack {
            DarkJobCardView(job: JobApplication(
                companyName: "Google",
                position: "Product Design Intern",
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
