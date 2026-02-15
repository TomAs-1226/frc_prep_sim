import SceneKit

// MARK: - Field Builder
// Constructs an FRC Reefscape-inspired competition field from FieldSpec coordinates.
// All geometry is procedural — no imported assets.
// Coherent minimalist art style: dark surface, clean shapes, alliance colors.

enum FieldBuilder {

    // MARK: - Shared Materials (reuse for performance)

    private static let floorMat: SCNMaterial = {
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(red: 0.15, green: 0.16, blue: 0.18, alpha: 1)
        m.roughness.contents = 0.8
        return m
    }()

    private static let wallMat: SCNMaterial = {
        let m = SCNMaterial(); m.diffuse.contents = UIColor(white: 0.55, alpha: 1); return m
    }()

    private static let redAllianceMat: SCNMaterial = {
        let m = SCNMaterial(); m.diffuse.contents = UIColor(red: 0.75, green: 0.15, blue: 0.15, alpha: 0.9); return m
    }()

    private static let blueAllianceMat: SCNMaterial = {
        let m = SCNMaterial(); m.diffuse.contents = UIColor(red: 0.15, green: 0.2, blue: 0.75, alpha: 0.9); return m
    }()

    private static let pipeMat: SCNMaterial = {
        let m = SCNMaterial(); m.diffuse.contents = UIColor(white: 0.60, alpha: 1); return m
    }()

    private static let bargeMat: SCNMaterial = {
        let m = SCNMaterial(); m.diffuse.contents = UIColor(white: 0.40, alpha: 1); return m
    }()

    private static let tagMat: SCNMaterial = {
        let m = SCNMaterial(); m.diffuse.contents = UIColor(white: 0.95, alpha: 1); return m
    }()

    private static let branchL2Mat: SCNMaterial = {
        let m = SCNMaterial(); m.diffuse.contents = UIColor(red: 0.3, green: 0.7, blue: 0.4, alpha: 1); return m
    }()
    private static let branchL3Mat: SCNMaterial = {
        let m = SCNMaterial(); m.diffuse.contents = UIColor(red: 0.7, green: 0.6, blue: 0.2, alpha: 1); return m
    }()
    private static let branchL4Mat: SCNMaterial = {
        let m = SCNMaterial(); m.diffuse.contents = UIColor(red: 0.8, green: 0.3, blue: 0.3, alpha: 1); return m
    }()

    private static let troughMat: SCNMaterial = {
        let m = SCNMaterial(); m.diffuse.contents = UIColor(red: 0.25, green: 0.60, blue: 0.45, alpha: 0.8); return m
    }()

    private static let redReefWallMat: SCNMaterial = {
        let m = SCNMaterial(); m.diffuse.contents = UIColor(red: 0.5, green: 0.12, blue: 0.12, alpha: 0.35); return m
    }()
    private static let blueReefWallMat: SCNMaterial = {
        let m = SCNMaterial(); m.diffuse.contents = UIColor(red: 0.12, green: 0.15, blue: 0.5, alpha: 0.35); return m
    }()

    private static let chainMat: SCNMaterial = {
        let m = SCNMaterial(); m.diffuse.contents = UIColor(white: 0.5, alpha: 0.6); return m
    }()

