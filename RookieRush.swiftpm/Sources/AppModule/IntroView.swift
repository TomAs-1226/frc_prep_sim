import SwiftUI

// MARK: - Intro View

/// Welcome screen that introduces the Rookie Workshop concept and starts the flow.
struct IntroView: View {
    let onStart: () -> Void
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
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(.orange)
                        .scaleEffect(appeared ? 1 : 0.6)
                        .opacity(appeared ? 1 : 0)
                        .accessibilityHidden(true)

                    Text("Rookie Workshop")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text("FRC Robot Builder")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange.opacity(0.9))
                        .tracking(1)
                }

                // Step cards
                VStack(spacing: 14) {
                    stepCard(number: "1", title: "Analyze the Game",
                             detail: "Each round generates a unique field with random scoring zones, game pieces, and endgame challenges.",
                             icon: "magnifyingglass", color: .orange)
                    stepCard(number: "2", title: "Build Your Robot",
                             detail: "Pick the right parts for the game: drivetrain, frame, manipulator, and intake.",
                             icon: "wrench.and.screwdriver.fill", color: .cyan)
                    stepCard(number: "3", title: "Compete & Learn",
                             detail: "Watch your robot in a 3v3 match and see how well your build matched the game.",
                             icon: "play.fill", color: .green)
                }
                .padding(.horizontal, 24)
                .offset(y: appeared ? 0 : 20)
                .opacity(appeared ? 1 : 0)

                Spacer()

                // Start button
                Button(action: onStart) {
                    HStack(spacing: 10) {
                        Image(systemName: "hammer.fill")
                        Text("Start Building")
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
                .accessibilityLabel("Start building your robot")
                .opacity(appeared ? 1 : 0)

                Text("~3 minute experience")
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
