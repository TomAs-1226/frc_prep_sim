import SwiftUI

// MARK: - Onboarding View

/// First-launch onboarding that introduces FRC concepts and app purpose.
struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0

    private let pages: [(title: String, subtitle: String, icon: String, description: String)] = [
        (
            "Welcome to Rookie Rush",
            "Your FRC Journey Starts Here",
            "graduationcap.fill",
            "FIRST Robotics Competition (FRC) is where students design, build, and program robots to compete in exciting challenges. It can feel overwhelming at first — but that's what this app is for."
        ),
        (
            "The Core Loop",
            "Strategy + Build + Run",
            "arrow.triangle.2.circlepath",
            "Every FRC team follows a loop: choose a strategy, build a robot to match, then run matches to test it. Success comes from understanding tradeoffs — speed vs. scoring power, risk vs. consistency."
        ),
        (
            "Your First Challenge",
            "Level 1: Reef Zone",
            "star.fill",
            "You'll choose a robot build, pick an autonomous routine, and watch your robot compete on a simplified field. See how your choices affect performance — then try again with new strategies!"
        ),
        (
            "AI Coaching",
            "Learn from Every Run",
            "brain.head.profile.fill",
            "After each simulation, you'll receive personalized coaching feedback. On supported devices, this is powered by Apple's on-device AI — your data stays private and works fully offline."
        ),
    ]

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.12),
                    Color(red: 0.1, green: 0.08, blue: 0.18),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        onboardingPage(pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .animation(.easeInOut, value: currentPage)

                // Bottom button
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
                }
                .accessibilityLabel(currentPage < pages.count - 1 ? "Next page" : "Start the app")
                .padding(.bottom, 40)

                // Skip button
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
