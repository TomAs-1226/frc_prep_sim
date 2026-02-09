import SwiftUI

// MARK: - Content View

/// Main coordinator: Intro → Workshop → Simulation → Results
/// Supports both single-match and tournament (series) modes.
struct ContentView: View {
    @AppStorage("randomSeed") private var randomSeed: Int = 42

    @StateObject private var profileManager = ProfileManager()

    @State private var phase: GamePhase = .intro
    @State private var currentGame: GeneratedGame?
    @State private var strategy: AllianceStrategy?
    @State private var role: RobotRole?
    @State private var robotBuild: RobotBuild?
    @State private var autoPlan: AutoPlan?
    @State private var matchResult: MatchResult?
    @State private var showSettings = false
    @State private var showProfile = false
    @State private var roundCounter: Int = 0

    // Tournament mode state
    @StateObject private var tournamentState = TournamentState(
        config: TournamentConfig.quickPlay(seed: 42)
    )
    @State private var isTournamentMode = false
    @State private var showTournamentSummary = false

    var body: some View {
        ZStack {
            Group {
                switch phase {
                case .intro:
                    IntroView(
                        profileManager: profileManager,
                        onStart: { startSingleMatch() },
                        onStartTournament: { config in startTournament(config) }
                    )
                    .transition(.opacity)

                case .workshop:
                    if let game = currentGame {
                        PreMatchView(game: game, profileManager: profileManager) { strat, r, build, auto in
                            strategy = strat; role = r; robotBuild = build; autoPlan = auto
                            withAnimation(.easeInOut(duration: 0.4)) { phase = .simulation }
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    }

                case .simulation:
                    if let strat = strategy, let r = role,
                       let build = robotBuild, let auto = autoPlan,
                       let game = currentGame {
                        MatchView(strategy: strat, playerRole: r, playerBuild: build,
                                  autoPlan: auto, game: game,
                                  tournamentLabel: isTournamentMode ? tournamentState.roundLabel : nil,
                                  seriesRecord: isTournamentMode ? tournamentState.seriesRecord : nil
                        ) { result in
                            matchResult = result
                            if isTournamentMode {
                                tournamentState.recordResult(result)
                            }
                            withAnimation(.easeInOut(duration: 0.5)) { phase = .results }
                        }
                        .transition(.opacity)
                    }

                case .results:
                    if let result = matchResult {
                        ResultsView(
                            result: result,
                            profileManager: profileManager,
                            tournamentState: isTournamentMode ? tournamentState : nil,
                            onTryAgain: { handlePostResult() }
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                }
            }
            .animation(.easeInOut(duration: 0.4), value: phase)

            // Top bar (visible during intro and workshop)
            if phase == .intro || phase == .workshop {
                VStack {
                    HStack(spacing: 10) {
                        // Level badge
                        Button(action: { showProfile = true }) {
                            levelBadge
                        }
                        .accessibilityLabel("Open profile, level \(profileManager.profile.level)")

                        // Tournament badge (when in tournament mode)
                        if isTournamentMode && phase == .workshop {
                            tournamentBadge
                        }

                        Spacer()

                        settingsButton
                    }
                    .padding(.horizontal, 12)
                    Spacer()
                }
                .padding(.top, 8)
            }

            // Tournament summary overlay
            if showTournamentSummary {
                tournamentSummaryOverlay
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView(profileManager: profileManager) }
        .sheet(isPresented: $showProfile) { ProfileView(profileManager: profileManager) }
    }

    // MARK: - Level Badge

    private var levelBadge: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 28, height: 28)
                Text("\(profileManager.profile.level)")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("LEVEL")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(0.5)

                // XP progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 4)
                        Capsule()
                            .fill(Color.orange)
                            .frame(width: max(2, geo.size.width * profileManager.profile.xpProgress), height: 4)
                    }
                }
                .frame(width: 50, height: 4)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(Color.white.opacity(0.06))
        )
        .modifier(GlassModifier(shape: Capsule()))
    }

    // MARK: - Tournament Badge

    private var tournamentBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "trophy.fill")
                .font(.caption2)
                .foregroundStyle(.yellow)
            Text(tournamentState.config.name)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.8))
            Text(tournamentState.seriesRecord)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(.yellow)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(Color.yellow.opacity(0.1))
                .overlay(Capsule().strokeBorder(Color.yellow.opacity(0.3), lineWidth: 1))
        )
    }

    // MARK: - Settings Button

    private var settingsButton: some View {
        Button(action: { showSettings = true }) {
            Image(systemName: "gearshape.fill")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.6))
                .padding(10)
                .background(Circle().fill(Color.white.opacity(0.08)))
                .modifier(GlassModifier(shape: Circle()))
        }
        .accessibilityLabel("Open settings")
    }

    // MARK: - Tournament Summary Overlay

    @ViewBuilder
    private var tournamentSummaryOverlay: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()

            VStack(spacing: 20) {
                // Title
                VStack(spacing: 8) {
                    Image(systemName: tournamentState.playerWonTournament ? "crown.fill" : "xmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(tournamentState.playerWonTournament ? .yellow : .red.opacity(0.7))

                    Text(tournamentState.playerWonTournament ? "TOURNAMENT WON!" : "TOURNAMENT OVER")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text(tournamentState.config.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white.opacity(0.6))
                }

                // Series record
                HStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Text("\(tournamentState.playerWins)")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundStyle(.green)
                        Text("WINS")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Text("-")
                        .font(.title2.bold())
                        .foregroundStyle(.white.opacity(0.3))
                    VStack(spacing: 4) {
                        Text("\(tournamentState.opponentWins)")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundStyle(.red)
                        Text("LOSSES")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

                // Stats
                HStack(spacing: 20) {
                    statPill(label: "Avg Build", value: "\(tournamentState.averageBuildScore)", color: .cyan)
                    statPill(label: "Total Pts", value: "\(tournamentState.totalPlayerScore)", color: .orange)
                    statPill(label: "Matches", value: "\(tournamentState.matchResults.count)", color: .purple)
                }

                if tournamentState.isSweep {
                    Text("CLEAN SWEEP!")
                        .font(.caption.bold())
                        .foregroundStyle(.yellow)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.yellow.opacity(0.15)))
                }

                // Return button
                Button(action: {
                    withAnimation {
                        showTournamentSummary = false
                        isTournamentMode = false
                        resetToIntro()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Back to Menu")
                            .font(.headline)
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: 220)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.orange))
                }
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(red: 0.06, green: 0.05, blue: 0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(
                                tournamentState.playerWonTournament ?
                                    Color.yellow.opacity(0.4) : Color.red.opacity(0.3),
                                lineWidth: 2
                            )
                    )
            )
            .modifier(GlassModifier(shape: RoundedRectangle(cornerRadius: 24)))
        }
        .transition(.scale.combined(with: .opacity))
    }

    @ViewBuilder
    private func statPill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.08))
        )
    }

    // MARK: - Game Flow

    private func startSingleMatch() {
        isTournamentMode = false
        roundCounter += 1
        currentGame = GameGenerator.generate(seed: UInt64(randomSeed + roundCounter))
        withAnimation(.easeInOut(duration: 0.4)) { phase = .workshop }
    }

    private func startTournament(_ config: TournamentConfig) {
        isTournamentMode = true
        tournamentState.resetWith(config: config)
        currentGame = tournamentState.currentGame
        withAnimation(.easeInOut(duration: 0.4)) { phase = .workshop }
    }

    private func handlePostResult() {
        strategy = nil; role = nil; robotBuild = nil; autoPlan = nil; matchResult = nil

        if isTournamentMode {
            if tournamentState.isComplete {
                // Check tournament achievements
                if tournamentState.playerWonTournament {
                    if !profileManager.profile.earnedAchievements.contains(Achievement.tournamentWinner.rawValue) {
                        profileManager.profile.earnedAchievements.insert(Achievement.tournamentWinner.rawValue)
                        _ = profileManager.profile.addXP(Achievement.tournamentWinner.xpReward)
                        profileManager.save()
                    }
                    if tournamentState.isSweep {
                        if !profileManager.profile.earnedAchievements.contains(Achievement.tournamentSweep.rawValue) {
                            profileManager.profile.earnedAchievements.insert(Achievement.tournamentSweep.rawValue)
                            _ = profileManager.profile.addXP(Achievement.tournamentSweep.xpReward)
                            profileManager.save()
                        }
                    }
                }
                withAnimation { showTournamentSummary = true }
            } else {
                // Next tournament match
                currentGame = tournamentState.currentGame
                withAnimation(.easeInOut(duration: 0.4)) { phase = .workshop }
            }
        } else {
            roundCounter += 1
            currentGame = GameGenerator.generate(seed: UInt64(randomSeed + roundCounter))
            withAnimation(.easeInOut(duration: 0.4)) { phase = .workshop }
        }
    }

    private func resetToIntro() {
        strategy = nil; role = nil; robotBuild = nil; autoPlan = nil
        matchResult = nil; currentGame = nil
        withAnimation(.easeInOut(duration: 0.4)) { phase = .intro }
    }
}
