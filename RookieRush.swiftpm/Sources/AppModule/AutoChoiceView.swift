import SwiftUI

// MARK: - Auto Choice View

/// Lets the user select one of three autonomous routines with risk/reward tradeoffs.
struct AutoChoiceView: View {
    let archetype: RobotArchetype
    let onSelect: (AutoPlanType) -> Void
    @State private var selectedPlan: AutoPlanType = .taxiPlusOne
    @State private var showDetail = false

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.1)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Header
                VStack(spacing: 4) {
                    Text("STEP 2: CHOOSE YOUR AUTO")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                        .tracking(1.5)

                    Text("Autonomous Routine")
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    Text("Your robot runs this automatically at match start")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.top, 16)

                // Robot context chip
                HStack(spacing: 8) {
                    Image(systemName: archetype.icon)
                        .foregroundStyle(archetype.color)
                    Text("Using: \(archetype.rawValue)")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(archetype.color.opacity(0.15))
                )

                // Auto plan cards
                VStack(spacing: 12) {
                    ForEach(AutoPlanType.allCases) { plan in
                        autoPlanCard(plan)
                    }
                }
                .padding(.horizontal, 20)

                // Risk/reward explanation
                if showDetail {
                    riskExplanation
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer()

                // Confirm button
                Button(action: { onSelect(selectedPlan) }) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.circle.fill")
                        Text("Run with \(selectedPlan.rawValue)")
                            .font(.headline)
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: 300)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(selectedPlan.color)
                    )
                }
                .accessibilityLabel("Confirm autonomous routine: \(selectedPlan.rawValue)")
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            withAnimation(.easeOut.delay(0.2)) {
                showDetail = true
            }
        }
    }

    // MARK: - Auto Plan Card

    @ViewBuilder
    private func autoPlanCard(_ plan: AutoPlanType) -> some View {
        let isSelected = plan == selectedPlan
        let autoPlan = buildAutoPlan(for: plan)
        let nodeCount = autoPlan.waypoints.filter { $0.action == .score }.count

        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedPlan = plan
            }
        }) {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    Circle()
                        .fill(plan.color.opacity(0.2))
                        .frame(width: 48, height: 48)
                    Image(systemName: plan.icon)
                        .font(.title3)
                        .foregroundStyle(plan.color)
                }
                .accessibilityHidden(true)

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(plan.rawValue)
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)

                        Spacer()

                        // Risk badge
                        Text(plan.riskLabel)
                            .font(.caption2.bold())
                            .foregroundStyle(plan.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(plan.color.opacity(0.15))
                            )
                    }

                    Text(plan.description)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(2)

                    // Stats row
                    HStack(spacing: 16) {
                        statChip(icon: "target", label: "\(nodeCount) node\(nodeCount == 1 ? "" : "s")")
                        statChip(icon: "star.fill", label: "Up to \(plan.pointsPossible) pts")
                        statChip(icon: "exclamationmark.triangle.fill", label: "\(Int(autoPlan.failureChance * 100))% fail")
                    }
                    .padding(.top, 2)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? plan.color.opacity(0.1) : Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                isSelected ? plan.color : Color.white.opacity(0.08),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(plan.rawValue), \(plan.riskLabel). \(plan.description). Up to \(plan.pointsPossible) points.")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func statChip(icon: String, label: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.4))
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Risk Explanation

    @ViewBuilder
    private var riskExplanation: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text("FRC Strategy Tip")
                    .font(.caption.bold())
                    .foregroundStyle(.yellow)
            }
            Text("In real FRC, teams balance auto complexity against reliability. A consistent 1-score auto often beats a risky 3-score that fails half the time. Start safe, then level up!")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.yellow.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.yellow.opacity(0.15), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
}
