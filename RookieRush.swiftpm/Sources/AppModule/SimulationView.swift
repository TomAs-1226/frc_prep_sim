import SwiftUI
import SceneKit

// MARK: - Simulation View

/// Displays the 3D field with the robot running, overlaid with a live scoreboard.
struct SimulationView: View {
    let archetype: RobotArchetype
    let autoPlanType: AutoPlanType
    let onFinished: (SimulationResult) -> Void

    @StateObject private var engine: SimulationEngine
    @State private var scene: SCNScene?
    @State private var hasStarted = false
    @State private var countdown = 3

    init(archetype: RobotArchetype, autoPlanType: AutoPlanType, onFinished: @escaping (SimulationResult) -> Void) {
        self.archetype = archetype
        self.autoPlanType = autoPlanType
        self.onFinished = onFinished
        self._engine = StateObject(wrappedValue: SimulationEngine(
            archetype: archetype,
            autoPlanType: autoPlanType,
            seed: 42,
            speedMultiplier: 2.0
        ))
    }

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.08)
                .ignoresSafeArea()

            if let scene {
                // 3D Scene
                SceneView(
                    scene: scene,
                    options: [.allowsCameraControl]
                )
                .ignoresSafeArea()
            }

            // UI Overlays
            VStack {
                // Top scoreboard
                scoreboardOverlay
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                Spacer()

                // Bottom status bar
                statusBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            // Countdown overlay
            if !hasStarted {
                countdownOverlay
            }

            // Speed indicator
            if hasStarted && engine.isRunning {
                VStack {
                    HStack {
                        Spacer()
                        speedBadge
                            .padding(.trailing, 16)
                            .padding(.top, 60)
                    }
                    Spacer()
                }
            }
        }
        .onAppear { setupScene() }
        .onChange(of: engine.isFinished) { _, finished in
            if finished {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    onFinished(engine.result)
                }
            }
        }
    }

    // MARK: - Setup

    private func setupScene() {
        let (fieldScene, nodeTargets) = FieldBuilder.buildScene()
        let robotNode = RobotBuilder.buildRobot(archetype: archetype)
        fieldScene.rootNode.addChildNode(robotNode)

        engine.attach(scene: fieldScene, robotNode: robotNode, nodeTargets: nodeTargets)
        self.scene = fieldScene

        // Start countdown
        startCountdown()
    }

    private func startCountdown() {
        countdown = 3
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            Task { @MainActor in
                if countdown > 1 {
                    countdown -= 1
                } else {
                    timer.invalidate()
                    withAnimation {
                        hasStarted = true
                    }
                    engine.start()
                }
            }
        }
    }

    // MARK: - Scoreboard Overlay

    @ViewBuilder
    private var scoreboardOverlay: some View {
        HStack(spacing: 20) {
            // Points
            VStack(spacing: 2) {
                Text("POINTS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                Text("\(engine.currentPoints)")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.green)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Points: \(engine.currentPoints)")

            Divider()
                .frame(height: 36)
                .background(Color.white.opacity(0.2))

            // Time
            VStack(spacing: 2) {
                Text("TIME")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                Text(timeString)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(timeColor)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Time remaining: \(timeString)")

            Divider()
                .frame(height: 36)
                .background(Color.white.opacity(0.2))

            // Nodes scored
            VStack(spacing: 2) {
                Text("NODES")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                Text("\(engine.nodesScored)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Nodes scored: \(engine.nodesScored)")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .opacity(0.9)
        )
        .modifier(GlassModifier(shape: RoundedRectangle(cornerRadius: 16)))
    }

    private var timeString: String {
        let remaining = max(0, engine.matchDuration - engine.elapsedTime)
        let secs = Int(remaining)
        let tenths = Int((remaining - Double(secs)) * 10)
        return String(format: "%02d.%d", secs, tenths)
    }

    private var timeColor: Color {
        let remaining = engine.matchDuration - engine.elapsedTime
        if remaining < 5 { return .red }
        if remaining < 10 { return .yellow }
        return .white
    }

    // MARK: - Status Bar

    @ViewBuilder
    private var statusBar: some View {
        HStack(spacing: 12) {
            // Activity indicator
            Circle()
                .fill(activityColor)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)

            Text(engine.activity.rawValue)
                .font(.subheadline.bold())
                .foregroundStyle(.white)

            Text("—")
                .foregroundStyle(.white.opacity(0.3))

            Text(engine.statusMessage)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)

            Spacer()

            if engine.isFinished {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Complete!")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .opacity(0.85)
        )
        .modifier(GlassModifier(shape: RoundedRectangle(cornerRadius: 12)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status: \(engine.activity.rawValue). \(engine.statusMessage)")
    }

    private var activityColor: Color {
        switch engine.activity {
        case .idle:      return .gray
        case .driving:   return .cyan
        case .scoring:   return .green
        case .pickingUp: return .yellow
        case .stalled:   return .red
        case .finished:  return .green
        }
    }

    // MARK: - Countdown Overlay

    @ViewBuilder
    private var countdownOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("MATCH STARTING")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.7))
                    .tracking(2)

                Text("\(countdown)")
                    .font(.system(size: 80, weight: .black, design: .rounded))
                    .foregroundStyle(.orange)
                    .contentTransition(.numericText())
                    .animation(.easeInOut, value: countdown)
            }
        }
        .accessibilityLabel("Match starting in \(countdown)")
    }

    // MARK: - Speed Badge

    @ViewBuilder
    private var speedBadge: some View {
        Text("2x SPEED")
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(.yellow)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.yellow.opacity(0.15))
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.yellow.opacity(0.3), lineWidth: 1)
                    )
            )
    }
}
