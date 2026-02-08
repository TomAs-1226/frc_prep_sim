import SceneKit

// MARK: - Field Builder
// Constructs a procedurally generated competition field from a GeneratedGame.
// All geometry is procedural — no imported assets.
// Coherent minimalist low-poly art style: dark surfaces, clean shapes, alliance colors.

enum FieldBuilder {

    /// Builds the complete 3D scene for a generated game.
    /// Returns the scene and a dictionary of scoring zone nodes keyed by zone ID.
    static func buildScene(game: GeneratedGame) -> (SCNScene, [Int: SCNNode]) {
        let scene = SCNScene()
        scene.background.contents = game.theme.bgColor

        addCamera(to: scene)
        addLighting(to: scene)
        addFloorAndWalls(to: scene, game: game)

        var zoneNodes: [Int: SCNNode] = [:]
        addScoringZones(to: scene, game: game, zoneNodes: &zoneNodes)
        addObstacles(to: scene, game: game)
        addEndgameZone(to: scene, game: game)
        addPickupStations(to: scene, game: game)
        addStartPositions(to: scene)
        addFieldLines(to: scene)

        return (scene, zoneNodes)
    }

    // MARK: - Camera

    private static func addCamera(to scene: SCNScene) {
        let cam = SCNCamera()
        cam.fieldOfView = 50
        cam.zNear = 0.05
        cam.zFar = 80
        let camNode = SCNNode()
        camNode.camera = cam
        camNode.position = SCNVector3(0, 7.5, 6.0)
        camNode.eulerAngles.x = -Float.pi / 3
        scene.rootNode.addChildNode(camNode)
    }

    // MARK: - Lighting

    private static func addLighting(to scene: SCNScene) {
        // Ambient
        let amb = SCNNode()
        amb.light = SCNLight()
        amb.light!.type = .ambient
        amb.light!.intensity = 500
        amb.light!.color = UIColor(white: 0.4, alpha: 1)
        scene.rootNode.addChildNode(amb)

        // Key directional
        let key = SCNNode()
        key.light = SCNLight()
        key.light!.type = .directional
        key.light!.intensity = 900
        key.light!.color = UIColor(white: 1.0, alpha: 1)
        key.light!.castsShadow = true
        key.light!.shadowMapSize = CGSize(width: 2048, height: 2048)
        key.light!.shadowRadius = 3
        key.position = SCNVector3(3, 12, 5)
        key.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(key)

        // Fill directional
        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light!.type = .directional
        fill.light!.intensity = 300
        fill.light!.color = UIColor(white: 0.9, alpha: 1)
        fill.position = SCNVector3(-3, 8, -4)
        fill.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(fill)
    }

    // MARK: - Floor & Walls

    private static func addFloorAndWalls(to scene: SCNScene, game: GeneratedGame) {
        let fw = FieldLayout.fieldWidth
        let fl = FieldLayout.fieldLength

        // Floor
        let floorGeo = SCNBox(width: CGFloat(fw), height: 0.005, length: CGFloat(fl), chamferRadius: 0)
        floorGeo.materials = [FieldMaterials.floor(theme: game.theme)]
        let floorNode = SCNNode(geometry: floorGeo)
        floorNode.position = SCNVector3(0, -0.0025, 0)
        scene.rootNode.addChildNode(floorNode)

        // Alliance carpet zones
        let carpetWidth: Float = 1.5
        for alliance in Alliance.allCases {
            let xSign: Float = alliance == .red ? 1 : -1
            let geo = SCNBox(width: CGFloat(carpetWidth), height: 0.003, length: CGFloat(fl - 0.1), chamferRadius: 0)
            let mat = SCNMaterial()
            mat.diffuse.contents = alliance.uiColor.withAlphaComponent(0.12)
            geo.materials = [mat]
            let node = SCNNode(geometry: geo)
            node.position = SCNVector3(xSign * (fw / 2 - carpetWidth / 2), 0.001, 0)
            scene.rootNode.addChildNode(node)
        }

        // Perimeter walls (low)
        let wallH: Float = 0.10
        let wallThick: Float = 0.05

        // Long walls (along x)
        for zSign: Float in [-1, 1] {
            let geo = SCNBox(width: CGFloat(fw), height: CGFloat(wallH), length: CGFloat(wallThick), chamferRadius: 0)
            geo.materials = [FieldMaterials.wall]
            let node = SCNNode(geometry: geo)
            node.position = SCNVector3(0, wallH / 2, zSign * (fl / 2))
            scene.rootNode.addChildNode(node)
        }

        // Alliance walls (colored, taller)
        for alliance in Alliance.allCases {
            let xSign: Float = alliance == .red ? 1 : -1
            let geo = SCNBox(width: CGFloat(wallThick), height: CGFloat(wallH * 1.5), length: CGFloat(fl), chamferRadius: 0)
            geo.materials = [FieldMaterials.allianceWall(alliance)]
            let node = SCNNode(geometry: geo)
            node.position = SCNVector3(xSign * (fw / 2), wallH * 0.75, 0)
            scene.rootNode.addChildNode(node)
        }
    }

