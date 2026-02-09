import SceneKit
import Foundation

// ============================================================================
// MARK: - Robot Model Contract
// ============================================================================
//
// NON-NEGOTIABLE HIERARCHY (all names MUST match):
//
// RobotRoot (y=0 on field)
//   ├─ Chassis
//   ├─ Bumpers
//   ├─ Superstructure
//   ├─ IntakeAnchor   (empty, for attaching game pieces)
//   ├─ ScoreAnchor    (empty, for scoring release pose)
//   ├─ ModuleFL
//   │    └─ SteerPivot  (rotates about +Y = yaw)
//   │         └─ WheelRoll  (rotates about local +X = rolling)
//   │              └─ WheelMesh  (cylinder, corrective rotation applied)
//   ├─ ModuleFR  (same structure)
//   ├─ ModuleBL  (same structure)
//   └─ ModuleBR  (same structure)
//
// Coordinate system:  +Y up, +X right, +Z forward.
// Robot origin = center of chassis footprint on ground.
// Chassis bottom at y=0 exactly (±0.002).
// Wheel contact at y=0.
// ============================================================================

// MARK: - Part Library

/// Reusable geometry parts for building robot models.
/// NO freeform shapes — only these parts are allowed.
enum PartLibrary {

    // MARK: Dimensions (shared constants)

    static let chassisWidth: Float  = 0.30
    static let chassisDepth: Float  = 0.30
    static let chassisHeight: Float = 0.06
    static let wheelRadius: Float   = 0.032
    static let wheelWidth: Float    = 0.018
    static let bumperHeight: Float  = 0.05
    static let bumperThickness: Float = 0.035

    /// Module corner positions: FL, FR, BL, BR
    static let modulePositions: [(name: String, x: Float, z: Float)] = [
        ("ModuleFL", -0.11,  0.11),
        ("ModuleFR",  0.11,  0.11),
        ("ModuleBL", -0.11, -0.11),
        ("ModuleBR",  0.11, -0.11),
    ]

    // MARK: - Chassis Box

    /// Flat chassis plate. Bottom face at y=0, center at y=height/2.
    static func chassisBox(material: SCNMaterial) -> SCNNode {
        let geo = SCNBox(width: CGFloat(chassisWidth - 0.02),
                         height: CGFloat(chassisHeight),
                         length: CGFloat(chassisDepth - 0.02),
                         chamferRadius: 0.003)
        geo.materials = [material]
        let node = SCNNode(geometry: geo)
        node.position = SCNVector3(0, chassisHeight / 2, 0)
        return node
    }

    /// Frame rails (tube perimeter)
    static func frameRails(material: SCNMaterial) -> [SCNNode] {
        var nodes: [SCNNode] = []
        let tubeSize: CGFloat = 0.016
        let halfW = chassisWidth / 2
        let halfD = chassisDepth / 2
        let railY = chassisHeight / 2

        // Front and back rails (along X)
        for zSign: Float in [-1, 1] {
            let geo = SCNBox(width: CGFloat(chassisWidth), height: tubeSize,
                             length: tubeSize, chamferRadius: 0.002)
            geo.materials = [material]
            let rail = SCNNode(geometry: geo)
            rail.position = SCNVector3(0, railY, zSign * halfD)
            nodes.append(rail)
        }
        // Left and right rails (along Z)
        for xSign: Float in [-1, 1] {
            let geo = SCNBox(width: tubeSize, height: tubeSize,
                             length: CGFloat(chassisDepth), chamferRadius: 0.002)
            geo.materials = [material]
            let rail = SCNNode(geometry: geo)
            rail.position = SCNVector3(xSign * halfW, railY, 0)
            nodes.append(rail)
        }
        // Cross members
        for zOff: Float in [-0.07, 0.07] {
            let geo = SCNBox(width: CGFloat(chassisWidth - 0.04), height: tubeSize * 0.8,
                             length: tubeSize * 0.8, chamferRadius: 0)
            geo.materials = [material]
            let cross = SCNNode(geometry: geo)
            cross.position = SCNVector3(0, railY, zOff)
            nodes.append(cross)
        }
        return nodes
    }

    /// Bellypan (bottom plate, sits just below frame rails)
    static func bellypan() -> SCNNode {
        let geo = SCNBox(width: CGFloat(chassisWidth - 0.03), height: 0.004,
                         length: CGFloat(chassisDepth - 0.03), chamferRadius: 0)
        geo.materials = [FieldMaterials.bellypan]
        let node = SCNNode(geometry: geo)
        node.position = SCNVector3(0, 0.002, 0)  // just above ground
        return node
    }

    // MARK: - Bumper Boxes (4 sides)

