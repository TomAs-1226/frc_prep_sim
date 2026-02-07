import SwiftUI

// MARK: - Pre-Match View

/// 4-step selection: Alliance Strategy → Robot Role → Robot Build → Auto Plan.
struct PreMatchView: View {
    let onReady: (AllianceStrategy, RobotRole, RobotBuild, AutoPlan) -> Void

    @State private var step = 0
    @State private var selectedStrategy: AllianceStrategy?
    @State private var selectedRole: RobotRole?
    @State private var selectedBuild = RobotBuild()
    @State private var selectedAuto: AutoPlan?

    private let stepCount = 4
    private let stepLabels = ["Strategy", "Role", "Robot Build", "Auto Plan"]

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

            VStack(spacing: 0) {
                // Progress bar
                progressBar
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                // Step content
                ScrollView {
                    VStack(spacing: 20) {
                        switch step {
                        case 0: strategyStep
                        case 1: roleStep
                        case 2: buildStep
                        default: autoStep
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }

                // Bottom bar
                bottomBar
            }
        }
    }

    // MARK: - Progress Bar

    @ViewBuilder
    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<stepCount, id: \.self) { i in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i <= step ? Color.orange : Color.white.opacity(0.15))
                        .frame(height: 4)
                    Text(stepLabels[i])
                        .font(.system(size: 8, weight: i == step ? .bold : .regular))
                        .foregroundStyle(i == step ? .orange : .white.opacity(0.4))
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
    }

    // MARK: - Strategy Selection

    @ViewBuilder
    private var strategyStep: some View {
        VStack(spacing: 8) {
            stepHeader(title: "Alliance Strategy", subtitle: "How should your 3-robot alliance play?")

            ForEach(AllianceStrategy.allCases) { strat in
                selectionCard(
                    title: strat.rawValue,
                    icon: strat.icon,
                    description: strat.description,
                    color: strat.color,
                    isSelected: selectedStrategy == strat
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedStrategy = strat }
                }
            }

            tipBanner(text: "Aggressive strategies score more but are vulnerable to defense. Defensive strategies limit opponents but need efficient scorers.")
        }
    }

    // MARK: - Role Selection

    @ViewBuilder
    private var roleStep: some View {
        VStack(spacing: 8) {
            stepHeader(title: "Your Robot Role", subtitle: "What role will YOUR robot play on the alliance?")

            ForEach(RobotRole.allCases) { role in
                selectionCard(
                    title: role.rawValue,
                    icon: role.icon,
                    description: role.description,
                    color: roleColor(role),
                    isSelected: selectedRole == role
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedRole = role }
                }
            }

            if let strat = selectedStrategy {
                tipBanner(text: "With \"\(strat.rawValue)\" strategy, your teammates will complement your role automatically.")
            }
        }
    }

    // MARK: - Robot Build Selection

    @ViewBuilder
    private var buildStep: some View {
        VStack(spacing: 16) {
            stepHeader(title: "Build Your Robot", subtitle: "Choose the hardware for your robot.")

            // Drivetrain
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("Drivetrain", icon: "gearshape.2.fill")

                ForEach(DrivetrainType.allCases) { dt in
                    VStack(spacing: 0) {
                        selectionCard(
                            title: dt.rawValue,
                            icon: dt.icon,
                            description: dt.description,
                            color: dt.color,
                            isSelected: selectedBuild.drivetrain == dt
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) { selectedBuild.drivetrain = dt }
                        }
                        prosConsRow(pros: dt.pros, cons: dt.cons)
                    }
                }
            }

            // Mechanism
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("Scoring Mechanism", icon: "arrow.up.and.down")

                ForEach(MechanismType.allCases) { mech in
                    VStack(spacing: 0) {
                        selectionCard(
                            title: mech.rawValue,
                            icon: mech.icon,
                            description: mech.description,
                            color: mech.color,
                            isSelected: selectedBuild.mechanism == mech
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) { selectedBuild.mechanism = mech }
                        }

                        // Level indicator
                        HStack(spacing: 8) {
                            Text("Reaches:")
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.4))
                            ForEach(1...4, id: \.self) { lvl in
                                Text("L\(lvl)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(lvl <= mech.maxLevel ? mech.color : .white.opacity(0.15))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 2)

                        prosConsRow(pros: mech.pros, cons: mech.cons)
                    }
                }
            }

            // Intake
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("Intake", icon: "hand.point.up.fill")

                ForEach(IntakeType.allCases) { intake in
                    VStack(spacing: 0) {
                        selectionCard(
                            title: intake.rawValue,
                            icon: intake.icon,
                            description: intake.description,
                            color: intake.color,
                            isSelected: selectedBuild.intake == intake
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) { selectedBuild.intake = intake }
                        }
                        prosConsRow(pros: intake.pros, cons: intake.cons)
                    }
                }
            }

            // Build summary
            buildSummaryCard

            tipBanner(text: "Every build has tradeoffs! Swerve+Elevator scores high but is fragile. Tank+Simple cycles fast and gets deep climb (12pts). No combo is best — it depends on your role.")
        }
    }

    @ViewBuilder
    private var buildSummaryCard: some View {
        VStack(spacing: 8) {
            Text("YOUR BUILD")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1)
            HStack(spacing: 12) {
                buildChip(icon: selectedBuild.drivetrain.icon,
                          label: selectedBuild.drivetrain.shortLabel,
                          color: selectedBuild.drivetrain.color)
                buildChip(icon: selectedBuild.mechanism.icon,
                          label: selectedBuild.mechanism.shortLabel,
                          color: selectedBuild.mechanism.color)
                buildChip(icon: selectedBuild.intake.icon,
                          label: selectedBuild.intake.shortLabel,
                          color: selectedBuild.intake.color)
            }
            Text("Max Level: L\(selectedBuild.mechanism.maxLevel)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(selectedBuild.mechanism.color)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func buildChip(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.12)))
    }

    // MARK: - Auto Selection

    @ViewBuilder
    private var autoStep: some View {
        VStack(spacing: 8) {
            stepHeader(title: "Auto Routine", subtitle: "Pick your 15-second autonomous program.")

            ForEach(AutoPlan.allCases) { auto in
                VStack(spacing: 0) {
                    selectionCard(
                        title: "\(auto.rawValue) Auto",
                        icon: auto.icon,
                        description: auto.description,
                        color: auto.color,
                        isSelected: selectedAuto == auto
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedAuto = auto }
                    }

                    HStack(spacing: 16) {
                        miniStat(label: "Pieces", value: "\(auto.piecesAttempted)")
                        miniStat(label: "Success", value: "\(Int(auto.successRate * 100))%")
                        miniStat(label: "Risk", value: riskLabel(auto))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }

            tipBanner(text: "Riskier autos attempt more game pieces but have a higher stall chance. In FRC, consistency often wins matches!")
        }
    }

    // MARK: - Bottom Bar

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 6) {
            HStack {
                if step > 0 {
                    Button(action: { withAnimation { step -= 1 } }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                    }
                    .accessibilityLabel("Go back")
                }

                Spacer()

                Button(action: advanceStep) {
                    HStack(spacing: 6) {
                        Text(step < stepCount - 1 ? "Next" : "Ready!")
                            .font(.headline)
                        if step < stepCount - 1 {
                            Image(systemName: "chevron.right")
                        } else {
                            Image(systemName: "flag.checkered")
                        }
                    }
                    .foregroundStyle(canAdvance ? .black : .white.opacity(0.3))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(canAdvance ? Color.orange : Color.white.opacity(0.08))
                    )
                    .modifier(GlassModifier(shape: RoundedRectangle(cornerRadius: 14)))
                }
                .disabled(!canAdvance)
                .accessibilityLabel(step < stepCount - 1 ? "Continue to next step" : "Start the match")
            }

            Text("Demo Level 1 — future levels will be more in-depth")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.2))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.3))
    }

    // MARK: - Navigation Logic

    private var canAdvance: Bool {
        switch step {
        case 0: return selectedStrategy != nil
        case 1: return selectedRole != nil
        case 2: return true  // Build always has defaults
        default: return selectedAuto != nil
        }
    }

    private func advanceStep() {
        guard canAdvance else { return }
        if step < stepCount - 1 {
            withAnimation(.easeInOut(duration: 0.3)) { step += 1 }
        } else if let s = selectedStrategy, let r = selectedRole, let a = selectedAuto {
            onReady(s, r, selectedBuild, a)
        }
    }

    // MARK: - Shared Components

    @ViewBuilder
    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func sectionLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.orange)
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    @ViewBuilder
    private func selectionCard(title: String, icon: String, description: String,
                                color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(isSelected ? 0.25 : 0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(color)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(color)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(isSelected ? 0.08 : 0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(isSelected ? color.opacity(0.5) : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func tipBanner(text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .font(.caption)
                .foregroundStyle(.yellow)
            Text(text)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.yellow.opacity(0.06))
        )
        .padding(.top, 4)
    }

    @ViewBuilder
    private func miniStat(label: String, value: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.7))
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.35))
        }
    }

    private func roleColor(_ role: RobotRole) -> Color {
        switch role {
        case .scorer:   return .orange
        case .cycler:   return .cyan
        case .defender: return .green
        }
    }

    private func riskLabel(_ auto: AutoPlan) -> String {
        switch auto {
        case .safe: return "Low"
        case .moderate: return "Med"
        case .risky: return "High"
        }
    }

    @ViewBuilder
    private func prosConsRow(pros: String, cons: String) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.green.opacity(0.7))
                Text(pros)
                    .font(.system(size: 9))
                    .foregroundStyle(.green.opacity(0.6))
                Spacer()
            }
            HStack(spacing: 4) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.red.opacity(0.7))
                Text(cons)
                    .font(.system(size: 9))
                    .foregroundStyle(.red.opacity(0.6))
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
