import SwiftUI

// MARK: - Welcome / Tutorial View

/// Quick tutorial overlay explaining the 3-step flow before the user begins.
struct WelcomeView: View {
    let onStart: () -> Void
    @State private var showSteps = false

    var body: some View {
        ZStack {
            // Dark background
            Color(red: 0.06, green: 0.06, blue: 0.1)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                // Title
                VStack(spacing: 8) {
                    Text("ROOKIE RUSH")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .yellow],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("Level 1")
                        .font(.title2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                }

                // Step cards
                if showSteps {
                    VStack(spacing: 14) {
                        stepCard(
                            number: 1,
                            icon: "wrench.and.screwdriver.fill",
                            title: "Choose Your Build",
                            subtitle: "Pick a robot archetype with unique tradeoffs",
                            color: .cyan
                        )
                        stepCard(
                            number: 2,
                            icon: "point.topleft.down.to.point.bottomright.curvepath.fill",
                            title: "Choose Your Auto",
                            subtitle: "Select an autonomous routine: safe or risky?",
                            color: .yellow
                        )
                        stepCard(
                            number: 3,
                            icon: "play.fill",
                            title: "Run the Sim",
                            subtitle: "Watch your robot compete and get coached",
                            color: .green
                        )
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .padding(.horizontal, 20)
                }

                Spacer()

                // Start button
                Button(action: onStart) {
                    HStack(spacing: 10) {
                        Image(systemName: "flag.checkered")
                        Text("Start Challenge")
                            .font(.headline)
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: 260)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.orange)
                    )
                }
                .accessibilityLabel("Start the Level 1 challenge")
                .padding(.bottom, 24)

                Text("~3 minutes to complete")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.bottom, 16)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                showSteps = true
            }
        }
    }

    @ViewBuilder
    private func stepCard(number: Int, icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 14) {
            // Step number circle
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 44, height: 44)
                Text("\(number)")
                    .font(.headline.bold())
                    .foregroundStyle(color)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundStyle(color)
                        .accessibilityHidden(true)
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(color.opacity(0.2), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number): \(title). \(subtitle)")
    }
}