    /// Four bumper boxes surrounding the chassis perimeter.
    static func bumperBoxes(alliance: Alliance, reinforced: Bool = false) -> [SCNNode] {
        let fabricMat = FieldMaterials.bumperFabric(alliance)
        let bH: Float = reinforced ? bumperHeight * 1.4 : bumperHeight
        let bT: Float = reinforced ? bumperThickness * 1.2 : bumperThickness
        let halfW = chassisWidth / 2
        let halfD = chassisDepth / 2
        let bY: Float = bH / 2  // bumper center Y (bottom at y=0)
        var nodes: [SCNNode] = []

        // Front
        let fGeo = SCNBox(width: CGFloat(chassisWidth + bT * 2), height: CGFloat(bH),
                          length: CGFloat(bT), chamferRadius: 0.004)
        fGeo.materials = [fabricMat]
        let front = SCNNode(geometry: fGeo)
        front.position = SCNVector3(0, bY, halfD + bT / 2)
        nodes.append(front)

        // Back
        let bkGeo = SCNBox(width: CGFloat(chassisWidth + bT * 2), height: CGFloat(bH),
                           length: CGFloat(bT), chamferRadius: 0.004)
        bkGeo.materials = [fabricMat]
        let back = SCNNode(geometry: bkGeo)
        back.position = SCNVector3(0, bY, -(halfD + bT / 2))
        nodes.append(back)

        // Left
        let lGeo = SCNBox(width: CGFloat(bT), height: CGFloat(bH),
                          length: CGFloat(chassisDepth), chamferRadius: 0.004)
        lGeo.materials = [fabricMat]
        let left = SCNNode(geometry: lGeo)
        left.position = SCNVector3(-(halfW + bT / 2), bY, 0)
        nodes.append(left)

        // Right
        let rGeo = SCNBox(width: CGFloat(bT), height: CGFloat(bH),
                          length: CGFloat(chassisDepth), chamferRadius: 0.004)
        rGeo.materials = [fabricMat]
        let right = SCNNode(geometry: rGeo)
        right.position = SCNVector3(halfW + bT / 2, bY, 0)
        nodes.append(right)

        return nodes
    }

    // MARK: - Swerve Module (SteerPivot → WheelRoll → WheelMesh)

    /// Creates one complete wheel module with correct hierarchy.
    /// - driveType: affects visual details (swerve gets fork, tank/mecanum get simpler housing)
    static func wheelModule(name: String, driveType: DrivetrainChoice) -> SCNNode {
        let moduleNode = SCNNode()
        moduleNode.name = name

        // SteerPivot: rotates about +Y
        let steerPivot = SCNNode()
        steerPivot.name = "SteerPivot"

        // WheelRoll: rotates about local +X
        let wheelRoll = SCNNode()
        wheelRoll.name = "WheelRoll"
        wheelRoll.position = SCNVector3(0, wheelRadius, 0) // center at wheelRadius above ground

        // WheelMesh: SCNCylinder default axis = Y, rotate Z by π/2 so axis = X
        let wheelGeo = SCNCylinder(radius: CGFloat(wheelRadius), height: CGFloat(wheelWidth))
        wheelGeo.radialSegmentCount = 12
        wheelGeo.materials = [FieldMaterials.wheel]
        let wheelMesh = SCNNode(geometry: wheelGeo)
        wheelMesh.name = "WheelMesh"
        // Corrective rotation: cylinder Y-axis → local X-axis for proper rolling
        wheelMesh.eulerAngles.z = Float.pi / 2

        wheelRoll.addChildNode(wheelMesh)
        steerPivot.addChildNode(wheelRoll)

        // Drive-type-specific decorations (attached to steerPivot)
        switch driveType {
        case .swerve:
            addSwerveDetails(to: steerPivot)
        case .tank:
            addTankDetails(to: steerPivot)
        case .mecanum:
            addMecanumDetails(to: steerPivot, wheelRoll: wheelRoll)
        }

        moduleNode.addChildNode(steerPivot)
        return moduleNode
    }

    private static func addSwerveDetails(to pivot: SCNNode) {
        // Module housing (cylindrical, above wheel)
        let housingGeo = SCNCylinder(radius: 0.018, height: 0.025)
        housingGeo.radialSegmentCount = 8
        housingGeo.materials = [FieldMaterials.motorHousing]
        let housing = SCNNode(geometry: housingGeo)
        housing.position = SCNVector3(0, wheelRadius + 0.024, 0)
        pivot.addChildNode(housing)

        // Fork prongs (two side plates)
        for xOff: Float in [-0.013, 0.013] {
            let prongGeo = SCNBox(width: 0.003, height: 0.028, length: 0.015, chamferRadius: 0)
            prongGeo.materials = [FieldMaterials.gusset]
            let prong = SCNNode(geometry: prongGeo)
            prong.position = SCNVector3(xOff, wheelRadius + 0.008, 0)
            pivot.addChildNode(prong)
        }

        // Steer motor (small cylinder on side)
        let motorGeo = SCNCylinder(radius: 0.010, height: 0.016)
        motorGeo.radialSegmentCount = 8
        motorGeo.materials = [FieldMaterials.motorHousing]
        let motor = SCNNode(geometry: motorGeo)
        motor.eulerAngles.z = Float.pi / 2
        motor.position = SCNVector3(0.020, wheelRadius + 0.024, 0)
        pivot.addChildNode(motor)
    }

    private static func addTankDetails(to pivot: SCNNode) {
        // Bearing block
        let bearingGeo = SCNBox(width: 0.014, height: 0.016, length: 0.010, chamferRadius: 0.001)
        bearingGeo.materials = [FieldMaterials.bearing]
        let bearing = SCNNode(geometry: bearingGeo)
        bearing.position = SCNVector3(0, wheelRadius + 0.014, 0)
        pivot.addChildNode(bearing)

        // Axle through wheel
        let axleGeo = SCNCylinder(radius: 0.003, height: 0.026)
        axleGeo.radialSegmentCount = 6
        axleGeo.materials = [FieldMaterials.metal]
        let axle = SCNNode(geometry: axleGeo)
        axle.eulerAngles.z = Float.pi / 2
        axle.position = SCNVector3(0, wheelRadius, 0)
        pivot.addChildNode(axle)

        // Sprocket
        let sprocketGeo = SCNTorus(ringRadius: 0.010, pipeRadius: 0.003)
        sprocketGeo.ringSegmentCount = 8
        sprocketGeo.pipeSegmentCount = 4
        sprocketGeo.materials = [FieldMaterials.metal]
        let sprocket = SCNNode(geometry: sprocketGeo)
        sprocket.eulerAngles.z = Float.pi / 2
        sprocket.position = SCNVector3(0, wheelRadius, 0)
        pivot.addChildNode(sprocket)
    }

