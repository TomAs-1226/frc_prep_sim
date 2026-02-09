import SwiftUI

// MARK: - Results View

/// Post-match results with score breakdown, build match analysis, and AI coaching feedback.
struct ResultsView: View {
    let result: MatchResult
    @ObservedObject var profileManager: ProfileManager
    var tournamentState: TournamentState?
    let onTryAgain: () -> Void

    @StateObject private var coach = AICoach()
    @State private var showBreakdown = false
    @State private var animateScore = false
    @State private var rewards: ProfileManager.MatchRewards?
    @State private var showLevelUp = false
    @State private var newAchievementIndex = 0
    @State private var showAchievement = false
    @State private var showXP = false

    private var isTournament: Bool { tournamentState != nil }

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

                    gameInfoSection
                        .padding(.horizontal, 20)

                    buildMatchSection
                        .padding(.horizontal, 20)

                    xpSection
                        .padding(.horizontal, 20)
                        .opacity(showXP ? 1 : 0)
                        .offset(y: showXP ? 0 : 10)

                    if let rewards = rewards, !rewards.newAchievements.isEmpty {
                        achievementSection(achievements: rewards.newAchievements)
                            .padding(.horizontal, 20)
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }

                    scoreComparison
                        .padding(.horizontal, 20)

                    if showBreakdown {
                        breakdownSection
                            .padding(.horizontal, 20)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    choicesSection
                        .padding(.horizontal, 20)

                    gameAnalysisSection
                        .padding(.horizontal, 20)

                    decisionMapSection
                        .padding(.horizontal, 20)

                    coachingCard
                        .padding(.horizontal, 20)

                    buildRecommendationSection
                        .padding(.horizontal, 20)

                    // Tournament status banner
                    if let ts = tournamentState {
                        tournamentStatusBanner(ts)
                            .padding(.horizontal, 20)
                    }

                    Button(action: onTryAgain) {
                        HStack(spacing: 8) {
                            Image(systemName: isTournament ?
                                  (tournamentState?.isComplete == true ? "trophy.fill" : "arrow.right") :
                                    "arrow.counterclockwise")
                            Text(buttonLabel)
                                .font(.headline)
                        }
                        .foregroundStyle(isTournament && tournamentState?.isComplete == true ? .yellow : .black)
                        .frame(maxWidth: 280)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(isTournament && tournamentState?.isComplete == true ?
                                      Color.yellow.opacity(0.2) : Color.orange)
                                .overlay(
                                    isTournament && tournamentState?.isComplete == true ?
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(Color.yellow.opacity(0.4), lineWidth: 1) : nil
                                )
                        )
                        .modifier(GlassModifier(shape: RoundedRectangle(cornerRadius: 14)))
                    }
                    .accessibilityLabel(buttonLabel)

