import SwiftUI
import SceneKit

// MARK: - Match View

/// Full match simulation view: 3D SceneKit field + scoreboard + callout buttons + coaching.
struct MatchView: View {
    let strategy: AllianceStrategy
    let playerRole: RobotRole
    let autoPlan: AutoPlan
    let onFinish: (MatchResult) -> Void

    @StateObject private var engine: MatchEngine
    @State private var sceneView: SCNView?
    @State private var scene: SCNScene?
    @State private var hasStarted = false

    init(strategy: AllianceStrategy, playerRole: RobotRole, autoPlan: AutoPlan,
         onFinish: @escaping (MatchResult) -> Void) {
        self.strategy = strategy
        self.playerRole = playerRole
        self.autoPlan = autoPlan
        self.onFinish = onFinish

        let configs = RobotFactory.buildRobots(playerRole: playerRole, strategy: strategy)
        _engine = StateObject(wrappedValue: MatchEngine(
            configs: configs, strategy: strategy, playerAuto: autoPlan
        ))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // 3D Scene
            MatchSceneView(engine: engine, onSceneReady: { s in
                scene = s
            })
            .ignoresSafeArea()

            // UI Overlays
            VStack(spacing: 0) {
                // Top scoreboard
                scoreboardBar
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                Spacer()

                // Coaching panel (visible during slow-mo)
                CoachingPanel(tip: engine.currentTip, isVisible: engine.isSlowMo)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .animation(.easeInOut(duration: 0.3), value: engine.isSlowMo)

                // Bottom controls
                controlBar
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }

            // "Match Over" overlay
            if engine.isFinished {
                matchOverOverlay
            }
        }
        .onAppear {
            if !hasStarted {
                hasStarted = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    engine.start()
                }
            }
        }
        .onChange(of: engine.isFinished) { finished in
            if finished {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    onFinish(engine.result)
                }
            }
        }
    }

    // MARK: - Scoreboard

    @ViewBuilder
    private var scoreboardBar: some View {
        HStack(spacing: 0) {
            // Red score
            VStack(spacing: 2) {
                Text("RED")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.red.opacity(0.8))
                Text("\(engine.redScore)")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.red)
            }
            .frame(minWidth: 60)

            Spacer()

            // Center: time + period
            VStack(spacing: 2) {
                Text(engine.period.rawValue)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.orange)
                    .tracking(1)
                Text(timeString)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                Text(engine.strategyMode)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            // Blue score
            VStack(spacing: 2) {
                Text("BLUE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color(red: 0.3, green: 0.5, blue: 1.0).opacity(0.8))
                Text("\(engine.blueScore)")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.3, green: 0.5, blue: 1.0))
            }
            .frame(minWidth: 60)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.6))
        )
        .modifier(GlassModifier(shape: RoundedRectangle(cornerRadius: 14)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Score: Red \(engine.redScore), Blue \(engine.blueScore). \(engine.period.rawValue) period. \(timeString) remaining.")
    }

    private var timeString: String {
        let remaining = max(0, MatchTiming.totalDuration - engine.simTime)
        let m = Int(remaining) / 60
        let s = Int(remaining) % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Control Bar

    @ViewBuilder
    private var controlBar: some View {
        HStack(spacing: 10) {
            // Slow-mo button
            Button(action: { engine.activateSlowMo() }) {
                HStack(spacing: 5) {
                    Image(systemName: engine.isSlowMo ? "eye.fill" : "magnifyingglass")
                        .font(.caption)
                    Text(engine.isSlowMo ? "Coaching..." : "Slow-Mo")
                        .font(.caption.bold())
                }
                .foregroundStyle(engine.isSlowMo ? .black : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(engine.isSlowMo ? Color.orange : Color.white.opacity(0.1))
                )
            }
            .disabled(engine.isSlowMo || !engine.isRunning)
            .accessibilityLabel("Activate slow motion coaching")

            Spacer()

            // Callout buttons
            ForEach(Callout.allCases) { callout in
                Button(action: { engine.useCallout(callout) }) {
                    VStack(spacing: 2) {
                        Image(systemName: callout.icon)
                            .font(.caption)
                        Text(callout.rawValue)
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundStyle(engine.canUseCallout ? callout.color : .white.opacity(0.3))
                    .frame(minWidth: 58)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(engine.canUseCallout ? 0.08 : 0.03))
                    )
                }
                .disabled(!engine.canUseCallout)
                .accessibilityLabel("Callout: \(callout.rawValue)")
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.5))
        )
        .modifier(GlassModifier(shape: RoundedRectangle(cornerRadius: 16)))
    }

    // MARK: - Match Over Overlay

    @ViewBuilder
    private var matchOverOverlay: some View {
        VStack(spacing: 12) {
            Text("MATCH OVER")
                .font(.title.bold())
                .foregroundStyle(.white)
            Text(engine.redScore > engine.blueScore ? "Red Alliance Wins!" :
                    (engine.blueScore > engine.redScore ? "Blue Alliance Wins!" : "It's a Tie!"))
                .font(.headline)
                .foregroundStyle(engine.redScore >= engine.blueScore ? .red : Color(red: 0.3, green: 0.5, blue: 1.0))

            Text("Loading results...")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.8))
        )
        .modifier(GlassModifier(shape: RoundedRectangle(cornerRadius: 20)))
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - SceneKit Representable

/// UIViewRepresentable wrapping SceneKit for the match simulation.
struct MatchSceneView: UIViewRepresentable {
    let engine: MatchEngine
    let onSceneReady: (SCNScene) -> Void

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .black
        view.antialiasingMode = .multisampling4X
        view.allowsCameraControl = false

        let (scene, reefNodes) = FieldBuilder.buildScene()
        let robotNodes = RobotBuilder.addRobots(to: scene, configs: engine.configs)
        engine.attach(scene: scene, robotNodes: robotNodes, reefNodes: reefNodes)

        view.scene = scene
        onSceneReady(scene)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}
}
