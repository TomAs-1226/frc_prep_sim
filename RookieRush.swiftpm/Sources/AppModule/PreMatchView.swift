import SwiftUI
import SceneKit

// MARK: - 3D Robot Preview

/// Rotating 3D preview of the current robot build, shown on the build selection page.
struct RobotPreviewView: UIViewRepresentable {
    let build: RobotBuild
    let role: RobotRole

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling2X

        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        // Camera
        let cam = SCNCamera()
        cam.fieldOfView = 30
        cam.zNear = 0.01
        cam.zFar = 10
        let camNode = SCNNode()
        camNode.camera = cam
        camNode.position = SCNVector3(0, 0.35, 0.9)
        camNode.eulerAngles.x = -0.35
        scene.rootNode.addChildNode(camNode)

        // Lighting
        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .omni
        keyLight.light?.intensity = 900
        keyLight.light?.color = UIColor(white: 0.95, alpha: 1)
        keyLight.position = SCNVector3(0.6, 1.2, 0.8)
        scene.rootNode.addChildNode(keyLight)

        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .omni
        fillLight.light?.intensity = 400
        fillLight.light?.color = UIColor(white: 0.85, alpha: 1)
        fillLight.position = SCNVector3(-0.4, 0.5, -0.5)
        scene.rootNode.addChildNode(fillLight)

        let ambLight = SCNNode()
        ambLight.light = SCNLight()
        ambLight.light?.type = .ambient
        ambLight.light?.intensity = 350
        scene.rootNode.addChildNode(ambLight)

        // Floor disc for grounding
        let floorGeo = SCNCylinder(radius: 0.3, height: 0.005)
        floorGeo.radialSegmentCount = 24
        let floorMat = SCNMaterial()
        floorMat.diffuse.contents = UIColor(white: 0.12, alpha: 0.5)
        floorGeo.materials = [floorMat]
        let floorNode = SCNNode(geometry: floorGeo)
        floorNode.position = SCNVector3(0, -0.002, 0)
        scene.rootNode.addChildNode(floorNode)

        view.scene = scene
        buildAndAddRobot(to: scene)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        guard let scene = uiView.scene else { return }
        scene.rootNode.childNode(withName: "preview_robot", recursively: false)?.removeFromParentNode()
        buildAndAddRobot(to: scene)
    }

    private func buildAndAddRobot(to scene: SCNScene) {
        let config = RobotFactory.previewConfig(build: build, role: role)
        let robot = RobotBuilder.buildRobot(config: config)
        robot.name = "preview_robot"
        scene.rootNode.addChildNode(robot)

        let rotate = SCNAction.repeatForever(
            SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 10)
        )
        robot.runAction(rotate)

        robot.enumerateChildNodes { child, _ in
            if let name = child.name, name.hasPrefix("wheel_") {
                let spin = SCNAction.repeatForever(
                    SCNAction.rotateBy(x: CGFloat.pi * 2, y: 0, z: 0, duration: 1.0)
                )
                child.runAction(spin)
            }
            if child.name == "intake_roller" {
                let spin = SCNAction.repeatForever(
                    SCNAction.rotateBy(x: 0, y: 0, z: CGFloat.pi * 2, duration: 0.8)
                )
                child.runAction(spin)
            }
        }
    }
}

// MARK: - Robot Workshop (Pre-Match View)

/// 5-step workshop: Game Reveal -> Robot Build -> Strategy -> Role -> Auto Plan.
/// The star experience of the app — players see the generated game challenge first,
/// then build their robot to match it, then choose strategy and role.
struct PreMatchView: View {
    let game: GeneratedGame
    let onReady: (AllianceStrategy, RobotRole, RobotBuild, AutoPlan) -> Void

    @State private var step = 0
    @State private var selectedStrategy: AllianceStrategy?
    @State private var selectedRole: RobotRole?
    @State private var selectedBuild = RobotBuild()
    @State private var selectedAuto: AutoPlan?

    private let stepCount = 5
    private let stepLabels = ["Game", "Build", "Strategy", "Role", "Auto"]

