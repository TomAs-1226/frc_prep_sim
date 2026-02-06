import SceneKit

// MARK: - Field Builder

/// Constructs a simplified FRC-inspired field using procedural SceneKit geometry.
/// The field is a 6m x 3.5m rectangle with zones and scoring nodes.
enum FieldBuilder {

    /// Build the complete field scene.
    /// Returns the scene plus references to the scoring node meshes (for pulse effects).
    static func buildScene() -> (scene: SCNScene, nodeTargets: [SCNNode]) {
        let scene = SCNScene()

        // -- Camera --
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 50
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 50
        cameraNode.position = SCNVector3(0, 5.5, 5.0)
        cameraNode.eulerAngles.x = -Float.pi / 3.2
        scene.rootNode.addChildNode(cameraNode)

        // -- Lighting --
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = UIColor(white: 0.4, alpha: 1.0)
        ambientLight.light?.intensity = 600
        scene.rootNode.addChildNode(ambientLight)

        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light?.type = .directional
        directionalLight.light?.color = UIColor(white: 1.0, alpha: 1.0)
        directionalLight.light?.intensity = 800
        directionalLight.light?.castsShadow = true
        directionalLight.light?.shadowRadius = 3
        directionalLight.light?.shadowSampleCount = 4
        directionalLight.position = SCNVector3(2, 8, 4)
        directionalLight.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 6, 0)
        scene.rootNode.addChildNode(directionalLight)

        // -- Field Floor --
        let floorGeometry = SCNBox(width: 6.5, height: 0.05, length: 4.0, chamferRadius: 0)
        let floorMaterial = SCNMaterial()
        floorMaterial.diffuse.contents = UIColor(red: 0.25, green: 0.25, blue: 0.28, alpha: 1.0)
        floorMaterial.roughness.contents = 0.8
        floorGeometry.materials = [floorMaterial]
        let floorNode = SCNNode(geometry: floorGeometry)
        floorNode.position = SCNVector3(0, -0.025, 0)
        scene.rootNode.addChildNode(floorNode)

        // -- Field Border Lines --
        addFieldBorder(to: scene.rootNode)

        // -- Start Zone (blue area, left side) --
        let startZone = SCNBox(width: 1.2, height: 0.02, length: 3.5, chamferRadius: 0)
        let startMaterial = SCNMaterial()
        startMaterial.diffuse.contents = UIColor(red: 0.15, green: 0.25, blue: 0.55, alpha: 0.6)
        startZone.materials = [startMaterial]
        let startNode = SCNNode(geometry: startZone)
        startNode.position = SCNVector3(-2.5, 0.01, 0)
        scene.rootNode.addChildNode(startNode)

        // Start Zone label
        addTextLabel("START", position: SCNVector3(-2.5, 0.03, 1.2), color: .cyan, to: scene.rootNode)

