import SwiftUI

/// Rookie Rush: Level 1 — An interactive robotics strategy onboarding playground.
/// Teaches new robotics students the core loop: Strategy → Build → Run.
@main
struct RookieRushApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            }
        }
    }
}