    // MARK: - Scoring Zones

    private static func addScoringZones(to scene: SCNScene, game: GeneratedGame, zoneNodes: inout [Int: SCNNode]) {
        for zone in game.scoringZones {
            let zoneRoot = SCNNode()
            zoneRoot.name = "zone_\(zone.id)"
            zoneRoot.position = SCNVector3(zone.position.x, 0, zone.position.y)

            buildTarget(for: zone, parent: zoneRoot)

            // Floor ring indicator
            let ringGeo = SCNTorus(ringRadius: 0.25, pipeRadius: 0.015)
            ringGeo.ringSegmentCount = 24
            ringGeo.pipeSegmentCount = 8
            ringGeo.materials = [FieldMaterials.zoneRing(zone.height)]
            let ring = SCNNode(geometry: ringGeo)
            ring.position = SCNVector3(0, 0.01, 0)
            zoneRoot.addChildNode(ring)

            // Points label
            let labelGeo = SCNText(string: "\(zone.pointsTeleop)pt", extrusionDepth: 0.005)
            labelGeo.font = UIFont.systemFont(ofSize: 0.08, weight: .bold)
            labelGeo.flatness = 0.3
            let labelMat = SCNMaterial()
            labelMat.diffuse.contents = UIColor.white.withAlphaComponent(0.7)
            labelGeo.materials = [labelMat]
            let label = SCNNode(geometry: labelGeo)
            let (lmin, lmax) = label.boundingBox
            let lw = lmax.x - lmin.x
            label.position = SCNVector3(-lw / 2, 0.02, 0.30)
            label.eulerAngles.x = -Float.pi / 2
            zoneRoot.addChildNode(label)

            scene.rootNode.addChildNode(zoneRoot)
            zoneNodes[zone.id] = zoneRoot
        }
    }

    private static func buildTarget(for zone: ScoringZone, parent: SCNNode) {
        let h = zone.height

        switch h {
        case .ground:
            // Ground trough — flat bin on the floor
            let binGeo = SCNBox(width: 0.30, height: 0.06, length: 0.20, chamferRadius: 0.01)
            binGeo.materials = [FieldMaterials.targetBase(h)]
            let bin = SCNNode(geometry: binGeo)
            bin.position = SCNVector3(0, 0.03, 0)
            parent.addChildNode(bin)

            // Lip edges
            for zSign: Float in [-1, 1] {
                let lip = SCNBox(width: 0.30, height: 0.03, length: 0.015, chamferRadius: 0)
                lip.materials = [FieldMaterials.targetGoal(zone.alliance)]
                let lipNode = SCNNode(geometry: lip)
                lipNode.position = SCNVector3(0, 0.06 + 0.015, zSign * 0.09)
                parent.addChildNode(lipNode)
            }

        case .low:
            // Low pedestal with shelf
            let pillarGeo = SCNCylinder(radius: 0.06, height: CGFloat(h.sceneHeight))
            pillarGeo.radialSegmentCount = 8
            pillarGeo.materials = [FieldMaterials.targetBase(h)]
            let pillar = SCNNode(geometry: pillarGeo)
            pillar.position = SCNVector3(0, h.sceneHeight / 2, 0)
            parent.addChildNode(pillar)

            let shelfGeo = SCNBox(width: 0.22, height: 0.03, length: 0.16, chamferRadius: 0.005)
            shelfGeo.materials = [FieldMaterials.targetGoal(zone.alliance)]
            let shelf = SCNNode(geometry: shelfGeo)
            shelf.position = SCNVector3(0, h.sceneHeight, 0)
            parent.addChildNode(shelf)

        case .mid:
            // Mid-height pillar with basket opening
            let pillarGeo = SCNCylinder(radius: 0.05, height: CGFloat(h.sceneHeight))
            pillarGeo.radialSegmentCount = 8
            pillarGeo.materials = [FieldMaterials.targetBase(h)]
            let pillar = SCNNode(geometry: pillarGeo)
            pillar.position = SCNVector3(0, h.sceneHeight / 2, 0)
            parent.addChildNode(pillar)

            // Basket ring
            let basketGeo = SCNTorus(ringRadius: 0.10, pipeRadius: 0.015)
            basketGeo.ringSegmentCount = 16
            basketGeo.pipeSegmentCount = 6
            basketGeo.materials = [FieldMaterials.targetGoal(zone.alliance)]
            let basket = SCNNode(geometry: basketGeo)
            basket.position = SCNVector3(0, h.sceneHeight + 0.02, 0)
            parent.addChildNode(basket)

            // Crossbar support
            let barGeo = SCNCylinder(radius: 0.01, height: 0.20)
            barGeo.radialSegmentCount = 6
            barGeo.materials = [FieldMaterials.metal]
            let bar = SCNNode(geometry: barGeo)
            bar.eulerAngles.z = Float.pi / 2
            bar.position = SCNVector3(0, h.sceneHeight + 0.02, 0)
            parent.addChildNode(bar)

        case .high:
            // Tall tower with hoop at top
            let baseGeo = SCNBox(width: 0.14, height: 0.08, length: 0.14, chamferRadius: 0.01)
            baseGeo.materials = [FieldMaterials.targetBase(h)]
            let base = SCNNode(geometry: baseGeo)
            base.position = SCNVector3(0, 0.04, 0)
            parent.addChildNode(base)

            // Tower shaft — faceted for low-poly look
            let shaftGeo = SCNCylinder(radius: 0.04, height: CGFloat(h.sceneHeight - 0.08))
            shaftGeo.radialSegmentCount = 6
            shaftGeo.materials = [FieldMaterials.metal]
            let shaft = SCNNode(geometry: shaftGeo)
            shaft.position = SCNVector3(0, 0.08 + (h.sceneHeight - 0.08) / 2, 0)
            parent.addChildNode(shaft)

            // Hoop ring at top
            let hoopGeo = SCNTorus(ringRadius: 0.12, pipeRadius: 0.018)
            hoopGeo.ringSegmentCount = 16
            hoopGeo.pipeSegmentCount = 6
            hoopGeo.materials = [FieldMaterials.targetGoal(zone.alliance)]
            let hoop = SCNNode(geometry: hoopGeo)
            hoop.position = SCNVector3(0, h.sceneHeight + 0.02, 0)
            parent.addChildNode(hoop)

            // Backboard
            let bbGeo = SCNBox(width: 0.24, height: 0.14, length: 0.015, chamferRadius: 0.005)
            bbGeo.materials = [FieldMaterials.targetGoal(zone.alliance)]
            let bb = SCNNode(geometry: bbGeo)
            bb.position = SCNVector3(0, h.sceneHeight + 0.06, -0.08)
            parent.addChildNode(bb)
        }
    }

