import SwiftUI

// MARK: - Content View

/// Main coordinator view that manages the linear game flow:
/// Welcome → Build Choice → Auto Choice → Simulation → Results
struct ContentView: View {
    @State private var phase: GamePhase = .welcome
    @State private var selectedArchetype: RobotArchetype?
    @State private var selectedAutoPlan: AutoPlanType?
    @State private var simulationResult: SimulationResult?
    @State private var showSettings = false

    var body: some View {
        ZStack {
            // Phase-specific content
            Group {
                switch phase {
                case .welcome:
                    WelcomeView(onStart: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            phase = .buildChoice
                        }
                    })
                    .transition(.opacity)

                case .buildChoice:
                    BuildChoiceView(onSelect: { archetype in
                        selectedArchetype = archetype
                        withAnimation(.easeInOut(duration: 0.4)) {
                            phase = .autoChoice
                        }
                    })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                case .autoChoice:
                    if let archetype = selectedArchetype {
                        AutoChoiceView(archetype: archetype, onSelect: { plan in
                            selectedAutoPlan = plan
                            withAnimation(.easeInOut(duration: 0.4)) {
                                phase = .simulation
                            }
                        })
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    }

                case .simulation:
                    if let archetype = selectedArchetype,
                       let autoPlan = selectedAutoPlan {
                        SimulationView(
                            archetype: archetype,
                            autoPlanType: autoPlan,
                            onFinished: { result in
                                simulationResult = result
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    phase = .results
                                }
                            }
                        )
                        .transition(.opacity)
                    }

                case .results:
                    if let result = simulationResult {
                        ResultsView(result: result, onTryAgain: {
                            resetGame()
                        })
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                }
            }
            .animation(.easeInOut(duration: 0.4), value: phase)

            // Settings button (top-right, always visible except during sim)
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
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    // MARK: - Settings Button

    @ViewBuilder
    private var settingsButton: some View {
        Button(action: { showSettings = true }) {
            Image(systemName: "gearshape.fill")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.6))
                .padding(10)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.08))
                )
                .modifier(GlassModifier(shape: Circle()))
        }
        .accessibilityLabel("Open settings")
    }

    // MARK: - Reset

    private func resetGame() {
        selectedArchetype = nil
        selectedAutoPlan = nil
        simulationResult = nil
        withAnimation(.easeInOut(duration: 0.4)) {
            phase = .welcome
        }
    }
}