    private static func addMecanumDetails(to pivot: SCNNode, wheelRoll: SCNNode) {
        // Bearing block
        let bearingGeo = SCNBox(width: 0.012, height: 0.014, length: 0.010, chamferRadius: 0.001)
        bearingGeo.materials = [FieldMaterials.bearing]
        let bearing = SCNNode(geometry: bearingGeo)
        bearing.position = SCNVector3(0, wheelRadius + 0.012, 0)
        pivot.addChildNode(bearing)

        // Diagonal rollers on wheel (4 rollers at 45° angles)
        for r in 0..<4 {
            let angle = Float(r) / 4.0 * Float.pi * 2
            let rX = (wheelRadius - 0.006) * cos(angle)
            let rY = (wheelRadius - 0.006) * sin(angle)
            let rollerGeo = SCNCylinder(radius: 0.005, height: 0.024)
            rollerGeo.radialSegmentCount = 6
            let rollerMat = SCNMaterial()
            rollerMat.diffuse.contents = UIColor(white: 0.30, alpha: 1)
            rollerGeo.materials = [rollerMat]
            let roller = SCNNode(geometry: rollerGeo)
            roller.eulerAngles = SCNVector3(Float.pi / 4, 0, Float.pi / 2)
            roller.position = SCNVector3(0, rY, rX)
            wheelRoll.addChildNode(roller)
        }
    }

    // MARK: - Elevator Tower

    /// Cascading elevator: two uprights + inner stage + gripper carriage.
    static func elevatorTower(height: Float, alliance: Alliance) -> SCNNode {
        let root = SCNNode()
        let baseY = PartLibrary.chassisHeight

        // Two C-channel uprights
        for xOff: Float in [-0.050, 0.050] {
            let uprightGeo = SCNBox(width: 0.014, height: CGFloat(height),
                                    length: 0.014, chamferRadius: 0)
            uprightGeo.materials = [FieldMaterials.frameTube]
            let upright = SCNNode(geometry: uprightGeo)
            upright.position = SCNVector3(xOff, baseY + height / 2, -0.04)
            root.addChildNode(upright)

            // C-channel lip
            let lipGeo = SCNBox(width: 0.004, height: CGFloat(height - 0.02),
                                length: 0.008, chamferRadius: 0)
            lipGeo.materials = [FieldMaterials.gusset]
            let lip = SCNNode(geometry: lipGeo)
            lip.position = SCNVector3(xOff > 0 ? xOff - 0.008 : xOff + 0.008,
                                       baseY + height / 2, -0.04)
            root.addChildNode(lip)
        }

        // Cross braces (3 levels)
        let braceSpacing = height / 4
        for i in 1...3 {
            let braceGeo = SCNBox(width: 0.08, height: 0.005, length: 0.008, chamferRadius: 0)
            braceGeo.materials = [FieldMaterials.gusset]
            let brace = SCNNode(geometry: braceGeo)
            brace.position = SCNVector3(0, baseY + braceSpacing * Float(i), -0.04)
            root.addChildNode(brace)
        }

        // Inner stage (telescoping)
        let stageH = height * 0.55
        let stageGeo = SCNBox(width: 0.06, height: CGFloat(stageH), length: 0.010, chamferRadius: 0)
        stageGeo.materials = [FieldMaterials.metal]
        let stage = SCNNode(geometry: stageGeo)
        stage.name = "elevator_stage"
        stage.position = SCNVector3(0, baseY + height * 0.5, -0.038)
        root.addChildNode(stage)

        // Chain run
        let chainGeo = SCNBox(width: 0.003, height: CGFloat(height - 0.02),
                              length: 0.003, chamferRadius: 0)
        chainGeo.materials = [FieldMaterials.chain]
        let chain = SCNNode(geometry: chainGeo)
        chain.position = SCNVector3(0.042, baseY + height / 2, -0.048)
        root.addChildNode(chain)

        // Gripper carriage at top
        let gripperGeo = SCNBox(width: 0.07, height: 0.020, length: 0.035, chamferRadius: 0.002)
        let gripMat = SCNMaterial()
        gripMat.diffuse.contents = alliance.uiColor.withAlphaComponent(0.7)
        gripMat.roughness.contents = NSNumber(value: 0.5)
        gripperGeo.materials = [gripMat]
        let gripper = SCNNode(geometry: gripperGeo)
        gripper.name = "elevator_gripper"
        gripper.position = SCNVector3(0, baseY + height - 0.02, -0.01)
        root.addChildNode(gripper)

        // Gripper fingers
        for xOff: Float in [-0.025, 0.025] {
            let fingerGeo = SCNBox(width: 0.005, height: 0.015, length: 0.020, chamferRadius: 0)
            fingerGeo.materials = [gripMat]
            let finger = SCNNode(geometry: fingerGeo)
            finger.position = SCNVector3(xOff, baseY + height - 0.01, 0.015)
            root.addChildNode(finger)
        }

        // Top crossbar
        let topGeo = SCNCylinder(radius: 0.006, height: 0.10)
        topGeo.radialSegmentCount = 6
        topGeo.materials = [FieldMaterials.metal]
        let topBar = SCNNode(geometry: topGeo)
        topBar.eulerAngles.z = Float.pi / 2
        topBar.position = SCNVector3(0, baseY + height + 0.01, -0.04)
        root.addChildNode(topBar)

        return root
    }

