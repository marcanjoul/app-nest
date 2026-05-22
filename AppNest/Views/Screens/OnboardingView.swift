import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0

    private let pages: [(icon: String, title: String, subtitle: String, color: Color)] = [
        ("briefcase.fill",       "Track Every Application",  "Keep all your job applications organized in one place.",  Color(red: 0.35, green: 0.65, blue: 0.96)),
        ("envelope.open.fill",   "Paste & Parse",            "Paste a job application email to extract its details.", Color(red: 0.96, green: 0.73, blue: 0.28)),
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
                                    .fill(page.color.opacity(0.08))
                                    .frame(width: 210, height: 210)
                                    .blur(radius: 28)
                                Circle()
                                    .fill(page.color.opacity(0.14))
                                    .frame(width: 110, height: 110)
                                Image(systemName: page.icon)
                                    .appFont(56, weight: .semibold)
                                    .foregroundStyle(page.color)
                                    .shadow(color: page.color.opacity(0.30), radius: 16, y: 6)
                            }

                            VStack(spacing: 10) {
                                Text(page.title)
                                    .font(.title2.weight(.bold))
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(Theme.textPrimary)

                                Text(page.subtitle)
                                    .font(.body)
                                    .foregroundStyle(Theme.textSecondary)
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
                            .frame(width: index == currentPage ? 22 : 8, height: 8)
                    }
                }
                .padding(.bottom, 36)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentPage)

                // CTA button
                Button {
                    if currentPage < pages.count - 1 {
                        AppHaptics.shared.light()
                        withAnimation(.appSmooth) {
                            currentPage += 1
                        }
                    } else {
                        AppHaptics.shared.success()
                        hasCompletedOnboarding = true
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "Continue" : "Get Started")
                        .appFont(17, weight: .semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background {
                            Capsule()
                                .fill(pages[currentPage].color)
                        }
                }
                .buttonStyle(PressScaleButtonStyle())
                .padding(.horizontal, 28)
                .animation(.appFastOut, value: currentPage)

                if currentPage < pages.count - 1 {
                    Button("Skip") {
                        AppHaptics.shared.light()
                        hasCompletedOnboarding = true
                    }
                    .appFont(15, weight: .medium)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 11)
                    .background(
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.10), lineWidth: 1))
                    )
                    .buttonStyle(PressScaleButtonStyle())
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
