import SwiftUI

// MARK: - Onboarding View

/// First-launch onboarding that introduces FRC concepts and the Match Coach app.
struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0

    private let pages: [(title: String, subtitle: String, icon: String, description: String)] = [
        (
            "Welcome to Match Coach",
            "Inspired by FRC Reefscape",
            "gamecontroller.fill",
            "FRC (FIRST Robotics Competition) is where students design, build, and program robots to compete in exciting challenges. This app teaches you how FRC match strategy works through interactive 6-robot simulations inspired by the Reefscape game."
        ),
        (
            "You're the Strategist",
            "Lead Your Alliance",
            "person.3.fill",
            "In each match, you'll lead a 3-robot alliance. Choose your team's strategy, pick your robot's role and autonomous routine, then watch how your decisions play out against 3 opponents."
        ),
        (
            "6 Robots, 1 Field",
            "Real-Time Simulation",
            "play.rectangle.fill",
            "Watch all 6 robots compete on a Reefscape-inspired field. Use slow-mo coaching to learn what's happening, and trigger strategic callouts to adjust mid-match — just like a real FRC drive coach."
        ),
        (
            "AI-Powered Coaching",
            "Learn from Every Match",
            "brain.head.profile.fill",
            "After each match, get personalized coaching feedback. On supported devices, this uses Apple's on-device AI. Your data stays private and everything works fully offline."
        ),
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.12),
                    Color(red: 0.1, green: 0.08, blue: 0.18),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        onboardingPage(pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .animation(.easeInOut, value: currentPage)

                Button(action: {
                    if currentPage < pages.count - 1 {
                        withAnimation { currentPage += 1 }
                    } else {
                        withAnimation { hasCompletedOnboarding = true }
                    }
                }) {
                    Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: 280)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.orange)
                        )
                        .modifier(GlassModifier(shape: RoundedRectangle(cornerRadius: 14)))
                }
                .accessibilityLabel(currentPage < pages.count - 1 ? "Next page" : "Start the app")
                .padding(.bottom, 16)

                if currentPage < pages.count - 1 {
                    Button("Skip") {
                        withAnimation { hasCompletedOnboarding = true }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.bottom, 20)
                    .accessibilityLabel("Skip onboarding")
                }
            }
        }
    }

    @ViewBuilder
    private func onboardingPage(_ page: (title: String, subtitle: String, icon: String, description: String)) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: page.icon)
                .font(.system(size: 60))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            Text(page.title)
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(page.subtitle)
                .font(.title3)
                .foregroundStyle(.orange)
                .multilineTextAlignment(.center)

            Text(page.description)
                .font(.body)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
            Spacer()
        }
        .padding()
    }
}