    // MARK: - Intake Assembly

    /// Ground intake with rollers and polycarbonate guards.
    static func intakeAssembly(alliance: Alliance) -> SCNNode {
        let root = SCNNode()
        let baseY: Float = chassisHeight * 0.5

        // Deploy arms
        for xOff: Float in [-0.07, 0.07] {
            let armGeo = SCNBox(width: 0.003, height: 0.04, length: 0.07, chamferRadius: 0)
            armGeo.materials = [FieldMaterials.gusset]
            let arm = SCNNode(geometry: armGeo)
            arm.position = SCNVector3(xOff, baseY - 0.008, 0.13)
            arm.eulerAngles.x = -0.12
            root.addChildNode(arm)
        }

        // Main roller
        let rollerGeo = SCNCylinder(radius: 0.020, height: 0.16)
        rollerGeo.radialSegmentCount = 10
        rollerGeo.materials = [FieldMaterials.teal]
        let roller = SCNNode(geometry: rollerGeo)
        roller.name = "intake_roller"
        roller.eulerAngles.z = Float.pi / 2
        roller.position = SCNVector3(0, 0.020, 0.17)
        root.addChildNode(roller)

        // Second roller
        let roller2Geo = SCNCylinder(radius: 0.016, height: 0.14)
        roller2Geo.radialSegmentCount = 10
        roller2Geo.materials = [FieldMaterials.teal]
        let roller2 = SCNNode(geometry: roller2Geo)
        roller2.eulerAngles.z = Float.pi / 2
        roller2.position = SCNVector3(0, 0.028, 0.13)
        root.addChildNode(roller2)

        // Polycarbonate top guard
        let guardGeo = SCNBox(width: 0.18, height: 0.003, length: 0.08, chamferRadius: 0)
        guardGeo.materials = [FieldMaterials.polycarbonate]
        let guardNode = SCNNode(geometry: guardGeo)
        guardNode.position = SCNVector3(0, chassisHeight, 0.14)
        guardNode.eulerAngles.x = -0.08
        root.addChildNode(guardNode)

        // Front guard (alliance colored)
        let fGeo = SCNBox(width: 0.18, height: 0.030, length: 0.004, chamferRadius: 0)
        let fMat = SCNMaterial()
        fMat.diffuse.contents = alliance.uiColor.withAlphaComponent(0.6)
        fGeo.materials = [fMat]
        let fGuard = SCNNode(geometry: fGeo)
        fGuard.position = SCNVector3(0, 0.035, 0.19)
        root.addChildNode(fGuard)

        return root
    }

    // MARK: - Arm Segment

    /// Pivot arm with gussets, extension tube, and wrist gripper.
    static func armSegment(alliance: Alliance) -> SCNNode {
        let root = SCNNode()
        let baseY = chassisHeight

        // Pivot tower gusset plates
        for xOff: Float in [-0.035, 0.035] {
            let plateGeo = SCNBox(width: 0.003, height: 0.08, length: 0.05, chamferRadius: 0)
            plateGeo.materials = [FieldMaterials.gusset]
            let plate = SCNNode(geometry: plateGeo)
            plate.position = SCNVector3(xOff, baseY + 0.05, -0.05)
            root.addChildNode(plate)
        }

        // Pivot shaft
        let pivotGeo = SCNCylinder(radius: 0.007, height: 0.08)
        pivotGeo.radialSegmentCount = 8
        pivotGeo.materials = [FieldMaterials.bearing]
        let pivot = SCNNode(geometry: pivotGeo)
        pivot.eulerAngles.z = Float.pi / 2
        pivot.position = SCNVector3(0, baseY + 0.08, -0.05)
        root.addChildNode(pivot)

        // Main arm tube
        let armGeo = SCNBox(width: 0.018, height: 0.22, length: 0.018, chamferRadius: 0.002)
        armGeo.materials = [FieldMaterials.frameTube]
        let arm = SCNNode(geometry: armGeo)
        arm.name = "pivot_arm"
        arm.pivot = SCNMatrix4MakeTranslation(0, -0.11, 0)
        arm.position = SCNVector3(0, baseY + 0.08, -0.05)
        arm.eulerAngles.z = 0.30
        root.addChildNode(arm)

        // Extension tube inside arm
        let extGeo = SCNBox(width: 0.012, height: 0.10, length: 0.012, chamferRadius: 0)
        extGeo.materials = [FieldMaterials.metal]
        let ext = SCNNode(geometry: extGeo)
        ext.position = SCNVector3(0, 0.15, 0)
        arm.addChildNode(ext)

        // Wrist joint
        let wristGeo = SCNCylinder(radius: 0.005, height: 0.020)
        wristGeo.radialSegmentCount = 6
        wristGeo.materials = [FieldMaterials.bearing]
        let wrist = SCNNode(geometry: wristGeo)
        wrist.eulerAngles.z = Float.pi / 2
        wrist.position = SCNVector3(0, 0.21, 0)
        arm.addChildNode(wrist)

        // Gripper
        let gripGeo = SCNBox(width: 0.05, height: 0.016, length: 0.030, chamferRadius: 0.002)
        let gripMat = SCNMaterial()
        gripMat.diffuse.contents = alliance.uiColor.withAlphaComponent(0.7)
        gripGeo.materials = [gripMat]
        let grip = SCNNode(geometry: gripGeo)
        grip.name = "arm_gripper"
        grip.position = SCNVector3(0, 0.23, 0)
        arm.addChildNode(grip)

        // Motor at pivot
        let motorGeo = SCNCylinder(radius: 0.012, height: 0.018)
        motorGeo.radialSegmentCount = 8
        motorGeo.materials = [FieldMaterials.motorHousing]
        let motor = SCNNode(geometry: motorGeo)
        motor.eulerAngles.z = Float.pi / 2
        motor.position = SCNVector3(0.048, baseY + 0.08, -0.05)
        root.addChildNode(motor)

        return root
    }