    private var fieldMatchScore: Int {
        game.buildMatchScore(build: selectedBuild)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.12),
                    Color(red: 0.08, green: 0.06, blue: 0.16),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                ScrollView {
                    VStack(spacing: 20) {
                        switch step {
                        case 0: gameRevealStep
                        case 1: buildStep
                        case 2: strategyStep
                        case 3: roleStep
                        default: autoStep
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }

                bottomBar
            }
        }
    }

    // MARK: - Progress Bar

    @ViewBuilder
    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<stepCount, id: \.self) { i in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i <= step ? Color.orange : Color.white.opacity(0.15))
                        .frame(height: 4)
                    Text(stepLabels[i])
                        .font(.system(size: 8, weight: i == step ? .bold : .regular))
                        .foregroundStyle(i == step ? .orange : .white.opacity(0.4))
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
    }

    // MARK: - Step 0: Game Reveal

    @ViewBuilder
    private var gameRevealStep: some View {
        VStack(spacing: 16) {
            stepHeader(title: "Game Reveal", subtitle: "Study the challenge before you build.")

            // Game name
            VStack(spacing: 6) {
                Text(game.name.uppercased())
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(.white)
                    .tracking(1.5)
                    .multilineTextAlignment(.center)

                // Archetype badge
                HStack(spacing: 8) {
                    Image(systemName: game.archetype.icon)
                        .font(.subheadline)
                        .foregroundStyle(game.archetype.color)
                    Text(game.archetype.rawValue)
                        .font(.subheadline.bold())
                        .foregroundStyle(game.archetype.color)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(game.archetype.color.opacity(0.15))
                )
            }
            .padding(.bottom, 4)

            // Archetype description
            Text(game.archetype.description)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            // Scoring zones by height
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("Scoring Zones", icon: "target")

                let redZones = game.redZones
                let grouped = Dictionary(grouping: redZones) { $0.height }

                ForEach(ScoringHeight.allCases.reversed(), id: \.self) { height in
                    if let zones = grouped[height], !zones.isEmpty {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(height.color)
                                .frame(width: 4, height: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(height.displayName)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(height.color)
                                Text("\(zones.count) target\(zones.count == 1 ? "" : "s") - \(zones[0].pointsTeleop)pts each (teleop)")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.5))
                            }

                            Spacer()

                            Text("\(zones.count)x")
                                .font(.headline.bold())
                                .foregroundStyle(height.color.opacity(0.8))
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(height.color.opacity(0.06))
                        )
                    }
                }
            }

            // Endgame challenge
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("Endgame Challenge", icon: "flag.checkered")

                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.purple.opacity(0.2))
                            .frame(width: 44, height: 44)
                        Image(systemName: game.endgameChallenge.icon)
                            .font(.title3)
                            .foregroundStyle(.purple)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(game.endgameChallenge.displayName)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("\(game.endgameChallenge.points) points per robot")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Spacer()

                    Text("+\(game.endgameChallenge.points)")
                        .font(.title3.bold())
                        .foregroundStyle(.purple)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color.purple.opacity(0.3), lineWidth: 1)
                        )
                )
            }

            // Game pieces
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("Game Pieces", icon: "shippingbox.fill")

                HStack(spacing: 12) {
                    ForEach(game.gamePieces, id: \.rawValue) { piece in
                        HStack(spacing: 8) {
                            Image(systemName: piece.icon)
                                .font(.title3)
                                .foregroundStyle(piece.color)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(piece.rawValue)
                                    .font(.caption.bold())
                                    .foregroundStyle(.white.opacity(0.8))
                                Text("Best: \(piece.idealIntake.shortLabel)")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(piece.color.opacity(0.08))
                        )
                    }
                    Spacer()
                }
            }

            // Challenge hints
            VStack(alignment: .leading, spacing: 6) {
                sectionLabel("Scouting Tips", icon: "lightbulb.fill")

                ForEach(Array(game.challengeHints.enumerated()), id: \.offset) { _, hint in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.yellow.opacity(0.7))
                            .padding(.top, 2)
                        Text(hint)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.yellow.opacity(0.04))
            )

            tipBanner(text: "Study these targets and hints carefully. Your robot build on the next step should match this game's demands!")
        }
    }

    // MARK: - Step 1: Robot Build

    @ViewBuilder
    private var buildStep: some View {
        VStack(spacing: 16) {
            stepHeader(title: "Build Your Robot", subtitle: "Choose hardware to match \(game.name).")

            // Live field match score gauge
            fieldMatchGauge

            // Drivetrain
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("Drivetrain", icon: "gearshape.2.fill")

                ForEach(DrivetrainChoice.allCases) { dt in
                    VStack(spacing: 0) {
                        selectionCard(
                            title: dt.rawValue,
                            icon: dt.icon,
                            description: dt.description,
                            color: dt.color,
                            isSelected: selectedBuild.drivetrain == dt
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) { selectedBuild.drivetrain = dt }
                        }
                        prosConsRow(pros: dt.pros, cons: dt.cons)
                    }
                }
            }

            // Frame
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("Frame", icon: "square.grid.3x3")

                ForEach(FrameChoice.allCases) { fr in
                    VStack(spacing: 0) {
                        selectionCard(
                            title: fr.rawValue,
                            icon: fr.icon,
                            description: fr.description,
                            color: fr.color,
                            isSelected: selectedBuild.frame == fr
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) { selectedBuild.frame = fr }
                        }
                        prosConsRow(pros: fr.pros, cons: fr.cons)
                    }
                }
            }

            // Manipulator
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("Manipulator", icon: "arrow.up.and.down")

                ForEach(ManipulatorChoice.allCases) { manip in
                    VStack(spacing: 0) {
                        selectionCard(
                            title: manip.rawValue,
                            icon: manip.icon,
                            description: manip.description,
                            color: manip.color,
                            isSelected: selectedBuild.manipulator == manip
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) { selectedBuild.manipulator = manip }
                        }

                        // Level reach indicator
                        HStack(spacing: 8) {
                            Text("Reaches:")
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.4))
                            ForEach(ScoringHeight.allCases, id: \.self) { h in
                                Text(h.displayName)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(
                                        h <= manip.maxReach ? manip.color : .white.opacity(0.15)
                                    )
                            }
                            Spacer()

                            if game.maxScoringHeight > manip.maxReach {
                                Text("Can't reach \(game.maxScoringHeight.displayName)!")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 2)

                        prosConsRow(pros: manip.pros, cons: manip.cons)
                    }
                }
            }

            // Intake
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("Intake", icon: "hand.point.up.fill")

                ForEach(IntakeChoice.allCases) { intake in
                    VStack(spacing: 0) {
                        selectionCard(
                            title: intake.rawValue,
                            icon: intake.icon,
                            description: intake.description,
                            color: intake.color,
                            isSelected: selectedBuild.intake == intake
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) { selectedBuild.intake = intake }
                        }

                        // Ideal piece match indicator
                        let idealPieces = game.gamePieces.filter { $0.idealIntake == intake }
                        if !idealPieces.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.green.opacity(0.7))
                                Text("Ideal for: \(idealPieces.map(\.rawValue).joined(separator: ", "))")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.green.opacity(0.6))
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 2)
                        }

                        prosConsRow(pros: intake.pros, cons: intake.cons)
                    }
                }
            }

            // 3D Robot Preview
            VStack(spacing: 6) {
                Text("PREVIEW")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(1)
                RobotPreviewView(
                    build: selectedBuild,
                    role: selectedRole ?? .scorer
                )
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(red: 0.06, green: 0.06, blue: 0.10))
                )
                .accessibilityLabel("3D preview of your robot build: \(selectedBuild.drivetrain.shortLabel) drive with \(selectedBuild.manipulator.shortLabel) mechanism and \(selectedBuild.intake.shortLabel) intake")
            }

            // Build summary
            buildSummaryCard

            tipBanner(text: "Every build has tradeoffs! Match your manipulator's reach to the game's scoring heights and your intake to the game pieces for the best Field Match Score.")
        }
    }

    // MARK: - Field Match Score Gauge

    @ViewBuilder
    private var fieldMatchGauge: some View {
        let score = fieldMatchScore
        let gaugeColor = gaugeColorForScore(score)

        VStack(spacing: 8) {
            HStack {
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .font(.subheadline)
                    .foregroundStyle(gaugeColor)
                Text("FIELD MATCH SCORE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(1)
                Spacer()
                Text("\(score)")
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(gaugeColor)
                Text("/ 100")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
            }

            // Horizontal gauge bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [gaugeColor.opacity(0.6), gaugeColor],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(score) / 100.0, height: 8)
                        .animation(.easeInOut(duration: 0.4), value: score)
                }
            }
            .frame(height: 8)

            HStack {
                Text(gaugeLabel(score))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(gaugeColor.opacity(0.8))
                Spacer()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(gaugeColor.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(gaugeColor.opacity(0.25), lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.3), value: score)
    }

    private func gaugeColorForScore(_ score: Int) -> Color {
        if score >= 75 { return .green }
        if score >= 55 { return .yellow }
        if score >= 40 { return .orange }
        return .red
    }

    private func gaugeLabel(_ score: Int) -> String {
        if score >= 80 { return "Excellent match! This build fits the game perfectly." }
        if score >= 65 { return "Good match. Your build handles most challenges well." }
        if score >= 50 { return "Decent match. Some weaknesses against this game." }
        if score >= 35 { return "Weak match. Consider changing parts to fit better." }
        return "Poor match. This build will struggle on this field."
    }

    // MARK: - Build Summary Card

    @ViewBuilder
    private var buildSummaryCard: some View {
        VStack(spacing: 8) {
            Text("YOUR BUILD")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1)
            HStack(spacing: 10) {
                buildChip(icon: selectedBuild.drivetrain.icon,
                          label: selectedBuild.drivetrain.shortLabel,
                          color: selectedBuild.drivetrain.color)
                buildChip(icon: selectedBuild.frame.icon,
                          label: selectedBuild.frame.shortLabel,
                          color: selectedBuild.frame.color)
                buildChip(icon: selectedBuild.manipulator.icon,
                          label: selectedBuild.manipulator.shortLabel,
                          color: selectedBuild.manipulator.color)
                buildChip(icon: selectedBuild.intake.icon,
                          label: selectedBuild.intake.shortLabel,
                          color: selectedBuild.intake.color)
            }
            HStack(spacing: 16) {
                Text("Max Level: \(selectedBuild.manipulator.maxReach.displayName)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(selectedBuild.manipulator.color)
                Text("Score: \(fieldMatchScore)/100")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(gaugeColorForScore(fieldMatchScore))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func buildChip(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.12)))
    }

    // MARK: - Step 2: Alliance Strategy

    @ViewBuilder
    private var strategyStep: some View {
        VStack(spacing: 8) {
            stepHeader(title: "Alliance Strategy", subtitle: "How should your 3-robot alliance play \(game.name)?")

            ForEach(AllianceStrategy.allCases) { strat in
                selectionCard(
                    title: strat.rawValue,
                    icon: strat.icon,
                    description: strat.description,
                    color: strat.color,
                    isSelected: selectedStrategy == strat
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedStrategy = strat }
                }
            }

            tipBanner(text: "Aggressive strategies score more but are vulnerable to defense. Defensive strategies limit opponents but need efficient scorers.")
        }
    }

    // MARK: - Step 3: Robot Role

    @ViewBuilder
    private var roleStep: some View {
        VStack(spacing: 8) {
            stepHeader(title: "Your Robot Role", subtitle: "What role will YOUR robot play on the alliance?")

            ForEach(RobotRole.allCases) { role in
                selectionCard(
                    title: role.rawValue,
                    icon: role.icon,
                    description: role.description,
                    color: roleColor(role),
                    isSelected: selectedRole == role
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedRole = role }
                }
            }

            if let strat = selectedStrategy {
                tipBanner(text: "With \"\(strat.rawValue)\" strategy, your teammates will complement your role automatically.")
            }
        }
    }

    // MARK: - Step 4: Auto Plan

    @ViewBuilder
    private var autoStep: some View {
        VStack(spacing: 8) {
            stepHeader(title: "Auto Routine", subtitle: "Pick your 15-second autonomous program.")

            ForEach(AutoPlan.allCases) { auto in
                VStack(spacing: 0) {
                    selectionCard(
                        title: "\(auto.rawValue) Auto",
                        icon: auto.icon,
                        description: auto.description,
                        color: auto.color,
                        isSelected: selectedAuto == auto
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedAuto = auto }
                    }

                    HStack(spacing: 16) {
                        miniStat(label: "Pieces", value: "\(auto.piecesAttempted)")
                        miniStat(label: "Success", value: "\(Int(auto.successRate * 100))%")
                        miniStat(label: "Risk", value: riskLabel(auto))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }

            // Final build summary reminder
            VStack(spacing: 8) {
                Text("YOUR SETUP")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(1)

                HStack(spacing: 14) {
                    VStack(spacing: 2) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Text(selectedBuild.drivetrain.shortLabel)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    VStack(spacing: 2) {
                        Image(systemName: selectedBuild.manipulator.icon)
                            .font(.caption)
                            .foregroundStyle(selectedBuild.manipulator.color)
                        Text(selectedBuild.manipulator.shortLabel)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    if let strat = selectedStrategy {
                        VStack(spacing: 2) {
                            Image(systemName: strat.icon)
                                .font(.caption)
                                .foregroundStyle(strat.color)
                            Text(strat.rawValue.components(separatedBy: " ").first ?? "")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    if let role = selectedRole {
                        VStack(spacing: 2) {
                            Image(systemName: role.icon)
                                .font(.caption)
                                .foregroundStyle(roleColor(role))
                            Text(role.rawValue)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }

                Text("Field Match: \(fieldMatchScore)/100")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(gaugeColorForScore(fieldMatchScore))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.orange.opacity(0.2), lineWidth: 1)
                    )
            )

            tipBanner(text: "Riskier autos attempt more game pieces but have a higher stall chance. In FRC, consistency often wins matches!")
        }
    }

    // MARK: - Bottom Bar

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 6) {
            HStack {
                if step > 0 {
                    Button(action: { withAnimation { step -= 1 } }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                    }
                    .accessibilityLabel("Go back")
                }

                Spacer()

                Button(action: advanceStep) {
                    HStack(spacing: 6) {
                        Text(step < stepCount - 1 ? "Next" : "Ready!")
                            .font(.headline)
                        if step < stepCount - 1 {
                            Image(systemName: "chevron.right")
                        } else {
                            Image(systemName: "flag.checkered")
                        }
                    }
                    .foregroundStyle(canAdvance ? .black : .white.opacity(0.3))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(canAdvance ? Color.orange : Color.white.opacity(0.08))
                    )
                    .modifier(GlassModifier(shape: RoundedRectangle(cornerRadius: 14)))
                }
                .disabled(!canAdvance)
                .accessibilityLabel(step < stepCount - 1 ? "Continue to next step" : "Start the match")
            }

            Text("Robot Workshop v1 — build smart, win big")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.2))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.3))
    }

    // MARK: - Navigation Logic

    private var canAdvance: Bool {
        switch step {
        case 0: return true          // Game reveal — always can continue
        case 1: return true          // Build always has defaults
        case 2: return selectedStrategy != nil
        case 3: return selectedRole != nil
        default: return selectedAuto != nil
        }
    }

    private func advanceStep() {
        guard canAdvance else { return }
        if step < stepCount - 1 {
            withAnimation(.easeInOut(duration: 0.3)) { step += 1 }
        } else if let s = selectedStrategy, let r = selectedRole, let a = selectedAuto {
            onReady(s, r, selectedBuild, a)
        }
    }

    // MARK: - Shared Components

    @ViewBuilder
    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func sectionLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.orange)
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    @ViewBuilder
    private func selectionCard(title: String, icon: String, description: String,
                                color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(isSelected ? 0.25 : 0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(color)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(color)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(isSelected ? 0.08 : 0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(isSelected ? color.opacity(0.5) : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func tipBanner(text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .font(.caption)
                .foregroundStyle(.yellow)
            Text(text)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.yellow.opacity(0.06))
        )
        .padding(.top, 4)
    }

    @ViewBuilder
    private func miniStat(label: String, value: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.7))
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.35))
        }
    }

    private func roleColor(_ role: RobotRole) -> Color {
        switch role {
        case .scorer:   return .orange
        case .cycler:   return .cyan
        case .defender: return .green
        }
    }

    private func riskLabel(_ auto: AutoPlan) -> String {
        switch auto {
        case .safe: return "Low"
        case .moderate: return "Med"
        case .risky: return "High"
        }
    }

    @ViewBuilder
    private func prosConsRow(pros: String, cons: String) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.green.opacity(0.7))
                Text(pros)
                    .font(.system(size: 9))
                    .foregroundStyle(.green.opacity(0.6))
                Spacer()
            }
            HStack(spacing: 4) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.red.opacity(0.7))
                Text(cons)
                    .font(.system(size: 9))
                    .foregroundStyle(.red.opacity(0.6))
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
