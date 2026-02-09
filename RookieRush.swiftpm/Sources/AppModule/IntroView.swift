import SwiftUI

// MARK: - Intro View

/// Welcome screen with single match and tournament mode options.
struct IntroView: View {
    let onStart: () -> Void
    let onTournament: () -> Void
    @State private var appeared = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.12),
                    Color(red: 0.08, green: 0.06, blue: 0.16),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                // Title block
                VStack(spacing: 10) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(.orange)
                        .scaleEffect(appeared ? 1 : 0.6)
                        .opacity(appeared ? 1 : 0)
                        .accessibilityHidden(true)

                    Text("Match Coach")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Inspired by FRC Reefscape")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange.opacity(0.9))
                        .tracking(1)
                }

                // Step cards
                VStack(spacing: 14) {
                    stepCard(number: "1", title: "Pick a Strategy",
                             detail: "Choose your alliance's approach: aggressive, balanced, or defensive.",
                             icon: "lightbulb.fill", color: .orange)
                    stepCard(number: "2", title: "Build & Tune Your Robot",
                             detail: "Select hardware, tune gear ratios, and customize your machine.",
                             icon: "wrench.and.screwdriver.fill", color: .cyan)
                    stepCard(number: "3", title: "Watch the Match",
                             detail: "6 robots compete with sound effects, particles, and real-time coaching.",
                             icon: "play.fill", color: .green)
                }
                .padding(.horizontal, 24)
                .offset(y: appeared ? 0 : 20)
                .opacity(appeared ? 1 : 0)

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    Button(action: onStart) {
                        HStack(spacing: 10) {
                            Image(systemName: "flag.checkered")
                            Text("Single Match")
                                .font(.headline)
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: 260)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.orange)
                        )
                        .modifier(GlassModifier(shape: RoundedRectangle(cornerRadius: 16)))
                    }
                    .accessibilityLabel("Start a single match")

                    Button(action: onTournament) {
                        HStack(spacing: 10) {
                            Image(systemName: "trophy.fill")
                            Text("Tournament Mode")
                                .font(.headline)
                        }
                        .foregroundStyle(.yellow)
                        .frame(maxWidth: 260)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.yellow.opacity(0.12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(Color.yellow.opacity(0.4), lineWidth: 1.5)
                                )
                        )
                    }
                    .accessibilityLabel("Enter tournament mode — play a series of matches")
                }
                .opacity(appeared ? 1 : 0)

                Text("Each match is uniquely generated")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.bottom, 30)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appeared = true }
        }
    }

    @ViewBuilder
    private func stepCard(number: String, title: String, detail: String, icon: String, color: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(color)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
        )
        .accessibilityElement(children: .combine)
    }
}
