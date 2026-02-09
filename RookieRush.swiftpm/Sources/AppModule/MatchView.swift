import SwiftUI
import SceneKit

// MARK: - Match View

/// Full match simulation view: 3D SceneKit field + scoreboard + callout buttons + coaching.
struct MatchView: View {
    let strategy: AllianceStrategy
    let playerRole: RobotRole
    let playerBuild: RobotBuild
    let autoPlan: AutoPlan
    let game: GeneratedGame
    let tournamentLabel: String?
    let seriesRecord: String?
    let onFinish: (MatchResult) -> Void

    @StateObject private var engine: MatchEngine
    @State private var sceneView: SCNView?
    @State private var scene: SCNScene?
    @State private var hasStarted = false
    @State private var validationFailures: [RobotValidator.ValidationFailure] = []
    @State private var showValidationOverlay = false
    @State private var countdownValue: Int? = nil

    init(strategy: AllianceStrategy, playerRole: RobotRole, playerBuild: RobotBuild,
         autoPlan: AutoPlan, game: GeneratedGame,
         tournamentLabel: String? = nil, seriesRecord: String? = nil,
         onFinish: @escaping (MatchResult) -> Void) {
        self.strategy = strategy
        self.playerRole = playerRole
        self.playerBuild = playerBuild
        self.autoPlan = autoPlan
        self.game = game
        self.tournamentLabel = tournamentLabel
        self.seriesRecord = seriesRecord
        self.onFinish = onFinish

        let configs = RobotConfigFactory.buildRobots(
            playerRole: playerRole, strategy: strategy, playerBuild: playerBuild
        )
        _engine = StateObject(wrappedValue: MatchEngine(
            configs: configs, strategy: strategy, playerAuto: autoPlan, game: game
        ))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // 3D Scene
            MatchSceneView(engine: engine, onSceneReady: { s in
                scene = s
            }, onValidation: { failures in
                let errors = failures.filter { $0.severity == .error }
                if !errors.isEmpty {
                    validationFailures = failures
                    showValidationOverlay = true
                }
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
                        Text("0.5x SLOW-MO")
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
                        Text("2x SPEED")
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

                // Footer: game name + tournament info
                VStack(spacing: 2) {
                    if let label = tournamentLabel {
                        HStack(spacing: 6) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.yellow.opacity(0.7))
                            Text(label)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.yellow.opacity(0.7))
                            if let record = seriesRecord {
                                Text("(\(record))")
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .foregroundStyle(.yellow.opacity(0.5))
                            }
                        }
                    }
                    Text(game.name)
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.25))
                }
                .padding(.bottom, 4)

                // Bottom controls
                controlBar
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
            .animation(.easeInOut(duration: 0.3), value: engine.isSlowMo)

            // Countdown overlay
            if let count = countdownValue {
                countdownOverlay(count: count)
            }

            // "Match Over" overlay
            if engine.isFinished {
                matchOverOverlay
            }

            // Validation failure overlay (blocks simulation)
            if showValidationOverlay {
                validationOverlay
            }
        }
        .onAppear {
            if !hasStarted {
                hasStarted = true
                startWithCountdown()
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
                        .accessibilityLabel("Callout: \(callout.rawValue) -- \(isActive ? "Active" : callout.subtitle)")
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

    // MARK: - Countdown

    private func startWithCountdown() {
        countdownValue = 3
        withAnimation(.easeInOut(duration: 0.3)) {}
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation { countdownValue = 2 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { countdownValue = 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation {
                countdownValue = nil
                engine.start()
            }
        }
    }

    @ViewBuilder
    private func countdownOverlay(count: Int) -> some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text(game.name)
                    .font(.headline.bold())
                    .foregroundStyle(.orange)
                    .tracking(1.5)

                Text("\(count)")
                    .font(.system(size: 80, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .scaleEffect(1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: count)

                Text("GET READY")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(3)
            }
        }
        .transition(.opacity)
    }

    // MARK: - Match Over Overlay

    @ViewBuilder
    private var matchOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

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
        }
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Validation Overlay

    @ViewBuilder
    private var validationOverlay: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.red)

                Text("ROBOT MODEL VALIDATION FAILED")
                    .font(.headline.bold())
                    .foregroundStyle(.red)

                Text("The simulation cannot proceed with broken models.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))

                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(validationFailures) { failure in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: failure.severity == .error
                                      ? "xmark.circle.fill" : "exclamationmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(failure.severity == .error ? .red : .yellow)
                                Text("[\(failure.severity.rawValue)] \(failure.description)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                    }
                    .padding(12)
                }
                .frame(maxHeight: 300)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.05))
                )
            }
            .padding(24)
        }
    }
}

// MARK: - SceneKit Representable

struct MatchSceneView: UIViewRepresentable {
    let engine: MatchEngine
    let onSceneReady: (SCNScene) -> Void
    let onValidation: ([RobotValidator.ValidationFailure]) -> Void

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .black
        view.antialiasingMode = .multisampling4X
        view.allowsCameraControl = true

        let (scene, zoneNodes) = FieldBuilder.buildScene(game: engine.game)
        let robotNodes = RobotModelFactory.addRobots(to: scene, configs: engine.configs)

        // Validate all robot models
        var allFailures: [RobotValidator.ValidationFailure] = []
        for robotNode in robotNodes {
            let result = RobotValidator.validate(root: robotNode)
            allFailures.append(contentsOf: result.failures)
        }
        if !allFailures.isEmpty {
            onValidation(allFailures)
        }

        engine.attach(scene: scene, robotNodes: robotNodes, zoneNodes: zoneNodes)

        // Robot spawn-in animation: scale from 0 → 1 with a bounce
        for (i, robotNode) in robotNodes.enumerated() {
            robotNode.scale = SCNVector3(0.01, 0.01, 0.01)
            let delay = Double(i) * 0.15
            let scaleUp = SCNAction.scale(to: 1.1, duration: 0.3)
            scaleUp.timingMode = .easeOut
            let settle = SCNAction.scale(to: 1.0, duration: 0.15)
            settle.timingMode = .easeInEaseOut
            robotNode.runAction(SCNAction.sequence([
                SCNAction.wait(duration: delay),
                scaleUp,
                settle
            ]))
        }

        // Camera fly-in animation
        if let cameraNode = scene.rootNode.childNodes.first(where: { $0.camera != nil }) {
            let finalPos = cameraNode.position
            let finalRot = cameraNode.eulerAngles
            // Start higher and further back
            cameraNode.position = SCNVector3(finalPos.x, finalPos.y + 3.0, finalPos.z + 4.0)
            cameraNode.eulerAngles.x = finalRot.x - 0.3

            let moveIn = SCNAction.move(to: finalPos, duration: 2.5)
            moveIn.timingMode = .easeInEaseOut
            cameraNode.runAction(moveIn)

            let rotateIn = SCNAction.customAction(duration: 2.5) { node, elapsed in
                let t = Float(elapsed / 2.5)
                let eased = t * t * (3.0 - 2.0 * t) // smoothstep
                node.eulerAngles.x = (finalRot.x - 0.3) + 0.3 * eased
            }
            cameraNode.runAction(rotateIn)
        }

        view.scene = scene
        onSceneReady(scene)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}
}
