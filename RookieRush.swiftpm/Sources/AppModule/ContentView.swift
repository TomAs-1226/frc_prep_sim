import SwiftUI

// MARK: - Content View

/// Main coordinator: Intro → Workshop → Simulation → Results
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

    var body: some View {
        ZStack {
            Group {
                switch phase {
                case .intro:
                    IntroView(profileManager: profileManager, onStart: {
                        currentGame = GameGenerator.generate(seed: UInt64(randomSeed + roundCounter))
                        withAnimation(.easeInOut(duration: 0.4)) { phase = .workshop }
                    })
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
                                  autoPlan: auto, game: game) { result in
                            matchResult = result
                            withAnimation(.easeInOut(duration: 0.5)) { phase = .results }
                        }
                        .transition(.opacity)
                    }

                case .results:
                    if let result = matchResult {
                        ResultsView(result: result, profileManager: profileManager,
                                    onTryAgain: { resetGame() })
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

                        Spacer()

                        settingsButton
                    }
                    .padding(.horizontal, 12)
                    Spacer()
                }
                .padding(.top, 8)
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

    private func resetGame() {
        strategy = nil; role = nil; robotBuild = nil; autoPlan = nil; matchResult = nil
        roundCounter += 1
        currentGame = GameGenerator.generate(seed: UInt64(randomSeed + roundCounter))
        withAnimation(.easeInOut(duration: 0.4)) { phase = .workshop }
    }
}