    private static let coralMat: SCNMaterial = {
        let m = SCNMaterial(); m.diffuse.contents = UIColor(red: 0.95, green: 0.90, blue: 0.85, alpha: 1); return m
    }()
    private static let algaeMat: SCNMaterial = {
        let m = SCNMaterial(); m.diffuse.contents = UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 0.85); return m
    }()

    private static let tagInnerMat: SCNMaterial = {
        let m = SCNMaterial(); m.diffuse.contents = UIColor(white: 0.1, alpha: 1); return m
    }()

    private static let redCarpetMat: SCNMaterial = {
        let m = SCNMaterial(); m.diffuse.contents = UIColor(red: 0.28, green: 0.06, blue: 0.06, alpha: 0.18); return m
    }()
    private static let blueCarpetMat: SCNMaterial = {
        let m = SCNMaterial(); m.diffuse.contents = UIColor(red: 0.06, green: 0.08, blue: 0.28, alpha: 0.18); return m
    }()

    private static let startMarkerMat: SCNMaterial = {
        let m = SCNMaterial(); m.diffuse.contents = UIColor(white: 0.7, alpha: 0.3); return m
    }()

    // Shared low-poly segment count
    private static let lowSeg: Int = 12

    // Shared geometry instances for repeated elements
    private static let sharedPipeGeo: SCNCylinder = {
        let g = SCNCylinder(radius: CGFloat(FieldSpec.reefPipeRadius), height: CGFloat(FieldSpec.reefPipeHeight))
        g.radialSegmentCount = lowSeg; g.materials = [pipeMat]; return g
    }()

    private static let sharedBranchGeo: SCNCylinder = {
        let g = SCNCylinder(radius: CGFloat(FieldSpec.branchRadius), height: CGFloat(FieldSpec.branchLength))
        g.radialSegmentCount = lowSeg; return g
    }()

    private static let sharedAlgaeGeo: SCNSphere = {
        let g = SCNSphere(radius: CGFloat(FieldSpec.algaeRadius))
        g.segmentCount = lowSeg; g.materials = [algaeMat]; return g
    }()

    private static let sharedCoralGeo: SCNCylinder = {
        let g = SCNCylinder(radius: CGFloat(FieldSpec.coralRadius), height: CGFloat(FieldSpec.coralLength))
        g.radialSegmentCount = lowSeg; g.materials = [coralMat]; return g
    }()

    private static let sharedStartMarkerGeo: SCNCylinder = {
        let g = SCNCylinder(radius: 0.08, height: 0.005)
        g.radialSegmentCount = lowSeg; g.materials = [startMarkerMat]; return g
    }()

    // MARK: - Build Scene

    static func buildScene() -> (scene: SCNScene, reefNodes: [SCNNode]) {
        let scene = SCNScene()
        scene.background.contents = UIColor(red: 0.04, green: 0.04, blue: 0.08, alpha: 1)

        let root = scene.rootNode
        addCamera(to: scene)
        addLighting(to: scene)

        // Floor
        let floor = SCNBox(width: CGFloat(FieldSpec.fieldLength + 0.4), height: 0.04,
                           length: CGFloat(FieldSpec.fieldWidth + 0.4), chamferRadius: 0)
        floor.materials = [floorMat]
        let floorNode = SCNNode(geometry: floor)
        floorNode.position = SCNVector3(0, -0.02, 0)
        root.addChildNode(floorNode)

        // Alliance carpet color zones (red +X half, blue -X half)
        addCarpetZones(to: root)

        // Field lines and border tape
        addFieldLines(to: root)

        // Perimeter walls
        addPerimeterWalls(to: root)

        // Alliance walls
        addAllianceWalls(to: root)

        // Reef structures (hexagonal)
        var reefNodes: [SCNNode] = []
        reefNodes += buildReef(center: FieldSpec.redReefCenter, alliance: .red, to: root)
        reefNodes += buildReef(center: FieldSpec.blueReefCenter, alliance: .blue, to: root)

        // Barge (center truss)
        buildBarge(to: root)

        // Coral stations (4 corners)
        buildCoralStation(pos: FieldSpec.redCoralNear, alliance: .red, to: root)
        buildCoralStation(pos: FieldSpec.redCoralFar, alliance: .red, to: root)
        buildCoralStation(pos: FieldSpec.blueCoralNear, alliance: .blue, to: root)
        buildCoralStation(pos: FieldSpec.blueCoralFar, alliance: .blue, to: root)

        // Processors
        buildProcessor(pos: FieldSpec.redProcessor, alliance: .red, onFarWall: true, to: root)
        buildProcessor(pos: FieldSpec.blueProcessor, alliance: .blue, onFarWall: false, to: root)

        // AprilTags
        addAprilTags(to: root)

        // Starting lines + position markers
        addStartingLines(to: root)
        addStartingMarkers(to: root)

        // Pre-staged game pieces (coral on marks + algae ON reef faces)
        addPreStagedPieces(to: root)

        return (scene, reefNodes)
    }

    // MARK: - Camera

    private static func addCamera(to scene: SCNScene) {
        let cam = SCNCamera()
        cam.fieldOfView = 50
        cam.zNear = 0.05
        cam.zFar = 80
        let node = SCNNode()
        node.camera = cam
        node.position = SCNVector3(0, 7.5, 6.0)
        node.eulerAngles.x = -Float.pi / 3
        scene.rootNode.addChildNode(node)
    }

    // MARK: - Lighting

    private static func addLighting(to scene: SCNScene) {
        let amb = SCNNode(); amb.light = SCNLight()
        amb.light?.type = .ambient; amb.light?.intensity = 500
        amb.light?.color = UIColor(white: 0.40, alpha: 1)
        scene.rootNode.addChildNode(amb)

        let dir = SCNNode(); dir.light = SCNLight()
        dir.light?.type = .directional; dir.light?.intensity = 900
        dir.light?.castsShadow = true; dir.light?.shadowRadius = 3
        dir.light?.shadowMapSize = CGSize(width: 2048, height: 2048)
        dir.position = SCNVector3(3, 12, 5)
        dir.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 8, 0)
        scene.rootNode.addChildNode(dir)

        let fill = SCNNode(); fill.light = SCNLight()
        fill.light?.type = .directional; fill.light?.intensity = 300
        fill.position = SCNVector3(-3, 8, -4)
        fill.eulerAngles = SCNVector3(-Float.pi / 4, -Float.pi / 6, 0)
        scene.rootNode.addChildNode(fill)
    }

    // MARK: - Carpet Zones

    private static func addCarpetZones(to root: SCNNode) {
        let hL = FieldSpec.halfLength
        let fW = FieldSpec.fieldWidth

        // Red carpet (+X half)
        let redZone = SCNBox(width: CGFloat(hL), height: 0.003, length: CGFloat(fW), chamferRadius: 0)
        redZone.materials = [redCarpetMat]
        let rn = SCNNode(geometry: redZone)
        rn.position = SCNVector3(hL / 2, 0.001, 0)
        root.addChildNode(rn)

        // Blue carpet (-X half)
        let blueZone = SCNBox(width: CGFloat(hL), height: 0.003, length: CGFloat(fW), chamferRadius: 0)
        blueZone.materials = [blueCarpetMat]
        let bn = SCNNode(geometry: blueZone)
        bn.position = SCNVector3(-hL / 2, 0.001, 0)
        root.addChildNode(bn)
    }

    // MARK: - Field Lines

    private static func addFieldLines(to root: SCNNode) {
        let hL = FieldSpec.halfLength
        let hW = FieldSpec.halfWidth

        // Center line
        addLine(from: SIMD2(0, -hW), to: SIMD2(0, hW), color: .white, alpha: 0.15, to: root)

        // Alliance area boundaries
        for sign: Float in [-1, 1] {
            let x = sign * (hL - 1.0)
            addLine(from: SIMD2(x, -hW), to: SIMD2(x, hW), color: .white, alpha: 0.08, to: root)
        }

        // Field border tape (perimeter outline on floor)
        let corners: [SIMD2<Float>] = [
            SIMD2(-hL, -hW), SIMD2(hL, -hW), SIMD2(hL, hW), SIMD2(-hL, hW)
        ]
        for i in 0..<4 {
            addLine(from: corners[i], to: corners[(i + 1) % 4],
                    color: .white, alpha: 0.25, to: root)
        }
    }

    private static func addLine(from a: SIMD2<Float>, to b: SIMD2<Float>,
                                 color: UIColor, alpha: Float, to root: SCNNode) {
        let dx = b.x - a.x, dz = b.y - a.y
        let len = sqrt(dx * dx + dz * dz)
        let line = SCNBox(width: CGFloat(len), height: 0.005, length: 0.015, chamferRadius: 0)
        let m = SCNMaterial(); m.diffuse.contents = color.withAlphaComponent(CGFloat(alpha))
        line.materials = [m]
        let node = SCNNode(geometry: line)
        node.position = SCNVector3((a.x + b.x) / 2, 0.003, (a.y + b.y) / 2)
        node.eulerAngles.y = atan2(dx, dz)
        root.addChildNode(node)
    }

    // MARK: - Perimeter Walls

    private static func addPerimeterWalls(to root: SCNNode) {
        let hL = FieldSpec.halfLength, hW = FieldSpec.halfWidth
        let wH = FieldSpec.perimeterWallHeight, wT = FieldSpec.wallThickness

        for zSign: Float in [-1, 1] {
            let wall = SCNBox(width: CGFloat(hL * 2), height: CGFloat(wH), length: CGFloat(wT), chamferRadius: 0)
            wall.materials = [wallMat]
            let n = SCNNode(geometry: wall)
            n.position = SCNVector3(0, wH / 2, zSign * hW)
            root.addChildNode(n)
        }
    }

    // MARK: - Alliance Walls

    private static func addAllianceWalls(to root: SCNNode) {
        let hL = FieldSpec.halfLength, hW = FieldSpec.halfWidth
        let aH = FieldSpec.allianceWallHeight, wT = FieldSpec.wallThickness

        let rWall = SCNBox(width: CGFloat(wT), height: CGFloat(aH), length: CGFloat(hW * 2), chamferRadius: 0)
        rWall.materials = [redAllianceMat]
        let rn = SCNNode(geometry: rWall)
        rn.position = SCNVector3(hL, aH / 2, 0)
        root.addChildNode(rn)

        let bWall = SCNBox(width: CGFloat(wT), height: CGFloat(aH), length: CGFloat(hW * 2), chamferRadius: 0)
        bWall.materials = [blueAllianceMat]
        let bn = SCNNode(geometry: bWall)
        bn.position = SCNVector3(-hL, aH / 2, 0)
        root.addChildNode(bn)
    }

    // MARK: - Reef (Hexagonal Structure)

    private static func buildReef(center: SIMD2<Float>, alliance: Alliance, to root: SCNNode) -> [SCNNode] {
        var scoringNodes: [SCNNode] = []
        let vertices = FieldSpec.reefVertices(center: center)
        let faces = FieldSpec.reefFaces(center: center)
        let pipeH = FieldSpec.reefPipeHeight
        let reefWallMat = alliance == .red ? redReefWallMat : blueReefWallMat

        // Hex walls (6 faces)
        for i in 0..<6 {
            let v1 = vertices[i]
            let v2 = vertices[(i + 1) % 6]
            let dx = v2.x - v1.x, dz = v2.y - v1.y
            let edgeLen = sqrt(dx * dx + dz * dz)
            let angle = atan2(dx, dz)

            let wallGeo = SCNBox(width: CGFloat(edgeLen), height: CGFloat(pipeH * 0.15),
                                  length: 0.01, chamferRadius: 0)
            wallGeo.materials = [reefWallMat]
            let wallNode = SCNNode(geometry: wallGeo)
            wallNode.position = SCNVector3((v1.x + v2.x) / 2, pipeH * 0.075, (v1.y + v2.y) / 2)
            wallNode.eulerAngles.y = angle
            root.addChildNode(wallNode)

            // L1 trough
            let face = faces[i]
            let troughGeo = SCNBox(width: CGFloat(edgeLen * 0.7), height: 0.025,
                                    length: CGFloat(FieldSpec.troughDepth), chamferRadius: 0.005)
            troughGeo.materials = [troughMat]
            let troughNode = SCNNode(geometry: troughGeo)
            let outward: Float = 0.03
            troughNode.position = SCNVector3(
                face.center.x + cos(face.angle) * outward,
                FieldSpec.troughL1,
                face.center.y + sin(face.angle) * outward
            )
            troughNode.eulerAngles.y = angle
            troughNode.name = "reef_l1_\(i)"
            root.addChildNode(troughNode)
            scoringNodes.append(troughNode)
        }

        // Scoring pipes (12 per reef) + branches at L2/L3/L4
        let branchMats: [Int: SCNMaterial] = [2: branchL2Mat, 3: branchL3Mat, 4: branchL4Mat]
        let pipes = FieldSpec.reefPipes(center: center)

        for (pIdx, pipe) in pipes.enumerated() {
            let pipeNode = SCNNode(geometry: sharedPipeGeo)
            pipeNode.position = SCNVector3(pipe.position.x, pipeH / 2, pipe.position.y)
            root.addChildNode(pipeNode)

            for (level, height) in [(2, FieldSpec.branchL2), (3, FieldSpec.branchL3), (4, FieldSpec.branchL4)] {
                let brGeo = sharedBranchGeo.copy() as! SCNCylinder
                if let mat = branchMats[level] { brGeo.materials = [mat] }
                let brNode = SCNNode(geometry: brGeo)
                let outX = cos(pipe.faceAngle) * FieldSpec.branchLength / 2
                let outZ = sin(pipe.faceAngle) * FieldSpec.branchLength / 2
                brNode.position = SCNVector3(pipe.position.x + outX, height, pipe.position.y + outZ)
                brNode.eulerAngles.z = -Float.pi / 2
                brNode.eulerAngles.y = pipe.faceAngle
                brNode.name = "reef_l\(level)_\(pIdx)"
                root.addChildNode(brNode)
                scoringNodes.append(brNode)
            }
        }

        // Algae ON reef faces (between L3 and L4)
        for faceIdx in FieldSpec.algaeOnReefFaces {
            let face = faces[faceIdx]
            let dist = FieldSpec.reefApothem + 0.025
            let algaeNode = SCNNode(geometry: sharedAlgaeGeo)
            algaeNode.position = SCNVector3(
                center.x + cos(face.angle) * dist,
                FieldSpec.algaeReefHeight,
                center.y + sin(face.angle) * dist
            )
            algaeNode.name = "reef_algae_\(faceIdx)"
            root.addChildNode(algaeNode)
        }

        // Reef zone indicator ring
        let zoneGeo = SCNTorus(ringRadius: CGFloat(FieldSpec.reefApothem + 0.15), pipeRadius: 0.008)
        zoneGeo.ringSegmentCount = 24; zoneGeo.pipeSegmentCount = 8
        let zoneMat = SCNMaterial()
        zoneMat.diffuse.contents = (alliance == .red)
            ? UIColor.red.withAlphaComponent(0.2)
            : UIColor.blue.withAlphaComponent(0.2)
        zoneGeo.materials = [zoneMat]
        let zoneNode = SCNNode(geometry: zoneGeo)
        zoneNode.position = SCNVector3(center.x, 0.005, center.y)
        root.addChildNode(zoneNode)

        // Label
        addText(alliance == .red ? "RED TOWER" : "BLUE TOWER",
                at: SCNVector3(center.x, 0.02, center.y + FieldSpec.reefApothem + 0.25),
                color: alliance == .red ? .red : UIColor(red: 0.3, green: 0.4, blue: 1.0, alpha: 1),
                size: 0.06, to: root)

        return scoringNodes
    }

    // MARK: - Barge (Center Truss Structure)

    private static func buildBarge(to root: SCNNode) {
        let span = FieldSpec.bargeTrussSpan
        let depth = FieldSpec.bargeTrussDepth
        let height = FieldSpec.bargeTrussHeight
        let legW = FieldSpec.bargeLegWidth

        // 4 legs
        let legGeo = SCNBox(width: CGFloat(legW), height: CGFloat(height), length: CGFloat(legW), chamferRadius: 0)
        legGeo.materials = [bargeMat]
        for xSign: Float in [-1, 1] {
            for zSign: Float in [-1, 1] {
                let n = SCNNode(geometry: legGeo)
                n.position = SCNVector3(xSign * depth / 2, height / 2, zSign * (span / 2 - 0.1))
                root.addChildNode(n)
            }
        }

        // Top beam
        let beam = SCNBox(width: CGFloat(depth), height: CGFloat(legW), length: CGFloat(span), chamferRadius: 0)
        beam.materials = [bargeMat]
        let beamNode = SCNNode(geometry: beam)
        beamNode.position = SCNVector3(0, height, 0)
        root.addChildNode(beamNode)

        // Cross braces (shared geometry)
        let brace = SCNBox(width: CGFloat(depth - legW), height: 0.015, length: 0.015, chamferRadius: 0)
        brace.materials = [bargeMat]
        for z: Float in stride(from: -span / 2 + 0.5, through: span / 2 - 0.5, by: 0.8) {
            let bn = SCNNode(geometry: brace)
            bn.position = SCNVector3(0, height * 0.7, z)
            root.addChildNode(bn)
        }

        // Cages (shared geometry)
        let cageMat = SCNMaterial()
        cageMat.diffuse.contents = UIColor(red: 0.6, green: 0.55, blue: 0.1, alpha: 0.8)
        let cageGeo = SCNBox(width: CGFloat(FieldSpec.cageWidth), height: CGFloat(FieldSpec.cageHeight),
                              length: 0.08, chamferRadius: 0.005)
        cageGeo.materials = [cageMat]

        for i in 0..<3 {
            let zOff = Float(i - 1) * 0.7
            for xSign: Float in [-1, 1] {
                let cn = SCNNode(geometry: cageGeo)
                let cageY = (i == 1) ? FieldSpec.shallowCageY : FieldSpec.deepCageY
                cn.position = SCNVector3(xSign * 0.15, cageY + FieldSpec.cageHeight / 2, zOff)
                root.addChildNode(cn)

                let chainLen = height - cageY - FieldSpec.cageHeight
                if chainLen > 0 {
                    let chain = SCNCylinder(radius: 0.004, height: CGFloat(chainLen))
                    chain.radialSegmentCount = 6; chain.materials = [chainMat]
                    let chNode = SCNNode(geometry: chain)
                    chNode.position = SCNVector3(xSign * 0.15,
                                                  cageY + FieldSpec.cageHeight + chainLen / 2, zOff)
                    root.addChildNode(chNode)
                }
            }
        }

        // Net
        let netGeo = SCNBox(width: CGFloat(FieldSpec.netWidth), height: 0.005,
                             length: CGFloat(FieldSpec.netLength), chamferRadius: 0)
        let netMat = SCNMaterial()
        netMat.diffuse.contents = UIColor(white: 0.8, alpha: 0.15); netMat.isDoubleSided = true
        netGeo.materials = [netMat]
        let netNode = SCNNode(geometry: netGeo)
        netNode.position = SCNVector3(0, FieldSpec.netHeight, 0)
        root.addChildNode(netNode)

        // Barge zone markings
        let zoneGeo = SCNBox(width: CGFloat(FieldSpec.bargeZoneDepth), height: 0.008,
                              length: CGFloat(FieldSpec.bargeZoneHalfLength * 2), chamferRadius: 0)
        for xSign: Float in [-1, 1] {
            let zoneColor = xSign > 0
                ? UIColor.red.withAlphaComponent(0.12)
                : UIColor.blue.withAlphaComponent(0.12)
            let zm = SCNMaterial(); zm.diffuse.contents = zoneColor
            let zoneCopy = zoneGeo.copy() as! SCNBox; zoneCopy.materials = [zm]
            let zn = SCNNode(geometry: zoneCopy)
            zn.position = SCNVector3(xSign * (depth / 2 + FieldSpec.bargeZoneDepth / 2), 0.004, 0)
            root.addChildNode(zn)
        }

        addText("SKYBRIDGE", at: SCNVector3(0, 0.02, span / 2 + 0.15),
                color: UIColor.white.withAlphaComponent(0.4), size: 0.08, to: root)
    }

    // MARK: - Coral Stations (correct 55-degree chute angle)

    private static func buildCoralStation(pos: SIMD2<Float>, alliance: Alliance, to root: SCNNode) {
        let color = alliance.uiColor.withAlphaComponent(0.25)
        let w = FieldSpec.coralStationWidth
        let d = FieldSpec.coralStationDepth

        // Floor zone
        let zone = SCNBox(width: CGFloat(w), height: 0.008, length: CGFloat(d), chamferRadius: 0)
        let zm = SCNMaterial(); zm.diffuse.contents = color; zone.materials = [zm]
        let zn = SCNNode(geometry: zone)
        zn.position = SCNVector3(pos.x, 0.004, pos.y)
        root.addChildNode(zn)

        // Chute structure at correct 55-degree angle
        let chute = SCNBox(width: CGFloat(w * 0.6), height: 0.04, length: 0.15, chamferRadius: 0.005)
        let cm = SCNMaterial(); cm.diffuse.contents = alliance.uiColor.withAlphaComponent(0.6)
        chute.materials = [cm]
        let cn = SCNNode(geometry: chute)
        let wallX = alliance == .red ? FieldSpec.halfLength : -FieldSpec.halfLength
        cn.position = SCNVector3(wallX, FieldSpec.coralChuteHeight, pos.y)
        cn.eulerAngles.z = alliance == .red ? -FieldSpec.coralChuteAngle : FieldSpec.coralChuteAngle
        root.addChildNode(cn)

        // Chute support wall (back plate against alliance wall)
        let support = SCNBox(width: 0.02, height: 0.30, length: CGFloat(w * 0.7), chamferRadius: 0)
        let sm = SCNMaterial(); sm.diffuse.contents = alliance.uiColor.withAlphaComponent(0.3)
        support.materials = [sm]
        let sn = SCNNode(geometry: support)
        sn.position = SCNVector3(wallX, 0.15, pos.y)
        root.addChildNode(sn)

        // Decorative coral near station
        for i in 0..<2 {
            let coral = SCNNode(geometry: sharedCoralGeo)
            let offset: Float = Float(i) * 0.12 - 0.06
            let approachX = alliance == .red ? pos.x - 0.3 : pos.x + 0.3
            coral.position = SCNVector3(approachX, 0.04, pos.y + offset)
            root.addChildNode(coral)
        }
    }

    // MARK: - Processors

    private static func buildProcessor(pos: SIMD2<Float>, alliance: Alliance,
                                        onFarWall: Bool, to root: SCNNode) {
        let w = FieldSpec.processorWidth
        let d = FieldSpec.processorDepth

        let zone = SCNBox(width: CGFloat(w), height: 0.008, length: CGFloat(d), chamferRadius: 0)
        let zm = SCNMaterial(); zm.diffuse.contents = alliance.uiColor.withAlphaComponent(0.20)
        zone.materials = [zm]
        let zn = SCNNode(geometry: zone)
        zn.position = SCNVector3(pos.x, 0.004, pos.y)
        root.addChildNode(zn)

        let proc = SCNBox(width: CGFloat(w * 0.8), height: 0.20, length: 0.12, chamferRadius: 0.01)
        let pm = SCNMaterial(); pm.diffuse.contents = alliance.uiColor.withAlphaComponent(0.5)
        proc.materials = [pm]
        let pn = SCNNode(geometry: proc)
        let wallZ = onFarWall ? FieldSpec.halfWidth : -FieldSpec.halfWidth
        pn.position = SCNVector3(pos.x, 0.10, wallZ)
        root.addChildNode(pn)

        addText("RECYCLER", at: SCNVector3(pos.x, 0.015, pos.y + (onFarWall ? -0.15 : 0.15)),
                color: alliance.uiColor.withAlphaComponent(0.5), size: 0.04, to: root)
    }

    // MARK: - AprilTags

    private static func addAprilTags(to root: SCNNode) {
        let size = FieldSpec.aprilTagSize

        for tag in FieldSpec.aprilTags {
            let tagNode = SCNNode()

            let border = SCNBox(width: CGFloat(size), height: CGFloat(size), length: 0.003, chamferRadius: 0)
            border.materials = [tagMat]
            tagNode.addChildNode(SCNNode(geometry: border))

            let inner = SCNBox(width: CGFloat(size * 0.75), height: CGFloat(size * 0.75), length: 0.004, chamferRadius: 0)
            inner.materials = [tagInnerMat]
            let innerNode = SCNNode(geometry: inner)
            innerNode.position.z = 0.001
            tagNode.addChildNode(innerNode)

            let idText = SCNText(string: "\(tag.id)", extrusionDepth: 0.002)
            idText.font = UIFont.monospacedDigitSystemFont(ofSize: CGFloat(size * 0.25), weight: .bold)
            idText.flatness = 0.5
            let idMat = SCNMaterial(); idMat.diffuse.contents = UIColor.white
            idText.materials = [idMat]
            let idNode = SCNNode(geometry: idText)
            let (mn, mx) = idNode.boundingBox
            idNode.pivot = SCNMatrix4MakeTranslation((mx.x - mn.x) / 2 + mn.x, (mx.y - mn.y) / 2 + mn.y, 0)
            idNode.position = SCNVector3(0, 0, 0.003)
            tagNode.addChildNode(idNode)

            tagNode.position = SCNVector3(tag.position.x, tag.position.y, tag.position.z)
            tagNode.eulerAngles.y = tag.yaw
            tagNode.name = "apriltag_\(tag.id)"
            root.addChildNode(tagNode)
        }
    }

    // MARK: - Starting Lines

    private static func addStartingLines(to root: SCNNode) {
        let hW = FieldSpec.halfWidth
        addLine(from: SIMD2(FieldSpec.redAutoLine, -hW + 0.1),
                to: SIMD2(FieldSpec.redAutoLine, hW - 0.1),
                color: .red, alpha: 0.35, to: root)
        addLine(from: SIMD2(FieldSpec.blueAutoLine, -hW + 0.1),
                to: SIMD2(FieldSpec.blueAutoLine, hW - 0.1),
                color: UIColor(red: 0.3, green: 0.4, blue: 1, alpha: 1), alpha: 0.35, to: root)
    }

    // MARK: - Starting Position Markers

    private static func addStartingMarkers(to root: SCNNode) {
        for (starts, alliance) in [(FieldSpec.redStarts, Alliance.red), (FieldSpec.blueStarts, Alliance.blue)] {
            for (i, pos) in starts.enumerated() {
                let marker = SCNNode(geometry: sharedStartMarkerGeo)
                marker.position = SCNVector3(pos.x, 0.003, pos.y)
                root.addChildNode(marker)

                // Small number label
                addText("\(i + 1)", at: SCNVector3(pos.x, 0.008, pos.y + 0.10),
                        color: alliance.uiColor.withAlphaComponent(0.4), size: 0.04, to: root)
            }
        }
    }

    // MARK: - Pre-Staged Game Pieces

    private static func addPreStagedPieces(to root: SCNNode) {
        // 6 coral on marks near each reef
        for center in [FieldSpec.redReefCenter, FieldSpec.blueReefCenter] {
            let faces = FieldSpec.reefFaces(center: center)
            for (i, face) in faces.enumerated() {
                let dist = FieldSpec.reefApothem + 0.30
                let cx = center.x + cos(face.angle) * dist
                let cz = center.y + sin(face.angle) * dist
                let coral = SCNNode(geometry: sharedCoralGeo)
                coral.position = SCNVector3(cx, 0.035, cz)
                coral.eulerAngles.x = Float.pi / 2
                coral.name = "prestaged_coral_\(i)"
                root.addChildNode(coral)
            }
        }
    }

    // MARK: - Game Piece Geometry (public for external use)

    static func makeCoral() -> SCNNode {
        SCNNode(geometry: sharedCoralGeo)
    }

    static func makeAlgae() -> SCNNode {
        SCNNode(geometry: sharedAlgaeGeo)
    }

    /// Spawn a ring (coral) projectile node for the scoring physics system.
    static func makeRingProjectile() -> SCNNode {
        let node = SCNNode(geometry: sharedCoralGeo)
        node.eulerAngles.x = Float.pi / 2  // Lie on side for flight
        node.name = "ring_projectile"
        return node
    }

    // MARK: - Text Helper

    private static func addText(_ text: String, at pos: SCNVector3, color: UIColor,
                                 size: CGFloat, to root: SCNNode) {
        let geo = SCNText(string: text, extrusionDepth: 0.005)
        geo.font = UIFont.systemFont(ofSize: size, weight: .bold); geo.flatness = 0.4
        let mat = SCNMaterial(); mat.diffuse.contents = color; geo.materials = [mat]
        let node = SCNNode(geometry: geo)
        let (mn, mx) = node.boundingBox
        node.pivot = SCNMatrix4MakeTranslation((mx.x - mn.x) / 2 + mn.x, 0, 0)
        node.position = pos; node.eulerAngles.x = -Float.pi / 2
        root.addChildNode(node)
    }
}

