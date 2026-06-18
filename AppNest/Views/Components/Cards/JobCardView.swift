import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct SparkleView: View {
    let color: Color
    
    @State private var particles: [SparkleParticle] = []
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                updateParticles(at: now)
                
                for particle in particles {
                    var pContext = context
                    pContext.opacity = particle.opacity
                    pContext.translateBy(x: particle.x, y: particle.y)
                    pContext.rotate(by: .radians(particle.rotation))
                    
                    let rect = CGRect(
                        x: -particle.size/2,
                        y: -particle.size/2,
                        width: particle.size,
                        height: particle.size
                    )
                    
                    if let resolved = context.resolveSymbol(id: particle.id) {
                        pContext.draw(resolved, in: rect)
                    }
                }
            } symbols: {
                ForEach(particles) { particle in
                    Image(systemName: particle.systemImage)
                        .font(.system(size: particle.size))
                        .foregroundStyle(color)
                        .tag(particle.id)
                }
            }
        }
        .frame(width: 120, height: 120)
        .onAppear {
            spawnParticles()
        }
    }
    
    @State private var lastUpdateTime: Double = 0.0
    
    private func spawnParticles() {
        var newParticles: [SparkleParticle] = []
        let shapes = ["sparkles", "star.fill", "circle.fill", "sparkle"]
        
        for _ in 0..<16 {
            let angle = Double.random(in: 0...(Double.pi * 2))
            let speed = CGFloat.random(in: 3...7)
            let vx = cos(angle) * speed
            let vy = sin(angle) * speed - CGFloat.random(in: 1...3)
            
            newParticles.append(SparkleParticle(
                x: 60,
                y: 60,
                vx: vx,
                vy: vy,
                size: CGFloat.random(in: 8...16),
                opacity: 1.0,
                systemImage: shapes.randomElement() ?? "sparkles",
                rotation: Double.random(in: 0...(Double.pi * 2)),
                rotVelocity: Double.random(in: -5...5)
            ))
        }
        particles = newParticles
        lastUpdateTime = Date().timeIntervalSinceReferenceDate
    }
    
    private func updateParticles(at now: Double) {
        if lastUpdateTime == 0.0 {
            lastUpdateTime = now
            return
        }
        
        let dt = CGFloat(min(now - lastUpdateTime, 0.03))
        lastUpdateTime = now
        
        let gravity: CGFloat = 8.0
        let drag: CGFloat = 0.96
        
        for i in 0..<particles.count {
            particles[i].vx *= drag
            particles[i].vy *= drag
            particles[i].vy += gravity * dt
            particles[i].x += particles[i].vx
            particles[i].y += particles[i].vy
            particles[i].rotation += particles[i].rotVelocity * Double(dt)
            particles[i].opacity -= 0.65 * Double(dt)
        }
        
        particles.removeAll { $0.opacity <= 0 }
    }
}

struct SparkleParticle: Identifiable {
    let id: UUID = UUID()
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var size: CGFloat
    var opacity: Double
    var systemImage: String
    var rotation: Double
    var rotVelocity: Double
}


// MARK: - Job Card View

/// Full glassmorphic job application card with avatar, status pill, and type tag.
struct DarkJobCardView: View {
    @Environment(AppState.self) private var appState
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
                appState.showOfferCelebration = true
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
