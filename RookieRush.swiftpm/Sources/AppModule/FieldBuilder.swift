import SceneKit

// MARK: - Field Builder

/// Constructs a full REEFSCAPE-inspired field with zones, scoring targets, and landmarks.
/// All geometry is procedural — no imported assets.
enum FieldBuilder {

    static func buildScene() -> (scene: SCNScene, reefNodes: [SCNNode]) {
        let scene = SCNScene()
        scene.background.contents = UIColor(red: 0.06, green: 0.06, blue: 0.1, alpha: 1.0)

        addCamera(to: scene)
        addLighting(to: scene)
        let root = scene.rootNode

        // Floor
        let floor = SCNBox(width: CGFloat(FieldLayout.fieldWidth) + 0.4, height: 0.05,
                           length: CGFloat(FieldLayout.fieldLength) + 0.4, chamferRadius: 0)
        let floorMat = SCNMaterial()
        floorMat.diffuse.contents = UIColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 1.0)
        floor.materials = [floorMat]
        let floorNode = SCNNode(geometry: floor)
        floorNode.position = SCNVector3(0, -0.025, 0)
        root.addChildNode(floorNode)

        addFieldBorders(to: root)

        // Alliance source zones
        addZone(to: root, pos: SCNVector3(3.0, 0.01, 0), size: (1.6, 3.8),
                color: UIColor(red: 0.7, green: 0.15, blue: 0.15, alpha: 0.3), label: "RED SOURCE")
        addZone(to: root, pos: SCNVector3(-3.0, 0.01, 0), size: (1.6, 3.8),
                color: UIColor(red: 0.15, green: 0.2, blue: 0.7, alpha: 0.3), label: "BLUE SOURCE")

        // Reef cluster
        addZone(to: root, pos: SCNVector3(0, 0.008, 0), size: (2.0, 1.8),
                color: UIColor(red: 0.1, green: 0.4, blue: 0.3, alpha: 0.25), label: "REEF ZONE")

        var reefNodes: [SCNNode] = []
        for (i, p) in FieldLayout.reefNodes.enumerated() {
            let n = makeReefNode(index: i)
            n.position = SCNVector3(p.x, 0.2, p.y)
            root.addChildNode(n)
            reefNodes.append(n)
            let ring = SCNTorus(ringRadius: 0.2, pipeRadius: 0.015)
            let rm = SCNMaterial(); rm.diffuse.contents = UIColor.white.withAlphaComponent(0.35)
            ring.materials = [rm]
            let rn = SCNNode(geometry: ring); rn.position = SCNVector3(p.x, 0.015, p.y)
            root.addChildNode(rn)
        }

        // Processors
        addProcessor(to: root, pos: FieldLayout.redProcessor, color: .red, label: "RED PROC")
        addProcessor(to: root, pos: FieldLayout.blueProcessor, color: .blue, label: "BLUE PROC")

        // Barge endgame zones
        addBarge(to: root, pos: FieldLayout.redBarge, color: UIColor(red: 0.7, green: 0.2, blue: 0.2, alpha: 0.4))
        addBarge(to: root, pos: FieldLayout.blueBarge, color: UIColor(red: 0.2, green: 0.2, blue: 0.7, alpha: 0.4))
        addText("BARGE", at: SCNVector3(0, 0.03, 2.0), color: .white, size: 0.12, to: root)

        // Mid-field dividers
        for x: Float in [-2.0, 2.0] {
            let d = SCNBox(width: 0.015, height: 0.01, length: CGFloat(FieldLayout.fieldLength) - 0.2, chamferRadius: 0)
            let m = SCNMaterial(); m.diffuse.contents = UIColor.white.withAlphaComponent(0.12); d.materials = [m]
            let n = SCNNode(geometry: d); n.position = SCNVector3(x, 0.025, 0); root.addChildNode(n)
        }

        // Barriers near reef
        for (bx, bz, bw, bl) in [(-1.2, 0.0, 0.06, 1.0), (1.2, 0.0, 0.06, 1.0),
                                   (0.0, -1.0, 1.5, 0.06), (0.0, 1.0, 1.5, 0.06)] as [(Float,Float,Float,Float)] {
            let w = SCNBox(width: CGFloat(bw), height: 0.15, length: CGFloat(bl), chamferRadius: 0.01)
            let wm = SCNMaterial(); wm.diffuse.contents = UIColor(white: 0.45, alpha: 0.6); w.materials = [wm]
            let wn = SCNNode(geometry: w); wn.position = SCNVector3(bx, 0.075, bz); root.addChildNode(wn)
        }

        // Decorative game pieces
        for off in [SIMD2<Float>(-0.2, -0.2), SIMD2<Float>(0.0, 0.1), SIMD2<Float>(0.2, -0.1)] {
            addPiece(to: root, at: FieldLayout.redSource + off)
            addPiece(to: root, at: FieldLayout.blueSource + off)
        }

