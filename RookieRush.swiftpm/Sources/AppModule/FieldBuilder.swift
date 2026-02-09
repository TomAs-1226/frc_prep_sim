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
            let binGeo = SCNBox(width: 0.30, height: 0.06, length: 0.20, chamferRadius: 0.01)
            binGeo.materials = [FieldMaterials.targetBase(h)]
            let bin = SCNNode(geometry: binGeo)
            bin.position = SCNVector3(0, 0.03, 0)
            parent.addChildNode(bin)

            for zSign: Float in [-1, 1] {
                let lip = SCNBox(width: 0.30, height: 0.03, length: 0.015, chamferRadius: 0)
                lip.materials = [FieldMaterials.targetGoal(zone.alliance)]
                let lipNode = SCNNode(geometry: lip)
                lipNode.position = SCNVector3(0, 0.06 + 0.015, zSign * 0.09)
                parent.addChildNode(lipNode)
            }

        case .low:
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
            let pillarGeo = SCNCylinder(radius: 0.05, height: CGFloat(h.sceneHeight))
            pillarGeo.radialSegmentCount = 8
            pillarGeo.materials = [FieldMaterials.targetBase(h)]
            let pillar = SCNNode(geometry: pillarGeo)
            pillar.position = SCNVector3(0, h.sceneHeight / 2, 0)
            parent.addChildNode(pillar)

            let basketGeo = SCNTorus(ringRadius: 0.10, pipeRadius: 0.015)
            basketGeo.ringSegmentCount = 16
            basketGeo.pipeSegmentCount = 6
            basketGeo.materials = [FieldMaterials.targetGoal(zone.alliance)]
            let basket = SCNNode(geometry: basketGeo)
            basket.position = SCNVector3(0, h.sceneHeight + 0.02, 0)
            parent.addChildNode(basket)

            let barGeo = SCNCylinder(radius: 0.01, height: 0.20)
            barGeo.radialSegmentCount = 6
            barGeo.materials = [FieldMaterials.metal]
            let bar = SCNNode(geometry: barGeo)
            bar.eulerAngles.z = Float.pi / 2
            bar.position = SCNVector3(0, h.sceneHeight + 0.02, 0)
            parent.addChildNode(bar)

        case .high:
            let baseGeo = SCNBox(width: 0.14, height: 0.08, length: 0.14, chamferRadius: 0.01)
            baseGeo.materials = [FieldMaterials.targetBase(h)]
            let base = SCNNode(geometry: baseGeo)
            base.position = SCNVector3(0, 0.04, 0)
            parent.addChildNode(base)

            let shaftGeo = SCNCylinder(radius: 0.04, height: CGFloat(h.sceneHeight - 0.08))
            shaftGeo.radialSegmentCount = 6
            shaftGeo.materials = [FieldMaterials.metal]
            let shaft = SCNNode(geometry: shaftGeo)
            shaft.position = SCNVector3(0, 0.08 + (h.sceneHeight - 0.08) / 2, 0)
            parent.addChildNode(shaft)

            let hoopGeo = SCNTorus(ringRadius: 0.12, pipeRadius: 0.018)
            hoopGeo.ringSegmentCount = 16
            hoopGeo.pipeSegmentCount = 6
            hoopGeo.materials = [FieldMaterials.targetGoal(zone.alliance)]
            let hoop = SCNNode(geometry: hoopGeo)
            hoop.position = SCNVector3(0, h.sceneHeight + 0.02, 0)
            parent.addChildNode(hoop)

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

        let topGeo = SCNBox(width: CGFloat(topW), height: 0.06, length: CGFloat(topL), chamferRadius: 0)
        topGeo.materials = [FieldMaterials.bridge]
        let top = SCNNode(geometry: topGeo)
        top.position = SCNVector3(0, topH, 0)
        bridgeRoot.addChildNode(top)

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

        let braceGeo = SCNCylinder(radius: 0.015, height: CGFloat(topL * 0.6))
        braceGeo.radialSegmentCount = 6
        braceGeo.materials = [FieldMaterials.metal]
        for xSign: Float in [-1, 1] {
            let brace = SCNNode(geometry: braceGeo)
            brace.position = SCNVector3(xSign * (topW / 2 - 0.06), topH * 0.5, 0)
            brace.eulerAngles.x = Float.pi / 6
            bridgeRoot.addChildNode(brace)
        }

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
        node.eulerAngles.z = Float.pi / 12
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

            let supportGeo = SCNCylinder(radius: 0.03, height: CGFloat(barH + 0.05))
            supportGeo.radialSegmentCount = 6
            supportGeo.materials = [FieldMaterials.metal]
            for dz: Float in [-0.40, 0.40] {
                let support = SCNNode(geometry: supportGeo)
                support.position = SCNVector3(0, (barH + 0.05) / 2, dz)
                barRoot.addChildNode(support)
            }

            let climbGeo = SCNCylinder(radius: 0.025, height: 0.80)
            climbGeo.radialSegmentCount = 8
            climbGeo.materials = [FieldMaterials.climbBar]
            let climb = SCNNode(geometry: climbGeo)
            climb.eulerAngles.x = Float.pi / 2
            climb.position = SCNVector3(0, barH, 0)
            barRoot.addChildNode(climb)

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
            plat.eulerAngles.z = Float.pi / 30 * xSign
            plat.name = "balance_\(alliance.rawValue)"
            scene.rootNode.addChildNode(plat)

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

            let zoneGeo = SCNBox(width: 0.45, height: 0.004, length: 0.45, chamferRadius: 0.02)
            zoneGeo.materials = [FieldMaterials.pickupStation(station.alliance)]
            let zone = SCNNode(geometry: zoneGeo)
            zone.position = SCNVector3(0, 0.002, 0)
            stationRoot.addChildNode(zone)

            let chuteGeo = SCNBox(width: 0.25, height: 0.30, length: 0.06, chamferRadius: 0)
            chuteGeo.materials = [FieldMaterials.metal]
            let chute = SCNNode(geometry: chuteGeo)
            let chuteAngle: Float = station.alliance == .red ? -0.8 : 0.8
            chute.eulerAngles.z = chuteAngle
            chute.position = SCNVector3(station.alliance == .red ? -0.10 : 0.10, 0.20, 0)
            stationRoot.addChildNode(chute)

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

        let centerGeo = SCNBox(width: 0.02, height: 0.002, length: CGFloat(fl), chamferRadius: 0)
        centerGeo.materials = [lineMat]
        let center = SCNNode(geometry: centerGeo)
        center.position = SCNVector3(0, 0.001, 0)
        scene.rootNode.addChildNode(center)

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

    // MARK: - Particle Helpers

    /// Spawn scoring particles at a position
    static func spawnScoreParticles(at position: SCNVector3, alliance: Alliance, scene: SCNScene) {
        let count = 8
        for i in 0..<count {
            let angle = Float(i) / Float(count) * Float.pi * 2
            let radius: Float = 0.06
            let sparkGeo = SCNSphere(radius: 0.015)
            sparkGeo.segmentCount = 6
            sparkGeo.materials = [FieldMaterials.scoreParticle(alliance)]
            let spark = SCNNode(geometry: sparkGeo)
            spark.position = position

            let dx = sin(angle) * radius
            let dz = cos(angle) * radius
            let endPos = SCNVector3(
                position.x + dx * 3,
                position.y + Float.random(in: 0.1...0.4),
                position.z + dz * 3
            )

            let moveUp = SCNAction.move(to: endPos, duration: 0.4)
            moveUp.timingMode = .easeOut
            let fade = SCNAction.fadeOut(duration: 0.3)
            let remove = SCNAction.removeFromParentNode()
            spark.runAction(SCNAction.sequence([moveUp, fade, remove]))

            scene.rootNode.addChildNode(spark)
        }
    }

    /// Spawn dust cloud when robots collide
    static func spawnCollisionDust(at position: SCNVector3, scene: SCNScene) {
        for _ in 0..<4 {
            let dustGeo = SCNSphere(radius: 0.02)
            dustGeo.segmentCount = 6
            dustGeo.materials = [FieldMaterials.dustParticle]
            let dust = SCNNode(geometry: dustGeo)
            dust.position = SCNVector3(
                position.x + Float.random(in: -0.05...0.05),
                0.04,
                position.z + Float.random(in: -0.05...0.05)
            )
            dust.opacity = 0.4

            let rise = SCNAction.moveBy(x: 0, y: 0.08, z: 0, duration: 0.5)
            rise.timingMode = .easeOut
            let grow = SCNAction.scale(to: 2.0, duration: 0.5)
            let fade = SCNAction.fadeOut(duration: 0.4)
            let remove = SCNAction.removeFromParentNode()
            dust.runAction(SCNAction.group([rise, grow]))
            dust.runAction(SCNAction.sequence([
                SCNAction.wait(duration: 0.3),
                fade, remove
            ]))

            scene.rootNode.addChildNode(dust)
        }
    }
}