    // MARK: - Decorative Panels

    /// Small decorative panel (thin box) for robot detail.
    static func panel(width: Float, height: Float, depth: Float,
                      material: SCNMaterial) -> SCNNode {
        let geo = SCNBox(width: CGFloat(width), height: CGFloat(height),
                         length: CGFloat(depth), chamferRadius: 0)
        geo.materials = [material]
        return SCNNode(geometry: geo)
    }

    // MARK: - Internals (Battery + Electronics)

    static func internals() -> SCNNode {
        let root = SCNNode()
        let frameY = chassisHeight * 0.6

        // Battery
        let battGeo = SCNBox(width: 0.06, height: 0.035, length: 0.08, chamferRadius: 0.002)
        battGeo.materials = [FieldMaterials.battery]
        let batt = SCNNode(geometry: battGeo)
        batt.position = SCNVector3(0, frameY + 0.018, -0.02)
        root.addChildNode(batt)

        // Battery terminals
        for xOff: Float in [-0.018, 0.018] {
            let termGeo = SCNCylinder(radius: 0.004, height: 0.006)
            termGeo.radialSegmentCount = 6
            let termMat = SCNMaterial()
            termMat.diffuse.contents = UIColor(white: 0.7, alpha: 1)
            termMat.metalness.contents = NSNumber(value: 0.8)
            termGeo.materials = [termMat]
            let term = SCNNode(geometry: termGeo)
            term.position = SCNVector3(xOff, frameY + 0.038, -0.04)
            root.addChildNode(term)
        }

        // Electronics board (roboRIO)
        let boardGeo = SCNBox(width: 0.05, height: 0.006, length: 0.04, chamferRadius: 0.001)
        boardGeo.materials = [FieldMaterials.electronics]
        let board = SCNNode(geometry: boardGeo)
        board.position = SCNVector3(0.05, frameY + 0.018, -0.07)
        root.addChildNode(board)

        // Radio on board
        let radioGeo = SCNBox(width: 0.020, height: 0.010, length: 0.020, chamferRadius: 0.001)
        radioGeo.materials = [FieldMaterials.motorHousing]
        let radio = SCNNode(geometry: radioGeo)
        radio.position = SCNVector3(0.05, frameY + 0.028, -0.07)
        root.addChildNode(radio)

        // PDP on other side
        let pdpGeo = SCNBox(width: 0.04, height: 0.008, length: 0.04, chamferRadius: 0.001)
        pdpGeo.materials = [FieldMaterials.electronics]
        let pdp = SCNNode(geometry: pdpGeo)
        pdp.position = SCNVector3(-0.05, frameY + 0.018, -0.07)
        root.addChildNode(pdp)

        return root
    }

    // MARK: - Defense Wedge

    static func defenseWedge(alliance: Alliance) -> SCNNode {
        let root = SCNNode()
        let baseY = chassisHeight

        // Wedge ramp plate
        let wedgeGeo = SCNBox(width: 0.26, height: 0.004, length: 0.14, chamferRadius: 0)
        let wedgeMat = SCNMaterial()
        wedgeMat.diffuse.contents = UIColor.systemGreen.withAlphaComponent(0.8)
        wedgeMat.metalness.contents = NSNumber(value: 0.3)
        wedgeGeo.materials = [wedgeMat]
        let wedge = SCNNode(geometry: wedgeGeo)
        wedge.position = SCNVector3(0, baseY * 0.7, 0.12)
        wedge.eulerAngles.x = -0.16
        root.addChildNode(wedge)

        // Support ribs
        for xOff: Float in [-0.07, 0.0, 0.07] {
            let ribGeo = SCNBox(width: 0.006, height: 0.016, length: 0.12, chamferRadius: 0)
            ribGeo.materials = [FieldMaterials.gusset]
            let rib = SCNNode(geometry: ribGeo)
            rib.position = SCNVector3(xOff, baseY * 0.6, 0.12)
            rib.eulerAngles.x = -0.16
            root.addChildNode(rib)
        }

        // Push face
        let faceGeo = SCNBox(width: 0.28, height: 0.07, length: 0.006, chamferRadius: 0.002)
        let faceMat = SCNMaterial()
        faceMat.diffuse.contents = alliance.uiColor.withAlphaComponent(0.85)
        faceMat.metalness.contents = NSNumber(value: 0.2)
        faceGeo.materials = [faceMat]
        let face = SCNNode(geometry: faceGeo)
        face.position = SCNVector3(0, baseY * 0.6, 0.19)
        root.addChildNode(face)

        // Reinforcement strips
        for yOff: Float in [-0.012, 0.012] {
            let stripGeo = SCNBox(width: 0.26, height: 0.003, length: 0.008, chamferRadius: 0)
            stripGeo.materials = [FieldMaterials.metal]
            let strip = SCNNode(geometry: stripGeo)
            strip.position = SCNVector3(0, baseY * 0.6 + yOff, 0.194)
            root.addChildNode(strip)
        }

        // Short arm stub
        let stubGeo = SCNBox(width: 0.014, height: 0.08, length: 0.014, chamferRadius: 0.001)
        stubGeo.materials = [FieldMaterials.frameTube]
        let stub = SCNNode(geometry: stubGeo)
        stub.position = SCNVector3(0, baseY + 0.04, -0.06)
        root.addChildNode(stub)

        return root
    }