    // MARK: - Obstacles

    private static func addObstacles(to scene: SCNScene, game: GeneratedGame) {
        for obs in game.obstacles {
            switch obs.kind {
            case .bridge:
                addBridge(to: scene, obstacle: obs)
            case .barrier:
                addBarrier(to: scene, obstacle: obs)
            case .ramp:
                addRamp(to: scene, obstacle: obs)
            }
        }
    }

    private static func addBridge(to scene: SCNScene, obstacle: FieldObstacle) {
        let bridgeRoot = SCNNode()
        bridgeRoot.name = "center_bridge"

        let topW = obstacle.size.x
        let topL = obstacle.size.y
        let topH: Float = 1.20

        // Top beam
        let topGeo = SCNBox(width: CGFloat(topW), height: 0.06, length: CGFloat(topL), chamferRadius: 0)
        topGeo.materials = [FieldMaterials.bridge]
        let top = SCNNode(geometry: topGeo)
        top.position = SCNVector3(0, topH, 0)
        bridgeRoot.addChildNode(top)

        // Four legs
        let legH: Float = topH - 0.03
        let legGeo = SCNCylinder(radius: 0.04, height: CGFloat(legH))
        legGeo.radialSegmentCount = 6
        legGeo.materials = [FieldMaterials.bridge]
        for (dx, dz) in [(-topW / 2 + 0.06, -topL / 2 + 0.15),
                          (-topW / 2 + 0.06,  topL / 2 - 0.15),
                          ( topW / 2 - 0.06, -topL / 2 + 0.15),
                          ( topW / 2 - 0.06,  topL / 2 - 0.15)] as [(Float, Float)] {
            let leg = SCNNode(geometry: legGeo)
            leg.position = SCNVector3(dx, legH / 2, dz)
            bridgeRoot.addChildNode(leg)
        }

        // Cross braces
        let braceGeo = SCNCylinder(radius: 0.015, height: CGFloat(topL * 0.6))
        braceGeo.radialSegmentCount = 6
        braceGeo.materials = [FieldMaterials.metal]
        for xSign: Float in [-1, 1] {
            let brace = SCNNode(geometry: braceGeo)
            brace.position = SCNVector3(xSign * (topW / 2 - 0.06), topH * 0.5, 0)
            brace.eulerAngles.x = Float.pi / 6
            bridgeRoot.addChildNode(brace)
        }

        // Endgame zone markings under bridge
        for alliance in Alliance.allCases {
            let xSign: Float = alliance == .red ? 1 : -1
            let zoneGeo = SCNBox(width: 0.6, height: 0.004, length: CGFloat(topL * 0.4), chamferRadius: 0)
            zoneGeo.materials = [FieldMaterials.parkZone(alliance)]
            let zone = SCNNode(geometry: zoneGeo)
            zone.position = SCNVector3(xSign * 0.35, 0.002, 0)
            bridgeRoot.addChildNode(zone)
        }

        bridgeRoot.position = SCNVector3(obstacle.position.x, 0, obstacle.position.y)
        scene.rootNode.addChildNode(bridgeRoot)
    }

