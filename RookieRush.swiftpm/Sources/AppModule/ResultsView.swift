import SwiftUI

// MARK: - Results View

/// Post-match results with score breakdown, build choices, and AI coaching feedback.
struct ResultsView: View {
    let result: MatchResult
    var tournament: TournamentState?
    let onTryAgain: () -> Void

    @StateObject private var coach = AICoach()
    @State private var showBreakdown = false
    @State private var animateScore = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.1),
                    Color(red: 0.08, green: 0.06, blue: 0.14),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                        .padding(.top, 24)

                    scoreComparison
                        .padding(.horizontal, 20)

                    if showBreakdown {
                        breakdownSection
                            .padding(.horizontal, 20)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    choicesSection
                        .padding(.horizontal, 20)

                    decisionMapSection
                        .padding(.horizontal, 20)

                    coachingCard
                        .padding(.horizontal, 20)

                    // Build recommendation
                    buildRecommendationCard
                        .padding(.horizontal, 20)

                    // Tournament progress (if applicable)
                    if let ts = tournament, !ts.isComplete {
                        tournamentProgressCard(ts)
                            .padding(.horizontal, 20)
                    }

                    Button(action: onTryAgain) {
                        HStack(spacing: 8) {
                            if let ts = tournament, !ts.isComplete {
                                Image(systemName: "play.fill")
                                Text("Next Match (\(ts.currentMatchIndex + 1)/\(ts.config.matchCount))")
                                    .font(.headline)
                            } else {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Try Different Strategy")
                                    .font(.headline)
                            }
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: 280)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.orange)
                        )
                        .modifier(GlassModifier(shape: RoundedRectangle(cornerRadius: 14)))
                    }
                    .accessibilityLabel("Continue")
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                animateScore = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.6)) {
                showBreakdown = true
            }
            Task { await coach.generateFeedback(for: result) }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(result.playerWon ? "VICTORY" : (result.margin == 0 ? "TIE" : "DEFEAT"))
                .font(.caption.bold())
                .foregroundStyle(result.playerWon ? .green : (result.margin == 0 ? .orange : .red))
                .tracking(3)

            Image(systemName: result.playerWon ? "trophy.fill" : (result.margin == 0 ? "equal.circle.fill" : "xmark.circle.fill"))
                .font(.system(size: 44))
                .foregroundStyle(result.playerWon ? .yellow : (result.margin == 0 ? .orange : .red.opacity(0.7)))
                .accessibilityHidden(true)

            Text(headerMessage)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
    }

    private var headerMessage: String {
        if result.playerWon && result.margin > 15 {
            return "Dominant Win!"
        } else if result.playerWon {
            return "Close Victory!"
        } else if result.margin == 0 {
            return "Dead Even!"
        } else if result.margin < 10 {
            return "So Close!"
        } else {
            return "Tough Match"
        }
    }

    // MARK: - Score Comparison

    @ViewBuilder
    private var scoreComparison: some View {
        HStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("RED ALLIANCE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.red.opacity(0.7))
                    .tracking(1)
                Text("\(result.redScore)")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(.red)
                    .scaleEffect(animateScore ? 1 : 0.5)
                    .opacity(animateScore ? 1 : 0)
                Text("YOUR TEAM")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .frame(maxWidth: .infinity)

            Text("vs")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.3))

            VStack(spacing: 6) {
                Text("BLUE ALLIANCE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color(red: 0.3, green: 0.5, blue: 1.0).opacity(0.7))
                    .tracking(1)
                Text("\(result.blueScore)")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.3, green: 0.5, blue: 1.0))
                    .scaleEffect(animateScore ? 1 : 0.5)
                    .opacity(animateScore ? 1 : 0)
                Text("OPPONENTS")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.orange.opacity(0.15), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Final score: Red \(result.redScore), Blue \(result.blueScore). \(result.playerWon ? "You won!" : "Opponents won.")")
    }

    // MARK: - Breakdown

    @ViewBuilder
    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SCORE BREAKDOWN")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1)

            HStack(spacing: 0) {
                breakdownColumn(title: "RED", breakdown: result.redBreakdown, color: .red)
                Divider().background(Color.white.opacity(0.1)).frame(height: 80)
                breakdownColumn(title: "BLUE", breakdown: result.blueBreakdown,
                                color: Color(red: 0.3, green: 0.5, blue: 1.0))
            }

            // Coral level breakdown for red
            if result.redBreakdown.totalPieces > 0 {
                HStack(spacing: 12) {
                    levelStat("L1", count: result.redBreakdown.coralL1, color: .green)
                    levelStat("L2", count: result.redBreakdown.coralL2, color: .green)
                    levelStat("L3", count: result.redBreakdown.coralL3, color: .yellow)
                    levelStat("L4", count: result.redBreakdown.coralL4, color: .red)
                    if result.redBreakdown.processorPieces > 0 {
                        levelStat("Proc", count: result.redBreakdown.processorPieces, color: .cyan)
                    }
                }
                .padding(.top, 2)
            }

            // Player robot stats
            HStack(spacing: 20) {
                playerStat(icon: "target", value: "\(result.playerRobotScored)", label: "Your Scores")
                playerStat(icon: "arrow.triangle.2.circlepath", value: "\(result.playerRobotCycled)", label: "Cycles")
                playerStat(icon: result.didPlayerStall ? "exclamationmark.triangle.fill" : "checkmark.circle.fill",
                           value: result.didPlayerStall ? "Yes" : "No", label: "Stalled")
                if !result.calloutsUsed.isEmpty {
                    playerStat(icon: "megaphone.fill", value: "\(result.calloutsUsed.count)", label: "Callouts")
                }
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
        )
    }

    @ViewBuilder
    private func breakdownColumn(title: String, breakdown: ScoreBreakdown, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.system(size: 9, weight: .bold)).foregroundStyle(color.opacity(0.7))
            HStack(spacing: 12) {
                miniStat("Auto", "\(breakdown.autoPoints)", color)
                miniStat("Teleop", "\(breakdown.teleopPoints)", color)
                miniStat("Endgame", "\(breakdown.endgamePoints)", color)
            }
            Text("\(breakdown.totalPieces) pieces scored")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func miniStat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 1) {
            Text(value).font(.caption.bold()).foregroundStyle(color)
            Text(label).font(.system(size: 8)).foregroundStyle(.white.opacity(0.35))
        }
    }

    @ViewBuilder
    private func levelStat(_ label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 1) {
            Text("\(count)")
                .font(.caption.bold())
                .foregroundStyle(count > 0 ? color : .white.opacity(0.2))
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(.white.opacity(0.35))
        }
    }

    @ViewBuilder
    private func playerStat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
                .accessibilityHidden(true)
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(.white.opacity(0.35))
        }
    }

    // MARK: - Choices

    @ViewBuilder
    private var choicesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR CHOICES")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1)

            // Strategy + Role + Auto
            HStack(spacing: 10) {
                choiceChip(icon: result.playerStrategy.icon, label: result.playerStrategy.rawValue,
                           color: result.playerStrategy.color)
                choiceChip(icon: result.playerRole.icon, label: result.playerRole.rawValue,
                           color: .cyan)
                choiceChip(icon: result.playerAuto.icon, label: "\(result.playerAuto.rawValue) Auto",
                           color: result.playerAuto.color)
            }

            // Robot build
            HStack(spacing: 10) {
                choiceChip(icon: result.playerBuild.drivetrain.icon,
                           label: result.playerBuild.drivetrain.shortLabel,
                           color: result.playerBuild.drivetrain.color)
                choiceChip(icon: result.playerBuild.mechanism.icon,
                           label: result.playerBuild.mechanism.shortLabel,
                           color: result.playerBuild.mechanism.color)
                choiceChip(icon: result.playerBuild.intake.icon,
                           label: result.playerBuild.intake.shortLabel,
                           color: result.playerBuild.intake.color)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
        )
    }

    @ViewBuilder
    private func choiceChip(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(color.opacity(0.12)))
    }

    // MARK: - Decision Map

    @ViewBuilder
    private var decisionMapSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DECISION MAP")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1)

            VStack(spacing: 0) {
                decisionNodesList
                calloutEventsList
                nodeConnector()
                outcomeNode
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.03))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Decision map showing your choices and match outcome")
    }

    @ViewBuilder
    private var decisionNodesList: some View {
        decisionNode(
            icon: result.playerStrategy.icon,
            label: result.playerStrategy.rawValue,
            detail: "Alliance strategy",
            color: result.playerStrategy.color,
            isStart: true
        )
        nodeConnector()

        decisionNode(
            icon: result.playerRole.icon,
            label: result.playerRole.rawValue,
            detail: "Your role",
            color: .cyan,
            isStart: false
        )
        nodeConnector()

        let buildLabel = "\(result.playerBuild.drivetrain.shortLabel) / \(result.playerBuild.mechanism.shortLabel) / \(result.playerBuild.intake.shortLabel)"
        decisionNode(
            icon: "wrench.and.screwdriver.fill",
            label: buildLabel,
            detail: "Robot build (max L\(result.playerBuild.mechanism.maxLevel))",
            color: .orange,
            isStart: false
        )
        nodeConnector()

        let autoDetail: String = result.didPlayerStall ? "Stalled!" : "\(result.playerAuto.piecesAttempted) pieces attempted"
        let autoColor: Color = result.didPlayerStall ? .red : result.playerAuto.color
        decisionNode(
            icon: result.playerAuto.icon,
            label: "\(result.playerAuto.rawValue) Auto",
            detail: autoDetail,
            color: autoColor,
            isStart: false
        )
    }

    @ViewBuilder
    private var calloutEventsList: some View {
        if !result.calloutEvents.isEmpty {
            nodeConnector()
            VStack(spacing: 4) {
                ForEach(Array(result.calloutEvents.enumerated()), id: \.offset) { _, event in
                    calloutEventRow(event: event)
                }
            }
            .padding(.leading, 24)
        }
    }

    @ViewBuilder
    private func calloutEventRow(event: CalloutEvent) -> some View {
        let timeStr = formatTime(event.matchTime)
        HStack(spacing: 8) {
            Image(systemName: event.callout.icon)
                .font(.system(size: 10))
                .foregroundStyle(event.callout.color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.callout.rawValue)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
                Text("@\(timeStr) — Score: \(event.redScoreAtTime)-\(event.blueScoreAtTime)")
                    .font(.system(size: 8))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            Circle()
                .fill(event.callout.color.opacity(0.3))
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(event.callout.color.opacity(0.06))
        )
    }

    @ViewBuilder
    private var outcomeNode: some View {
        let won = result.playerWon
        let tied = result.margin == 0
        let outcomeColor: Color = won ? .green : (tied ? .orange : .red)
        let iconName: String = won ? "trophy.fill" : (tied ? "equal.circle.fill" : "xmark.circle.fill")
        let iconColor: Color = won ? .yellow : (tied ? .orange : .red)
        let label = won ? "VICTORY" : (tied ? "TIE" : "DEFEAT")
        let gapLabel = won ? "lead" : "gap"

        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(outcomeColor.opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: iconName)
                    .font(.body)
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(outcomeColor)
                Text("\(result.redScore) - \(result.blueScore) (\(result.margin)pt \(gapLabel))")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(outcomeColor.opacity(0.3), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func decisionNode(icon: String, label: String, detail: String, color: Color, isStart: Bool) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                Text(detail)
                    .font(.system(size: 8))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.04))
        )
    }

    @ViewBuilder
    private func nodeConnector() -> some View {
        HStack {
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 2, height: 16)
                .padding(.leading, 24)
            Spacer()
        }
    }

    private func formatTime(_ simTime: Double) -> String {
        let remaining = max(0, MatchTiming.totalDuration - simTime)
        let m = Int(remaining) / 60
        let s = Int(remaining) % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Build Recommendation

    @ViewBuilder
    private var buildRecommendationCard: some View {
        let rec = buildRecommendation
        if !rec.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .foregroundStyle(.cyan)
                    Text("Build Suggestion")
                        .font(.caption.bold())
                        .foregroundStyle(.cyan)
                }

                Text(rec)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.cyan.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.cyan.opacity(0.15), lineWidth: 1)
                    )
            )
        }
    }

    private var buildRecommendation: String {
        let build = result.playerBuild
        var lines: [String] = []

        // Specific build combos
        if build.mechanism == .elevator && build.intake == .roller {
            lines.append("Elevator + Roller is high-risk: consider Claw intake for the reliability bump, since elevator scoring is already slow.")
        }
        if build.drivetrain == .swerve && result.playerRole == .defender {
            lines.append("Swerve drive has low push power for defense. Tank drive gives +40% pushing force and deep climb (12pts vs 6pts).")
        }
        if build.mechanism == .simple && result.playerRole == .scorer {
            lines.append("Simple mechanism caps at L2. Switch to Arm (L3) or Elevator (L4) to unlock higher-value scoring as a Scorer.")
        }

        if result.didPlayerStall && build.tuning.mechanismTuning < 0.4 {
            lines.append("Your mechanism tuning is speed-biased. Increase precision to reduce stall chance.")
        }

        if result.playerRobotScored < 3 && build.tuning.gearRatio > 0.7 {
            lines.append("Speed-biased gear ratio didn't translate to scores. Try balanced (50%) for better acceleration to and from scoring positions.")
        }

        return lines.joined(separator: " ")
    }

    // MARK: - Tournament Progress

    @ViewBuilder
    private func tournamentProgressCard(_ ts: TournamentState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(.yellow)
                Text("\(ts.config.name) Progress")
                    .font(.caption.bold())
                    .foregroundStyle(.yellow)
            }

            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text("\(ts.wins)")
                        .font(.title3.bold())
                        .foregroundStyle(.green)
                    Text("Wins")
                        .font(.system(size: 8))
                        .foregroundStyle(.white.opacity(0.4))
                }
                VStack(spacing: 2) {
                    Text("\(ts.losses)")
                        .font(.title3.bold())
                        .foregroundStyle(.red)
                    Text("Losses")
                        .font(.system(size: 8))
                        .foregroundStyle(.white.opacity(0.4))
                }
                VStack(spacing: 2) {
                    Text("\(ts.ties)")
                        .font(.title3.bold())
                        .foregroundStyle(.orange)
                    Text("Ties")
                        .font(.system(size: 8))
                        .foregroundStyle(.white.opacity(0.4))
                }
                Spacer()
                VStack(spacing: 2) {
                    Text("\(ts.currentMatchIndex)/\(ts.config.matchCount)")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Text("Played")
                        .font(.system(size: 8))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.yellow.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.yellow.opacity(0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - Coaching Card

    @ViewBuilder
    private var coachingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: coach.isAIAvailable ? "brain.head.profile.fill" : "person.fill")
                    .foregroundStyle(.orange)
                Text(coach.isAIAvailable ? "AI Coach" : "Coach's Analysis")
                    .font(.subheadline.bold())
                    .foregroundStyle(.orange)
                Spacer()
                if coach.isAIAvailable {
                    Text("On-Device AI")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                }
            }

            if coach.isGenerating {
                HStack(spacing: 8) {
                    ProgressView().tint(.orange)
                    Text("Analyzing your match...")
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
