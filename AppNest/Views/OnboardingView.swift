import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0

    private let pages: [(icon: String, title: String, subtitle: String, color: Color)] = [
        ("briefcase.fill",       "Track Every Application",  "Keep all your job applications organized in one place.",  Color(red: 0.35, green: 0.65, blue: 0.96)),
        ("envelope.open.fill",   "Paste & Parse",            "Paste a confirmation email and AppNest extracts the details automatically.", Color(red: 0.96, green: 0.73, blue: 0.28)),
        ("chart.bar.fill",       "Stay On Top",              "Stats, filters, and exports to master your job search.", Color(red: 0.30, green: 0.80, blue: 0.45)),
    ]

    var body: some View {
        ZStack {
            AmbientBackground()

            VStack(spacing: 0) {
                Spacer()

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        let page = pages[index]
                        VStack(spacing: 24) {
                            ZStack {
                                Circle()
                                    .fill(page.color.opacity(0.15))
                                    .frame(width: 120, height: 120)
                                Circle()
                                    .fill(page.color.opacity(0.08))
                                    .frame(width: 160, height: 160)
                                    .blur(radius: 10)
                                Image(systemName: page.icon)
                                    .font(.system(size: 52, weight: .semibold))
                                    .foregroundStyle(page.color)
                                    .shadow(color: page.color.opacity(0.24), radius: 12, y: 4)
                            }

                            VStack(spacing: 10) {
                                Text(page.title)
                                    .font(.title2.weight(.bold))
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(DarkTheme.textPrimary)

                                Text(page.subtitle)
                                    .font(.body)
                                    .foregroundStyle(DarkTheme.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 36)
                            }
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                Spacer()

                // Page dots
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage ? pages[currentPage].color : Color.primary.opacity(0.15))
                            .frame(width: index == currentPage ? 20 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, 36)

                // CTA button
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            currentPage += 1
                        }
                    } else {
                        hasCompletedOnboarding = true
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "Continue" : "Get Started")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background {
                            Capsule()
                                .fill(pages[currentPage].color)
                                .overlay {
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.25), Color.clear],
                                        startPoint: .top, endPoint: .center
                                    )
                                    .clipShape(Capsule())
                                }
                                .shadow(color: pages[currentPage].color.opacity(0.30), radius: 14, y: 5)
                        }
                }
                .padding(.horizontal, 28)
                .animation(.easeInOut(duration: 0.2), value: currentPage)

                if currentPage < pages.count - 1 {
                    Button("Skip") {
                        hasCompletedOnboarding = true
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(DarkTheme.textSecondary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 11)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
                    )
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                } else {
                    Spacer().frame(height: 52)
                }
            }
        }
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