    private static func addBarrier(to scene: SCNScene, obstacle: FieldObstacle) {
        let geo = SCNBox(width: CGFloat(obstacle.size.x), height: 0.25,
                         length: CGFloat(obstacle.size.y), chamferRadius: 0.01)
        geo.materials = [FieldMaterials.barrier]
        let node = SCNNode(geometry: geo)
        node.name = "barrier_\(obstacle.id)"
        node.position = SCNVector3(obstacle.position.x, 0.125, obstacle.position.y)
        scene.rootNode.addChildNode(node)
    }

    private static func addRamp(to scene: SCNScene, obstacle: FieldObstacle) {
        let geo = SCNBox(width: CGFloat(obstacle.size.x), height: 0.12,
                         length: CGFloat(obstacle.size.y), chamferRadius: 0)
        geo.materials = [FieldMaterials.rampMat]
        let node = SCNNode(geometry: geo)
        node.name = "ramp_\(obstacle.id)"
        node.position = SCNVector3(obstacle.position.x, 0.06, obstacle.position.y)
        node.eulerAngles.z = Float.pi / 12  // slight tilt
        scene.rootNode.addChildNode(node)
    }

    // MARK: - Endgame Zone

    private static func addEndgameZone(to scene: SCNScene, game: GeneratedGame) {
        switch game.endgameChallenge {
        case .climb(let difficulty, _):
            addClimbBars(to: scene, difficulty: difficulty)
        case .balance:
            addBalancePlatform(to: scene)
        case .park:
            // Park zones are already shown under bridge
            break
        }
    }

    private static func addClimbBars(to scene: SCNScene, difficulty: ClimbDifficulty) {
        let barH: Float
        switch difficulty {
        case .low:  barH = 0.35
        case .mid:  barH = 0.65
        case .high: barH = 0.95
        }

        for alliance in Alliance.allCases {
            let xSign: Float = alliance == .red ? 1 : -1
            let barRoot = SCNNode()

            // Vertical supports
            let supportGeo = SCNCylinder(radius: 0.03, height: CGFloat(barH + 0.05))
            supportGeo.radialSegmentCount = 6
            supportGeo.materials = [FieldMaterials.metal]
            for dz: Float in [-0.40, 0.40] {
                let support = SCNNode(geometry: supportGeo)
                support.position = SCNVector3(0, (barH + 0.05) / 2, dz)
                barRoot.addChildNode(support)
            }

            // Horizontal climb bar
            let climbGeo = SCNCylinder(radius: 0.025, height: 0.80)
            climbGeo.radialSegmentCount = 8
            climbGeo.materials = [FieldMaterials.climbBar]
            let climb = SCNNode(geometry: climbGeo)
            climb.eulerAngles.x = Float.pi / 2
            climb.position = SCNVector3(0, barH, 0)
            barRoot.addChildNode(climb)

            // Label
            let labelGeo = SCNText(string: difficulty.rawValue, extrusionDepth: 0.003)
            labelGeo.font = UIFont.systemFont(ofSize: 0.06, weight: .bold)
            labelGeo.flatness = 0.3
            let labelMat = SCNMaterial()
            labelMat.diffuse.contents = UIColor.systemYellow.withAlphaComponent(0.6)
            labelGeo.materials = [labelMat]
            let label = SCNNode(geometry: labelGeo)
            let (lmin, lmax) = label.boundingBox
            label.position = SCNVector3(-(lmax.x - lmin.x) / 2, barH + 0.08, 0)
            barRoot.addChildNode(label)

            barRoot.position = SCNVector3(xSign * 0.35, 0, 0)
            scene.rootNode.addChildNode(barRoot)
        }
    }

    private static func addBalancePlatform(to scene: SCNScene) {
        for alliance in Alliance.allCases {
            let xSign: Float = alliance == .red ? 1 : -1

            let platGeo = SCNBox(width: 0.60, height: 0.08, length: 0.80, chamferRadius: 0.02)
            platGeo.materials = [FieldMaterials.balancePlatform]
            let plat = SCNNode(geometry: platGeo)
            plat.position = SCNVector3(xSign * 0.35, 0.06, 0)
            plat.eulerAngles.z = Float.pi / 30 * xSign  // slight tilt
            plat.name = "balance_\(alliance.rawValue)"
            scene.rootNode.addChildNode(plat)

            // Fulcrum
            let fulGeo = SCNCylinder(radius: 0.03, height: 0.80)
            fulGeo.radialSegmentCount = 6
            fulGeo.materials = [FieldMaterials.metal]
            let ful = SCNNode(geometry: fulGeo)
            ful.eulerAngles.x = Float.pi / 2
            ful.position = SCNVector3(xSign * 0.35, 0.02, 0)
            scene.rootNode.addChildNode(ful)
        }
    }

    // MARK: - Pickup Stations

