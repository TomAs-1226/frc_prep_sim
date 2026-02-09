import SwiftUI

// MARK: - Content View

/// Main coordinator: Intro → PreMatch → Simulation → Results
/// Also supports: Tournament flow with series of matches
struct ContentView: View {
    @State private var phase: GamePhase = .intro
    @State private var strategy: AllianceStrategy?
    @State private var role: RobotRole?
    @State private var robotBuild: RobotBuild?
    @State private var autoPlan: AutoPlan?
    @State private var matchResult: MatchResult?
    @State private var showSettings = false

    // Tournament
    @State private var tournamentConfig: TournamentConfig?
    @State private var tournament: TournamentState?
    @State private var inTournament = false
    @State private var matchSeed: UInt64 = 42
    @State private var blueMatchPolicy: StrategyPolicy?

    var body: some View {
        ZStack {
            Group {
                switch phase {
                case .intro:
                    IntroView(
                        onStart: {
                            inTournament = false
                            matchSeed = UInt64.random(in: 1...100000)
                            blueMatchPolicy = nil
                            withAnimation(.easeInOut(duration: 0.4)) { phase = .preMatch }
                        },
                        onTournament: {
                            withAnimation(.easeInOut(duration: 0.4)) { phase = .tournament }
                        }
                    )
                    .transition(.opacity)

                case .preMatch:
                    PreMatchView { strat, r, build, auto in
                        strategy = strat; role = r; robotBuild = build; autoPlan = auto
                        if inTournament, let config = tournamentConfig {
                            let ts = TournamentState(config: config, strategy: strat,
                                                      role: r, build: build, auto: auto)
                            tournament = ts
                            matchSeed = ts.currentSeed
                            blueMatchPolicy = ts.opponentStrategy(for: 0)
                        }
                        withAnimation(.easeInOut(duration: 0.4)) { phase = .simulation }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                case .simulation:
                    if let strat = strategy, let r = role, let build = robotBuild, let auto = autoPlan {
                        MatchView(
                            strategy: strat, playerRole: r, playerBuild: build,
                            autoPlan: auto, seed: matchSeed, bluePolicy: blueMatchPolicy
                        ) { result in
                            handleMatchResult(result)
                        }
                        .id(matchSeed) // Force new view for each match
                        .transition(.opacity)
                    }

                case .results:
                    if let result = matchResult {
                        ResultsView(
                            result: result,
                            tournament: tournament,
                            onTryAgain: {
                                if inTournament, let ts = tournament, !ts.isComplete {
                                    // Continue tournament — start next match
                                    matchSeed = ts.currentSeed
                                    blueMatchPolicy = ts.opponentStrategy(for: ts.currentMatchIndex)
                                    withAnimation(.easeInOut(duration: 0.4)) { phase = .simulation }
                                } else {
                                    resetGame()
                                }
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }

                case .tournament:
                    TournamentSelectView(
                        onSelect: { config in
                            tournamentConfig = config
                            inTournament = true
                            withAnimation(.easeInOut(duration: 0.4)) { phase = .preMatch }
                        },
                        onBack: {
                            withAnimation(.easeInOut(duration: 0.4)) { phase = .intro }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                case .tournamentResults:
                    if let ts = tournament {
                        TournamentResultsView(tournament: ts) { resetGame() }
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                }
            }
            .animation(.easeInOut(duration: 0.4), value: phase)

            // Settings button
            if phase != .simulation {
                VStack {
                    HStack {
                        Spacer()
                        settingsButton
                    }
                    Spacer()
                }
                .padding(.top, 8)
                .padding(.trailing, 12)
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    // MARK: - Match Result Handling

    private func handleMatchResult(_ result: MatchResult) {
        matchResult = result

        if inTournament, let ts = tournament {
            ts.recordResult(result)
            if ts.isComplete {
                withAnimation(.easeInOut(duration: 0.5)) { phase = .tournamentResults }
            } else {
                withAnimation(.easeInOut(duration: 0.5)) { phase = .results }
            }
        } else {
            withAnimation(.easeInOut(duration: 0.5)) { phase = .results }
        }
    }

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

    private func resetGame() {
        strategy = nil; role = nil; robotBuild = nil; autoPlan = nil; matchResult = nil
        inTournament = false; tournamentConfig = nil; tournament = nil
        blueMatchPolicy = nil; matchSeed = 42
        withAnimation(.easeInOut(duration: 0.4)) { phase = .intro }
    }
}
