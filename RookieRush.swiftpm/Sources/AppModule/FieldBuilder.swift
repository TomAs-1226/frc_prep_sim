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
// MARK: - Robot Builder (DEPRECATED — use RobotModelFactory instead)
// Legacy shim: delegates to RobotModelFactory for backward compat.
// ===================================================================

enum RobotBuilder {
    static func addRobots(to scene: SCNScene, configs: [RobotConfig]) -> [SCNNode] {
        RobotModelFactory.addRobots(to: scene, configs: configs)
    }
    static func buildRobot(config: RobotConfig) -> SCNNode {
        RobotModelFactory.buildRobot(config: config)
    }
}