    private static func addPickupStations(to scene: SCNScene, game: GeneratedGame) {
        for station in game.pickupStations {
            let stationRoot = SCNNode()
            stationRoot.name = "pickup_\(station.id)"

            // Floor zone
            let zoneGeo = SCNBox(width: 0.45, height: 0.004, length: 0.45, chamferRadius: 0.02)
            zoneGeo.materials = [FieldMaterials.pickupStation(station.alliance)]
            let zone = SCNNode(geometry: zoneGeo)
            zone.position = SCNVector3(0, 0.002, 0)
            stationRoot.addChildNode(zone)

            // Chute structure
            let chuteGeo = SCNBox(width: 0.25, height: 0.30, length: 0.06, chamferRadius: 0)
            chuteGeo.materials = [FieldMaterials.metal]
            let chute = SCNNode(geometry: chuteGeo)
            let chuteAngle: Float = station.alliance == .red ? -0.8 : 0.8
            chute.eulerAngles.z = chuteAngle
            chute.position = SCNVector3(station.alliance == .red ? -0.10 : 0.10, 0.20, 0)
            stationRoot.addChildNode(chute)

            // Game piece display
            if let primaryPiece = game.gamePieces.first {
                let pieceNode = makeGamePiece(kind: primaryPiece)
                pieceNode.position = SCNVector3(0, 0.06, 0)
                stationRoot.addChildNode(pieceNode)
            }

            stationRoot.position = SCNVector3(station.position.x, 0, station.position.y)
            scene.rootNode.addChildNode(stationRoot)
        }
    }

    static func makeGamePiece(kind: GamePieceKind) -> SCNNode {
        let geo: SCNGeometry
        switch kind {
        case .ball:
            geo = SCNSphere(radius: 0.05)
            (geo as! SCNSphere).segmentCount = 12
        case .cube:
            geo = SCNBox(width: 0.08, height: 0.08, length: 0.08, chamferRadius: 0.005)
        case .cone:
            geo = SCNCone(topRadius: 0.01, bottomRadius: 0.04, height: 0.10)
            (geo as! SCNCone).radialSegmentCount = 8
        case .ring:
            geo = SCNTorus(ringRadius: 0.04, pipeRadius: 0.012)
            (geo as! SCNTorus).ringSegmentCount = 12
            (geo as! SCNTorus).pipeSegmentCount = 6
        }
        geo.materials = [FieldMaterials.gamePiece(kind)]
        let node = SCNNode(geometry: geo)
        node.name = "game_piece"
        return node
    }

    // MARK: - Start Positions

    private static func addStartPositions(to scene: SCNScene) {
        for (i, pos) in FieldLayout.redStarts.enumerated() {
            addStartMarker(to: scene, position: pos, number: i + 1, alliance: .red)
        }
        for (i, pos) in FieldLayout.blueStarts.enumerated() {
            addStartMarker(to: scene, position: pos, number: i + 1, alliance: .blue)
        }
    }

    private static func addStartMarker(to scene: SCNScene, position: SIMD2<Float>, number: Int, alliance: Alliance) {
        let geo = SCNCylinder(radius: 0.16, height: 0.005)
        geo.radialSegmentCount = 16
        let mat = SCNMaterial()
        mat.diffuse.contents = alliance.uiColor.withAlphaComponent(0.3)
        geo.materials = [mat]
        let node = SCNNode(geometry: geo)
        node.position = SCNVector3(position.x, 0.003, position.y)
        scene.rootNode.addChildNode(node)

        let txtGeo = SCNText(string: "\(number)", extrusionDepth: 0.003)
        txtGeo.font = UIFont.systemFont(ofSize: 0.12, weight: .bold)
        txtGeo.flatness = 0.3
        let txtMat = SCNMaterial()
        txtMat.diffuse.contents = alliance.uiColor.withAlphaComponent(0.5)
        txtGeo.materials = [txtMat]
        let txtNode = SCNNode(geometry: txtGeo)
        let (mn, mx) = txtNode.boundingBox
        txtNode.position = SCNVector3(position.x - (mx.x - mn.x) / 2, 0.006, position.y + 0.04)
        txtNode.eulerAngles.x = -Float.pi / 2
        scene.rootNode.addChildNode(txtNode)
    }

    // MARK: - Field Lines

    private static func addFieldLines(to scene: SCNScene) {
        let fl = FieldLayout.fieldLength
        let lineMat = SCNMaterial()
        lineMat.diffuse.contents = UIColor.white.withAlphaComponent(0.15)

        // Center line
        let centerGeo = SCNBox(width: 0.02, height: 0.002, length: CGFloat(fl), chamferRadius: 0)
        centerGeo.materials = [lineMat]
        let center = SCNNode(geometry: centerGeo)
        center.position = SCNVector3(0, 0.001, 0)
        scene.rootNode.addChildNode(center)

        // Auto lines
        for x in [FieldLayout.redAutoLine, FieldLayout.blueAutoLine] {
            let autoGeo = SCNBox(width: 0.02, height: 0.002, length: CGFloat(fl), chamferRadius: 0)
            let autoMat = SCNMaterial()
            autoMat.diffuse.contents = UIColor.orange.withAlphaComponent(0.25)
            autoGeo.materials = [autoMat]
            let autoLine = SCNNode(geometry: autoGeo)
            autoLine.position = SCNVector3(x, 0.001, 0)
            scene.rootNode.addChildNode(autoLine)
        }
    }
}