// MARK: - Robot Builder

enum RobotBuilder {

    // Shared wheel geometry
    private static let swerveWheelGeo: SCNCylinder = {
        let g = SCNCylinder(radius: 0.035, height: 0.025); g.radialSegmentCount = 12
        let m = SCNMaterial(); m.diffuse.contents = UIColor.darkGray; g.materials = [m]; return g
    }()
    private static let swerveHousingGeo: SCNCylinder = {
        let g = SCNCylinder(radius: 0.025, height: 0.02); g.radialSegmentCount = 12
        let m = SCNMaterial(); m.diffuse.contents = UIColor(white: 0.3, alpha: 1); g.materials = [m]; return g
    }()
    private static let tankWheelGeo: SCNCylinder = {
        let g = SCNCylinder(radius: 0.04, height: 0.02); g.radialSegmentCount = 12
        let m = SCNMaterial(); m.diffuse.contents = UIColor.darkGray; g.materials = [m]; return g
    }()

    static func buildRobot(config: RobotConfig) -> SCNNode {
        let root = SCNNode()
        root.name = "robot_\(config.id)"
        let allianceColor = config.alliance.uiColor

        let cW: CGFloat = 0.32, cH: CGFloat = 0.08, cL: CGFloat = 0.32

        // Chassis
        let chassisGeo = SCNBox(width: cW, height: cH, length: cL, chamferRadius: 0.01)
        let chassisMat = SCNMaterial()
        chassisMat.diffuse.contents = UIColor(white: 0.22, alpha: 1)
        chassisMat.metalness.contents = 0.4
        chassisGeo.materials = [chassisMat]
        let chassis = SCNNode(geometry: chassisGeo)
        chassis.position = SCNVector3(0, Float(cH / 2), 0)
        root.addChildNode(chassis)

        // Bumpers
        let bGeo = SCNBox(width: cW + 0.05, height: cH * 0.5, length: cL + 0.05, chamferRadius: 0.008)
        let bMat = SCNMaterial()
        bMat.diffuse.contents = allianceColor.withAlphaComponent(0.85)
        bGeo.materials = [bMat]
        let bumpers = SCNNode(geometry: bGeo)
        bumpers.position = SCNVector3(0, Float(cH * 0.25), 0)
        root.addChildNode(bumpers)

        // Wheels
        if config.build.drivetrain == .swerve {
            addSwerveWheels(to: root, cW: cW, cL: cL)
        } else {
            addTankWheels(to: root, cW: cW, cL: cL)
        }

        // Superstructure
        let baseY = Float(cH)
        switch config.superstructure {
        case .elevator: addElevator(to: root, baseY: baseY, color: allianceColor)
        case .arm:      addPivotArm(to: root, baseY: baseY, color: allianceColor)
        case .intake:   addLowIntake(to: root, baseY: baseY, cL: Float(cL), color: allianceColor)
        case .wedge:    addWedge(to: root, baseY: baseY, cW: Float(cW), cL: Float(cL), color: allianceColor)
        }

        // Team number plate
        let label = SCNText(string: config.teamNumber, extrusionDepth: 0.002)
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 0.035, weight: .bold)
        label.flatness = 0.5
        let lMat = SCNMaterial(); lMat.diffuse.contents = UIColor.white
        label.materials = [lMat]
        let labelNode = SCNNode(geometry: label)
        let (mn, mx) = labelNode.boundingBox
        labelNode.pivot = SCNMatrix4MakeTranslation((mx.x - mn.x) / 2 + mn.x, 0, 0)
        labelNode.position = SCNVector3(0, Float(cH * 0.6), Float(cL / 2) + 0.005)
        root.addChildNode(labelNode)

