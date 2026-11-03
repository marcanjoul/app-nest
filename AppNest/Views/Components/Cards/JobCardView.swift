import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Job Card View

/// Application summary with company logo, status, and job type.
struct DarkJobCardView: View {
    let job: JobApplication
    /// Off in edit mode, where a tap anywhere on the card selects it.
    var isInteractive = true
    /// The status dropdown is open for this card (drawn by the list, over the screen).
    var isStatusOpen = false
    /// Asks the list to open the status dropdown: the pill's and the card's global frames.
    var onStatusTap: ((_ pill: CGRect, _ card: CGRect) -> Void)? = nil

    @State private var pillFrame: CGRect = .zero
    @State private var cardFrame: CGRect = .zero

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private var dateText: String {
        Self.relativeDateFormatter.localizedString(for: job.dateApplied, relativeTo: Date())
    }


    #if canImport(UIKit)
    // ponytail: UIImage(data:) decodes on every body pass — cache it. Key includes byte
    // count so a replaced logo for the same company still invalidates.
    private static let decodedLogos = NSCache<NSString, UIImage>()

    private var logoImage: UIImage? {
        guard let data = job.companyLogoImageData else { return nil }
        let key = "\(job.companyName)-\(data.count)" as NSString
        if let cached = Self.decodedLogos.object(forKey: key) { return cached }
        guard let ui = UIImage(data: data) else { return nil }
        Self.decodedLogos.setObject(ui, forKey: key)
        return ui
    }
    #endif

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            avatarView
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(job.position)
                    .appFont(.headline, weight: .semibold)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .padding(.bottom, -2)   // 4pt to the company line; the rest of the stack stays at 6

                HStack {
                    Text(job.companyName)
                        .appFont(.body)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    Text(dateText)
                        .appFont(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    // No long-press menus on cards: status changes through this dropdown, the
                    // rest in the job's detail view.
                    if let status = job.status {
                        Button {
                            onStatusTap?(pillFrame, cardFrame)
                        } label: {
                            DarkStatusPill(status: status, isOpen: onStatusTap == nil ? nil : isStatusOpen)
                                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { pillFrame = $0 }
                        }
                        .buttonStyle(PressScaleButtonStyle())
                        .allowsHitTesting(isInteractive && onStatusTap != nil)
                        .accessibilityLabel("Status: \(status.rawValue)")
                        .accessibilityHint("Shows the other statuses")
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
        .surface(cornerRadius: Theme.cardRadius)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { cardFrame = $0 }
        .task(id: job.companyName) {
            guard !job.logoRemoved, job.companyLogoImageData == nil else { return }
            let trimmed = job.companyName.trimmingCharacters(in: .whitespaces)
            guard trimmed.count >= 2 else { return }
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
                AppHaptics.shared.success()
            }
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        #if canImport(UIKit)
        if let ui = logoImage {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white.opacity(0.05))
        } else {
            InitialAvatar(name: job.companyName, fontSize: 20)
        }
        #else
        InitialAvatar(name: job.companyName, fontSize: 20)
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
