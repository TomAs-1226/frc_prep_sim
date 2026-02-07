import Foundation

// MARK: - Field Spec
// Numerical coordinate specification for the competition field.
// Inspired by FRC 2025 Reefscape — not a direct copy.
//
// Coordinate system:
//   Origin = field center
//   +X = toward red alliance wall (along length)
//   +Z = toward "far" long wall (along width)
//   +Y = up
//
// Scale: 1 scene unit = 2 real-world meters (both horizontal and vertical)
//
// Procedural field layout. Replace numeric values to customize.
// The architecture is designed for drop-in coord replacement.

enum FieldSpec {

    // MARK: - Scale

    /// 1 scene unit = 2 real-world meters
    static let scale: Float = 0.5

    // MARK: - Field Dimensions
    // Real field: 16.46m × 8.05m → Scene: 8.23 × 4.025

    static let fieldLength: Float = 8.23
    static let fieldWidth: Float = 4.03
    static let halfLength: Float = 4.115
    static let halfWidth: Float = 2.015

    // MARK: - Wall Dimensions

    static let perimeterWallHeight: Float = 0.10
    static let allianceWallHeight: Float = 0.15
    static let wallThickness: Float = 0.03

    // MARK: - Scoring Tower Geometry
    //
    // Each alliance has one hexagonal scoring tower on their half.
    // 6 faces, each with 2 vertical pipes and branches at L2/L3/L4
    //
    // Tower centers:
    //   Red tower:  scene (2.14, 0.0)
    //   Blue tower: scene (-2.14, 0.0)

    static let reefApothem: Float = 0.415     // half of face-to-face distance
    static let reefRadius: Float = 0.479      // center-to-vertex = apothem / cos(30°)
    static let reefFaceEdge: Float = 0.479    // edge length = radius for regular hex
    static let reefPipeHeight: Float = 0.915  // 1.83m → scene
    static let reefPipeRadius: Float = 0.016  // 1.25in schedule 40 pipe

    static let pipePairSpacing: Float = 0.165 // 33cm center-to-center between pipe pair
    static let pipePairOffset: Float = 0.0825 // half spacing from face center

    // Branch heights above floor
    static let branchL2: Float = 0.405   // 0.81m real
    static let branchL3: Float = 0.605   // 1.21m real
    static let branchL4: Float = 0.915   // 1.83m real
    static let troughL1: Float = 0.04    // near ground level

    // Branch dimensions
    static let branchLength: Float = 0.06
    static let branchRadius: Float = 0.012
    static let troughWidth: Float = 0.20   // L1 trough per face
    static let troughDepth: Float = 0.06

    static let redReefCenter = SIMD2<Float>(2.14, 0.0)
    static let blueReefCenter = SIMD2<Float>(-2.14, 0.0)

    // MARK: - Skybridge (center divider structure)
    //
    // Truss spanning field width at center.

    static let bargeCenter = SIMD2<Float>(0.0, 0.0)
    static let bargeTrussSpan: Float = 4.45  // spans width (8.89m → scene)
    static let bargeTrussDepth: Float = 0.56 // 1.12m → scene
    static let bargeTrussHeight: Float = 1.29 // 2.57m → scene
    static let bargeLegWidth: Float = 0.08
    static let bargeLegDepth: Float = 0.08

    // Cage dimensions (simplified)
    static let cageWidth: Float = 0.094  // 7.375in → scene
    static let cageHeight: Float = 0.305 // 2ft → scene
    static let deepCageY: Float = 0.04   // near floor
    static let shallowCageY: Float = 0.385 // 2ft 6in → scene

    // Net above barge (simplified)
    static let netWidth: Float = 0.60   // 1.2m → scene
    static let netLength: Float = 1.85  // 3.7m → scene
    static let netHeight: Float = 0.965 // 6ft 4in → scene

    // Barge zone (endgame parking area on each side)
    static let bargeZoneHalfLength: Float = 0.93  // 1.86m each half
    static let bargeZoneDepth: Float = 0.585

    // MARK: - Supply Stations (at 4 field corners)
    //
    // Angled chutes where human players feed game pieces into the field.

    static let redCoralNear  = SIMD2<Float>(3.96, -1.68)
    static let redCoralFar   = SIMD2<Float>(3.96,  1.69)
    static let blueCoralNear = SIMD2<Float>(-3.96, -1.68)
    static let blueCoralFar  = SIMD2<Float>(-3.96,  1.69)

    static let coralStationWidth: Float = 0.90
    static let coralStationDepth: Float = 1.20  // playable area near opening

    // MARK: - Recyclers (on opposite long walls)
    //
    // Red recycler on far wall (+Z), blue on near wall (-Z)