        return (scene, reefNodes)
    }

    // MARK: - Helpers

    private static func addCamera(to scene: SCNScene) {
        let c = SCNNode(); c.camera = SCNCamera()
        c.camera?.fieldOfView = 48; c.camera?.zNear = 0.1; c.camera?.zFar = 60
        c.position = SCNVector3(0, 7.0, 6.5); c.eulerAngles.x = -Float.pi / 3.0
        scene.rootNode.addChildNode(c)
    }

    private static func addLighting(to scene: SCNScene) {
        let a = SCNNode(); a.light = SCNLight(); a.light?.type = .ambient
        a.light?.intensity = 600; a.light?.color = UIColor(white: 0.35, alpha: 1)
        scene.rootNode.addChildNode(a)
        let d = SCNNode(); d.light = SCNLight(); d.light?.type = .directional
        d.light?.intensity = 800; d.light?.castsShadow = true; d.light?.shadowRadius = 4
        d.position = SCNVector3(2, 10, 5); d.eulerAngles = SCNVector3(-Float.pi/3, Float.pi/8, 0)
        scene.rootNode.addChildNode(d)
    }

    private static func addFieldBorders(to root: SCNNode) {
        let w = FieldLayout.fieldWidth, l = FieldLayout.fieldLength
        let c = UIColor.white.withAlphaComponent(0.3)
        for (ex,ez,ew,el) in [(0,-l/2,w,Float(0.03)),(0,l/2,w,Float(0.03)),
                               (-w/2,0,Float(0.03),l),(w/2,0,Float(0.03),l)] as [(Float,Float,Float,Float)] {
            let b = SCNBox(width: CGFloat(ew), height: 0.01, length: CGFloat(el), chamferRadius: 0)
            let m = SCNMaterial(); m.diffuse.contents = c; b.materials = [m]
            let n = SCNNode(geometry: b); n.position = SCNVector3(ex, 0.03, ez); root.addChildNode(n)
        }
    }

    private static func addZone(to root: SCNNode, pos: SCNVector3, size: (Float,Float), color: UIColor, label: String) {
        let z = SCNBox(width: CGFloat(size.0), height: 0.015, length: CGFloat(size.1), chamferRadius: 0)
        let m = SCNMaterial(); m.diffuse.contents = color; z.materials = [m]
        let n = SCNNode(geometry: z); n.position = pos; root.addChildNode(n)
        addText(label, at: SCNVector3(pos.x, 0.025, pos.z + size.1/2 - 0.15),
                color: UIColor.white.withAlphaComponent(0.5), size: 0.1, to: root)
    }

    private static func makeReefNode(index: Int) -> SCNNode {
        let g = SCNCylinder(radius: 0.14, height: 0.4)
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(hue: CGFloat(index)/6*0.3+0.1, saturation: 0.65, brightness: 0.85, alpha: 1)
        m.emission.contents = UIColor.black; g.materials = [m]
        let n = SCNNode(geometry: g); n.name = "reef_\(index)"; return n
    }

    private static func addProcessor(to root: SCNNode, pos: SIMD2<Float>, color: UIColor, label: String) {
        let b = SCNBox(width: 0.5, height: 0.02, length: 0.5, chamferRadius: 0)
        let bm = SCNMaterial(); bm.diffuse.contents = color.withAlphaComponent(0.5); b.materials = [bm]
        let bn = SCNNode(geometry: b); bn.position = SCNVector3(pos.x, 0.01, pos.y); root.addChildNode(bn)
        for dx: Float in [-0.2, 0.2] { for dz: Float in [-0.2, 0.2] {
            let p = SCNCylinder(radius: 0.02, height: 0.3)
            let pm = SCNMaterial(); pm.diffuse.contents = color.withAlphaComponent(0.7); p.materials = [pm]
            let pn = SCNNode(geometry: p); pn.position = SCNVector3(pos.x+dx, 0.15, pos.y+dz); root.addChildNode(pn)
        }}
        addText(label, at: SCNVector3(pos.x, 0.03, pos.y+0.35), color: .white, size: 0.07, to: root)
    }

    private static func addBarge(to root: SCNNode, pos: SIMD2<Float>, color: UIColor) {
        let p = SCNBox(width: 1.2, height: 0.08, length: 0.6, chamferRadius: 0.02)
        let pm = SCNMaterial(); pm.diffuse.contents = color; p.materials = [pm]
        let pn = SCNNode(geometry: p); pn.position = SCNVector3(pos.x, 0.04, pos.y); root.addChildNode(pn)
        let r = SCNBox(width: 0.4, height: 0.04, length: 0.3, chamferRadius: 0)
        let rm = SCNMaterial(); rm.diffuse.contents = color.withAlphaComponent(0.6); r.materials = [rm]
        let rn = SCNNode(geometry: r); rn.position = SCNVector3(pos.x, 0.02, pos.y-0.4)
        rn.eulerAngles.x = -0.15; root.addChildNode(rn)
    }

    private static func addPiece(to root: SCNNode, at pos: SIMD2<Float>) {
        let s = SCNSphere(radius: 0.06)
        let m = SCNMaterial(); m.diffuse.contents = UIColor.orange; s.materials = [m]
        let n = SCNNode(geometry: s); n.position = SCNVector3(pos.x, 0.08, pos.y)
        let u = SCNAction.moveBy(x: 0, y: 0.04, z: 0, duration: 0.7); u.timingMode = .easeInEaseOut
        n.runAction(SCNAction.repeatForever(SCNAction.sequence([u, u.reversed()]))); root.addChildNode(n)
    }

    private static func addText(_ text: String, at pos: SCNVector3, color: UIColor, size: CGFloat, to root: SCNNode) {
        let g = SCNText(string: text, extrusionDepth: 0.008)
        g.font = UIFont.systemFont(ofSize: size, weight: .bold); g.flatness = 0.4
        let m = SCNMaterial(); m.diffuse.contents = color.withAlphaComponent(0.6); g.materials = [m]
        let n = SCNNode(geometry: g)
        let (mn, mx) = n.boundingBox; n.pivot = SCNMatrix4MakeTranslation((mx.x-mn.x)/2+mn.x, 0, 0)
        n.position = pos; n.eulerAngles.x = -Float.pi/2; root.addChildNode(n)
    }
}