// ===================================================================
// MARK: - Robot Builder
// Builds mechanically-correct, detailed low-poly FRC robot models.
// Each robot has: tube frame, bellypan, battery, electronics, bumpers,
// drivetrain, and superstructure — all from SceneKit primitives.
// ===================================================================

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

        // Build order matters for layering (bottom-up)
        addDrivetrain(to: root, config: config)
        addFrame(to: root, config: config)
        addBumpers(to: root, config: config)
        addInternals(to: root, config: config)
        addSuperstructure(to: root, config: config)
        addTeamNumber(to: root, config: config)

        return root
    }

    // MARK: - Frame (Tube Perimeter + Cross Members + Bellypan)

    private static func addFrame(to root: SCNNode, config: RobotConfig) {
        let frameMat = FieldMaterials.frameForChoice(config.build.frame)
        let tubeSize: CGFloat = 0.018  // 1" square tube scaled
        let frameW: Float = 0.30       // frame width (x)
        let frameD: Float = 0.30       // frame depth (z)
        let frameY: Float = 0.05       // frame rail height from ground
        let halfW = frameW / 2
        let halfD = frameD / 2

        // Four perimeter rails (tube frame)
        // Front and back rails (along X)
        for zSign: Float in [-1, 1] {
            let railGeo = SCNBox(width: CGFloat(frameW), height: tubeSize, length: tubeSize, chamferRadius: 0.002)
            railGeo.materials = [frameMat]
            let rail = SCNNode(geometry: railGeo)
            rail.position = SCNVector3(0, frameY, zSign * halfD)
            root.addChildNode(rail)
        }
        // Left and right rails (along Z)
        for xSign: Float in [-1, 1] {
            let railGeo = SCNBox(width: tubeSize, height: tubeSize, length: CGFloat(frameD), chamferRadius: 0.002)
            railGeo.materials = [frameMat]
            let rail = SCNNode(geometry: railGeo)
            rail.position = SCNVector3(xSign * halfW, frameY, 0)
            root.addChildNode(rail)
        }

        // Cross members (2 internal support tubes)
        for zOff: Float in [-0.08, 0.08] {
            let crossGeo = SCNBox(width: CGFloat(frameW - 0.04), height: tubeSize * 0.8, length: tubeSize * 0.8, chamferRadius: 0)
            crossGeo.materials = [frameMat]
            let cross = SCNNode(geometry: crossGeo)
            cross.position = SCNVector3(0, frameY, zOff)
            root.addChildNode(cross)
        }

        // Bellypan (bottom plate)
        let bellyGeo = SCNBox(width: CGFloat(frameW - 0.02), height: 0.004, length: CGFloat(frameD - 0.02), chamferRadius: 0)
        bellyGeo.materials = [FieldMaterials.bellypan]
        let belly = SCNNode(geometry: bellyGeo)
        belly.position = SCNVector3(0, frameY - Float(tubeSize) / 2 - 0.002, 0)
        root.addChildNode(belly)

        // Top plate (chassis plate behind superstructure area)
        let topGeo = SCNBox(width: CGFloat(frameW - 0.06), height: 0.005, length: CGFloat(frameD * 0.4), chamferRadius: 0)
        topGeo.materials = [FieldMaterials.chassis]
        let topPlate = SCNNode(geometry: topGeo)
        topPlate.position = SCNVector3(0, frameY + Float(tubeSize) / 2 + 0.002, -0.05)
        topPlate.name = "chassis"
        root.addChildNode(topPlate)
    }

    // MARK: - Bumpers (FRC-style: pool noodle + fabric wrap)

    private static func addBumpers(to root: SCNNode, config: RobotConfig) {
        let bumperH: Float = 0.05
        let bumperThick: Float = 0.035
        let frameW: Float = 0.30
        let frameD: Float = 0.30
        let bumperY: Float = 0.05  // same as frame rail height

        let fabricMat = FieldMaterials.bumperFabric(config.alliance)

        // Front bumper
        let frontGeo = SCNBox(width: CGFloat(frameW + bumperThick * 2),
                              height: CGFloat(bumperH),
                              length: CGFloat(bumperThick), chamferRadius: 0.005)
        frontGeo.materials = [fabricMat]
        let front = SCNNode(geometry: frontGeo)
        front.position = SCNVector3(0, bumperY, frameD / 2 + bumperThick / 2)
        root.addChildNode(front)

        // Back bumper
        let backGeo = SCNBox(width: CGFloat(frameW + bumperThick * 2),
                             height: CGFloat(bumperH),
                             length: CGFloat(bumperThick), chamferRadius: 0.005)
        backGeo.materials = [fabricMat]
        let back = SCNNode(geometry: backGeo)
        back.position = SCNVector3(0, bumperY, -(frameD / 2 + bumperThick / 2))
        root.addChildNode(back)

        // Left bumper
        let leftGeo = SCNBox(width: CGFloat(bumperThick),
                             height: CGFloat(bumperH),
                             length: CGFloat(frameD), chamferRadius: 0.005)
        leftGeo.materials = [fabricMat]
        let left = SCNNode(geometry: leftGeo)
        left.position = SCNVector3(-(frameW / 2 + bumperThick / 2), bumperY, 0)
        root.addChildNode(left)

        // Right bumper
        let rightGeo = SCNBox(width: CGFloat(bumperThick),
                              height: CGFloat(bumperH),
                              length: CGFloat(frameD), chamferRadius: 0.005)
        rightGeo.materials = [fabricMat]
        let right = SCNNode(geometry: rightGeo)
        right.position = SCNVector3(frameW / 2 + bumperThick / 2, bumperY, 0)
        root.addChildNode(right)

        // Corner gusset triangles (4 corners, small detail)
        for (xSign, zSign) in [(-1, -1), (-1, 1), (1, -1), (1, 1)] as [(Float, Float)] {
            let gusGeo = SCNBox(width: CGFloat(bumperThick), height: CGFloat(bumperH * 0.8),
                                length: CGFloat(bumperThick), chamferRadius: 0.003)
            gusGeo.materials = [fabricMat]
            let gus = SCNNode(geometry: gusGeo)
            gus.position = SCNVector3(xSign * (frameW / 2 + bumperThick / 2),
                                       bumperY,
                                       zSign * (frameD / 2 + bumperThick / 2))
            root.addChildNode(gus)
        }
    }

    // MARK: - Internals (Battery + Electronics)

    private static func addInternals(to root: SCNNode, config: RobotConfig) {
        let frameY: Float = 0.05

        // Battery (centered, low, heavy — like a real FRC battery)
        let battGeo = SCNBox(width: 0.07, height: 0.04, length: 0.10, chamferRadius: 0.003)
        battGeo.materials = [FieldMaterials.battery]
        let batt = SCNNode(geometry: battGeo)
        batt.position = SCNVector3(0, frameY + 0.03, -0.02)
        root.addChildNode(batt)

        // Battery terminals (two small cylinders on top)
        for xOff: Float in [-0.02, 0.02] {
            let termGeo = SCNCylinder(radius: 0.005, height: 0.008)
            termGeo.radialSegmentCount = 6
            let termMat = SCNMaterial()
            termMat.diffuse.contents = UIColor(white: 0.7, alpha: 1)
            termMat.metalness.contents = NSNumber(value: 0.8)
            termGeo.materials = [termMat]
            let term = SCNNode(geometry: termGeo)
            term.position = SCNVector3(xOff, frameY + 0.054, -0.04)
            root.addChildNode(term)
        }

        // Electronics board (roboRIO / radio)
        let boardGeo = SCNBox(width: 0.06, height: 0.008, length: 0.05, chamferRadius: 0.002)
        boardGeo.materials = [FieldMaterials.electronics]
        let board = SCNNode(geometry: boardGeo)
        board.position = SCNVector3(0.06, frameY + 0.025, -0.08)
        root.addChildNode(board)

        // Small radio box on top of board
        let radioGeo = SCNBox(width: 0.025, height: 0.012, length: 0.025, chamferRadius: 0.002)
        radioGeo.materials = [FieldMaterials.motorHousing]
        let radio = SCNNode(geometry: radioGeo)
        radio.position = SCNVector3(0.06, frameY + 0.038, -0.08)
        root.addChildNode(radio)

        // Power distribution (on the other side)
        let pdpGeo = SCNBox(width: 0.05, height: 0.01, length: 0.05, chamferRadius: 0.002)
        pdpGeo.materials = [FieldMaterials.electronics]
        let pdp = SCNNode(geometry: pdpGeo)
        pdp.position = SCNVector3(-0.06, frameY + 0.025, -0.08)
        root.addChildNode(pdp)
    }

    // MARK: - Drivetrain

    private static func addDrivetrain(to root: SCNNode, config: RobotConfig) {
        switch config.build.drivetrain {
        case .swerve:  addSwerveModules(to: root, config: config)
        case .tank:    addTankDrive(to: root, config: config)
        case .mecanum: addMecanumWheels(to: root, config: config)
        }
    }

    // MARK: Swerve Drive (4 independent modules)

    private static func addSwerveModules(to root: SCNNode, config: RobotConfig) {
        let positions: [(Float, Float)] = [
            (-0.11, -0.11), (-0.11, 0.11), (0.11, -0.11), (0.11, 0.11)
        ]
        let wheelR: CGFloat = 0.032
        let wheelW: CGFloat = 0.018

        for (i, (dx, dz)) in positions.enumerated() {
            let moduleRoot = SCNNode()
            moduleRoot.name = "swerve_module_\(i)"

            // Module housing (cylindrical fork)
            let housingGeo = SCNCylinder(radius: 0.020, height: 0.028)
            housingGeo.radialSegmentCount = 8
            housingGeo.materials = [FieldMaterials.motorHousing]
            let housing = SCNNode(geometry: housingGeo)
            housing.position = SCNVector3(0, 0.050, 0)
            moduleRoot.addChildNode(housing)

            // Fork prongs (two side plates holding the wheel)
            for xOff: Float in [-0.014, 0.014] {
                let prongGeo = SCNBox(width: 0.004, height: 0.032, length: 0.018, chamferRadius: 0)
                prongGeo.materials = [FieldMaterials.gusset]
                let prong = SCNNode(geometry: prongGeo)
                prong.position = SCNVector3(xOff, 0.030, 0)
                moduleRoot.addChildNode(prong)
            }

            // Motor (small cylinder on top of module)
            let motorGeo = SCNCylinder(radius: 0.012, height: 0.020)
            motorGeo.radialSegmentCount = 8
            motorGeo.materials = [FieldMaterials.motorHousing]
            let motor = SCNNode(geometry: motorGeo)
            motor.eulerAngles.z = Float.pi / 2
            motor.position = SCNVector3(0.022, 0.050, 0)
            moduleRoot.addChildNode(motor)

            // Wheel
            let wheelGeo = SCNCylinder(radius: wheelR, height: wheelW)
            wheelGeo.radialSegmentCount = 12
            wheelGeo.materials = [FieldMaterials.wheel]
            let wheel = SCNNode(geometry: wheelGeo)
            wheel.name = "wheel_\(i)"
            wheel.eulerAngles.z = Float.pi / 2
            wheel.position = SCNVector3(0, Float(wheelR), 0)
            moduleRoot.addChildNode(wheel)

            // Tread pattern (thin ring on wheel)
            let treadGeo = SCNTorus(ringRadius: wheelR - 0.002, pipeRadius: 0.003)
            treadGeo.ringSegmentCount = 12
            treadGeo.pipeSegmentCount = 4
            treadGeo.materials = [FieldMaterials.chain]
            let tread = SCNNode(geometry: treadGeo)
            tread.eulerAngles.z = Float.pi / 2
            tread.position = SCNVector3(0, Float(wheelR), 0)
            moduleRoot.addChildNode(tread)

            moduleRoot.position = SCNVector3(dx, 0, dz)
            root.addChildNode(moduleRoot)
        }
    }

    // MARK: Tank Drive (6 wheels with chain runs)

    private static func addTankDrive(to root: SCNNode, config: RobotConfig) {
        let wheelR: CGFloat = 0.038
        let wheelW: CGFloat = 0.020
        let zPositions: [Float] = [-0.10, 0.0, 0.10]
        let xOffset: Float = 0.155

        for (i, z) in zPositions.enumerated() {
            for (j, xSign) in [-1.0 as Float, 1.0].enumerated() {
                let wheelIdx = i * 2 + j

                // Bearing block (mounting plate for axle)
                let bearingGeo = SCNBox(width: 0.016, height: 0.018, length: 0.012, chamferRadius: 0.001)
                bearingGeo.materials = [FieldMaterials.bearing]
                let bearingNode = SCNNode(geometry: bearingGeo)
                bearingNode.position = SCNVector3(xSign * (xOffset - 0.012), 0.04, z)
                root.addChildNode(bearingNode)

                // Axle (thin rod through wheel)
                let axleGeo = SCNCylinder(radius: 0.004, height: 0.028)
                axleGeo.radialSegmentCount = 6
                axleGeo.materials = [FieldMaterials.metal]
                let axle = SCNNode(geometry: axleGeo)
                axle.eulerAngles.z = Float.pi / 2
                axle.position = SCNVector3(xSign * xOffset, Float(wheelR), z)
                root.addChildNode(axle)

                // Wheel
                let wheelGeo = SCNCylinder(radius: wheelR, height: wheelW)
                wheelGeo.radialSegmentCount = 12
                wheelGeo.materials = [FieldMaterials.wheel]
                let wheel = SCNNode(geometry: wheelGeo)
                wheel.name = "wheel_\(wheelIdx)"
                wheel.eulerAngles.z = Float.pi / 2
                wheel.position = SCNVector3(xSign * xOffset, Float(wheelR), z)
                root.addChildNode(wheel)

                // Tread ring
                let treadGeo = SCNTorus(ringRadius: wheelR - 0.003, pipeRadius: 0.004)
                treadGeo.ringSegmentCount = 12
                treadGeo.pipeSegmentCount = 4
                treadGeo.materials = [FieldMaterials.chain]
                let tread = SCNNode(geometry: treadGeo)
                tread.eulerAngles.z = Float.pi / 2
                tread.position = SCNVector3(xSign * xOffset, Float(wheelR), z)
                root.addChildNode(tread)
            }
        }

        // Chain runs (connecting front and rear wheels on each side)
        for xSign: Float in [-1, 1] {
            let chainLen: Float = 0.20
            let chainGeo = SCNBox(width: 0.006, height: 0.005, length: CGFloat(chainLen), chamferRadius: 0)
            chainGeo.materials = [FieldMaterials.chain]

            // Upper chain run
            let chainUpper = SCNNode(geometry: chainGeo)
            chainUpper.position = SCNVector3(xSign * xOffset, 0.062, 0)
            root.addChildNode(chainUpper)

            // Lower chain run
            let chainLower = SCNNode(geometry: chainGeo)
            chainLower.position = SCNVector3(xSign * xOffset, 0.018, 0)
            root.addChildNode(chainLower)
        }

        // Sprockets on each wheel (visual only)
        for z in zPositions {
            for xSign: Float in [-1, 1] {
                let sprocketGeo = SCNTorus(ringRadius: 0.012, pipeRadius: 0.003)
                sprocketGeo.ringSegmentCount = 8
                sprocketGeo.pipeSegmentCount = 4
                sprocketGeo.materials = [FieldMaterials.metal]
                let sprocket = SCNNode(geometry: sprocketGeo)
                sprocket.eulerAngles.z = Float.pi / 2
                sprocket.position = SCNVector3(xSign * (xOffset - 0.011), Float(wheelR), z)
                root.addChildNode(sprocket)
            }
        }
    }

    // MARK: Mecanum Drive (4 wheels with diagonal rollers)

    private static func addMecanumWheels(to root: SCNNode, config: RobotConfig) {
        let positions: [(Float, Float)] = [
            (-0.12, -0.10), (-0.12, 0.10), (0.12, -0.10), (0.12, 0.10)
        ]
        let wheelR: CGFloat = 0.036
        let wheelW: CGFloat = 0.028

        for (i, (dx, dz)) in positions.enumerated() {
            // Bearing block
            let bearingGeo = SCNBox(width: 0.014, height: 0.016, length: 0.012, chamferRadius: 0.001)
            bearingGeo.materials = [FieldMaterials.bearing]
            let bearingNode = SCNNode(geometry: bearingGeo)
            let xInset: Float = dx > 0 ? -0.012 : 0.012
            bearingNode.position = SCNVector3(dx + xInset, 0.04, dz)
            root.addChildNode(bearingNode)

            // Main wheel body
            let wheelGeo = SCNCylinder(radius: wheelR, height: wheelW)
            wheelGeo.radialSegmentCount = 12
            wheelGeo.materials = [FieldMaterials.wheel]
            let wheel = SCNNode(geometry: wheelGeo)
            wheel.name = "wheel_\(i)"
            wheel.eulerAngles.z = Float.pi / 2
            wheel.position = SCNVector3(dx, Float(wheelR), dz)
            root.addChildNode(wheel)

            // Diagonal rollers (4 per wheel, the signature mecanum detail)
            let rollerCount = 4
            for r in 0..<rollerCount {
                let angle = Float(r) / Float(rollerCount) * Float.pi * 2
                let rX = Float(wheelR - 0.008) * cos(angle)
                let rY = Float(wheelR - 0.008) * sin(angle)

                let rollerGeo = SCNCylinder(radius: 0.006, height: 0.030)
                rollerGeo.radialSegmentCount = 6
                let rollerMat = SCNMaterial()
                rollerMat.diffuse.contents = UIColor(white: 0.35, alpha: 1)
                rollerGeo.materials = [rollerMat]
                let roller = SCNNode(geometry: rollerGeo)

                // Diagonal orientation (45 degrees — the defining feature of mecanum)
                let diagAngle: Float = (i % 2 == 0) ? Float.pi / 4 : -Float.pi / 4
                roller.eulerAngles = SCNVector3(diagAngle, 0, Float.pi / 2)
                roller.position = SCNVector3(dx, Float(wheelR) + rY, dz + rX)
                root.addChildNode(roller)
            }

            // Motor visible on inner side
            let motorGeo = SCNCylinder(radius: 0.010, height: 0.018)
            motorGeo.radialSegmentCount = 8
            motorGeo.materials = [FieldMaterials.motorHousing]
            let motor = SCNNode(geometry: motorGeo)
            motor.eulerAngles.z = Float.pi / 2
            motor.position = SCNVector3(dx + xInset, 0.04, dz)
            root.addChildNode(motor)
        }
    }

    // MARK: - Superstructure

    private static func addSuperstructure(to root: SCNNode, config: RobotConfig) {
        switch config.superstructure {
        case .elevator: addElevator(to: root, config: config)
        case .arm:      addPivotArm(to: root, config: config)
        case .shooter:  addShooter(to: root, config: config)
        case .intake:   addGroundIntake(to: root, config: config)
        case .wedge:    addDefenseWedge(to: root, config: config)
        }
    }

    // MARK: Elevator (Cascading 2-stage with chain)

    private static func addElevator(to root: SCNNode, config: RobotConfig) {
        let baseY: Float = 0.08
        let allianceColor = config.alliance.uiColor

        // Two C-channel uprights (outer stage)
        for xOff: Float in [-0.055, 0.055] {
            // Main upright
            let uprightGeo = SCNBox(width: 0.016, height: 0.36, length: 0.016, chamferRadius: 0)
            uprightGeo.materials = [FieldMaterials.frameTube]
            let upright = SCNNode(geometry: uprightGeo)
            upright.position = SCNVector3(xOff, baseY + 0.18, -0.04)
            root.addChildNode(upright)

            // C-channel lip (inner face detail)
            let lipGeo = SCNBox(width: 0.005, height: 0.34, length: 0.010, chamferRadius: 0)
            lipGeo.materials = [FieldMaterials.gusset]
            let lip = SCNNode(geometry: lipGeo)
            lip.position = SCNVector3(xOff > 0 ? xOff - 0.009 : xOff + 0.009, baseY + 0.18, -0.04)
            root.addChildNode(lip)
        }

        // Cross braces between uprights (3 levels)
        for yOff: Float in [0.06, 0.18, 0.30] {
            let braceGeo = SCNBox(width: 0.09, height: 0.006, length: 0.010, chamferRadius: 0)
            braceGeo.materials = [FieldMaterials.gusset]
            let brace = SCNNode(geometry: braceGeo)
            brace.position = SCNVector3(0, baseY + yOff, -0.04)
            root.addChildNode(brace)
        }

        // Inner stage (telescoping — slightly smaller)
        let stageGeo = SCNBox(width: 0.07, height: 0.20, length: 0.012, chamferRadius: 0)
        stageGeo.materials = [FieldMaterials.metal]
        let stage = SCNNode(geometry: stageGeo)
        stage.name = "elevator_stage"
        stage.position = SCNVector3(0, baseY + 0.22, -0.038)
        root.addChildNode(stage)

        // Chain run (single line on right side)
        let chainGeo = SCNBox(width: 0.004, height: 0.32, length: 0.004, chamferRadius: 0)
        chainGeo.materials = [FieldMaterials.chain]
        let chain = SCNNode(geometry: chainGeo)
        chain.position = SCNVector3(0.048, baseY + 0.16, -0.050)
        root.addChildNode(chain)

        // Sprocket at top
        let sprocketGeo = SCNTorus(ringRadius: 0.010, pipeRadius: 0.003)
        sprocketGeo.ringSegmentCount = 8
        sprocketGeo.pipeSegmentCount = 4
        sprocketGeo.materials = [FieldMaterials.metal]
        let sprocket = SCNNode(geometry: sprocketGeo)
        sprocket.position = SCNVector3(0.048, baseY + 0.34, -0.050)
        root.addChildNode(sprocket)

        // Carriage / gripper at top of inner stage
        let gripperGeo = SCNBox(width: 0.08, height: 0.025, length: 0.04, chamferRadius: 0.003)
        let gripMat = SCNMaterial()
        gripMat.diffuse.contents = allianceColor.withAlphaComponent(0.7)
        gripMat.roughness.contents = NSNumber(value: 0.5)
        gripperGeo.materials = [gripMat]
        let gripper = SCNNode(geometry: gripperGeo)
        gripper.name = "elevator_gripper"
        gripper.position = SCNVector3(0, baseY + 0.34, -0.01)
        root.addChildNode(gripper)

        // Gripper fingers (two small plates)
        for xOff: Float in [-0.03, 0.03] {
            let fingerGeo = SCNBox(width: 0.006, height: 0.018, length: 0.025, chamferRadius: 0)
            fingerGeo.materials = [gripMat]
            let finger = SCNNode(geometry: fingerGeo)
            finger.position = SCNVector3(xOff, baseY + 0.35, 0.02)
            root.addChildNode(finger)
        }

        // Top crossbar
        let topGeo = SCNCylinder(radius: 0.008, height: 0.12)
        topGeo.radialSegmentCount = 6
        topGeo.materials = [FieldMaterials.metal]
        let topBar = SCNNode(geometry: topGeo)
        topBar.eulerAngles.z = Float.pi / 2
        topBar.position = SCNVector3(0, baseY + 0.37, -0.04)
        root.addChildNode(topBar)

        // Base gusset plates (triangular support — approximated with small boxes)
        for xOff: Float in [-0.055, 0.055] {
            let gusGeo = SCNBox(width: 0.018, height: 0.04, length: 0.025, chamferRadius: 0)
            gusGeo.materials = [FieldMaterials.gusset]
            let gus = SCNNode(geometry: gusGeo)
            gus.position = SCNVector3(xOff, baseY + 0.02, -0.06)
            gus.eulerAngles.x = 0.2
            root.addChildNode(gus)
        }
    }

    // MARK: Pivot Arm (with gussets, extension, wrist)

    private static func addPivotArm(to root: SCNNode, config: RobotConfig) {
        let baseY: Float = 0.08
        let allianceColor = config.alliance.uiColor

        // Pivot tower (two triangular gusset plates)
        for xOff: Float in [-0.04, 0.04] {
            // Upright plate
            let plateGeo = SCNBox(width: 0.004, height: 0.10, length: 0.06, chamferRadius: 0)
            plateGeo.materials = [FieldMaterials.gusset]
            let plate = SCNNode(geometry: plateGeo)
            plate.position = SCNVector3(xOff, baseY + 0.06, -0.06)
            root.addChildNode(plate)

            // Diagonal brace
            let braceGeo = SCNBox(width: 0.004, height: 0.08, length: 0.012, chamferRadius: 0)
            braceGeo.materials = [FieldMaterials.gusset]
            let brace = SCNNode(geometry: braceGeo)
            brace.eulerAngles.x = 0.5
            brace.position = SCNVector3(xOff, baseY + 0.04, -0.08)
            root.addChildNode(brace)
        }

        // Pivot axle (horizontal shaft)
        let pivotGeo = SCNCylinder(radius: 0.008, height: 0.09)
        pivotGeo.radialSegmentCount = 8
        pivotGeo.materials = [FieldMaterials.bearing]
        let pivot = SCNNode(geometry: pivotGeo)
        pivot.eulerAngles.z = Float.pi / 2
        pivot.position = SCNVector3(0, baseY + 0.10, -0.06)
        root.addChildNode(pivot)

        // Main arm tube (pivoting)
        let armGeo = SCNBox(width: 0.020, height: 0.26, length: 0.020, chamferRadius: 0.002)
        armGeo.materials = [FieldMaterials.frameTube]
        let arm = SCNNode(geometry: armGeo)
        arm.name = "pivot_arm"
        arm.pivot = SCNMatrix4MakeTranslation(0, -0.13, 0)
        arm.position = SCNVector3(0, baseY + 0.10, -0.06)
        arm.eulerAngles.z = 0.35  // resting angle
        root.addChildNode(arm)

        // Extension tube (inside main arm, slightly smaller)
        let extGeo = SCNBox(width: 0.014, height: 0.12, length: 0.014, chamferRadius: 0)
        extGeo.materials = [FieldMaterials.metal]
        let ext = SCNNode(geometry: extGeo)
        ext.position = SCNVector3(0, 0.18, 0)
        arm.addChildNode(ext)

        // Wrist joint
        let wristGeo = SCNCylinder(radius: 0.006, height: 0.025)
        wristGeo.radialSegmentCount = 6
        wristGeo.materials = [FieldMaterials.bearing]
        let wrist = SCNNode(geometry: wristGeo)
        wrist.eulerAngles.z = Float.pi / 2
        wrist.position = SCNVector3(0, 0.25, 0)
        arm.addChildNode(wrist)

        // Gripper at end of arm
        let gripGeo = SCNBox(width: 0.06, height: 0.020, length: 0.035, chamferRadius: 0.003)
        let gripMat = SCNMaterial()
        gripMat.diffuse.contents = allianceColor.withAlphaComponent(0.7)
        gripGeo.materials = [gripMat]
        let grip = SCNNode(geometry: gripGeo)
        grip.name = "arm_gripper"
        grip.position = SCNVector3(0, 0.27, 0)
        arm.addChildNode(grip)

        // Gripper jaw plates
        for xOff: Float in [-0.025, 0.025] {
            let jawGeo = SCNBox(width: 0.004, height: 0.015, length: 0.025, chamferRadius: 0)
            jawGeo.materials = [gripMat]
            let jaw = SCNNode(geometry: jawGeo)
            jaw.position = SCNVector3(xOff, 0.28, 0.015)
            arm.addChildNode(jaw)
        }

        // Motor at pivot base
        let motorGeo = SCNCylinder(radius: 0.014, height: 0.022)
        motorGeo.radialSegmentCount = 8
        motorGeo.materials = [FieldMaterials.motorHousing]
        let motor = SCNNode(geometry: motorGeo)
        motor.eulerAngles.z = Float.pi / 2
        motor.position = SCNVector3(0.055, baseY + 0.10, -0.06)
        root.addChildNode(motor)

        // Counterweight at back
        let cwGeo = SCNBox(width: 0.04, height: 0.03, length: 0.04, chamferRadius: 0.003)
        cwGeo.materials = [FieldMaterials.chassis]
        let cw = SCNNode(geometry: cwGeo)
        cw.position = SCNVector3(0, baseY + 0.04, -0.12)
        root.addChildNode(cw)
    }

    // MARK: Shooter (Hood shooter with flywheels)

    private static func addShooter(to root: SCNNode, config: RobotConfig) {
        let baseY: Float = 0.08
        let allianceColor = config.alliance.uiColor

        // Shooter housing frame
        let housingGeo = SCNBox(width: 0.18, height: 0.06, length: 0.12, chamferRadius: 0.005)
        housingGeo.materials = [FieldMaterials.chassis]
        let housing = SCNNode(geometry: housingGeo)
        housing.position = SCNVector3(0, baseY + 0.04, 0.02)
        root.addChildNode(housing)

        // Side plates (polycarbonate guards)
        for xSign: Float in [-1, 1] {
            let sideGeo = SCNBox(width: 0.004, height: 0.08, length: 0.14, chamferRadius: 0)
            sideGeo.materials = [FieldMaterials.polycarbonate]
            let side = SCNNode(geometry: sideGeo)
            side.position = SCNVector3(xSign * 0.08, baseY + 0.05, 0.02)
            root.addChildNode(side)
        }

        // Dual flywheels (the defining feature)
        for xOff: Float in [-0.06, 0.06] {
            let fwGeo = SCNCylinder(radius: 0.035, height: 0.012)
            fwGeo.radialSegmentCount = 12
            fwGeo.materials = [FieldMaterials.flywheel]
            let fw = SCNNode(geometry: fwGeo)
            fw.name = "flywheel"
            fw.eulerAngles.z = Float.pi / 2
            fw.position = SCNVector3(xOff, baseY + 0.09, 0.06)
            root.addChildNode(fw)

            // Motor behind each flywheel
            let motorGeo = SCNCylinder(radius: 0.012, height: 0.020)
            motorGeo.radialSegmentCount = 8
            motorGeo.materials = [FieldMaterials.motorHousing]
            let motor = SCNNode(geometry: motorGeo)
            motor.eulerAngles.z = Float.pi / 2
            motor.position = SCNVector3(xOff > 0 ? xOff + 0.020 : xOff - 0.020, baseY + 0.09, 0.06)
            root.addChildNode(motor)
        }

        // Hood / adjustable backboard
        let hoodGeo = SCNBox(width: 0.14, height: 0.06, length: 0.008, chamferRadius: 0)
        hoodGeo.materials = [FieldMaterials.polycarbonate]
        let hood = SCNNode(geometry: hoodGeo)
        hood.position = SCNVector3(0, baseY + 0.10, -0.02)
        hood.eulerAngles.x = 0.15
        root.addChildNode(hood)

        // Ball channel / feeder ramp
        let rampGeo = SCNBox(width: 0.08, height: 0.005, length: 0.10, chamferRadius: 0)
        let rampMat = SCNMaterial()
        rampMat.diffuse.contents = allianceColor.withAlphaComponent(0.5)
        rampGeo.materials = [rampMat]
        let ramp = SCNNode(geometry: rampGeo)
        ramp.position = SCNVector3(0, baseY + 0.06, 0.06)
        ramp.eulerAngles.x = -0.2
        root.addChildNode(ramp)

        // Turret ring base (allows rotation)
        let turretGeo = SCNTorus(ringRadius: 0.05, pipeRadius: 0.008)
        turretGeo.ringSegmentCount = 16
        turretGeo.pipeSegmentCount = 6
        turretGeo.materials = [FieldMaterials.bearing]
        let turret = SCNNode(geometry: turretGeo)
        turret.position = SCNVector3(0, baseY + 0.01, 0.02)
        root.addChildNode(turret)
    }

    // MARK: Ground Intake (Roller intake with polycarbonate guards)

    private static func addGroundIntake(to root: SCNNode, config: RobotConfig) {
        let baseY: Float = 0.05
        let allianceColor = config.alliance.uiColor

        // Intake deploy arm pivot
        for xOff: Float in [-0.08, 0.08] {
            let armGeo = SCNBox(width: 0.004, height: 0.05, length: 0.08, chamferRadius: 0)
            armGeo.materials = [FieldMaterials.gusset]
            let arm = SCNNode(geometry: armGeo)
            arm.position = SCNVector3(xOff, baseY - 0.01, 0.14)
            arm.eulerAngles.x = -0.15
            root.addChildNode(arm)
        }

        // Main intake roller
        let rollerGeo = SCNCylinder(radius: 0.022, height: 0.18)
        rollerGeo.radialSegmentCount = 10
        rollerGeo.materials = [FieldMaterials.teal]
        let roller = SCNNode(geometry: rollerGeo)
        roller.name = "intake_roller"
        roller.eulerAngles.z = Float.pi / 2
        roller.position = SCNVector3(0, 0.022, 0.18)
        root.addChildNode(roller)

        // Second roller (behind first)
        let roller2Geo = SCNCylinder(radius: 0.018, height: 0.16)
        roller2Geo.radialSegmentCount = 10
        roller2Geo.materials = [FieldMaterials.teal]
        let roller2 = SCNNode(geometry: roller2Geo)
        roller2.eulerAngles.z = Float.pi / 2
        roller2.position = SCNVector3(0, 0.03, 0.14)
        root.addChildNode(roller2)

        // Polycarbonate top guard
        let guardGeo = SCNBox(width: 0.20, height: 0.003, length: 0.10, chamferRadius: 0)
        guardGeo.materials = [FieldMaterials.polycarbonate]
        let guardNode = SCNNode(geometry: guardGeo)
        guardNode.position = SCNVector3(0, 0.06, 0.15)
        guardNode.eulerAngles.x = -0.1
        root.addChildNode(guardNode)

        // Front guard plate (alliance colored)
        let frontGeo = SCNBox(width: 0.20, height: 0.035, length: 0.005, chamferRadius: 0)
        let frontMat = SCNMaterial()
        frontMat.diffuse.contents = allianceColor.withAlphaComponent(0.6)
        frontGeo.materials = [frontMat]
        let frontGuard = SCNNode(geometry: frontGeo)
        frontGuard.position = SCNVector3(0, 0.04, 0.20)
        root.addChildNode(frontGuard)

        // Hopper / storage tray behind intake
        let hopperGeo = SCNBox(width: 0.16, height: 0.005, length: 0.10, chamferRadius: 0)
        let hopMat = SCNMaterial()
        hopMat.diffuse.contents = UIColor(white: 0.25, alpha: 1)
        hopperGeo.materials = [hopMat]
        let hopper = SCNNode(geometry: hopperGeo)
        hopper.position = SCNVector3(0, baseY + 0.02, 0.08)
        hopper.eulerAngles.x = Float.pi / 12
        root.addChildNode(hopper)

        // Side walls of hopper
        for xSign: Float in [-1, 1] {
            let wallGeo = SCNBox(width: 0.004, height: 0.04, length: 0.10, chamferRadius: 0)
            wallGeo.materials = [FieldMaterials.polycarbonate]
            let wall = SCNNode(geometry: wallGeo)
            wall.position = SCNVector3(xSign * 0.08, baseY + 0.03, 0.08)
            root.addChildNode(wall)
        }
    }

    // MARK: Defense Wedge (Low profile push bot)

    private static func addDefenseWedge(to root: SCNNode, config: RobotConfig) {
        let baseY: Float = 0.05
        let allianceColor = config.alliance.uiColor

        // Wedge ramp plate (angled forward)
        let wedgeGeo = SCNBox(width: 0.28, height: 0.004, length: 0.16, chamferRadius: 0)
        let wedgeMat = SCNMaterial()
        wedgeMat.diffuse.contents = UIColor.systemGreen.withAlphaComponent(0.8)
        wedgeMat.metalness.contents = NSNumber(value: 0.3)
        wedgeGeo.materials = [wedgeMat]
        let wedge = SCNNode(geometry: wedgeGeo)
        wedge.position = SCNVector3(0, baseY - 0.01, 0.13)
        wedge.eulerAngles.x = -0.18
        root.addChildNode(wedge)

        // Wedge support ribs (3 ribs under the plate)
        for xOff: Float in [-0.08, 0.0, 0.08] {
            let ribGeo = SCNBox(width: 0.008, height: 0.02, length: 0.14, chamferRadius: 0)
            ribGeo.materials = [FieldMaterials.gusset]
            let rib = SCNNode(geometry: ribGeo)
            rib.position = SCNVector3(xOff, baseY - 0.02, 0.13)
            rib.eulerAngles.x = -0.18
            root.addChildNode(rib)
        }

        // Push face (tall front plate)
        let faceGeo = SCNBox(width: 0.30, height: 0.08, length: 0.008, chamferRadius: 0.003)
        let faceMat = SCNMaterial()
        faceMat.diffuse.contents = allianceColor.withAlphaComponent(0.85)
        faceMat.metalness.contents = NSNumber(value: 0.2)
        faceGeo.materials = [faceMat]
        let face = SCNNode(geometry: faceGeo)
        face.position = SCNVector3(0, baseY + 0.02, 0.20)
        root.addChildNode(face)

        // Reinforcement strips on push face
        for yOff: Float in [-0.015, 0.015] {
            let stripGeo = SCNBox(width: 0.28, height: 0.004, length: 0.010, chamferRadius: 0)
            stripGeo.materials = [FieldMaterials.metal]
            let strip = SCNNode(geometry: stripGeo)
            strip.position = SCNVector3(0, baseY + 0.02 + yOff, 0.205)
            root.addChildNode(strip)
        }

        // Low-profile top plate
        let topGeo = SCNBox(width: 0.26, height: 0.005, length: 0.20, chamferRadius: 0)
        topGeo.materials = [FieldMaterials.chassis]
        let topPlate = SCNNode(geometry: topGeo)
        topPlate.position = SCNVector3(0, baseY + 0.05, 0.03)
        root.addChildNode(topPlate)
    }

    // MARK: - Team Number

    private static func addTeamNumber(to root: SCNNode, config: RobotConfig) {
        let txtGeo = SCNText(string: config.teamNumber, extrusionDepth: 0.005)
        txtGeo.font = UIFont.monospacedSystemFont(ofSize: 0.04, weight: .bold)
        txtGeo.flatness = 0.3
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.white.withAlphaComponent(0.9)
        txtGeo.materials = [mat]
        let txtNode = SCNNode(geometry: txtGeo)
        let (mn, mx) = txtNode.boundingBox
        txtNode.position = SCNVector3(-(mx.x - mn.x) / 2, 0.08, 0.19)
        txtNode.name = "team_number"
        root.addChildNode(txtNode)
    }
}