    // MARK: - Shooter Assembly

    static func shooterAssembly(alliance: Alliance) -> SCNNode {
        let root = SCNNode()
        let baseY = chassisHeight

        // Housing frame
        let housingGeo = SCNBox(width: 0.16, height: 0.05, length: 0.10, chamferRadius: 0.004)
        housingGeo.materials = [FieldMaterials.chassis]
        let housing = SCNNode(geometry: housingGeo)
        housing.position = SCNVector3(0, baseY + 0.035, 0.02)
        root.addChildNode(housing)

        // Side plates
        for xSign: Float in [-1, 1] {
            let sideGeo = SCNBox(width: 0.003, height: 0.07, length: 0.12, chamferRadius: 0)
            sideGeo.materials = [FieldMaterials.polycarbonate]
            let side = SCNNode(geometry: sideGeo)
            side.position = SCNVector3(xSign * 0.07, baseY + 0.04, 0.02)
            root.addChildNode(side)
        }

        // Dual flywheels
        for xOff: Float in [-0.05, 0.05] {
            let fwGeo = SCNCylinder(radius: 0.030, height: 0.010)
            fwGeo.radialSegmentCount = 12
            fwGeo.materials = [FieldMaterials.flywheel]
            let fw = SCNNode(geometry: fwGeo)
            fw.name = "flywheel"
            fw.eulerAngles.z = Float.pi / 2
            fw.position = SCNVector3(xOff, baseY + 0.07, 0.05)
            root.addChildNode(fw)
        }

        // Hood
        let hoodGeo = SCNBox(width: 0.12, height: 0.05, length: 0.006, chamferRadius: 0)
        hoodGeo.materials = [FieldMaterials.polycarbonate]
        let hood = SCNNode(geometry: hoodGeo)
        hood.position = SCNVector3(0, baseY + 0.08, -0.02)
        hood.eulerAngles.x = 0.12
        root.addChildNode(hood)

        // Ball channel
        let rampGeo = SCNBox(width: 0.07, height: 0.004, length: 0.08, chamferRadius: 0)
        let rampMat = SCNMaterial()
        rampMat.diffuse.contents = alliance.uiColor.withAlphaComponent(0.5)
        rampGeo.materials = [rampMat]
        let ramp = SCNNode(geometry: rampGeo)
        ramp.position = SCNVector3(0, baseY + 0.05, 0.05)
        ramp.eulerAngles.x = -0.15
        root.addChildNode(ramp)

        // Turret ring
        let turretGeo = SCNTorus(ringRadius: 0.04, pipeRadius: 0.006)
        turretGeo.ringSegmentCount = 16
        turretGeo.pipeSegmentCount = 6
        turretGeo.materials = [FieldMaterials.bearing]
        let turret = SCNNode(geometry: turretGeo)
        turret.position = SCNVector3(0, baseY + 0.008, 0.02)
        root.addChildNode(turret)

        return root
    }
}

// ============================================================================
// MARK: - Robot Factory (3D Model Builder)
// ============================================================================

/// Builds 3D robot models conforming to the strict Model Contract.
/// Uses ONLY parts from PartLibrary. Produces 3 recognizable configurations:
///   A) Cycler  — floor intake + short elevator
///   B) Scorer  — tall elevator (or arm/shooter based on build)
///   C) Defender — reinforced bumpers + wedge + arm stub
enum RobotModelFactory {

    /// Build all robots and add them to the scene. Returns robot nodes in order.
    static func addRobots(to scene: SCNScene, configs: [RobotConfig]) -> [SCNNode] {
        configs.map { config in
            let robot = buildRobot(config: config)
            robot.position = SCNVector3(config.startPosition.x, 0, config.startPosition.y)
            scene.rootNode.addChildNode(robot)
            return robot
        }
    }