    static let redProcessor  = SIMD2<Float>(1.39, 2.02)
    static let blueProcessor = SIMD2<Float>(-1.39, -2.01)
    static let processorWidth: Float = 0.55
    static let processorDepth: Float = 0.45

    // MARK: - Starting Positions
    //
    // 3 robots per alliance start behind the starting line.
    // Starting line: 2ft (0.61m → 0.305 scene) from alliance wall.

    static let redStarts: [SIMD2<Float>] = [
        SIMD2( 3.72, -0.70),
        SIMD2( 3.72,  0.00),
        SIMD2( 3.72,  0.70),
    ]
    static let blueStarts: [SIMD2<Float>] = [
        SIMD2(-3.72, -0.70),
        SIMD2(-3.72,  0.00),
        SIMD2(-3.72,  0.70),
    ]

    // Auto line positions (must cross to earn Leave points)
    static let redAutoLine: Float = 3.42    // 0.305 scene from red wall
    static let blueAutoLine: Float = -3.42

    // MARK: - Game Piece Dimensions

    static let coralRadius: Float = 0.029   // OD 4.5in → 57mm → scene
    static let coralLength: Float = 0.076   // 11.875in → 302mm → scene
    static let algaeRadius: Float = 0.103   // 16in diameter → scene

    // MARK: - Spheres on Tower
    // 3 spheres per tower on alternating faces (0, 2, 4).
    // Seated between L3 and L4 branch heights on the outer face.

    static let algaeOnReefFaces: [Int] = [0, 2, 4]
    static let algaeReefHeight: Float = (branchL3 + branchL4) / 2

    // MARK: - Carpet Zones
    // Red carpet covers +X half, blue carpet covers -X half

    static let redCarpetCenter: Float  =  halfLength / 2   // +X half
    static let blueCarpetCenter: Float = -halfLength / 2   // -X half

    // MARK: - Coral Station Chute
    // Real chute angle: 55° from horizontal → 0.96 radians

    static let coralChuteAngle: Float = 0.96  // radians (~55°)
    static let coralChuteHeight: Float = 0.40 // scene units

    // MARK: - Vision Marker Specification

    static let aprilTagSize: Float = 0.103  // marker size in scene units

    struct AprilTag {
        let id: Int
        let position: SIMD3<Float>   // scene coordinates (x, y, z)
        let yaw: Float               // facing direction (radians)
        let element: String
    }

    static let aprilTags: [AprilTag] = [
        // Red Coral Stations
        AprilTag(id: 1,  position: SIMD3( 3.96, 0.745, -1.68), yaw: .pi,        element: "Red Supply Station"),
        AprilTag(id: 2,  position: SIMD3( 3.96, 0.745,  1.69), yaw: .pi,        element: "Red Supply Station"),
        // Red Processor
        AprilTag(id: 3,  position: SIMD3( 1.39, 0.65,   2.02), yaw: -.pi / 2,   element: "Red Recycler"),
        // Red Barge
        AprilTag(id: 4,  position: SIMD3( 0.25, 0.935,  1.06), yaw: 0,          element: "Red Skybridge"),
        AprilTag(id: 5,  position: SIMD3( 0.25, 0.935, -1.06), yaw: 0,          element: "Red Skybridge"),
        // Red Reef Faces (6-11)
        AprilTag(id: 6,  position: SIMD3( 2.35, 0.155, -0.36), yaw: -.pi / 3,   element: "Red Tower"),
        AprilTag(id: 7,  position: SIMD3( 2.56, 0.155,  0.00), yaw: 0,          element: "Red Tower"),
        AprilTag(id: 8,  position: SIMD3( 2.35, 0.155,  0.36), yaw: .pi / 3,    element: "Red Tower"),
        AprilTag(id: 9,  position: SIMD3( 1.93, 0.155,  0.36), yaw: 2 * .pi / 3, element: "Red Tower"),
        AprilTag(id: 10, position: SIMD3( 1.73, 0.155,  0.00), yaw: .pi,        element: "Red Tower"),
        AprilTag(id: 11, position: SIMD3( 1.93, 0.155, -0.36), yaw: -2 * .pi / 3, element: "Red Tower"),
        // Blue Coral Stations
        AprilTag(id: 12, position: SIMD3(-3.96, 0.745, -1.68), yaw: 0,          element: "Blue Supply Station"),
        AprilTag(id: 13, position: SIMD3(-3.96, 0.745,  1.69), yaw: 0,          element: "Blue Supply Station"),
        // Blue Barge
        AprilTag(id: 14, position: SIMD3(-0.25, 0.935,  1.06), yaw: .pi,        element: "Blue Skybridge"),
        AprilTag(id: 15, position: SIMD3(-0.25, 0.935, -1.06), yaw: .pi,        element: "Blue Skybridge"),
        // Blue Processor
        AprilTag(id: 16, position: SIMD3(-1.39, 0.65,  -2.01), yaw: .pi / 2,    element: "Blue Recycler"),
        // Blue Reef Faces (17-22)
        AprilTag(id: 17, position: SIMD3(-2.35, 0.155, -0.36), yaw: -2 * .pi / 3, element: "Blue Tower"),
        AprilTag(id: 18, position: SIMD3(-2.56, 0.155,  0.00), yaw: .pi,        element: "Blue Tower"),
        AprilTag(id: 19, position: SIMD3(-2.35, 0.155,  0.36), yaw: 2 * .pi / 3, element: "Blue Tower"),
        AprilTag(id: 20, position: SIMD3(-1.93, 0.155,  0.36), yaw: .pi / 3,    element: "Blue Tower"),
        AprilTag(id: 21, position: SIMD3(-1.73, 0.155,  0.00), yaw: 0,          element: "Blue Tower"),
        AprilTag(id: 22, position: SIMD3(-1.93, 0.155, -0.36), yaw: -.pi / 3,   element: "Blue Tower"),
    ]