                    Text(result.game.name)
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.2))
                        .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            let r = profileManager.processMatchResult(result)
            rewards = r

            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                animateScore = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
                showXP = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.6)) {
                showBreakdown = true
            }
            if r.didLevelUp {
                withAnimation(.spring(response: 0.6).delay(1.2)) {
                    showLevelUp = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    withAnimation { showLevelUp = false }
                }
            }
            if !r.newAchievements.isEmpty {
                withAnimation(.spring(response: 0.5).delay(1.5)) {
                    showAchievement = true
                }
            }
            Task { await coach.generateFeedback(for: result) }
        }
        .overlay {
            if showLevelUp, let r = rewards {
                levelUpOverlay(level: r.newLevel)
            }
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

    // MARK: - Game Info

    @ViewBuilder
    private var gameInfoSection: some View {
        HStack(spacing: 12) {
            Image(systemName: result.game.archetype.icon)
                .font(.title2)
                .foregroundStyle(result.game.archetype.color)

            VStack(alignment: .leading, spacing: 3) {
                Text(result.game.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                HStack(spacing: 6) {
                    Text(result.game.archetype.rawValue)
                        .font(.caption.bold())
                        .foregroundStyle(result.game.archetype.color)
                    Text(result.game.endgameChallenge.displayName)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            Spacer()

            // Game pieces
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    ForEach(result.game.gamePieces, id: \.rawValue) { piece in
                        Image(systemName: piece.icon)
                            .font(.caption)
                            .foregroundStyle(piece.color)
                    }
                }
                Text("Pieces")
                    .font(.system(size: 8))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(result.game.archetype.color.opacity(0.2), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Game: \(result.game.name), archetype: \(result.game.archetype.rawValue)")
    }

    // MARK: - Build Match Score

    @ViewBuilder
    private var buildMatchSection: some View {
        VStack(spacing: 12) {
            Text("BUILD MATCH SCORE")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1)

            // Gauge
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(Color.white.opacity(0.08), lineWidth: 10)
                    .rotationEffect(.degrees(135))

                Circle()
                    .trim(from: 0, to: animateScore ? CGFloat(result.buildMatchScore) / 100.0 * 0.75 : 0)
                    .stroke(buildMatchColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(135))
                    .animation(.easeOut(duration: 1.0).delay(0.3), value: animateScore)

                VStack(spacing: 2) {
                    Text("\(result.buildMatchScore)")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(buildMatchColor)
                    Text("/ 100")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                    Text(buildMatchLabel)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(buildMatchColor.opacity(0.8))
                }
            }
            .frame(width: 140, height: 140)

            Text("How well your robot parts matched the generated game")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(buildMatchColor.opacity(0.2), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Build match score: \(result.buildMatchScore) out of 100. \(buildMatchLabel).")
    }

    private var buildMatchColor: Color {
        if result.buildMatchScore >= 75 { return .green }
        if result.buildMatchScore >= 50 { return .yellow }
        if result.buildMatchScore >= 30 { return .orange }
        return .red
    }

    private var buildMatchLabel: String {
        if result.buildMatchScore >= 80 { return "Excellent Fit" }
        if result.buildMatchScore >= 65 { return "Good Fit" }
        if result.buildMatchScore >= 50 { return "Decent Fit" }
        if result.buildMatchScore >= 35 { return "Poor Fit" }
        return "Mismatched"
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

            // Scoring height breakdown for red
            if result.redBreakdown.totalPieces > 0 {
                HStack(spacing: 12) {
                    levelStat("Ground", count: result.redBreakdown.groundScores, color: .green)
                    levelStat("Low", count: result.redBreakdown.lowScores, color: .cyan)
                    levelStat("Mid", count: result.redBreakdown.midScores, color: .yellow)
                    levelStat("High", count: result.redBreakdown.highScores, color: .red)
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

            // Robot build (with frame)
            HStack(spacing: 10) {
                choiceChip(icon: result.playerBuild.drivetrain.icon,
                           label: result.playerBuild.drivetrain.shortLabel,
                           color: result.playerBuild.drivetrain.color)
                choiceChip(icon: result.playerBuild.frame.icon,
                           label: result.playerBuild.frame.shortLabel,
                           color: result.playerBuild.frame.color)
                choiceChip(icon: result.playerBuild.manipulator.icon,
                           label: result.playerBuild.manipulator.shortLabel,
                           color: result.playerBuild.manipulator.color)
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

    // MARK: - Game Analysis

    @ViewBuilder
    private var gameAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("BUILD vs GAME ANALYSIS")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1)

            // Manipulator reach vs game heights
            let maxZone = result.game.maxScoringHeight
            let maxReach = result.playerBuild.manipulator.maxReach
            analysisRow(
                icon: result.playerBuild.manipulator.icon,
                label: "Manipulator Reach",
                detail: "\(result.playerBuild.manipulator.shortLabel) reaches \(maxReach.displayName) -- game needs \(maxZone.displayName)",
                isGood: maxReach >= maxZone,
                color: result.playerBuild.manipulator.color
            )

            // Intake vs game pieces
            let intakeMatch = result.game.gamePieces.contains { $0.idealIntake == result.playerBuild.intake }
            let pieceNames = result.game.gamePieces.map(\.rawValue).joined(separator: ", ")
            analysisRow(
                icon: result.playerBuild.intake.icon,
                label: "Intake Match",
                detail: "\(result.playerBuild.intake.shortLabel) for \(pieceNames)",
                isGood: intakeMatch,
                color: result.playerBuild.intake.color
            )

            // Endgame fit
            let (endgameFit, endgameDetail): (Bool, String) = {
                switch result.game.endgameChallenge {
                case .climb(let difficulty, _):
                    if difficulty == .high {
                        return (result.playerBuild.drivetrain.canDeepClimb,
                                "High climb needs Tank Drive deep climb")
                    } else {
                        return (true,
                                "\(difficulty.rawValue) is accessible to all drivetrains")
                    }
                case .balance:
                    return (result.playerBuild.drivetrain.canStrafe,
                            "Balance favors strafing (Swerve/Mecanum)")
                case .park:
                    return (true, "Simple park -- no special build needed")
                }
            }()
            analysisRow(
                icon: result.game.endgameChallenge.icon,
                label: "Endgame Fit",
                detail: endgameDetail,
                isGood: endgameFit,
                color: .purple
            )

            // Speed fit for archetype
            if result.game.archetype == .speed {
                let totalSpeed = result.playerBuild.drivetrain.baseSpeed
                    + result.playerBuild.frame.speedModifier
                    + result.playerBuild.manipulator.speedModifier
                let isFast = totalSpeed > 2.2
                analysisRow(
                    icon: "hare.fill",
                    label: "Speed Rating",
                    detail: "Speed Rush archetype rewards fast builds (\(String(format: "%.1f", totalSpeed)) m/s)",
                    isGood: isFast,
                    color: .cyan
                )
            }

            // Power fit for archetype
            if result.game.archetype == .power || result.game.archetype == .defenseArena {
                let strongPush = result.playerBuild.drivetrain.pushPower > 0.7
                analysisRow(
                    icon: "bolt.shield.fill",
                    label: "Power Rating",
                    detail: "\(result.game.archetype.rawValue) rewards strong pushers (\(result.playerBuild.drivetrain.shortLabel))",
                    isGood: strongPush,
                    color: .red
                )
            }

            // Endgame Focus fit
            if result.game.archetype == .endgameFocus {
                let endgameGood = result.game.endgameChallenge.requiresTank ? result.playerBuild.drivetrain.canDeepClimb :
                    (result.playerBuild.drivetrain.canStrafe || true)
                analysisRow(
                    icon: "flag.checkered",
                    label: "Endgame Prep",
                    detail: "Endgame Focus: \(result.game.endgameChallenge.points)pts available from endgame alone",
                    isGood: endgameGood,
                    color: .indigo
                )
            }

            // Hybrid fit
            if result.game.archetype == .hybrid {
                let canShoot = result.playerBuild.manipulator.canShoot
                let canReachMid = result.playerBuild.manipulator.maxReach >= .mid
                analysisRow(
                    icon: "arrow.triangle.branch",
                    label: "Versatility",
                    detail: "Hybrid Challenge rewards \(canShoot ? "shooting + " : "")reaching \(result.playerBuild.manipulator.maxReach.displayName)",
                    isGood: canShoot || canReachMid,
                    color: .mint
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.03))
        )
    }

    @ViewBuilder
    private func analysisRow(icon: String, label: String, detail: String, isGood: Bool, color: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
                Text(detail)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            Image(systemName: isGood ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(isGood ? .green : .red.opacity(0.7))
        }
        .padding(.vertical, 4)
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

        let buildLabel = "\(result.playerBuild.drivetrain.shortLabel) / \(result.playerBuild.frame.shortLabel) / \(result.playerBuild.manipulator.shortLabel) / \(result.playerBuild.intake.shortLabel)"
        decisionNode(
            icon: "wrench.and.screwdriver.fill",
            label: buildLabel,
            detail: "Robot build (max \(result.playerBuild.manipulator.maxReach.displayName))",
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
                Text("@\(timeStr) -- Score: \(event.redScoreAtTime)-\(event.blueScoreAtTime)")
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

    // MARK: - XP Section

    @ViewBuilder
    private var xpSection: some View {
        VStack(spacing: 10) {
            Text("XP EARNED")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1)

            if let rewards = rewards {
                // Total XP
                Text("+\(rewards.xpTotal) XP")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.orange)

                // Breakdown
                VStack(spacing: 4) {
                    ForEach(Array(rewards.xpBreakdown.enumerated()), id: \.offset) { _, item in
                        HStack {
                            Text(item.0)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                            Spacer()
                            Text("+\(item.1)")
                                .font(.caption.bold())
                                .foregroundStyle(.orange.opacity(0.8))
                        }
                    }
                }

                // Level progress bar
                VStack(spacing: 4) {
                    HStack {
                        Text("Level \(profileManager.profile.level)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                        Spacer()
                        Text("\(profileManager.profile.xp) / \(profileManager.profile.xpForNextLevel) XP")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.4))
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 6)
                            Capsule()
                                .fill(Color.orange)
                                .frame(width: max(2, geo.size.width * profileManager.profile.xpProgress), height: 6)
                                .animation(.easeOut(duration: 0.8), value: profileManager.profile.xpProgress)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.orange.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.orange.opacity(0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - Achievement Section

    @ViewBuilder
    private func achievementSection(achievements: [Achievement]) -> some View {
        VStack(spacing: 10) {
            Text("ACHIEVEMENTS UNLOCKED")
                .font(.caption.bold())
                .foregroundStyle(.yellow.opacity(0.7))
                .tracking(1)

            ForEach(achievements) { achievement in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(achievement.color.opacity(0.2))
                            .frame(width: 36, height: 36)
                        Image(systemName: achievement.icon)
                            .font(.body)
                            .foregroundStyle(achievement.color)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(achievement.rawValue)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                        Text(achievement.description)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Spacer()

                    Text("+\(achievement.xpReward) XP")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.orange.opacity(0.12)))
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(achievement.color.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(achievement.color.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.yellow.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.yellow.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - Level Up Overlay

    @ViewBuilder
    private func levelUpOverlay(level: Int) -> some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange)

                Text("LEVEL UP!")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("Level \(level)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)

                Text("New parts may be unlocked!")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(red: 0.08, green: 0.06, blue: 0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(Color.orange.opacity(0.4), lineWidth: 2)
                    )
            )
            .scaleEffect(showLevelUp ? 1 : 0.7)
            .opacity(showLevelUp ? 1 : 0)
        }
        .onTapGesture {
            withAnimation { showLevelUp = false }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Level up! You reached level \(level)")
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

    // MARK: - Build Recommendation

    @ViewBuilder
    private var buildRecommendationSection: some View {
        let recommendation = BuildRecommendation.forGame(result.game)
        let playerScore = result.buildMatchScore
        let improvement = recommendation.expectedScore - playerScore

        if improvement > 5 {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                    Text("BUILD RECOMMENDATION")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.yellow)
                        .tracking(0.5)
                    Spacer()
                    Text("+\(improvement) pts possible")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green.opacity(0.8))
                }

                Text("For \(result.game.name), try:")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))

                HStack(spacing: 8) {
                    recoPill(icon: recommendation.drivetrain.icon, label: recommendation.drivetrain.shortLabel,
                             color: recommendation.drivetrain.color)
                    recoPill(icon: recommendation.frame.icon, label: recommendation.frame.shortLabel,
                             color: recommendation.frame.color)
                    recoPill(icon: recommendation.manipulator.icon, label: recommendation.manipulator.shortLabel,
                             color: recommendation.manipulator.color)
                    recoPill(icon: recommendation.intake.icon, label: recommendation.intake.shortLabel,
                             color: recommendation.intake.color)
                }

                Text(recommendation.reasoning)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.yellow.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.yellow.opacity(0.15), lineWidth: 1)
                    )
            )
        }
    }

    @ViewBuilder
    private func recoPill(icon: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.08))
        )
    }

    // MARK: - Tournament Status

    @ViewBuilder
    private func tournamentStatusBanner(_ ts: TournamentState) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(.yellow)
                Text(ts.activeConfig.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Spacer()
                Text("Series: \(ts.seriesRecord)")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(.yellow)
            }

            // Match dots (showing which matches won/lost)
            HStack(spacing: 8) {
                ForEach(0..<ts.activeConfig.roundCount, id: \.self) { i in
                    if i < ts.matchResults.count {
                        let won = ts.matchResults[i].playerWon
                        Circle()
                            .fill(won ? Color.green : Color.red)
                            .frame(width: 14, height: 14)
                            .overlay(
                                Image(systemName: won ? "checkmark" : "xmark")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                    } else if i == ts.currentRound && !ts.isComplete {
                        Circle()
                            .strokeBorder(Color.yellow, lineWidth: 2)
                            .frame(width: 14, height: 14)
                            .overlay(
                                Text("\(i + 1)")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(.yellow)
                            )
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 14, height: 14)
                    }
                }
                Spacer()

                if ts.isComplete {
                    Text(ts.playerWonTournament ? "WON" : "ELIMINATED")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(ts.playerWonTournament ? .green : .red)
                } else {
                    Text("Next: \(ts.activeConfig.roundCount - ts.currentRound) remaining")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.yellow.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.yellow.opacity(0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - Button Label

    private var buttonLabel: String {
        if let ts = tournamentState {
            if ts.isComplete {
                return ts.playerWonTournament ? "Tournament Summary" : "Tournament Summary"
            } else {
                return "Next Match (\(ts.roundLabel))"
            }
        }
        return "Try New Game"
    }
}