    /// Build a single robot conforming to the Model Contract hierarchy.
    static func buildRobot(config: RobotConfig) -> SCNNode {
        let root = SCNNode()
        root.name = "RobotRoot"

        // --- Chassis ---
        let chassis = SCNNode()
        chassis.name = "Chassis"
        let frameMat = FieldMaterials.frameForChoice(config.build.frame)

        // Frame rails
        for rail in PartLibrary.frameRails(material: frameMat) {
            chassis.addChildNode(rail)
        }
        // Bellypan
        chassis.addChildNode(PartLibrary.bellypan())
        // Top plate
        let topPlate = PartLibrary.panel(
            width: PartLibrary.chassisWidth - 0.06,
            height: 0.004,
            depth: PartLibrary.chassisDepth * 0.35,
            material: FieldMaterials.chassis
        )
        topPlate.position = SCNVector3(0, PartLibrary.chassisHeight + 0.002, -0.04)
        chassis.addChildNode(topPlate)

        root.addChildNode(chassis)

        // --- Bumpers ---
        let bumpers = SCNNode()
        bumpers.name = "Bumpers"
        let reinforced = config.role == .defender
        for bumper in PartLibrary.bumperBoxes(alliance: config.alliance, reinforced: reinforced) {
            bumpers.addChildNode(bumper)
        }
        root.addChildNode(bumpers)

        // --- Internals ---
        root.addChildNode(PartLibrary.internals())

        // --- Superstructure ---
        let superstructure = buildSuperstructure(config: config)
        superstructure.name = "Superstructure"
        root.addChildNode(superstructure)

        // --- Anchors ---
        let intakeAnchor = SCNNode()
        intakeAnchor.name = "IntakeAnchor"
        intakeAnchor.position = SCNVector3(0, 0.04, PartLibrary.chassisDepth / 2 + 0.02)
        root.addChildNode(intakeAnchor)

        let scoreAnchor = SCNNode()
        scoreAnchor.name = "ScoreAnchor"
        // Position depends on superstructure type
        switch config.superstructure {
        case .elevator:
            scoreAnchor.position = SCNVector3(0, 0.35, -0.01)
        case .arm:
            scoreAnchor.position = SCNVector3(0, 0.25, -0.05)
        case .shooter:
            scoreAnchor.position = SCNVector3(0, 0.15, 0.06)
        case .intake:
            scoreAnchor.position = SCNVector3(0, 0.08, 0.15)
        case .wedge:
            scoreAnchor.position = SCNVector3(0, 0.08, 0.10)
        }
        root.addChildNode(scoreAnchor)

        // --- Wheel Modules (FL, FR, BL, BR) ---
        for mp in PartLibrary.modulePositions {
            let module = PartLibrary.wheelModule(name: mp.name,
                                                  driveType: config.build.drivetrain)
            module.position = SCNVector3(mp.x, 0, mp.z)
            root.addChildNode(module)
        }

        // --- Team Number ---
        addTeamNumber(to: root, config: config)

        return root
    }

    // MARK: - Superstructure Builder

    private static func buildSuperstructure(config: RobotConfig) -> SCNNode {
        // Map to 3 visual configurations based on role + superstructure
        switch config.superstructure {
        case .elevator:
            // Scorer: tall elevator (or short for cycler role)
            let height: Float = config.role == .cycler ? 0.20 : 0.36
            let elevator = PartLibrary.elevatorTower(height: height, alliance: config.alliance)
            // Cycler also gets intake
            if config.role == .cycler {
                let intake = PartLibrary.intakeAssembly(alliance: config.alliance)
                elevator.addChildNode(intake)
            }
            return elevator

        case .arm:
            let arm = PartLibrary.armSegment(alliance: config.alliance)
            if config.role == .cycler {
                let intake = PartLibrary.intakeAssembly(alliance: config.alliance)
                arm.addChildNode(intake)
            }
            return arm

        case .shooter:
            let shooter = PartLibrary.shooterAssembly(alliance: config.alliance)
            return shooter

        case .intake:
            // Cycler config: floor intake + short elevator
            let container = SCNNode()
            let intake = PartLibrary.intakeAssembly(alliance: config.alliance)
            container.addChildNode(intake)
            // Add short elevator for scoring
            let elevator = PartLibrary.elevatorTower(height: 0.16, alliance: config.alliance)
            container.addChildNode(elevator)
            return container

        case .wedge:
            // Defender: wedge + reinforced look
            return PartLibrary.defenseWedge(alliance: config.alliance)
        }
    }

    // MARK: - Team Number Label

    private static func addTeamNumber(to root: SCNNode, config: RobotConfig) {
        let txtGeo = SCNText(string: config.teamNumber, extrusionDepth: 0.004)
        txtGeo.font = UIFont.monospacedSystemFont(ofSize: 0.035, weight: .bold)
        txtGeo.flatness = 0.3
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.white.withAlphaComponent(0.9)
        txtGeo.materials = [mat]
        let txtNode = SCNNode(geometry: txtGeo)
        let (mn, mx) = txtNode.boundingBox
        txtNode.position = SCNVector3(-(mx.x - mn.x) / 2, PartLibrary.chassisHeight + 0.005,
                                       PartLibrary.chassisDepth / 2 + PartLibrary.bumperThickness + 0.001)
        txtNode.name = "team_number"
        root.addChildNode(txtNode)
    }
}

// ============================================================================
// MARK: - Robot Validator
// ============================================================================

/// Validates a robot model against the strict Model Contract.
/// Returns a list of failures. Simulation must NOT proceed if any errors exist.
enum RobotValidator {

    struct ValidationFailure: Identifiable {
        let id = UUID()
        let description: String
        let severity: Severity

        enum Severity: String {
            case error   = "ERROR"
            case warning = "WARNING"
        }
    }