        return root
    }

    // MARK: - Drivetrain Visuals

    private static func addSwerveWheels(to root: SCNNode, cW: CGFloat, cL: CGFloat) {
        let positions: [(CGFloat, CGFloat)] = [
            (-cW/2 + 0.03, -cL/2 + 0.04), (cW/2 - 0.03, -cL/2 + 0.04),
            (-cW/2 + 0.03, cL/2 - 0.04), (cW/2 - 0.03, cL/2 - 0.04)
        ]
        for (i, (ox, oz)) in positions.enumerated() {
            let hn = SCNNode(geometry: swerveHousingGeo)
            hn.position = SCNVector3(Float(ox), 0.01, Float(oz))
            root.addChildNode(hn)

            let wn = SCNNode(geometry: swerveWheelGeo)
            wn.eulerAngles.z = .pi / 2
            wn.position = SCNVector3(Float(ox), 0.035, Float(oz))
            wn.name = "wheel_\(i)"
            root.addChildNode(wn)
        }
    }

    private static func addTankWheels(to root: SCNNode, cW: CGFloat, cL: CGFloat) {
        var idx = 0
        for side: CGFloat in [-1, 1] {
            for zOff: CGFloat in [-cL/2 + 0.05, 0, cL/2 - 0.05] {
                let wn = SCNNode(geometry: tankWheelGeo)
                wn.eulerAngles.z = .pi / 2
                wn.position = SCNVector3(Float(side * (cW/2 - 0.01)), 0.04, Float(zOff))
                wn.name = "wheel_\(idx)"
                root.addChildNode(wn)
                idx += 1
            }
        }
    }

    // MARK: - Superstructures

    private static func addElevator(to root: SCNNode, baseY: Float, color: UIColor) {
        let railColor = UIColor(white: 0.45, alpha: 1)

        for dx: Float in [-0.06, 0.06] {
            let rail = SCNBox(width: 0.018, height: 0.38, length: 0.018, chamferRadius: 0)
            let rm = SCNMaterial(); rm.diffuse.contents = railColor; rail.materials = [rm]
            let rn = SCNNode(geometry: rail)
            rn.position = SCNVector3(dx, baseY + 0.19, -0.04)
            root.addChildNode(rn)
        }

        let innerStage = SCNNode(); innerStage.name = "elevator_stage"
        for dx: Float in [-0.04, 0.04] {
            let inner = SCNBox(width: 0.012, height: 0.30, length: 0.012, chamferRadius: 0)
            let im = SCNMaterial(); im.diffuse.contents = UIColor(white: 0.55, alpha: 1); inner.materials = [im]
            let iNode = SCNNode(geometry: inner)
            iNode.position = SCNVector3(dx, 0.15, 0)
            innerStage.addChildNode(iNode)
        }
        innerStage.position = SCNVector3(0, baseY + 0.08, -0.04)
        root.addChildNode(innerStage)

        let claw = SCNBox(width: 0.10, height: 0.025, length: 0.06, chamferRadius: 0.005)
        let clawMat = SCNMaterial(); clawMat.diffuse.contents = color.withAlphaComponent(0.7)
        claw.materials = [clawMat]
        let clawNode = SCNNode(geometry: claw)
        clawNode.position = SCNVector3(0, 0.30, 0.02)
        innerStage.addChildNode(clawNode)

        let brace = SCNBox(width: 0.12, height: 0.01, length: 0.01, chamferRadius: 0)
        let brMat = SCNMaterial(); brMat.diffuse.contents = railColor; brace.materials = [brMat]
        let brNode = SCNNode(geometry: brace)
        brNode.position = SCNVector3(0, baseY + 0.37, -0.04)
        root.addChildNode(brNode)
    }

    private static func addPivotArm(to root: SCNNode, baseY: Float, color: UIColor) {
        let pivotY = baseY + 0.04
        let armLen: Float = 0.28
        let arm = SCNCylinder(radius: 0.012, height: CGFloat(armLen)); arm.radialSegmentCount = 8
        let aMat = SCNMaterial(); aMat.diffuse.contents = UIColor.systemOrange; arm.materials = [aMat]
        let armNode = SCNNode(geometry: arm)
        armNode.position = SCNVector3(0, pivotY + armLen * 0.4, 0.02)
        armNode.eulerAngles.x = 0.35; armNode.name = "pivot_arm"
        root.addChildNode(armNode)

        let grip = SCNBox(width: 0.08, height: 0.02, length: 0.05, chamferRadius: 0.005)
        let gMat = SCNMaterial(); gMat.diffuse.contents = color.withAlphaComponent(0.7)
        grip.materials = [gMat]
        let gripNode = SCNNode(geometry: grip)
        gripNode.position = SCNVector3(0, pivotY + armLen * 0.7, 0.10)
        root.addChildNode(gripNode)

        let base = SCNCylinder(radius: 0.025, height: 0.03); base.radialSegmentCount = 12
        let bMat = SCNMaterial(); bMat.diffuse.contents = UIColor(white: 0.35, alpha: 1)
        base.materials = [bMat]
        let bn = SCNNode(geometry: base)
        bn.position = SCNVector3(0, pivotY, -0.06)
        root.addChildNode(bn)
    }

    private static func addLowIntake(to root: SCNNode, baseY: Float, cL: Float, color: UIColor) {
        let roller = SCNCylinder(radius: 0.028, height: 0.22); roller.radialSegmentCount = 12
        let rMat = SCNMaterial(); rMat.diffuse.contents = UIColor.systemTeal; roller.materials = [rMat]
        let rn = SCNNode(geometry: roller)
        rn.eulerAngles.z = .pi / 2
        rn.position = SCNVector3(0, baseY + 0.028, cL / 2 + 0.02)
        rn.name = "intake_roller"
        root.addChildNode(rn)

        let guard_ = SCNBox(width: 0.24, height: 0.04, length: 0.06, chamferRadius: 0)
        let gMat = SCNMaterial(); gMat.diffuse.contents = color.withAlphaComponent(0.4)
        guard_.materials = [gMat]
        let gn = SCNNode(geometry: guard_)
        gn.position = SCNVector3(0, baseY + 0.06, cL / 2 + 0.01)
        root.addChildNode(gn)

        let hopper = SCNBox(width: 0.14, height: 0.03, length: 0.10, chamferRadius: 0.005)
        let hMat = SCNMaterial(); hMat.diffuse.contents = UIColor(white: 0.3, alpha: 1)
        hopper.materials = [hMat]
        let hn = SCNNode(geometry: hopper)
        hn.position = SCNVector3(0, baseY + 0.015, 0)
        root.addChildNode(hn)
    }

    private static func addWedge(to root: SCNNode, baseY: Float, cW: Float, cL: Float, color: UIColor) {
        let wedge = SCNBox(width: CGFloat(cW + 0.02), height: 0.04, length: 0.18, chamferRadius: 0.005)
        let wMat = SCNMaterial(); wMat.diffuse.contents = UIColor.systemGreen; wedge.materials = [wMat]
        let wn = SCNNode(geometry: wedge)
        wn.position = SCNVector3(0, baseY + 0.02, cL / 2 + 0.06)
        wn.eulerAngles.x = -0.15
        root.addChildNode(wn)

        let plate = SCNBox(width: CGFloat(cW + 0.04), height: 0.10, length: 0.015, chamferRadius: 0)
        let pMat = SCNMaterial(); pMat.diffuse.contents = color.withAlphaComponent(0.6)
        plate.materials = [pMat]
        let pn = SCNNode(geometry: plate)
        pn.position = SCNVector3(0, baseY + 0.05, cL / 2 + 0.14)
        root.addChildNode(pn)
    }

    // MARK: - Add All Robots to Scene

    static func addRobots(to scene: SCNScene, configs: [RobotConfig]) -> [SCNNode] {
        configs.map { config in
            let robot = buildRobot(config: config)
            robot.position = SCNVector3(config.startPosition.x, 0.0, config.startPosition.y)
            robot.eulerAngles.y = config.alliance == .red ? Float.pi : 0
            scene.rootNode.addChildNode(robot)
            return robot
        }
    }
}
