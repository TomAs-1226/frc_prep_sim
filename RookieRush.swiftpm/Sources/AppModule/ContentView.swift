import SwiftUI

// MARK: - Content View

/// Main coordinator: Intro → PreMatch → Simulation → Results
struct ContentView: View {
    @State private var phase: GamePhase = .intro
    @State private var strategy: AllianceStrategy?
    @State private var role: RobotRole?
    @State private var robotBuild: RobotBuild?
    @State private var autoPlan: AutoPlan?
    @State private var matchResult: MatchResult?
    @State private var showSettings = false

    var body: some View {
        ZStack {
            Group {
                switch phase {
                case .intro:
                    IntroView(onStart: {
                        withAnimation(.easeInOut(duration: 0.4)) { phase = .preMatch }
                    })
                    .transition(.opacity)

                case .preMatch:
                    PreMatchView { strat, r, build, auto in
                        strategy = strat; role = r; robotBuild = build; autoPlan = auto
                        withAnimation(.easeInOut(duration: 0.4)) { phase = .simulation }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                case .simulation:
                    if let strat = strategy, let r = role, let build = robotBuild, let auto = autoPlan {
                        MatchView(strategy: strat, playerRole: r, playerBuild: build, autoPlan: auto) { result in
                            matchResult = result
                            withAnimation(.easeInOut(duration: 0.5)) { phase = .results }
                        }
                        .transition(.opacity)
                    }

                case .results:
                    if let result = matchResult {
                        ResultsView(result: result, onTryAgain: { resetGame() })
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                }
            }
            .animation(.easeInOut(duration: 0.4), value: phase)

            // Settings button (hidden during match)
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
        withAnimation(.easeInOut(duration: 0.4)) { phase = .intro }
    }
}