    struct ValidationResult {
        let failures: [ValidationFailure]
        var passed: Bool {
            !failures.contains { $0.severity == .error }
        }
    }

    /// Run all validation checks on a robot root node.
    static func validate(root: SCNNode) -> ValidationResult {
        var failures: [ValidationFailure] = []

        // 1. Check root name
        if root.name != "RobotRoot" {
            failures.append(.init(
                description: "Root node name is '\(root.name ?? "nil")' — expected 'RobotRoot'",
                severity: .error
            ))
        }

        // 2. Required named entities
        let requiredEntities = ["Chassis", "Bumpers", "Superstructure",
                                 "IntakeAnchor", "ScoreAnchor"]
        for name in requiredEntities {
            if root.childNode(withName: name, recursively: false) == nil {
                failures.append(.init(
                    description: "Missing required entity: '\(name)'",
                    severity: .error
                ))
            }
        }

        // 3. Check 4 wheel modules
        let moduleNames = ["ModuleFL", "ModuleFR", "ModuleBL", "ModuleBR"]
        for moduleName in moduleNames {
            guard let module = root.childNode(withName: moduleName, recursively: false) else {
                failures.append(.init(
                    description: "Missing wheel module: '\(moduleName)'",
                    severity: .error
                ))
                continue
            }

            // Check SteerPivot
            guard let steerPivot = module.childNode(withName: "SteerPivot", recursively: false) else {
                failures.append(.init(
                    description: "\(moduleName): Missing 'SteerPivot'",
                    severity: .error
                ))
                continue
            }

            // Check WheelRoll
            guard let wheelRoll = steerPivot.childNode(withName: "WheelRoll", recursively: false) else {
                failures.append(.init(
                    description: "\(moduleName)/SteerPivot: Missing 'WheelRoll'",
                    severity: .error
                ))
                continue
            }

            // Check WheelMesh
            if wheelRoll.childNode(withName: "WheelMesh", recursively: false) == nil {
                failures.append(.init(
                    description: "\(moduleName)/SteerPivot/WheelRoll: Missing 'WheelMesh'",
                    severity: .error
                ))
            }

            // 5. Wheel contact check: wheel bottom y ≈ 0
            let wheelWorldPos = wheelRoll.convertPosition(SCNVector3(0, 0, 0), to: root)
            let wheelBottomY = wheelWorldPos.y - PartLibrary.wheelRadius
            if abs(wheelBottomY) > 0.005 {
                failures.append(.init(
                    description: "\(moduleName): Wheel bottom y=\(String(format: "%.4f", wheelBottomY)) — expected ≈0",
                    severity: abs(wheelBottomY) > 0.01 ? .error : .warning
                ))
            }

            // 7. SteerPivot axis check (should rotate about Y — default for SCNNode)
            // WheelRoll axis check (should rotate about local X)
            // These are enforced by construction — verify WheelMesh has corrective rotation
            if let wheelMesh = wheelRoll.childNode(withName: "WheelMesh", recursively: false) {
                let meshZRot = abs(wheelMesh.eulerAngles.z - Float.pi / 2)
                if meshZRot > 0.01 {
                    failures.append(.init(
                        description: "\(moduleName): WheelMesh Z rotation is \(String(format: "%.3f", wheelMesh.eulerAngles.z)) — expected π/2 for axle alignment",
                        severity: .warning
                    ))
                }
            }
        }

        // 4. Chassis bottom y ≈ 0
        if let chassis = root.childNode(withName: "Chassis", recursively: false) {
            let (cMin, _) = chassis.boundingBox
            let chassisBottomWorld = chassis.convertPosition(cMin, to: root)
            if abs(chassisBottomWorld.y) > 0.01 {
                failures.append(.init(
                    description: "Chassis bottom y=\(String(format: "%.4f", chassisBottomWorld.y)) — expected ≈0 (±0.002)",
                    severity: abs(chassisBottomWorld.y) > 0.02 ? .error : .warning
                ))
            }
        }

        // Bumpers not below ground
        if let bumpers = root.childNode(withName: "Bumpers", recursively: false) {
            let (bMin, _) = bumpers.boundingBox
            let bumperBottomWorld = bumpers.convertPosition(bMin, to: root)
            if bumperBottomWorld.y < -0.005 {
                failures.append(.init(
                    description: "Bumpers below ground: y=\(String(format: "%.4f", bumperBottomWorld.y))",
                    severity: .warning
                ))
            }
        }

        // 6. NaN/infinite transform check
        checkForNaNs(node: root, path: "RobotRoot", failures: &failures)

        return ValidationResult(failures: failures)
    }

    private static func checkForNaNs(node: SCNNode, path: String,
                                      failures: inout [ValidationFailure]) {
        let pos = node.position
        if pos.x.isNaN || pos.y.isNaN || pos.z.isNaN ||
            pos.x.isInfinite || pos.y.isInfinite || pos.z.isInfinite {
            failures.append(.init(
                description: "\(path): Position contains NaN/Infinite",
                severity: .error
            ))
        }
        let rot = node.eulerAngles
        if rot.x.isNaN || rot.y.isNaN || rot.z.isNaN {
            failures.append(.init(
                description: "\(path): EulerAngles contains NaN",
                severity: .error
            ))
        }
        for child in node.childNodes {
            let childPath = "\(path)/\(child.name ?? "unnamed")"
            checkForNaNs(node: child, path: childPath, failures: &failures)
        }
    }
}