        // -- Midfield Zone --
        let midZone = SCNBox(width: 2.0, height: 0.02, length: 3.5, chamferRadius: 0)
        let midMaterial = SCNMaterial()
        midMaterial.diffuse.contents = UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.3)
        midZone.materials = [midMaterial]
        let midNode = SCNNode(geometry: midZone)
        midNode.position = SCNVector3(0, 0.01, 0)
        scene.rootNode.addChildNode(midNode)

        // -- Reef Zone (scoring area, right side) --
        let reefZone = SCNBox(width: 1.8, height: 0.02, length: 3.5, chamferRadius: 0)
        let reefMaterial = SCNMaterial()
        reefMaterial.diffuse.contents = UIColor(red: 0.15, green: 0.5, blue: 0.35, alpha: 0.5)
        reefZone.materials = [reefMaterial]
        let reefNode = SCNNode(geometry: reefZone)
        reefNode.position = SCNVector3(2.0, 0.01, 0)
        scene.rootNode.addChildNode(reefNode)

        addTextLabel("REEF ZONE", position: SCNVector3(2.0, 0.03, 1.2), color: .green, to: scene.rootNode)

        // -- Scoring Nodes (3 cylinders in the reef area) --
        var nodeTargets: [SCNNode] = []

        let nodePositions: [(x: Float, z: Float, label: String)] = [
            (-0.5, -0.8, "Node 1"),
            (1.0,  0.0,  "Node 2"),
            (2.0,  0.8,  "Node 3"),
        ]

        for (i, pos) in nodePositions.enumerated() {
            let nodeGeom = SCNCylinder(radius: 0.18, height: 0.5)
            let nodeMaterial = SCNMaterial()
            let hue = CGFloat(i) / 3.0 * 0.3 + 0.1  // warm colors
            nodeMaterial.diffuse.contents = UIColor(hue: hue, saturation: 0.7, brightness: 0.9, alpha: 1.0)
            nodeMaterial.emission.contents = UIColor.black
            nodeGeom.materials = [nodeMaterial]

            let nodeNode = SCNNode(geometry: nodeGeom)
            nodeNode.position = SCNVector3(pos.x, 0.25, pos.z)
            nodeNode.name = "scoringNode_\(i)"
            scene.rootNode.addChildNode(nodeNode)
            nodeTargets.append(nodeNode)

            // Add a ring at the base
            let ring = SCNTorus(ringRadius: 0.25, pipeRadius: 0.02)
            let ringMaterial = SCNMaterial()
            ringMaterial.diffuse.contents = UIColor.white.withAlphaComponent(0.5)
            ring.materials = [ringMaterial]
            let ringNode = SCNNode(geometry: ring)
            ringNode.position = SCNVector3(pos.x, 0.02, pos.z)
            scene.rootNode.addChildNode(ringNode)
        }

        // -- Low Walls / Obstacles --
        let wallPositions: [(x: Float, z: Float, w: Float, l: Float)] = [
            (-0.8,  0.6, 0.6, 0.08),
            (0.5, -0.5, 0.08, 0.8),
        ]

        for wall in wallPositions {
            let wallGeom = SCNBox(width: CGFloat(wall.w), height: 0.2, length: CGFloat(wall.l), chamferRadius: 0.01)
            let wallMaterial = SCNMaterial()
            wallMaterial.diffuse.contents = UIColor(white: 0.5, alpha: 0.7)
            wallGeom.materials = [wallMaterial]
            let wallNode = SCNNode(geometry: wallGeom)
            wallNode.position = SCNVector3(wall.x, 0.1, wall.z)
            scene.rootNode.addChildNode(wallNode)
        }

        // -- Game Pieces on field (small colored cubes) --
        let piecePositions: [SIMD2<Float>] = [
            SIMD2(-1.0, 0.0),
            SIMD2(0.0, 0.0),
            SIMD2(1.5, 0.5),
        ]

        for pos in piecePositions {
            let piece = SCNBox(width: 0.12, height: 0.12, length: 0.12, chamferRadius: 0.02)
            let pieceMat = SCNMaterial()
            pieceMat.diffuse.contents = UIColor.orange
            piece.materials = [pieceMat]
            let pieceNode = SCNNode(geometry: piece)
            pieceNode.position = SCNVector3(pos.x, 0.08, pos.y)

            // Gentle floating animation
            let hover = SCNAction.moveBy(x: 0, y: 0.05, z: 0, duration: 0.8)
            hover.timingMode = .easeInEaseOut
            let hoverDown = hover.reversed()
            pieceNode.runAction(SCNAction.repeatForever(SCNAction.sequence([hover, hoverDown])))

            scene.rootNode.addChildNode(pieceNode)
        }

        // -- Background color --
        scene.background.contents = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0)

        return (scene, nodeTargets)
    }

    // MARK: - Helpers

    private static func addFieldBorder(to root: SCNNode) {
        let borderColor = UIColor.white.withAlphaComponent(0.3)
        let lineThickness: CGFloat = 0.03
        let fieldWidth: Float = 6.5
        let fieldLength: Float = 4.0

        // Four border edges
        let edges: [(x: Float, z: Float, w: CGFloat, l: CGFloat)] = [
            (0, -fieldLength / 2, CGFloat(fieldWidth), lineThickness),
            (0,  fieldLength / 2, CGFloat(fieldWidth), lineThickness),
            (-fieldWidth / 2, 0, lineThickness, CGFloat(fieldLength)),
            ( fieldWidth / 2, 0, lineThickness, CGFloat(fieldLength)),
        ]

        for edge in edges {
            let line = SCNBox(width: edge.w, height: 0.01, length: edge.l, chamferRadius: 0)
            let mat = SCNMaterial()
            mat.diffuse.contents = borderColor
            line.materials = [mat]
            let lineNode = SCNNode(geometry: line)
            lineNode.position = SCNVector3(edge.x, 0.03, edge.z)
            root.addChildNode(lineNode)
        }

        // Zone divider lines
        let dividers: [Float] = [-1.9, 1.1]
        for x in dividers {
            let div = SCNBox(width: 0.02, height: 0.01, length: CGFloat(fieldLength - 0.1), chamferRadius: 0)
            let mat = SCNMaterial()
            mat.diffuse.contents = UIColor.white.withAlphaComponent(0.15)
            div.materials = [mat]
            let divNode = SCNNode(geometry: div)
            divNode.position = SCNVector3(x, 0.03, 0)
            root.addChildNode(divNode)
        }
    }

    private static func addTextLabel(_ text: String, position: SCNVector3, color: UIColor, to root: SCNNode) {
        let textGeom = SCNText(string: text, extrusionDepth: 0.01)
        textGeom.font = UIFont.systemFont(ofSize: 0.15, weight: .bold)
        textGeom.flatness = 0.3
        let mat = SCNMaterial()
        mat.diffuse.contents = color.withAlphaComponent(0.7)
        textGeom.materials = [mat]
        let textNode = SCNNode(geometry: textGeom)
        // Center the text
        let (min, max) = textNode.boundingBox
        let cx = (max.x - min.x) / 2 + min.x
        textNode.pivot = SCNMatrix4MakeTranslation(cx, 0, 0)
        textNode.position = position
        textNode.eulerAngles.x = -Float.pi / 2
        textNode.scale = SCNVector3(1, 1, 1)
        root.addChildNode(textNode)
    }
}