// MARK: - Robot Builder

/// Builds 6 visually distinct robots from primitive geometry.
enum RobotBuilder {

    static func buildRobot(config: RobotConfig) -> SCNNode {
        let root = SCNNode()
        root.name = "robot_\(config.id)"
        let color = config.alliance.uiColor
        let cW: CGFloat = 0.28, cH: CGFloat = 0.1, cL: CGFloat = 0.32

        // Chassis
        let ch = SCNBox(width: cW, height: cH, length: cL, chamferRadius: 0.015)
        let cm = SCNMaterial(); cm.diffuse.contents = UIColor(white: 0.25, alpha: 1); ch.materials = [cm]
        let cn = SCNNode(geometry: ch); cn.position = SCNVector3(0, Float(cH/2), 0); root.addChildNode(cn)

        // Bumpers
        let bm = SCNBox(width: cW+0.04, height: cH*0.45, length: cL+0.04, chamferRadius: 0.008)
        let bmm = SCNMaterial(); bmm.diffuse.contents = color.withAlphaComponent(0.85); bm.materials = [bmm]
        let bn = SCNNode(geometry: bm); bn.position = SCNVector3(0, Float(cH*0.25), 0); root.addChildNode(bn)

        // 4 swerve wheels
        let wr: CGFloat = 0.04
        for (ox, oz) in [(-cW/2, -cL/2+0.04), (cW/2, -cL/2+0.04),
                          (-cW/2, cL/2-0.04), (cW/2, cL/2-0.04)] as [(CGFloat,CGFloat)] {
            let w = SCNCylinder(radius: wr, height: 0.025)
            let wm = SCNMaterial(); wm.diffuse.contents = UIColor.darkGray; w.materials = [wm]
            let wn = SCNNode(geometry: w); wn.eulerAngles.z = .pi/2
            wn.position = SCNVector3(Float(ox), Float(wr), Float(oz)); root.addChildNode(wn)
        }

        // Superstructure
        addSuper(to: root, type: config.superstructure, h: Float(cH))

        // Team number
        let lb = SCNText(string: config.teamNumber, extrusionDepth: 0.003)
        lb.font = UIFont.monospacedDigitSystemFont(ofSize: 0.04, weight: .bold); lb.flatness = 0.5
        let lm = SCNMaterial(); lm.diffuse.contents = UIColor.white; lb.materials = [lm]
        let ln = SCNNode(geometry: lb)
        let (mn, mx) = ln.boundingBox; ln.pivot = SCNMatrix4MakeTranslation((mx.x-mn.x)/2+mn.x, 0, 0)
        ln.position = SCNVector3(0, Float(cH*0.6), Float(cL/2)+0.003); root.addChildNode(ln)

        return root
    }

