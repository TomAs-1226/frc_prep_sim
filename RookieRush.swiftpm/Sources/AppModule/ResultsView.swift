import SwiftUI

// MARK: - Results View

/// Displays simulation results with AI-powered coaching feedback.
struct ResultsView: View {
    let result: SimulationResult
    let onTryAgain: () -> Void
    @StateObject private var coach = AICoach()
    @State private var showDetails = false
    @State private var animateScore = false

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.1),
                    Color(red: 0.08, green: 0.06, blue: 0.14),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("MATCH RESULTS")
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                            .tracking(2)

                        Text(headerEmoji)
                            .font(.system(size: 48))
                            .accessibilityHidden(true)

                        Text(headerMessage)
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)

                    // Score card
                    scoreCard
                        .padding(.horizontal, 20)

                    // Details
                    if showDetails {
                        detailsCard
                            .padding(.horizontal, 20)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // AI Coaching
                    coachingCard
                        .padding(.horizontal, 20)

                    // Actions
                    VStack(spacing: 12) {
                        Button(action: onTryAgain) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Try Different Choices")
                                    .font(.headline)
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: 280)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.orange)
                            )
                        }
                        .accessibilityLabel("Try again with different robot and auto choices")
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                showDetails = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                animateScore = true
            }
            Task {
                await coach.generateFeedback(for: result)
            }
        }
    }

    // MARK: - Header Logic

    private var scoringRatio: Double {
        result.totalNodes > 0 ? Double(result.nodesScored) / Double(result.totalNodes) : 0
    }

    private var headerEmoji: String {
        if scoringRatio >= 0.9 { return "star.fill" }
        if scoringRatio >= 0.5 { return "hand.thumbsup.fill" }
        return "lightbulb.fill"
    }

    private var headerMessage: String {
        if scoringRatio >= 0.9 { return "Outstanding Run!" }
        if scoringRatio >= 0.5 { return "Solid Performance!" }
        return "Room to Improve!"
    }

    // MARK: - Score Card

    @ViewBuilder
    private var scoreCard: some View {
        VStack(spacing: 16) {
            // Big score
            Text("\(result.totalPoints)")
                .font(.system(size: 64, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .yellow],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .scaleEffect(animateScore ? 1.0 : 0.5)
                .opacity(animateScore ? 1.0 : 0)

            Text("TOTAL POINTS")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.5))
                .tracking(1.5)

            // Stats row
            HStack(spacing: 24) {
                resultStat(
                    icon: "target",
                    value: "\(result.nodesScored)/\(result.totalNodes)",
                    label: "Nodes"
                )
                resultStat(
                    icon: "clock.fill",
                    value: String(format: "%.0fs", result.timeUsed),
                    label: "Time Used"
                )
                resultStat(
                    icon: result.didStall ? "exclamationmark.triangle.fill" : "checkmark.circle.fill",
                    value: result.didStall ? "Yes" : "No",
                    label: "Stalled"
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Score: \(result.totalPoints) points. \(result.nodesScored) of \(result.totalNodes) nodes scored. \(result.didStall ? "Robot stalled during match." : "No stalls.")")
    }

    @ViewBuilder
    private func resultStat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .accessibilityHidden(true)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    // MARK: - Details Card

    @ViewBuilder
    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR CHOICES")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1)

            HStack(spacing: 12) {
                choiceChip(
                    icon: result.archetype.icon,
                    label: result.archetype.rawValue,
                    color: result.archetype.color
                )
                choiceChip(
                    icon: result.autoPlan.icon,
                    label: result.autoPlan.rawValue,
                    color: result.autoPlan.color
                )
            }

            // Max possible points
            HStack {
                Text("Max possible:")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
                Text("\(result.autoPlan.pointsPossible) pts")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text("Achieved:")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
                Text("\(Int(scoringRatio * 100))%")
                    .font(.caption.bold())
                    .foregroundStyle(scoringRatio >= 0.8 ? .green : (scoringRatio >= 0.5 ? .yellow : .red))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
        )
    }

    @ViewBuilder
    private func choiceChip(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
        )
    }

    // MARK: - Coaching Card

    @ViewBuilder
    private var coachingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: coach.isAIAvailable ? "brain.head.profile.fill" : "person.fill")
                    .foregroundStyle(.orange)
                Text(coach.isAIAvailable ? "AI Coach" : "Coach's Feedback")
                    .font(.subheadline.bold())
                    .foregroundStyle(.orange)

                Spacer()

                if coach.isAIAvailable {
                    Text("On-Device AI")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                        )
                }
            }

            if coach.isGenerating {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.orange)
                    Text("Analyzing your run...")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            } else if !coach.coachingText.isEmpty {
                Text(coach.coachingText)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.orange.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.orange.opacity(0.15), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Coach feedback: \(coach.coachingText)")
    }
}
