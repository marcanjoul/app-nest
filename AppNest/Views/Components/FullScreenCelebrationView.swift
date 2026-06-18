import SwiftUI

struct FullScreenCelebrationView: View {
    @Environment(AppState.self) private var appState
    
    @State private var particles: [CelebrationParticle] = []
    @State private var showModal = false
    @State private var modalScale = 0.6
    @State private var modalOpacity = 0.0
    @State private var fadeOutCelebration = false
    
    private let colors: [Color] = [
        Color(red: 0.30, green: 0.80, blue: 0.45), // Offer Green
        Color(red: 0.32, green: 0.26, blue: 0.73), // Offer Purple
        Color(red: 0.96, green: 0.65, blue: 0.14), // Interview Yellow/Gold
        Color(red: 0.30, green: 0.60, blue: 0.94)  // Applied Blue
    ]
    
    private let shapes = [
        "checkmark.seal.fill",
        "sparkles",
        "star.fill",
        "circle.fill",
        "suit.heart.fill"
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dimmed background that fades in
                Color.black.opacity(fadeOutCelebration ? 0.0 : 0.3)
                    .ignoresSafeArea()
                    .animation(.easeOut(duration: 0.6), value: fadeOutCelebration)
                
                // Physics-driven particle container
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        let now = timeline.date.timeIntervalSinceReferenceDate
                        updateParticles(in: size, at: now)
                        
                        for particle in particles {
                            var pContext = context
                            pContext.opacity = particle.opacity
                            pContext.translateBy(x: particle.x, y: particle.y)
                            pContext.rotate(by: .radians(particle.rotation))
                            pContext.scaleBy(x: particle.scaleX, y: 1.0)
                            
                            let rect = CGRect(x: -particle.size/2, y: -particle.size/2, width: particle.size, height: particle.size)
                            
                            if particle.systemImage == "circle.fill" {
                                pContext.fill(Path(ellipseIn: rect), with: .color(particle.color))
                            } else if let resolved = context.resolveSymbol(id: particle.id) {
                                pContext.draw(resolved, in: rect)
                            }
                        }
                    } symbols: {
                        ForEach(particles) { particle in
                            if particle.systemImage != "circle.fill" {
                                Image(systemName: particle.systemImage)
                                    .font(.system(size: particle.size))
                                    .foregroundStyle(particle.color)
                                    .tag(particle.id)
                            }
                        }
                    }
                }
                .ignoresSafeArea()
                
                // Congratulations Dialog Card
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.30, green: 0.80, blue: 0.45).opacity(0.12))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundStyle(Color(red: 0.30, green: 0.80, blue: 0.45))
                    }
                    
                    VStack(spacing: 8) {
                        Text("Congratulations! 🎉")
                            .appFont(22, weight: .bold)
                            .foregroundStyle(Theme.textPrimary)
                        
                        Text("You've secured an offer!")
                            .appFont(15, weight: .medium)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 36)
                .background {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Theme.background)
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(Color(red: 0.30, green: 0.80, blue: 0.45).opacity(0.25), lineWidth: 1.5)
                        }
                        .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
                }
                .scaleEffect(modalScale)
                .opacity(modalOpacity)
                .padding(24)
            }
            .onAppear {
                spawnInitialParticles(in: geometry.size)
                
                // Animate Modal entrance
                withAnimation(.spring(response: 0.55, dampingFraction: 0.68, blendDuration: 0)) {
                    modalScale = 1.0
                    modalOpacity = 1.0
                }
                
                // Trigger success haptic
                AppHaptics.shared.success()
                
                // Extra sparkles bursts and pop haptic feedback
                for delay in [0.3, 0.6, 0.9, 1.2, 1.5] {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        if !fadeOutCelebration {
                            AppHaptics.shared.selection()
                            spawnBurst(in: geometry.size)
                        }
                    }
                }
                
                // Auto-dismiss timing
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation(.easeIn(duration: 0.35)) {
                        modalScale = 0.8
                        modalOpacity = 0.0
                        fadeOutCelebration = true
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        appState.showOfferCelebration = false
                    }
                }
            }
        }
    }
    
    @State private var lastUpdateTime: Double = 0.0
    
    private func spawnInitialParticles(in size: CGSize) {
        var newParticles: [CelebrationParticle] = []
        let spawnPoints = [
            CGPoint(x: size.width * 0.15, y: size.height + 20),
            CGPoint(x: size.width * 0.5, y: size.height + 20),
            CGPoint(x: size.width * 0.85, y: size.height + 20)
        ]
        
        for point in spawnPoints {
            let count = point.x == size.width * 0.5 ? 40 : 25
            for _ in 0..<count {
                let angle = point.x < size.width * 0.4 
                    ? Double.random(in: (-Double.pi/3)...(-Double.pi/6)) // Up & Right
                    : (point.x > size.width * 0.6 
                        ? Double.random(in: (-Double.pi * 5/6)...(-Double.pi * 2/3)) // Up & Left
                        : Double.random(in: (-Double.pi * 3/4)...(-Double.pi/4))) // Up
                
                let speed = CGFloat.random(in: 12...24)
                let vx = cos(angle) * speed
                let vy = sin(angle) * speed
                
                newParticles.append(CelebrationParticle(
                    x: point.x,
                    y: point.y,
                    vx: vx,
                    vy: vy,
                    size: CGFloat.random(in: 14...28),
                    opacity: 1.0,
                    color: colors.randomElement() ?? .green,
                    systemImage: shapes.randomElement() ?? "sparkles",
                    rotation: Double.random(in: 0...(Double.pi * 2)),
                    rotVelocity: Double.random(in: -4...4)
                ))
            }
        }
        particles = newParticles
        lastUpdateTime = Date().timeIntervalSinceReferenceDate
    }
    
    private func spawnBurst(in size: CGSize) {
        let x = CGFloat.random(in: size.width * 0.2...size.width * 0.8)
        let y = CGFloat.random(in: size.height * 0.25...size.height * 0.55)
        
        var newParticles = particles
        for _ in 0..<15 {
            let angle = Double.random(in: 0...(Double.pi * 2))
            let speed = CGFloat.random(in: 4...12)
            newParticles.append(CelebrationParticle(
                x: x,
                y: y,
                vx: cos(angle) * speed,
                vy: sin(angle) * speed,
                size: CGFloat.random(in: 10...20),
                opacity: 1.0,
                color: colors.randomElement() ?? .green,
                systemImage: shapes.randomElement() ?? "sparkles",
                rotation: Double.random(in: 0...(Double.pi * 2)),
                rotVelocity: Double.random(in: -6...6)
            ))
        }
        particles = newParticles
    }
    
    private func updateParticles(in size: CGSize, at now: Double) {
        if lastUpdateTime == 0.0 {
            lastUpdateTime = now
            return
        }
        
        let dt = CGFloat(min(now - lastUpdateTime, 0.03))
        lastUpdateTime = now
        
        let gravity: CGFloat = 16.0
        let drag: CGFloat = 0.985
        
        for i in 0..<particles.count {
            particles[i].vx *= drag
            particles[i].vy *= drag
            particles[i].vy += gravity * dt
            particles[i].x += particles[i].vx
            particles[i].y += particles[i].vy
            particles[i].rotation += particles[i].rotVelocity * Double(dt)
            particles[i].scaleX = sin(now * 3.0 + Double(i))
            particles[i].opacity -= 0.22 * Double(dt)
        }
        
        particles.removeAll { $0.opacity <= 0 || $0.y > size.height + 50 }
    }
}

struct CelebrationParticle: Identifiable {
    let id: UUID = UUID()
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var size: CGFloat
    var opacity: Double
    var color: Color
    var systemImage: String
    var rotation: Double
    var rotVelocity: Double
    var scaleX: CGFloat = 1.0
}