// MARK: - Robot Builder
// Builds mechanically-correct low-poly robot models from RobotConfig.

enum RobotBuilder {

    static func addRobots(to scene: SCNScene, configs: [RobotConfig]) -> [SCNNode] {
        configs.map { config in
            let robot = buildRobot(config: config)
            robot.position = SCNVector3(config.startPosition.x, 0, config.startPosition.y)
            scene.rootNode.addChildNode(robot)
            return robot
        }
    }

    static func buildRobot(config: RobotConfig) -> SCNNode {
        let root = SCNNode()
        root.name = "robot_\(config.id)"

        addChassis(to: root, config: config)
        addDrivetrain(to: root, config: config)
        addSuperstructure(to: root, config: config)
        addTeamNumber(to: root, config: config)

        return root
    }

    // MARK: - Chassis

    private static func addChassis(to root: SCNNode, config: RobotConfig) {
        let chassisW: CGFloat = 0.32
        let chassisH: CGFloat = 0.08
        let chassisD: CGFloat = 0.32

        // Frame body
        let bodyGeo = SCNBox(width: chassisW, height: chassisH, length: chassisD, chamferRadius: 0.005)
        bodyGeo.materials = [FieldMaterials.chassis]
        let body = SCNNode(geometry: bodyGeo)
        body.position = SCNVector3(0, Float(chassisH) / 2 + 0.04, 0)
        body.name = "chassis"
        root.addChildNode(body)

        // Bumpers (alliance-colored wrap)
        let bumperH: CGFloat = 0.05
        let bumperW: CGFloat = chassisW + 0.03
        let bumperD: CGFloat = chassisD + 0.03
        let bumperGeo = SCNBox(width: bumperW, height: bumperH, length: bumperD, chamferRadius: 0.01)
        bumperGeo.materials = [FieldMaterials.bumper(config.alliance)]
        let bumper = SCNNode(geometry: bumperGeo)
        bumper.position = SCNVector3(0, 0.04 + Float(bumperH) / 2, 0)
        root.addChildNode(bumper)
    }

    // MARK: - Drivetrain

    private static func addDrivetrain(to root: SCNNode, config: RobotConfig) {
        switch config.build.drivetrain {
        case .swerve:
            addSwerveWheels(to: root)
        case .tank:
            addTankWheels(to: root)
        case .mecanum:
            addMecanumWheels(to: root)
        }
    }

    private static func addSwerveWheels(to root: SCNNode) {
        let positions: [(Float, Float)] = [
            (-0.13, -0.13), (-0.13, 0.13), (0.13, -0.13), (0.13, 0.13)
        ]
        for (i, (dx, dz)) in positions.enumerated() {
            // Swerve module housing
            let moduleGeo = SCNCylinder(radius: 0.025, height: 0.03)
            moduleGeo.radialSegmentCount = 8
            moduleGeo.materials = [FieldMaterials.metal]
            let module = SCNNode(geometry: moduleGeo)
            module.position = SCNVector3(dx, 0.055, dz)
            root.addChildNode(module)

            // Wheel
            let wheelGeo = SCNCylinder(radius: 0.035, height: 0.02)
            wheelGeo.radialSegmentCount = 12
            wheelGeo.materials = [FieldMaterials.wheel]
            let wheel = SCNNode(geometry: wheelGeo)
            wheel.name = "wheel_\(i)"
            wheel.eulerAngles.z = Float.pi / 2
            wheel.position = SCNVector3(dx, 0.035, dz)
            root.addChildNode(wheel)
        }
    }

    private static func addTankWheels(to root: SCNNode) {
        let zPos: [Float] = [-0.11, 0.0, 0.11]
        for (i, z) in zPos.enumerated() {
            for (j, xSign) in [-1.0 as Float, 1.0].enumerated() {
                let wheelGeo = SCNCylinder(radius: 0.04, height: 0.022)
                wheelGeo.radialSegmentCount = 12
                wheelGeo.materials = [FieldMaterials.wheel]
                let wheel = SCNNode(geometry: wheelGeo)
                wheel.name = "wheel_\(i * 2 + j)"
                wheel.eulerAngles.z = Float.pi / 2
                wheel.position = SCNVector3(xSign * 0.17, 0.04, z)
                root.addChildNode(wheel)
            }
        }
    }

    private static func addMecanumWheels(to root: SCNNode) {
        let positions: [(Float, Float)] = [
            (-0.14, -0.12), (-0.14, 0.12), (0.14, -0.12), (0.14, 0.12)
        ]
        for (i, (dx, dz)) in positions.enumerated() {
            // Mecanum wheel (slightly larger, with roller indicators)
            let wheelGeo = SCNCylinder(radius: 0.038, height: 0.024)
            wheelGeo.radialSegmentCount = 12
            wheelGeo.materials = [FieldMaterials.wheel]
            let wheel = SCNNode(geometry: wheelGeo)
            wheel.name = "wheel_\(i)"
            wheel.eulerAngles.z = Float.pi / 2
            wheel.position = SCNVector3(dx, 0.038, dz)
            root.addChildNode(wheel)

            // Small diagonal roller indicators (low-poly feel)
            let rollerGeo = SCNCylinder(radius: 0.008, height: 0.025)
            rollerGeo.radialSegmentCount = 6
            let rollerMat = SCNMaterial()
            rollerMat.diffuse.contents = UIColor(white: 0.3, alpha: 1)
            rollerGeo.materials = [rollerMat]
            let roller = SCNNode(geometry: rollerGeo)
            roller.eulerAngles.x = Float.pi / 4  // diagonal
            roller.position = SCNVector3(dx, 0.038, dz)
            root.addChildNode(roller)
        }
    }