    private static func addSuper(to root: SCNNode, type: SuperstructureType, h: Float) {
        switch type {
        case .elevator:
            for dx: Float in [-0.06, 0.06] {
                let r = SCNBox(width: 0.02, height: 0.35, length: 0.02, chamferRadius: 0)
                let m = SCNMaterial(); m.diffuse.contents = UIColor.systemGray; r.materials = [m]
                let n = SCNNode(geometry: r); n.position = SCNVector3(dx, h+0.175, 0); root.addChildNode(n)
            }
            let c = SCNBox(width: 0.1, height: 0.025, length: 0.05, chamferRadius: 0.005)
            let cm = SCNMaterial(); cm.diffuse.contents = UIColor.systemYellow; c.materials = [cm]
            let cn = SCNNode(geometry: c); cn.position = SCNVector3(0, h+0.35, 0); root.addChildNode(cn)

        case .arm:
            let a = SCNCylinder(radius: 0.015, height: 0.22)
            let am = SCNMaterial(); am.diffuse.contents = UIColor.systemOrange; a.materials = [am]
            let an = SCNNode(geometry: a); an.position = SCNVector3(0, h+0.11, 0.04)
            an.eulerAngles.x = 0.3; root.addChildNode(an)
            let g = SCNBox(width: 0.08, height: 0.02, length: 0.04, chamferRadius: 0.005)
            let gm = SCNMaterial(); gm.diffuse.contents = UIColor.systemYellow; g.materials = [gm]
            let gn = SCNNode(geometry: g); gn.position = SCNVector3(0, h+0.22, 0.1); root.addChildNode(gn)

        case .intake:
            let r = SCNCylinder(radius: 0.03, height: 0.2)
            let rm = SCNMaterial(); rm.diffuse.contents = UIColor.systemTeal; r.materials = [rm]
            let rn = SCNNode(geometry: r); rn.eulerAngles.z = .pi/2
            rn.position = SCNVector3(0, h+0.03, 0.18); root.addChildNode(rn)
            let p = SCNBox(width: 0.24, height: 0.03, length: 0.08, chamferRadius: 0)
            let pm = SCNMaterial(); pm.diffuse.contents = UIColor.systemTeal.withAlphaComponent(0.5); p.materials = [pm]
            let pn = SCNNode(geometry: p); pn.position = SCNVector3(0, h+0.06, 0.17); root.addChildNode(pn)

        case .dualRail:
            for dx: Float in [-0.08, 0.08] {
                let r = SCNBox(width: 0.015, height: 0.4, length: 0.015, chamferRadius: 0)
                let m = SCNMaterial(); m.diffuse.contents = UIColor.systemRed; r.materials = [m]
                let n = SCNNode(geometry: r); n.position = SCNVector3(dx, h+0.2, 0); root.addChildNode(n)
            }
            let t = SCNBox(width: 0.14, height: 0.02, length: 0.12, chamferRadius: 0.005)
            let tm = SCNMaterial(); tm.diffuse.contents = UIColor.systemRed.withAlphaComponent(0.7); t.materials = [tm]
            let tn = SCNNode(geometry: t); tn.position = SCNVector3(0, h+0.3, 0); root.addChildNode(tn)

        case .turretIntake:
            let b = SCNCylinder(radius: 0.06, height: 0.04)
            let bm = SCNMaterial(); bm.diffuse.contents = UIColor.systemIndigo; b.materials = [bm]
            let bn = SCNNode(geometry: b); bn.position = SCNVector3(0, h+0.02, 0); root.addChildNode(bn)
            let a = SCNBox(width: 0.03, height: 0.03, length: 0.14, chamferRadius: 0)
            let am = SCNMaterial(); am.diffuse.contents = UIColor.systemIndigo.withAlphaComponent(0.8); a.materials = [am]
            let an = SCNNode(geometry: a); an.position = SCNVector3(0, h+0.05, 0.05); root.addChildNode(an)

        case .wedge:
            let w = SCNBox(width: 0.3, height: 0.05, length: 0.2, chamferRadius: 0.01)
            let wm = SCNMaterial(); wm.diffuse.contents = UIColor.systemGreen; w.materials = [wm]
            let wn = SCNNode(geometry: w); wn.position = SCNVector3(0, h+0.025, 0.14)
            wn.eulerAngles.x = -0.2; root.addChildNode(wn)
            let p = SCNBox(width: 0.32, height: 0.08, length: 0.02, chamferRadius: 0)
            let pm = SCNMaterial(); pm.diffuse.contents = UIColor.systemGreen.withAlphaComponent(0.7); p.materials = [pm]
            let pn = SCNNode(geometry: p); pn.position = SCNVector3(0, h+0.04, 0.22); root.addChildNode(pn)
        }
    }

    static func addRobots(to scene: SCNScene, configs: [RobotConfig]) -> [SCNNode] {
        configs.map { config in
            let robot = buildRobot(config: config)
            robot.position = SCNVector3(config.startPosition.x, 0.15, config.startPosition.y)
            robot.eulerAngles.y = config.alliance == .red ? Float.pi : 0
            scene.rootNode.addChildNode(robot)
            return robot
        }
    }
}
