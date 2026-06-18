import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

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

// MARK: - Job Card View

/// Full glassmorphic job application card with avatar, status pill, and type tag.
struct DarkJobCardView: View {
    let job: JobApplication
    @State private var showCelebration = false
    @State private var showStatusMenu = false
    @State private var showTypeMenu = false

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private var dateText: String {
        Self.relativeDateFormatter.localizedString(for: job.dateApplied, relativeTo: Date())
    }

    private var initial: String { String(job.companyName.prefix(1)).uppercased() }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            avatarView
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.20), radius: 4, y: 2)
                .overlay {
                    if showCelebration {
                        SparkleView(color: Color(red: 0.30, green: 0.80, blue: 0.45))
                            .transition(.opacity)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    showCelebration = false
                                }
                            }
                    }
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(job.position)
                    .appFont(16, weight: .bold)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack {
                    Text(job.companyName)
                        .appFont(14)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    Text(dateText)
                        .appFont(11)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    if let status = job.status {
                        DarkStatusPill(status: status)
                            .onLongPressGesture(minimumDuration: 0.35) {
                                AppHaptics.shared.medium()
                                showStatusMenu = true
                            }
                            .sheet(isPresented: $showStatusMenu) {
                                PillPickerSheet(
                                    current: job.status,
                                    colorFor: { $0.color },
                                    iconFor: { $0.iconName }
                                ) { newStatus in
                                    withAnimation(.appSmooth) { job.status = newStatus }
                                }
                                .presentationDetents([.height(290)])
                                .presentationCornerRadius(24)
                                .presentationDragIndicator(.hidden)
                                .presentationBackground(.ultraThinMaterial)
                            }
                    }
                    if let type = job.jobType {
                        DarkTypeTag(text: type.rawValue, icon: type.iconName, color: type.color)
                            .onLongPressGesture(minimumDuration: 0.35) {
                                AppHaptics.shared.medium()
                                showTypeMenu = true
                            }
                            .sheet(isPresented: $showTypeMenu) {
                                PillPickerSheet(
                                    current: job.jobType,
                                    colorFor: { $0.color },
                                    iconFor: { $0.iconName }
                                ) { newType in
                                    withAnimation(.appSmooth) { job.jobType = newType }
                                }
                                .presentationDetents([.height(240)])
                                .presentationCornerRadius(24)
                                .presentationDragIndicator(.hidden)
                                .presentationBackground(.ultraThinMaterial)
                            }
                    }
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .glassCard(cornerRadius: Theme.cardRadius, fillOpacity: 1.0)
        .task(id: job.companyName) {
            guard job.companyLogoImageData == nil else { return }
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
                .appFont(20, weight: .bold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.avatarFill(for: job.companyName))
        }
        #else
        Text(initial)
            .appFont(20, weight: .bold)
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