    // MARK: - Superstructure

    private static func addSuperstructure(to root: SCNNode, config: RobotConfig) {
        switch config.superstructure {
        case .elevator:
            addElevator(to: root, alliance: config.alliance)
        case .arm:
            addPivotArm(to: root, alliance: config.alliance)
        case .shooter:
            addShooter(to: root, alliance: config.alliance)
        case .intake:
            addIntake(to: root, alliance: config.alliance)
        case .wedge:
            addWedge(to: root, alliance: config.alliance)
        }
    }

    private static func addElevator(to root: SCNNode, alliance: Alliance) {
        let baseY: Float = 0.12

        // Dual vertical rails
        for xOff: Float in [-0.06, 0.06] {
            let railGeo = SCNBox(width: 0.018, height: 0.38, length: 0.018, chamferRadius: 0)
            railGeo.materials = [FieldMaterials.metal]
            let rail = SCNNode(geometry: railGeo)
            rail.position = SCNVector3(xOff, baseY + 0.19, -0.02)
            root.addChildNode(rail)
        }

        // Inner telescoping stage
        let stageGeo = SCNBox(width: 0.08, height: 0.18, length: 0.015, chamferRadius: 0)
        stageGeo.materials = [FieldMaterials.metal]
        let stage = SCNNode(geometry: stageGeo)
        stage.name = "elevator_stage"
        stage.position = SCNVector3(0, baseY + 0.22, -0.02)
        root.addChildNode(stage)

        // Gripper at top
        let gripGeo = SCNBox(width: 0.10, height: 0.04, length: 0.05, chamferRadius: 0.005)
        let gripMat = SCNMaterial()
        gripMat.diffuse.contents = alliance.uiColor.withAlphaComponent(0.7)
        gripGeo.materials = [gripMat]
        let grip = SCNNode(geometry: gripGeo)
        grip.name = "elevator_gripper"
        grip.position = SCNVector3(0, baseY + 0.33, 0.01)
        root.addChildNode(grip)

        // Top crossbar
        let topGeo = SCNCylinder(radius: 0.01, height: 0.14)
        topGeo.radialSegmentCount = 6
        topGeo.materials = [FieldMaterials.metal]
        let topBar = SCNNode(geometry: topGeo)
        topBar.eulerAngles.z = Float.pi / 2
        topBar.position = SCNVector3(0, baseY + 0.38, -0.02)
        root.addChildNode(topBar)
    }

    private static func addPivotArm(to root: SCNNode, alliance: Alliance) {
        let baseY: Float = 0.12

        // Pivot base
        let pivotGeo = SCNCylinder(radius: 0.025, height: 0.04)
        pivotGeo.radialSegmentCount = 8
        pivotGeo.materials = [FieldMaterials.metal]
        let pivot = SCNNode(geometry: pivotGeo)
        pivot.position = SCNVector3(0, baseY + 0.06, -0.04)
        root.addChildNode(pivot)

        // Arm extension
        let armGeo = SCNCylinder(radius: 0.012, height: 0.28)
        armGeo.radialSegmentCount = 6
        armGeo.materials = [FieldMaterials.metal]
        let arm = SCNNode(geometry: armGeo)
        arm.name = "pivot_arm"
        arm.pivot = SCNMatrix4MakeTranslation(0, -0.14, 0)
        arm.position = SCNVector3(0, baseY + 0.08, -0.04)
        arm.eulerAngles.z = 0.35  // resting angle
        root.addChildNode(arm)

        // Gripper at end
        let gripGeo = SCNBox(width: 0.08, height: 0.03, length: 0.04, chamferRadius: 0.005)
        let gripMat = SCNMaterial()
        gripMat.diffuse.contents = alliance.uiColor.withAlphaComponent(0.7)
        gripGeo.materials = [gripMat]
        let grip = SCNNode(geometry: gripGeo)
        grip.name = "arm_gripper"
        grip.position = SCNVector3(0, 0.28, 0)
        arm.addChildNode(grip)
    }