// MARK: - Robot Builder

/// Constructs a simple robot from primitive geometry.
enum RobotBuilder {

    /// Build a robot node for a given archetype.
    /// The robot is a box chassis with 4 cylinder wheels and a "mechanism" on top.
    static func buildRobot(archetype: RobotArchetype) -> SCNNode {
        let root = SCNNode()
        root.name = "robot"

        let scale = archetype.chassisScale

        // -- Chassis (main body box) --
        let chassisGeom = SCNBox(
            width: CGFloat(scale.x),
            height: CGFloat(scale.y * 0.4),
            length: CGFloat(scale.z),
            chamferRadius: 0.02
        )
        let chassisMat = SCNMaterial()
        chassisMat.diffuse.contents = UIColor(archetype.color)
        chassisMat.roughness.contents = 0.6
        chassisGeom.materials = [chassisMat]
        let chassis = SCNNode(geometry: chassisGeom)
        chassis.position = SCNVector3(0, Float(scale.y * 0.2), 0)
        root.addChildNode(chassis)

        // -- Bumper (slightly larger outline box, semi-transparent) --
        let bumperGeom = SCNBox(
            width: CGFloat(scale.x + 0.06),
            height: CGFloat(scale.y * 0.15),
            length: CGFloat(scale.z + 0.06),
            chamferRadius: 0.01
        )
        let bumperMat = SCNMaterial()
        bumperMat.diffuse.contents = UIColor.white.withAlphaComponent(0.3)
        bumperGeom.materials = [bumperMat]
        let bumper = SCNNode(geometry: bumperGeom)
        bumper.position = SCNVector3(0, Float(scale.y * 0.08), 0)
        root.addChildNode(bumper)

        // -- Wheels (4 cylinders) --
        let wheelRadius: CGFloat = CGFloat(scale.y * 0.25)
        let wheelWidth: CGFloat = 0.05
        let wheelColor = UIColor.darkGray

        let wheelOffsets: [(x: Float, z: Float)] = [
            (-scale.x / 2 - 0.03,  scale.z / 2 - 0.1),
            ( scale.x / 2 + 0.03,  scale.z / 2 - 0.1),
            (-scale.x / 2 - 0.03, -scale.z / 2 + 0.1),
            ( scale.x / 2 + 0.03, -scale.z / 2 + 0.1),
        ]

        for offset in wheelOffsets {
            let wheelGeom = SCNCylinder(radius: wheelRadius, height: wheelWidth)
            let wheelMat = SCNMaterial()
            wheelMat.diffuse.contents = wheelColor
            wheelGeom.materials = [wheelMat]
            let wheel = SCNNode(geometry: wheelGeom)
            wheel.eulerAngles.z = Float.pi / 2
            wheel.position = SCNVector3(offset.x, Float(wheelRadius), offset.z)
            root.addChildNode(wheel)
        }

        // -- Top Mechanism (varies by archetype) --
        switch archetype {
        case .speedy:
            // Low-profile intake: flat box on front
            let intake = SCNBox(width: CGFloat(scale.x * 0.6), height: 0.04, length: 0.15, chamferRadius: 0.01)
            let intakeMat = SCNMaterial()
            intakeMat.diffuse.contents = UIColor.systemTeal
            intake.materials = [intakeMat]
            let intakeNode = SCNNode(geometry: intake)
            intakeNode.position = SCNVector3(0, Float(scale.y * 0.4), scale.z / 2 + 0.05)
            root.addChildNode(intakeNode)

        case .balanced:
            // Medium arm: cylinder sticking up
            let arm = SCNCylinder(radius: 0.03, height: CGFloat(scale.y * 0.6))
            let armMat = SCNMaterial()
            armMat.diffuse.contents = UIColor.systemOrange
            arm.materials = [armMat]
            let armNode = SCNNode(geometry: arm)
            armNode.position = SCNVector3(0, Float(scale.y * 0.5), Float(scale.z * 0.2))
            root.addChildNode(armNode)

            // Gripper at top
            let gripper = SCNBox(width: 0.12, height: 0.04, length: 0.06, chamferRadius: 0.01)
            let gripMat = SCNMaterial()
            gripMat.diffuse.contents = UIColor.systemYellow
            gripper.materials = [gripMat]
            let gripNode = SCNNode(geometry: gripper)
            gripNode.position = SCNVector3(0, Float(scale.y * 0.8), Float(scale.z * 0.2))
            root.addChildNode(gripNode)

        case .heavy:
            // Large elevator tower
            let tower = SCNBox(width: 0.08, height: CGFloat(scale.y * 0.9), length: 0.08, chamferRadius: 0.01)
            let towerMat = SCNMaterial()
            towerMat.diffuse.contents = UIColor.systemRed
            tower.materials = [towerMat]
            let towerNode = SCNNode(geometry: tower)
            towerNode.position = SCNVector3(0, Float(scale.y * 0.65), 0)
            root.addChildNode(towerNode)

            // Top plate
            let plate = SCNBox(width: CGFloat(scale.x * 0.5), height: 0.03, length: CGFloat(scale.z * 0.4), chamferRadius: 0.01)
            let plateMat = SCNMaterial()
            plateMat.diffuse.contents = UIColor.systemRed.withAlphaComponent(0.7)
            plate.materials = [plateMat]
            let plateNode = SCNNode(geometry: plate)
            plateNode.position = SCNVector3(0, Float(scale.y * 1.1), 0)
            root.addChildNode(plateNode)
        }

        // -- Team Number Label --
        let labelGeom = SCNText(string: "9999", extrusionDepth: 0.005)
        labelGeom.font = UIFont.monospacedDigitSystemFont(ofSize: 0.06, weight: .bold)
        labelGeom.flatness = 0.5
        let labelMat = SCNMaterial()
        labelMat.diffuse.contents = UIColor.white
        labelGeom.materials = [labelMat]
        let labelNode = SCNNode(geometry: labelGeom)
        let (lMin, lMax) = labelNode.boundingBox
        let lCx = (lMax.x - lMin.x) / 2 + lMin.x
        labelNode.pivot = SCNMatrix4MakeTranslation(lCx, 0, 0)
        labelNode.position = SCNVector3(0, Float(scale.y * 0.25), scale.z / 2 + 0.005)
        labelNode.scale = SCNVector3(1, 1, 1)
        root.addChildNode(labelNode)

        return root
    }

    /// Build a small preview robot for the build selection screen.
    static func buildPreviewScene(archetype: RobotArchetype) -> SCNScene {
        let scene = SCNScene()

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 40
        cameraNode.position = SCNVector3(0.8, 0.8, 1.2)
        cameraNode.look(at: SCNVector3(0, 0.15, 0))
        scene.rootNode.addChildNode(cameraNode)

        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 500
        scene.rootNode.addChildNode(ambientLight)

        let dirLight = SCNNode()
        dirLight.light = SCNLight()
        dirLight.light?.type = .directional
        dirLight.light?.intensity = 700
        dirLight.position = SCNVector3(1, 2, 1)
        dirLight.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 6, 0)
        scene.rootNode.addChildNode(dirLight)

        let robot = buildRobot(archetype: archetype)
        // Slow spin
        robot.runAction(SCNAction.repeatForever(
            SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 8)
        ))
        scene.rootNode.addChildNode(robot)

        scene.background.contents = UIColor(red: 0.1, green: 0.1, blue: 0.14, alpha: 1.0)

        return scene
    }
}