    // MARK: - Computed Reef Geometry

    /// 6 face centers + normal angles for a reef hexagon.
    static func reefFaces(center: SIMD2<Float>) -> [(center: SIMD2<Float>, angle: Float)] {
        (0..<6).map { i in
            let angle = Float(i) * .pi / 3.0
            return (
                SIMD2(center.x + reefApothem * cos(angle),
                      center.y + reefApothem * sin(angle)),
                angle
            )
        }
    }

    /// 6 vertices for a reef hexagon (offset 30° from face normals).
    static func reefVertices(center: SIMD2<Float>) -> [SIMD2<Float>] {
        (0..<6).map { i in
            let angle = Float(i) * .pi / 3.0 + .pi / 6.0
            return SIMD2(center.x + reefRadius * cos(angle),
                         center.y + reefRadius * sin(angle))
        }
    }

    /// 12 pipe positions for a reef (2 per face), with face angle for orientation.
    static func reefPipes(center: SIMD2<Float>) -> [(position: SIMD2<Float>, faceAngle: Float)] {
        var pipes: [(SIMD2<Float>, Float)] = []
        for face in reefFaces(center: center) {
            let perp = SIMD2<Float>(-sin(face.angle), cos(face.angle))
            pipes.append((face.center + perp * pipePairOffset, face.angle))
            pipes.append((face.center - perp * pipePairOffset, face.angle))
        }
        return pipes
    }

    /// Scoring approach positions — where robots drive to score on a specific face.
    /// Positioned slightly in front of the face (outward from hex center).
    static func scoringApproach(center: SIMD2<Float>, faceIndex: Int) -> SIMD2<Float> {
        let angle = Float(faceIndex) * .pi / 3.0
        let approachDist = reefApothem + 0.20  // just outside the reef
        return SIMD2(center.x + approachDist * cos(angle),
                     center.y + approachDist * sin(angle))
    }

    /// Scoring socket transforms for seated coral. Slots fan across the face tangent.
    static func scoringSocket(center: SIMD2<Float>, faceIndex: Int, level: Int, slot: Int)
        -> (position: SIMD3<Float>, yaw: Float) {
        let face = reefFaces(center: center)[faceIndex]
        let normal = SIMD2<Float>(cos(face.angle), sin(face.angle))
        let tangent = SIMD2<Float>(-sin(face.angle), cos(face.angle))
        let slotOffset: Float = slot == 0 ? -0.05 : 0.05
        let outward: Float = reefApothem + 0.045
        let height: Float
        switch level {
        case 1: height = troughL1 + 0.045
        case 2: height = branchL2 + 0.03
        case 3: height = branchL3 + 0.03
        default: height = branchL4 + 0.03
        }
        let pos2d = face.center + normal * outward + tangent * slotOffset
        let yaw = face.angle + .pi / 2
        return (SIMD3(pos2d.x, height, pos2d.y), yaw)
    }

    // MARK: - Scoring Values

    struct Scoring {
        // Auto period points
        static let autoLeave: Int = 3
        static let autoCoralL1: Int = 3
        static let autoCoralL2: Int = 4
        static let autoCoralL3: Int = 6
        static let autoCoralL4: Int = 7
        static let autoProcessor: Int = 6
        static let autoNet: Int = 4

        // Teleop period points
        static let teleopCoralL1: Int = 2
        static let teleopCoralL2: Int = 3
        static let teleopCoralL3: Int = 4
        static let teleopCoralL4: Int = 5
        static let teleopProcessor: Int = 6
        static let teleopNet: Int = 4

        // Endgame points
        static let park: Int = 2
        static let shallowClimb: Int = 6
        static let deepClimb: Int = 12
    }
}