    private static func addShooter(to root: SCNNode, alliance: Alliance) {
        let baseY: Float = 0.12

        // Shooter housing
        let housingGeo = SCNBox(width: 0.20, height: 0.10, length: 0.14, chamferRadius: 0.01)
        housingGeo.materials = [FieldMaterials.chassis]
        let housing = SCNNode(geometry: housingGeo)
        housing.position = SCNVector3(0, baseY + 0.05, 0.02)
        root.addChildNode(housing)

        // Dual flywheels
        for xOff: Float in [-0.08, 0.08] {
            let fwGeo = SCNCylinder(radius: 0.04, height: 0.015)
            fwGeo.radialSegmentCount = 10
            let fwMat = SCNMaterial()
            fwMat.diffuse.contents = UIColor.systemGreen
            fwGeo.materials = [fwMat]
            let fw = SCNNode(geometry: fwGeo)
            fw.name = "flywheel"
            fw.eulerAngles.z = Float.pi / 2
            fw.position = SCNVector3(xOff, baseY + 0.12, 0.08)
            root.addChildNode(fw)
        }

        // Exit chute (angled up)
        let chuteGeo = SCNBox(width: 0.06, height: 0.03, length: 0.12, chamferRadius: 0)
        let chuteMat = SCNMaterial()
        chuteMat.diffuse.contents = alliance.uiColor.withAlphaComponent(0.6)
        chuteGeo.materials = [chuteMat]
        let chute = SCNNode(geometry: chuteGeo)
        chute.position = SCNVector3(0, baseY + 0.12, 0.10)
        chute.eulerAngles.x = -Float.pi / 6
        root.addChildNode(chute)

        // Hood/backboard
        let hoodGeo = SCNBox(width: 0.18, height: 0.08, length: 0.01, chamferRadius: 0)
        hoodGeo.materials = [FieldMaterials.metal]
        let hood = SCNNode(geometry: hoodGeo)
        hood.position = SCNVector3(0, baseY + 0.12, -0.03)
        root.addChildNode(hood)
    }

    private static func addIntake(to root: SCNNode, alliance: Alliance) {
        // Front roller intake
        let rollerGeo = SCNCylinder(radius: 0.028, height: 0.22)
        rollerGeo.radialSegmentCount = 10
        rollerGeo.materials = [FieldMaterials.teal]
        let roller = SCNNode(geometry: rollerGeo)
        roller.name = "intake_roller"
        roller.eulerAngles.z = Float.pi / 2
        roller.position = SCNVector3(0, 0.05, 0.18)
        root.addChildNode(roller)

        // Guard plate
        let guardGeo = SCNBox(width: 0.24, height: 0.04, length: 0.02, chamferRadius: 0)
        let guardMat = SCNMaterial()
        guardMat.diffuse.contents = alliance.uiColor.withAlphaComponent(0.5)
        guardGeo.materials = [guardMat]
        let guardNode = SCNNode(geometry: guardGeo)
        guardNode.position = SCNVector3(0, 0.07, 0.19)
        root.addChildNode(guardNode)

        // Hopper tray behind roller
        let hoppGeo = SCNBox(width: 0.20, height: 0.02, length: 0.12, chamferRadius: 0)
        let hoppMat = SCNMaterial()
        hoppMat.diffuse.contents = UIColor(white: 0.30, alpha: 1)
        hoppGeo.materials = [hoppMat]
        let hopper = SCNNode(geometry: hoppGeo)
        hopper.position = SCNVector3(0, 0.09, 0.10)
        hopper.eulerAngles.x = Float.pi / 8
        root.addChildNode(hopper)
    }

    private static func addWedge(to root: SCNNode, alliance: Alliance) {
        // Low wedge push plate
        let wedgeGeo = SCNBox(width: 0.30, height: 0.03, length: 0.18, chamferRadius: 0)
        let wedgeMat = SCNMaterial()
        wedgeMat.diffuse.contents = UIColor.systemGreen
        wedgeGeo.materials = [wedgeMat]
        let wedge = SCNNode(geometry: wedgeGeo)
        wedge.position = SCNVector3(0, 0.04, 0.15)
        wedge.eulerAngles.x = -0.15
        root.addChildNode(wedge)

        // Push face
        let faceGeo = SCNBox(width: 0.32, height: 0.10, length: 0.02, chamferRadius: 0.005)
        let faceMat = SCNMaterial()
        faceMat.diffuse.contents = alliance.uiColor.withAlphaComponent(0.8)
        faceGeo.materials = [faceMat]
        let face = SCNNode(geometry: faceGeo)
        face.position = SCNVector3(0, 0.08, 0.20)
        root.addChildNode(face)
    }

    // MARK: - Team Number

    private static func addTeamNumber(to root: SCNNode, config: RobotConfig) {
        let txtGeo = SCNText(string: config.teamNumber, extrusionDepth: 0.005)
        txtGeo.font = UIFont.monospacedSystemFont(ofSize: 0.05, weight: .bold)
        txtGeo.flatness = 0.3
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.white.withAlphaComponent(0.9)
        txtGeo.materials = [mat]
        let txtNode = SCNNode(geometry: txtGeo)
        let (mn, mx) = txtNode.boundingBox
        txtNode.position = SCNVector3(-(mx.x - mn.x) / 2, 0.11, 0.18)
        txtNode.name = "team_number"
        root.addChildNode(txtNode)
    }
}
