import SwiftUI
import SceneKit

// MARK: - Match View

/// Full match simulation view: 3D SceneKit field + scoreboard + callout buttons + coaching.
struct MatchView: View {
    let strategy: AllianceStrategy
    let playerRole: RobotRole
    let playerBuild: RobotBuild
    let autoPlan: AutoPlan
    let onFinish: (MatchResult) -> Void

    @StateObject private var engine: MatchEngine
    @State private var sceneView: SCNView?
    @State private var scene: SCNScene?
    @State private var hasStarted = false

    init(strategy: AllianceStrategy, playerRole: RobotRole, playerBuild: RobotBuild,
         autoPlan: AutoPlan, onFinish: @escaping (MatchResult) -> Void) {
        self.strategy = strategy
        self.playerRole = playerRole
        self.playerBuild = playerBuild
        self.autoPlan = autoPlan
        self.onFinish = onFinish

        let configs = RobotFactory.buildRobots(
            playerRole: playerRole, strategy: strategy, playerBuild: playerBuild
        )
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

            // Slow-mo dim overlay
            if engine.isSlowMo {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)

                // Vignette border
                RoundedRectangle(cornerRadius: 0)
                    .strokeBorder(
                        RadialGradient(
                            colors: [.clear, Color.orange.opacity(0.25)],
                            center: .center,
                            startRadius: 200, endRadius: 500
                        ),
                        lineWidth: 80
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            // UI Overlays
            VStack(spacing: 0) {
                // Top scoreboard
                scoreboardBar
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                // Speed indicator
                if engine.isSlowMo {
                    HStack(spacing: 6) {
                        Image(systemName: "tortoise.fill")
                            .font(.caption2)
                        Text("0.5× SLOW-MO")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.orange.opacity(0.15)))
                    .transition(.scale.combined(with: .opacity))
                    .padding(.top, 6)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "hare.fill")
                            .font(.system(size: 8))
                        Text("2× SPEED")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.top, 4)
                }

                Spacer()

                // Coaching panel (visible during slow-mo)
                CoachingPanel(tip: engine.currentTip, isVisible: engine.isSlowMo)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .animation(.easeInOut(duration: 0.3), value: engine.isSlowMo)

                // Footer text
                Text("Demo Level 1 — future levels will be more in-depth")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.2))
                    .padding(.bottom, 4)

                // Bottom controls
                controlBar
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
            .animation(.easeInOut(duration: 0.3), value: engine.isSlowMo)

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

            // Callout buttons (6 options, scrollable, per-callout availability)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(Callout.allCases) { callout in
                        let available = engine.canUseCallout(callout)
                        let isActive = engine.activeCallouts.contains(callout)
                        Button(action: { engine.useCallout(callout) }) {
                            VStack(spacing: 1) {
                                Image(systemName: callout.icon)
                                    .font(.system(size: 10))
                                Text(callout.rawValue)
                                    .font(.system(size: 7, weight: .bold))
                                Text(isActive ? "ACTIVE" : callout.subtitle)
                                    .font(.system(size: 6, weight: isActive ? .bold : .regular))
                                    .foregroundStyle(isActive ? .green.opacity(0.9) : .white.opacity(0.35))
                            }
                            .foregroundStyle(isActive ? .green : (available ? callout.color : .white.opacity(0.3)))
                            .frame(minWidth: 50)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isActive ? Color.green.opacity(0.12) :
                                            Color.white.opacity(available ? 0.08 : 0.03))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(isActive ? Color.green.opacity(0.5) : Color.clear, lineWidth: 1)
                                    )
                            )
                        }
                        .disabled(!available)
                        .accessibilityLabel("Callout: \(callout.rawValue) — \(isActive ? "Active" : callout.subtitle)")
                    }

                    // Cooldown indicator
                    if engine.calloutCooldown > 0 {
                        VStack(spacing: 2) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 9))
                            Text(String(format: "%.0fs", engine.calloutCooldown))
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(.orange.opacity(0.6))
                        .frame(minWidth: 36)
                        .padding(.vertical, 6)
                    }
                }
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

struct MatchSceneView: UIViewRepresentable {
    let engine: MatchEngine
    let onSceneReady: (SCNScene) -> Void

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .black
        view.antialiasingMode = .multisampling4X
        view.allowsCameraControl = true  // Drag to orbit, pinch to zoom

        let (scene, reefNodes) = FieldBuilder.buildScene()
        let robotNodes = RobotBuilder.addRobots(to: scene, configs: engine.configs)
        engine.attach(scene: scene, robotNodes: robotNodes, reefNodes: reefNodes)

        view.scene = scene
        onSceneReady(scene)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}
}
