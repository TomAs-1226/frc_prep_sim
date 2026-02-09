import Foundation
import SwiftUI

// MARK: - Game Phase

enum GamePhase: Equatable {
    case intro
    case workshop       // Robot building experience — the star of the app
    case simulation
    case results
}

// MARK: - Alliance

enum Alliance: String, CaseIterable {
    case red  = "Red"
    case blue = "Blue"

    var color: Color {
        switch self {
        case .red:  return .red
        case .blue: return Color(red: 0.2, green: 0.4, blue: 0.9)
        }
    }

    var uiColor: UIColor {
        switch self {
        case .red:  return UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1)
        case .blue: return UIColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1)
        }
    }
}

// MARK: - Seeded RNG

struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64 = 42) { state = seed == 0 ? 1 : seed }

    mutating func next() -> UInt64 {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17; return state
    }
    mutating func nextDouble() -> Double { Double(next() & 0x1FFFFFFFFFFFFF) / Double(1 << 53) }
    mutating func nextFloat() -> Float { Float(nextDouble()) }
    mutating func nextInt(_ range: Range<Int>) -> Int {
        guard range.count > 0 else { return range.lowerBound }
        return range.lowerBound + Int(next() % UInt64(range.count))
    }
    mutating func nextBool(probability: Double = 0.5) -> Bool { nextDouble() < probability }
}

// ============================================================================
// MARK: - Procedural Game System
// ============================================================================

// MARK: - Game Piece Types

enum GamePieceKind: String, CaseIterable, Identifiable {
    case ball = "Power Cell"
    case cube = "Cargo Cube"
    case cone = "Signal Cone"
    case ring = "Coral Ring"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .ball: return .orange
        case .cube: return .purple
        case .cone: return .yellow
        case .ring: return Color(red: 0.90, green: 0.85, blue: 0.75)
        }
    }

    var uiColor: UIColor {
        switch self {
        case .ball: return .systemOrange
        case .cube: return .systemPurple
        case .cone: return .systemYellow
        case .ring: return UIColor(red: 0.90, green: 0.85, blue: 0.75, alpha: 1)
        }
    }

    var icon: String {
        switch self {
        case .ball: return "circle.fill"
        case .cube: return "cube.fill"
        case .cone: return "triangle.fill"
        case .ring: return "circle.dashed"
        }
    }

    /// Which intake handles this piece best
    var idealIntake: IntakeChoice {
        switch self {
        case .ball:  return .roller
        case .cube:  return .claw
        case .cone:  return .claw
        case .ring:  return .roller
        }
    }
}

// MARK: - Scoring Height

enum ScoringHeight: Int, CaseIterable, Comparable, Identifiable {
    case ground = 0
    case low    = 1
    case mid    = 2
    case high   = 3

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .ground: return "Ground"
        case .low:    return "Low"
        case .mid:    return "Mid"
        case .high:   return "High"
        }
    }

    /// 3D scene Y position
    var sceneHeight: Float {
        switch self {
        case .ground: return 0.06
        case .low:    return 0.40
        case .mid:    return 0.72
        case .high:   return 1.10
        }
    }

    var color: Color {
        switch self {
        case .ground: return .green
        case .low:    return .cyan
        case .mid:    return .yellow
        case .high:   return .red
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

// MARK: - Scoring Zone

struct ScoringZone: Identifiable {
    let id: Int
    let name: String
    let position: SIMD2<Float>   // scene (x, z) coordinates
    let height: ScoringHeight
    let pointsAuto: Int
    let pointsTeleop: Int
    let alliance: Alliance
}

// MARK: - Endgame Challenge

enum EndgameChallenge: Equatable {
    case climb(difficulty: ClimbDifficulty, points: Int)
    case balance(points: Int)
    case park(points: Int)

    var displayName: String {
        switch self {
        case .climb(let d, _): return "Climb \(d.rawValue)"
        case .balance:         return "Balance Platform"
        case .park:            return "Park in Zone"
        }
    }

    var points: Int {
        switch self {
        case .climb(_, let p): return p
        case .balance(let p):  return p
        case .park(let p):     return p
        }
    }

    var icon: String {
        switch self {
        case .climb:   return "figure.climbing"
        case .balance: return "scale.3d"
        case .park:    return "parkingsign.circle.fill"
        }
    }

    var requiresTank: Bool {
        if case .climb(let d, _) = self, d == .high { return true }
        return false
    }
}

enum ClimbDifficulty: String, Equatable {
    case low  = "Low Bar"
    case mid  = "Mid Bar"
    case high = "High Bar"

    var climbTime: Double {
        switch self {
        case .low:  return 2.0
        case .mid:  return 3.5
        case .high: return 5.0
        }
    }
}

// MARK: - Field Obstacle

struct FieldObstacle: Identifiable {
    let id: Int
    let kind: ObstacleKind
    let position: SIMD2<Float>
    let size: SIMD2<Float>
}

enum ObstacleKind: String {
    case barrier = "Barrier"
    case ramp    = "Ramp"
    case bridge  = "Center Bridge"
}

// MARK: - Pickup Station

struct PickupStation: Identifiable {
    let id: Int
    let position: SIMD2<Float>
    let alliance: Alliance
}

// MARK: - Field Theme

enum FieldTheme: String, CaseIterable {
    case industrial = "Industrial"
    case arena      = "Arena"
    case cosmic     = "Cosmic"
    case nature     = "Nature"

    var floorColor: UIColor {
        switch self {
        case .industrial: return UIColor(red: 0.15, green: 0.16, blue: 0.18, alpha: 1)
        case .arena:      return UIColor(red: 0.12, green: 0.14, blue: 0.20, alpha: 1)
        case .cosmic:     return UIColor(red: 0.08, green: 0.08, blue: 0.20, alpha: 1)
        case .nature:     return UIColor(red: 0.12, green: 0.18, blue: 0.14, alpha: 1)
        }
    }

    var bgColor: UIColor {
        switch self {
        case .industrial: return UIColor(red: 0.04, green: 0.04, blue: 0.08, alpha: 1)
        case .arena:      return UIColor(red: 0.03, green: 0.04, blue: 0.12, alpha: 1)
        case .cosmic:     return UIColor(red: 0.02, green: 0.02, blue: 0.14, alpha: 1)
        case .nature:     return UIColor(red: 0.04, green: 0.06, blue: 0.04, alpha: 1)
        }
    }
}

// MARK: - Game Archetype

enum GameArchetype: String, CaseIterable {
    case vertical      = "Altitude Challenge"
    case speed         = "Speed Rush"
    case precision     = "Precision Strike"
    case power         = "Power Play"
    case classic       = "All-Rounder"
    case endgameFocus  = "Endgame Focus"
    case hybrid        = "Hybrid Challenge"
    case defenseArena  = "Defense Arena"

    var description: String {
        switch self {
        case .vertical:     return "Tall scoring targets reward robots that can reach high. Climbing endgame favors sturdy builds."
        case .speed:        return "Many low targets reward fast cycling. Light, agile builds dominate."
        case .precision:    return "Mid-height targets require accurate placement. Reliable builds shine."
        case .power:        return "Obstacles and tight spaces reward strong pushers and durable frames."
        case .classic:      return "A balanced mix of heights and challenges. Versatile builds do well."
        case .endgameFocus: return "Endgame is worth massive points. Plan your robot around the final challenge."
        case .hybrid:       return "Mix of shooting and placing. Versatile mechanisms that can do both excel."
        case .defenseArena: return "Low-scoring slugfest with many obstacles. Defense wins championships here."
        }
    }

    var icon: String {
        switch self {
        case .vertical:     return "arrow.up.circle.fill"
        case .speed:        return "hare.fill"
        case .precision:    return "scope"
        case .power:        return "bolt.shield.fill"
        case .classic:      return "star.fill"
        case .endgameFocus: return "flag.checkered"
        case .hybrid:       return "arrow.triangle.branch"
        case .defenseArena: return "shield.lefthalf.filled"
        }
    }

    var color: Color {
        switch self {
        case .vertical:     return .purple
        case .speed:        return .cyan
        case .precision:    return .yellow
        case .power:        return .red
        case .classic:      return .orange
        case .endgameFocus: return .indigo
        case .hybrid:       return .mint
        case .defenseArena: return .pink
        }
    }
}

// MARK: - Generated Game

struct GeneratedGame: Identifiable {
    let id = UUID()
    let name: String
    let archetype: GameArchetype
    let gamePieces: [GamePieceKind]
    let scoringZones: [ScoringZone]
    let pickupStations: [PickupStation]
    let endgameChallenge: EndgameChallenge
    let obstacles: [FieldObstacle]
    let autoLeavePoints: Int
    let theme: FieldTheme

    var maxScoringHeight: ScoringHeight {
        scoringZones.map(\.height).max() ?? .ground
    }

    var redZones: [ScoringZone] { scoringZones.filter { $0.alliance == .red } }
    var blueZones: [ScoringZone] { scoringZones.filter { $0.alliance == .blue } }

    /// How well does a build suit this game? Returns 0-100.
    func buildMatchScore(build: RobotBuild) -> Int {
        var score = 40

        let maxReach = build.manipulator.maxReach
        let maxZone = maxScoringHeight
        if maxReach >= maxZone { score += 20 }
        else if maxReach.rawValue >= maxZone.rawValue - 1 { score += 8 }

        for piece in gamePieces {
            if build.intake == piece.idealIntake { score += 10 }
        }

        switch endgameChallenge {
        case .climb(let difficulty, _):
            if difficulty == .high && build.drivetrain.canDeepClimb { score += 15 }
            else if difficulty == .mid { score += 8 }
            else if difficulty == .low { score += 5 }
        case .balance:
            if build.drivetrain.canStrafe { score += 10 }
        case .park:
            score += 3
        }

        if archetype == .speed {
            let totalSpeed = build.drivetrain.baseSpeed + build.frame.speedModifier + build.manipulator.speedModifier
            if totalSpeed > 2.2 { score += 12 }
            else if totalSpeed > 2.0 { score += 6 }
        }

        if archetype == .power || archetype == .defenseArena {
            if build.drivetrain.pushPower > 0.7 { score += 10 }
            if build.frame == .steel { score += 5 }
        }

        if archetype == .endgameFocus {
            switch endgameChallenge {
            case .climb(let d, _):
                if d == .high && build.drivetrain.canDeepClimb { score += 10 }
                else if d != .high { score += 5 }
            case .balance:
                if build.drivetrain.canStrafe { score += 10 }
            case .park:
                score += 3
            }
        }

        if archetype == .hybrid {
            if build.manipulator.canShoot { score += 8 }
            if build.manipulator.maxReach >= .mid { score += 6 }
        }

        if archetype == .defenseArena {
            if build.drivetrain.pushPower > 0.5 { score += 8 }
            if build.frame == .steel { score += 5 }
        }

        return min(100, max(0, score))
    }

    /// Build hints for the player
    var challengeHints: [String] {
        var hints: [String] = []
        let highZones = redZones.filter { $0.height == .high }
        let midZones = redZones.filter { $0.height == .mid }
        let lowZones = redZones.filter { $0.height <= .low }

        if !highZones.isEmpty {
            hints.append("High targets (\(highZones.count)) need an Elevator — worth \(highZones[0].pointsTeleop)pts each")
        }
        if !midZones.isEmpty {
            hints.append("Mid targets need Pivot Arm or Elevator — \(midZones[0].pointsTeleop)pts each")
        }
        if lowZones.count >= 3 {
            hints.append("Many low targets — fast Simple Tray cycling could outscore slow climbers")
        }

        switch endgameChallenge {
        case .climb(let d, let p):
            if d == .high {
                hints.append("High climb (\(p)pts) needs Tank Drive for deep climb")
            } else {
                hints.append("Climb endgame (\(p)pts) — plan time to get there")
            }
        case .balance(let p):
            hints.append("Balance (\(p)pts) — Swerve or Mecanum strafing helps")
        case .park(let p):
            hints.append("Easy park (\(p)pts) — focus build on scoring speed")
        }

        for piece in gamePieces {
            hints.append("\(piece.rawValue) works best with \(piece.idealIntake.shortLabel)")
        }

        return hints
    }
}

// ============================================================================
// MARK: - Robot Parts Catalog
// ============================================================================

// MARK: - Drivetrain

enum DrivetrainChoice: String, CaseIterable, Identifiable {
    case swerve  = "Swerve Drive"
    case tank    = "Tank Drive"
    case mecanum = "Mecanum Drive"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .swerve:  return "rotate.3d"
        case .tank:    return "rectangle.on.rectangle"
        case .mecanum: return "arrow.up.and.down.and.arrow.left.and.right"
        }
    }

    var shortLabel: String {
        switch self { case .swerve: return "Swerve"; case .tank: return "Tank"; case .mecanum: return "Mecanum" }
    }

    var description: String {
        switch self {
        case .swerve:  return "Independent wheel modules enable omnidirectional movement. Each wheel rotates 360°."
        case .tank:    return "Fixed parallel wheels with skid steering. Simple, rugged, and powerful."
        case .mecanum: return "Angled rollers on each wheel allow sideways strafing without turning."
        }
    }

    var pros: String {
        switch self {
        case .swerve:  return "Fastest, can strafe, agile turning"
        case .tank:    return "Reliable, strong push, deep climb (12pts)"
        case .mecanum: return "Can strafe, moderate speed, balanced"
        }
    }

    var cons: String {
        switch self {
        case .swerve:  return "Less reliable, weak pushing, shallow climb only"
        case .tank:    return "Slower, no strafing, wide turns"
        case .mecanum: return "Weak pushing, no deep climb, moderate reliability"
        }
    }

    var color: Color {
        switch self { case .swerve: return .cyan; case .tank: return .orange; case .mecanum: return .mint }
    }

    // Stats
    var baseSpeed: Float {
        switch self { case .swerve: return 2.30; case .tank: return 1.85; case .mecanum: return 2.05 }
    }
    var turnRate: Float {
        switch self { case .swerve: return 3.5; case .tank: return 1.8; case .mecanum: return 2.8 }
    }
    var pushPower: Float {
        switch self { case .swerve: return 0.3; case .tank: return 1.0; case .mecanum: return 0.45 }
    }
    var baseReliability: Float {
        switch self { case .swerve: return 0.84; case .tank: return 0.94; case .mecanum: return 0.88 }
    }
    var weight: Float {
        switch self { case .swerve: return 15; case .tank: return 18; case .mecanum: return 16 }
    }
    var canDeepClimb: Bool {
        switch self { case .swerve: return false; case .tank: return true; case .mecanum: return false }
    }
    var canStrafe: Bool {
        switch self { case .swerve: return true; case .tank: return false; case .mecanum: return true }
    }

    var unlockLevel: Int {
        switch self { case .tank: return 1; case .mecanum: return 3; case .swerve: return 8 }
    }
}

// MARK: - Frame

enum FrameChoice: String, CaseIterable, Identifiable {
    case aluminum  = "Aluminum Frame"
    case steel     = "Steel Frame"
    case composite = "Composite Frame"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .aluminum:  return "square.grid.3x3"
        case .steel:     return "shield.fill"
        case .composite: return "wind"
        }
    }

    var shortLabel: String {
        switch self { case .aluminum: return "Aluminum"; case .steel: return "Steel"; case .composite: return "Composite" }
    }

    var description: String {
        switch self {
        case .aluminum:  return "Industry standard. Good balance of weight, strength, and cost."
        case .steel:     return "Heavy but extremely durable. Absorbs impacts and resists bending."
        case .composite: return "Carbon fiber panels reduce weight significantly. Fragile under impact."
        }
    }

    var pros: String {
        switch self {
        case .aluminum:  return "Balanced stats, affordable, easy to fabricate"
        case .steel:     return "Most durable (+5% reliability), best for defense"
        case .composite: return "Lightest (+0.15 speed), best for fast cycling"
        }
    }

    var cons: String {
        switch self {
        case .aluminum:  return "No standout advantage in any area"
        case .steel:     return "Heaviest (-0.20 speed), slows everything down"
        case .composite: return "Fragile (-3% reliability), breaks under contact"
        }
    }

    var color: Color {
        switch self { case .aluminum: return .gray; case .steel: return .blue; case .composite: return .green }
    }

    var speedModifier: Float {
        switch self { case .aluminum: return 0; case .steel: return -0.20; case .composite: return 0.15 }
    }
    var reliabilityModifier: Float {
        switch self { case .aluminum: return 0; case .steel: return 0.05; case .composite: return -0.03 }
    }
    var weightValue: Float {
        switch self { case .aluminum: return 10; case .steel: return 14; case .composite: return 7 }
    }

    var unlockLevel: Int {
        switch self { case .aluminum: return 1; case .composite: return 5; case .steel: return 10 }
    }
}

// MARK: - Manipulator

enum ManipulatorChoice: String, CaseIterable, Identifiable {
    case elevator = "Cascading Elevator"
    case arm      = "Pivot Arm"
    case shooter  = "Flywheel Shooter"
    case simple   = "Simple Tray"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .elevator: return "arrow.up.and.down"
        case .arm:      return "arrow.up.right"
        case .shooter:  return "scope"
        case .simple:   return "tray.fill"
        }
    }

    var shortLabel: String {
        switch self { case .elevator: return "Elevator"; case .arm: return "Arm"; case .shooter: return "Shooter"; case .simple: return "Tray" }
    }

    var description: String {
        switch self {
        case .elevator: return "Telescoping stages reach all heights. Heavy but the only way to score High."
        case .arm:      return "Rotating arm reaches Mid targets. Good balance of speed and reach."
        case .shooter:  return "Dual flywheels launch pieces at targets. Can score from a distance."
        case .simple:   return "Low-profile tray for ground/low scoring only. Lightest and fastest."
        }
    }

    var pros: String {
        switch self {
        case .elevator: return "Reaches High targets (max points), versatile"
        case .arm:      return "Reaches Mid, balanced speed, moderate weight"
        case .shooter:  return "Scores from distance, reaches Mid effectively"
        case .simple:   return "Fastest scoring (0.6s), lightest (+0.15 speed)"
        }
    }

    var cons: String {
        switch self {
        case .elevator: return "Heavy (-0.25 speed), slow scoring (1.6s), less reliable"
        case .arm:      return "Can't reach High targets, mid-range stats"
        case .shooter:  return "Less accurate (-5% reliability), can't place precisely"
        case .simple:   return "Ground/Low only, lowest scoring potential per piece"
        }
    }

    var color: Color {
        switch self { case .elevator: return .purple; case .arm: return .orange; case .shooter: return .red; case .simple: return .green }
    }

    var maxReach: ScoringHeight {
        switch self { case .elevator: return .high; case .arm: return .mid; case .shooter: return .mid; case .simple: return .low }
    }

    var scoringTime: Double {
        switch self { case .elevator: return 1.6; case .arm: return 1.2; case .shooter: return 1.0; case .simple: return 0.6 }
    }

    var speedModifier: Float {
        switch self { case .elevator: return -0.25; case .arm: return -0.10; case .shooter: return -0.15; case .simple: return 0.15 }
    }

    var reliabilityModifier: Float {
        switch self { case .elevator: return -0.05; case .arm: return 0; case .shooter: return -0.05; case .simple: return 0.05 }
    }

    var weightValue: Float {
        switch self { case .elevator: return 8; case .arm: return 5; case .shooter: return 6; case .simple: return 2 }
    }

    var canShoot: Bool { self == .shooter }

    var maxLevel: Int { maxReach.rawValue }

    var unlockLevel: Int {
        switch self { case .simple: return 1; case .arm: return 4; case .shooter: return 9; case .elevator: return 13 }
    }
}

// MARK: - Intake

enum IntakeChoice: String, CaseIterable, Identifiable {
    case roller    = "Roller Intake"
    case claw      = "Claw Gripper"
    case pneumatic = "Pneumatic Gripper"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .roller:    return "gearshape.2.fill"
        case .claw:      return "hand.point.up.fill"
        case .pneumatic: return "lungs.fill"
        }
    }

    var shortLabel: String {
        switch self { case .roller: return "Rollers"; case .claw: return "Claw"; case .pneumatic: return "Pneumatic" }
    }

    var description: String {
        switch self {
        case .roller:    return "Spinning compliant wheels pull pieces in quickly. Best for balls and rings."
        case .claw:      return "Mechanical fingers grip pieces precisely. Best for cubes and cones."
        case .pneumatic: return "Air-powered grippers actuate instantly. Fastest pickup, heaviest system."
        }
    }

    var pros: String {
        switch self {
        case .roller:    return "Fast pickup (0.5s), great for balls/rings"
        case .claw:      return "Most reliable (+8%), precise grip, great for cubes/cones"
        case .pneumatic: return "Fastest pickup (0.3s), strong grip force"
        }
    }

    var cons: String {
        switch self {
        case .roller:    return "Less reliable (-5%), can fumble pieces"
        case .claw:      return "Slow pickup (1.0s), loses time each cycle"
        case .pneumatic: return "Heavy (needs compressor), moderate reliability"
        }
    }

    var color: Color {
        switch self { case .roller: return .teal; case .claw: return .yellow; case .pneumatic: return .indigo }
    }

    var pickupTime: Double {
        switch self { case .roller: return 0.5; case .claw: return 1.0; case .pneumatic: return 0.3 }
    }

    var reliabilityModifier: Float {
        switch self { case .roller: return -0.05; case .claw: return 0.08; case .pneumatic: return 0.0 }
    }

    var weightValue: Float {
        switch self { case .roller: return 3; case .claw: return 4; case .pneumatic: return 6 }
    }

    var unlockLevel: Int {
        switch self { case .roller: return 1; case .claw: return 6; case .pneumatic: return 11 }
    }
}

// ============================================================================
// MARK: - Robot Configuration
// ============================================================================

// MARK: - Robot Build

struct RobotBuild: Equatable {
    var drivetrain: DrivetrainChoice = .tank
    var frame: FrameChoice = .aluminum
    var manipulator: ManipulatorChoice = .arm
    var intake: IntakeChoice = .roller
}

// MARK: - Robot Role

enum RobotRole: String, CaseIterable, Identifiable {
    case scorer   = "Scorer"
    case cycler   = "Cycler"
    case defender = "Defender"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .scorer:   return "target"
        case .cycler:   return "arrow.triangle.2.circlepath"
        case .defender: return "shield.fill"
        }
    }

    var description: String {
        switch self {
        case .scorer:   return "Places pieces on higher targets. Slower but maximizes points per piece."
        case .cycler:   return "Rapid piece delivery to low targets. Fast cycles, high volume."
        case .defender: return "Disrupts opponents by blocking lanes. Tough and fast, scores when open."
        }
    }
}

// MARK: - Robot Stats

struct RobotStats {
    let maxSpeed: Float
    let acceleration: Float
    let turnRate: Float
    let scoringTime: Double
    let pickupTime: Double
    let reliability: Double
    let maxReachHeight: ScoringHeight
    let pushPower: Float
    let canDeepClimb: Bool
    let canStrafe: Bool
    let canShoot: Bool
    let totalWeight: Float
}

// MARK: - Superstructure Type (visual)

enum SuperstructureType: String {
    case elevator
    case arm
    case shooter
    case intake
    case wedge
}

// MARK: - Robot Config

struct RobotConfig: Identifiable {
    let id: Int
    let alliance: Alliance
    let role: RobotRole
    let stats: RobotStats
    let superstructure: SuperstructureType
    let build: RobotBuild
    let teamNumber: String
    let startPosition: SIMD2<Float>
}

// MARK: - Robot State

enum RobotState: String {
    case idle           = "Idle"
    case driving        = "Driving"
    case pickingUp      = "Picking Up"
    case scoring        = "Scoring"
    case defending      = "Defending"
    case headingEndgame = "→ Endgame"
    case climbing       = "Climbing"
    case parked         = "Parked"
    case stalled        = "Stalled!"
    case autoPath       = "Auto Path"
}

// ============================================================================
// MARK: - Strategy & Callouts
// ============================================================================

// MARK: - Alliance Strategy

enum AllianceStrategy: String, CaseIterable, Identifiable {
    case aggressive = "Aggressive Scoring"
    case balanced   = "Balanced"
    case defensive  = "Defense + Cycles"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .aggressive: return "flame.fill"
        case .balanced:   return "scalemass.fill"
        case .defensive:  return "shield.lefthalf.filled"
        }
    }

    var color: Color {
        switch self {
        case .aggressive: return .orange
        case .balanced:   return .cyan
        case .defensive:  return .green
        }
    }

    var description: String {
        switch self {
        case .aggressive: return "All-in on scoring. High risk, high reward. No dedicated defense."
        case .balanced:   return "Mix of scoring and defense. Adaptable mid-match."
        case .defensive:  return "One bot defends while others cycle. Slows opponents, wins by margin."
        }
    }

    var basePolicy: StrategyPolicy {
        switch self {
        case .aggressive: return StrategyPolicy(scoringWeight: 0.9, defenseWeight: 0.05, endgameWeight: 0.05)
        case .balanced:   return StrategyPolicy(scoringWeight: 0.6, defenseWeight: 0.2, endgameWeight: 0.2)
        case .defensive:  return StrategyPolicy(scoringWeight: 0.4, defenseWeight: 0.45, endgameWeight: 0.15)
        }
    }
}

// MARK: - Strategy Policy

struct StrategyPolicy {
    var scoringWeight: Double
    var defenseWeight: Double
    var endgameWeight: Double
    var preferHighLevel: Bool = false
    var spreadOut: Bool = false

    func applying(callout: Callout) -> StrategyPolicy {
        var p = self
        switch callout {
        case .pushScoring:  p.scoringWeight += 0.3
        case .playDefense:  p.defenseWeight += 0.4
        case .endgameNow:   p.endgameWeight += 0.5
        case .focusHigh:    p.preferHighLevel = true; p.scoringWeight += 0.15
        case .spreadOut:    p.spreadOut = true
        case .allOut:       p.scoringWeight = 1.0; p.defenseWeight = 0
        }
        return p
    }

    var dominantMode: String {
        if endgameWeight >= scoringWeight && endgameWeight >= defenseWeight { return "Endgame Push" }
        else if defenseWeight >= scoringWeight { return "Defense Mode" }
        else { return "Scoring Mode" }
    }
}

// MARK: - Auto Plan

enum AutoPlan: String, CaseIterable, Identifiable {
    case safe     = "Safe"
    case moderate = "Moderate"
    case risky    = "Risky"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .safe:     return "shield.fill"
        case .moderate: return "gauge.with.dots.needle.50percent"
        case .risky:    return "bolt.fill"
        }
    }

    var color: Color {
        switch self { case .safe: return .green; case .moderate: return .yellow; case .risky: return .red }
    }

    var description: String {
        switch self {
        case .safe:     return "Cross line + score 1 piece. Reliable guaranteed points."
        case .moderate: return "Score 2 pieces during auto. Needs decent speed and accuracy."
        case .risky:    return "Attempt 3 pieces in auto. High ceiling but real stall chance."
        }
    }

    var piecesAttempted: Int {
        switch self { case .safe: return 1; case .moderate: return 2; case .risky: return 3 }
    }

    var successRate: Double {
        switch self { case .safe: return 0.95; case .moderate: return 0.75; case .risky: return 0.45 }
    }
}

// MARK: - Callout

enum Callout: String, CaseIterable, Identifiable {
    case pushScoring = "Push Scoring"
    case playDefense = "Play Defense"
    case endgameNow  = "Endgame Now"
    case focusHigh   = "Focus High"
    case spreadOut   = "Spread Out"
    case allOut      = "All Out"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .pushScoring: return "scope"
        case .playDefense: return "shield.fill"
        case .endgameNow:  return "flag.checkered"
        case .focusHigh:   return "arrow.up.to.line"
        case .spreadOut:   return "arrow.left.and.right"
        case .allOut:      return "flame.fill"
        }
    }

    var color: Color {
        switch self {
        case .pushScoring: return .orange
        case .playDefense: return .green
        case .endgameNow:  return .purple
        case .focusHigh:   return .red
        case .spreadOut:   return .cyan
        case .allOut:      return .yellow
        }
    }

    var subtitle: String {
        switch self {
        case .pushScoring: return "Boost scoring"
        case .playDefense: return "Block opponents"
        case .endgameNow:  return "Rush endgame"
        case .focusHigh:   return "Target high zones"
        case .spreadOut:   return "Reduce congestion"
        case .allOut:      return "Max aggression"
        }
    }

    func isAvailable(during period: MatchPeriod) -> Bool {
        period == .teleop || period == .endgame
    }
}

// MARK: - Callout Event

struct CalloutEvent: Equatable {
    let callout: Callout
    let matchTime: Double
    let redScoreAtTime: Int
    let blueScoreAtTime: Int
}

// MARK: - Match Period

enum MatchPeriod: String {
    case auto     = "AUTO"
    case teleop   = "TELEOP"
    case endgame  = "ENDGAME"
    case finished = "FINAL"
}

// MARK: - Match Timing

enum MatchTiming {
    static let autoDuration: Double = 15.0
    static let teleopStart: Double = 15.0
    static let endgameStart: Double = 135.0
    static let totalDuration: Double = 150.0
}

// MARK: - Coaching Tip

struct CoachingTip: Equatable {
    let headline: String
    let detail: String
    let highlightRobotId: Int?
}

// ============================================================================
// MARK: - Match Result
// ============================================================================

struct MatchResult {
    let game: GeneratedGame
    let playerStrategy: AllianceStrategy
    let playerRole: RobotRole
    let playerAuto: AutoPlan
    let playerBuild: RobotBuild
    let redScore: Int
    let blueScore: Int
    let redBreakdown: ScoreBreakdown
    let blueBreakdown: ScoreBreakdown
    let calloutsUsed: [Callout]
    let calloutEvents: [CalloutEvent]
    let playerRobotScored: Int
    let playerRobotCycled: Int
    let didPlayerStall: Bool
    let matchDuration: Double
    let slowMoUsed: Bool
    let buildMatchScore: Int

    var playerWon: Bool { redScore > blueScore }
    var margin: Int { abs(redScore - blueScore) }
}

struct ScoreBreakdown {
    var autoPoints: Int = 0
    var teleopPoints: Int = 0
    var endgamePoints: Int = 0
    var totalPieces: Int = 0
    var groundScores: Int = 0
    var lowScores: Int = 0
    var midScores: Int = 0
    var highScores: Int = 0
    var total: Int { autoPoints + teleopPoints + endgamePoints }
}

// ============================================================================
// MARK: - Field Layout
// ============================================================================

enum FieldLayout {
    static let fieldWidth: Float  = 8.23
    static let fieldLength: Float = 4.03
    static let halfWidth: Float   = 4.115
    static let halfLength: Float  = 2.015

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

    static let redAutoLine: Float = 3.42
    static let blueAutoLine: Float = -3.42

    static let endgameRedPos  = SIMD2<Float>( 0.35, 0.0)
    static let endgameBluePos = SIMD2<Float>(-0.35, 0.0)
}

// ============================================================================
// MARK: - Game Generator
// ============================================================================

enum GameGenerator {

    static func generate(seed: UInt64) -> GeneratedGame {
        var rng = SeededRNG(seed: seed)

        let archetype = GameArchetype.allCases[rng.nextInt(0..<GameArchetype.allCases.count)]
        let theme = FieldTheme.allCases[rng.nextInt(0..<FieldTheme.allCases.count)]
        let name = generateName(archetype: archetype, rng: &rng)
        let pieces = generatePieces(archetype: archetype, rng: &rng)
        let zones = generateScoringZones(archetype: archetype, rng: &rng)
        let endgame = generateEndgame(archetype: archetype, rng: &rng)
        let obstacles = generateObstacles(archetype: archetype, rng: &rng)

        let pickups = [
            PickupStation(id: 0, position: SIMD2(3.70, -1.20), alliance: .red),
            PickupStation(id: 1, position: SIMD2(3.70,  1.20), alliance: .red),
            PickupStation(id: 2, position: SIMD2(-3.70, -1.20), alliance: .blue),
            PickupStation(id: 3, position: SIMD2(-3.70,  1.20), alliance: .blue),
        ]

        return GeneratedGame(
            name: name,
            archetype: archetype,
            gamePieces: pieces,
            scoringZones: zones,
            pickupStations: pickups,
            endgameChallenge: endgame,
            obstacles: obstacles,
            autoLeavePoints: 3,
            theme: theme
        )
    }

    // MARK: - Name Generation

    private static func generateName(archetype: GameArchetype, rng: inout SeededRNG) -> String {
        let adjectives = [
            "Stellar", "Rapid", "Iron", "Quantum", "Voltage", "Titan", "Nova", "Apex", "Turbo", "Hyper",
            "Crimson", "Cobalt", "Neon", "Omega", "Phoenix", "Storm", "Fusion", "Cosmic", "Thunder", "Vortex",
            "Blazing", "Frozen", "Shadow", "Lunar", "Solar", "Atomic", "Inferno", "Crystal", "Phantom", "Radiant"
        ]
        let nouns: [String]
        switch archetype {
        case .vertical:     nouns = ["Heights", "Ascent", "Summit", "Pinnacle", "Skyreach", "Zenith", "Tower", "Spire"]
        case .speed:        nouns = ["Sprint", "Dash", "Blitz", "Rush", "Velocity", "Surge", "Flash", "Tempo"]
        case .precision:    nouns = ["Strike", "Focus", "Aim", "Precision", "Marksman", "Scope", "Bullseye", "Sniper"]
        case .power:        nouns = ["Forge", "Clash", "Siege", "Fortress", "Bastion", "Rampart", "Anvil", "Juggernaut"]
        case .classic:      nouns = ["Challenge", "Arena", "Circuit", "Showdown", "Gauntlet", "Championship", "Rally", "Invitational"]
        case .endgameFocus: nouns = ["Finale", "Climax", "Countdown", "Crescendo", "Overtime", "Last Stand", "Endzone", "Clutch"]
        case .hybrid:       nouns = ["Spectrum", "Fusion", "Nexus", "Matrix", "Synergy", "Crossover", "Catalyst", "Mosaic"]
        case .defenseArena: nouns = ["Warzone", "Stronghold", "Barricade", "Lockdown", "Bunker", "Citadel", "Bulwark", "Blockade"]
        }

        let adj = adjectives[rng.nextInt(0..<adjectives.count)]
        let noun = nouns[rng.nextInt(0..<nouns.count)]
        return "\(adj) \(noun)"
    }

    // MARK: - Piece Generation

    private static func generatePieces(archetype: GameArchetype, rng: inout SeededRNG) -> [GamePieceKind] {
        let allPieces = GamePieceKind.allCases
        let primary = allPieces[rng.nextInt(0..<allPieces.count)]

        if rng.nextBool(probability: 0.4) {
            var secondary = allPieces[rng.nextInt(0..<allPieces.count)]
            while secondary == primary { secondary = allPieces[rng.nextInt(0..<allPieces.count)] }
            return [primary, secondary]
        }
        return [primary]
    }

    // MARK: - Scoring Zone Generation

    private static func generateScoringZones(archetype: GameArchetype, rng: inout SeededRNG) -> [ScoringZone] {
        var zones: [ScoringZone] = []
        var zoneId = 0

        // Define height distribution per archetype
        let heights: [ScoringHeight]
        switch archetype {
        case .vertical:
            heights = [.ground, .low, .mid, .high]
        case .speed:
            heights = [.ground, .ground, .ground, .low]
        case .precision:
            heights = [.ground, .mid, .mid, .high]
        case .power:
            heights = [.ground, .ground, .low, .mid]
        case .classic:
            heights = [.ground, .low, .mid, .high]
        case .endgameFocus:
            heights = [.ground, .low, .low, .mid]
        case .hybrid:
            heights = [.ground, .low, .mid, .high]
        case .defenseArena:
            heights = [.ground, .ground, .low, .low]
        }

        // Z positions for scoring zones (spread across field width)
        let zPositions: [Float] = [-1.10, -0.35, 0.35, 1.10]

        // Generate for red alliance
        for (i, height) in heights.enumerated() {
            let xBase: Float = 1.8 + rng.nextFloat() * 0.8  // 1.8 to 2.6
            let z = zPositions[i % zPositions.count]
            let autoPts = pointsForHeight(height, isAuto: true)
            let telePts = pointsForHeight(height, isAuto: false)

            zones.append(ScoringZone(
                id: zoneId, name: "\(height.displayName) Target \(i + 1)",
                position: SIMD2(xBase, z), height: height,
                pointsAuto: autoPts, pointsTeleop: telePts, alliance: .red
            ))
            zoneId += 1

            // Mirror for blue
            zones.append(ScoringZone(
                id: zoneId, name: "\(height.displayName) Target \(i + 1)",
                position: SIMD2(-xBase, z), height: height,
                pointsAuto: autoPts, pointsTeleop: telePts, alliance: .blue
            ))
            zoneId += 1
        }

        return zones
    }

    private static func pointsForHeight(_ height: ScoringHeight, isAuto: Bool) -> Int {
        let base: Int
        switch height {
        case .ground: base = 2
        case .low:    base = 3
        case .mid:    base = 5
        case .high:   base = 7
        }
        return isAuto ? base + 1 : base
    }

    // MARK: - Endgame Generation

    private static func generateEndgame(archetype: GameArchetype, rng: inout SeededRNG) -> EndgameChallenge {
        switch archetype {
        case .vertical:
            return .climb(difficulty: .high, points: 12)
        case .speed:
            return .park(points: 2)
        case .precision:
            return .balance(points: 8)
        case .power:
            return .climb(difficulty: .low, points: 6)
        case .classic:
            let options: [EndgameChallenge] = [
                .climb(difficulty: .mid, points: 8),
                .climb(difficulty: .low, points: 6),
                .balance(points: 8),
            ]
            return options[rng.nextInt(0..<options.count)]
        case .endgameFocus:
            // Endgame is worth a LOT here
            let options: [EndgameChallenge] = [
                .climb(difficulty: .high, points: 20),
                .climb(difficulty: .mid, points: 15),
                .balance(points: 18),
            ]
            return options[rng.nextInt(0..<options.count)]
        case .hybrid:
            let options: [EndgameChallenge] = [
                .climb(difficulty: .mid, points: 10),
                .balance(points: 10),
            ]
            return options[rng.nextInt(0..<options.count)]
        case .defenseArena:
            return .climb(difficulty: .low, points: 4)
        }
    }

    // MARK: - Obstacle Generation

    private static func generateObstacles(archetype: GameArchetype, rng: inout SeededRNG) -> [FieldObstacle] {
        var obstacles: [FieldObstacle] = []

        // Center bridge is always present (like the old barge)
        obstacles.append(FieldObstacle(
            id: 0, kind: .bridge,
            position: SIMD2(0, 0),
            size: SIMD2(0.56, 4.0)
        ))

        // Power Play and Defense Arena get extra barriers
        if archetype == .power || archetype == .defenseArena {
            obstacles.append(FieldObstacle(
                id: 1, kind: .barrier,
                position: SIMD2(1.5, 0),
                size: SIMD2(0.10, 1.2)
            ))
            obstacles.append(FieldObstacle(
                id: 2, kind: .barrier,
                position: SIMD2(-1.5, 0),
                size: SIMD2(0.10, 1.2)
            ))
        }

        // Defense Arena gets even more obstacles
        if archetype == .defenseArena {
            // Additional barriers near scoring zones
            obstacles.append(FieldObstacle(
                id: obstacles.count, kind: .barrier,
                position: SIMD2(2.2, 0.6),
                size: SIMD2(0.10, 0.8)
            ))
            obstacles.append(FieldObstacle(
                id: obstacles.count + 1, kind: .barrier,
                position: SIMD2(-2.2, -0.6),
                size: SIMD2(0.10, 0.8)
            ))
        }

        // Random chance of ramp
        if rng.nextBool(probability: 0.3) && archetype != .speed {
            let side: Float = rng.nextBool() ? 1.0 : -1.0
            obstacles.append(FieldObstacle(
                id: obstacles.count, kind: .ramp,
                position: SIMD2(side * 1.0, rng.nextFloat() * 1.5 - 0.75),
                size: SIMD2(0.5, 0.8)
            ))
        }

        // Hybrid gets a ramp on each side
        if archetype == .hybrid {
            obstacles.append(FieldObstacle(
                id: obstacles.count, kind: .ramp,
                position: SIMD2(1.2, 0.5),
                size: SIMD2(0.5, 0.7)
            ))
            obstacles.append(FieldObstacle(
                id: obstacles.count + 1, kind: .ramp,
                position: SIMD2(-1.2, -0.5),
                size: SIMD2(0.5, 0.7)
            ))
        }

        return obstacles
    }
}

// ============================================================================
// MARK: - Robot Factory
// ============================================================================

enum RobotFactory {

    private static let redTeamNumbers  = ["9999", "2468", "1357"]
    private static let blueTeamNumbers = ["254", "1678", "118"]

    static func buildRobots(playerRole: RobotRole, strategy: AllianceStrategy,
                            playerBuild: RobotBuild, seed: UInt64 = 42) -> [RobotConfig] {
        var rng = SeededRNG(seed: seed)
        var configs: [RobotConfig] = []

        // Player robot (red alliance, id 0)
        let playerStats = statsForBuild(playerBuild, role: playerRole, boost: true)
        configs.append(RobotConfig(
            id: 0, alliance: .red, role: playerRole,
            stats: playerStats,
            superstructure: superstructureFor(playerBuild, role: playerRole),
            build: playerBuild,
            teamNumber: redTeamNumbers[0], startPosition: FieldLayout.redStarts[0]
        ))

        // Red teammates
        let comp1Role = complementRole1(for: strategy, playerRole: playerRole)
        let comp1Build = randomBuild(for: comp1Role, rng: &rng)
        configs.append(RobotConfig(
            id: 1, alliance: .red, role: comp1Role,
            stats: statsForBuild(comp1Build, role: comp1Role, boost: false),
            superstructure: superstructureFor(comp1Build, role: comp1Role),
            build: comp1Build,
            teamNumber: redTeamNumbers[1], startPosition: FieldLayout.redStarts[1]
        ))

        let comp2Role = complementRole2(for: strategy, playerRole: playerRole)
        let comp2Build = randomBuild(for: comp2Role, rng: &rng)
        configs.append(RobotConfig(
            id: 2, alliance: .red, role: comp2Role,
            stats: statsForBuild(comp2Build, role: comp2Role, boost: false),
            superstructure: superstructureFor(comp2Build, role: comp2Role),
            build: comp2Build,
            teamNumber: redTeamNumbers[2], startPosition: FieldLayout.redStarts[2]
        ))

        // Blue alliance (opponents)
        let blueRoles: [RobotRole] = [.scorer, .cycler, .defender]
        for (i, role) in blueRoles.enumerated() {
            let build = randomBuild(for: role, rng: &rng)
            configs.append(RobotConfig(
                id: 3 + i, alliance: .blue, role: role,
                stats: statsForBuild(build, role: role, boost: false),
                superstructure: superstructureFor(build, role: role),
                build: build,
                teamNumber: blueTeamNumbers[i], startPosition: FieldLayout.blueStarts[i]
            ))
        }

        return configs
    }

    // MARK: - Stats Calculation

    static func statsForBuild(_ build: RobotBuild, role: RobotRole, boost: Bool) -> RobotStats {
        let b: Float = boost ? 0.1 : 0.0

        let dt = build.drivetrain
        let fr = build.frame
        let mp = build.manipulator
        let ink = build.intake

        // Role adjustments
        let roleSpeedMod: Float
        let roleScoringMod: Double
        switch role {
        case .scorer:   roleSpeedMod = -0.15; roleScoringMod = -0.10
        case .cycler:   roleSpeedMod =  0.20; roleScoringMod =  0.05
        case .defender: roleSpeedMod =  0.30; roleScoringMod =  0.30
        }

        let totalWeight = dt.weight + fr.weightValue + mp.weightValue + ink.weightValue
        let weightPenalty: Float = max(0, (totalWeight - 35) * 0.01)

        let finalSpeed = max(1.0, dt.baseSpeed + fr.speedModifier + mp.speedModifier + roleSpeedMod + b - weightPenalty)
        let finalReliability = min(0.98, max(0.50,
            Double(dt.baseReliability + fr.reliabilityModifier + mp.reliabilityModifier + ink.reliabilityModifier)))

        return RobotStats(
            maxSpeed: finalSpeed,
            acceleration: dt == .tank ? 1.5 : 2.0,
            turnRate: dt.turnRate,
            scoringTime: max(0.4, mp.scoringTime + roleScoringMod),
            pickupTime: ink.pickupTime,
            reliability: finalReliability,
            maxReachHeight: mp.maxReach,
            pushPower: dt.pushPower,
            canDeepClimb: dt.canDeepClimb,
            canStrafe: dt.canStrafe,
            canShoot: mp.canShoot,
            totalWeight: totalWeight
        )
    }

    // MARK: - Random Build

    private static func randomBuild(for role: RobotRole, rng: inout SeededRNG) -> RobotBuild {
        let dts = DrivetrainChoice.allCases
        let frs = FrameChoice.allCases
        let mps = ManipulatorChoice.allCases
        let inks = IntakeChoice.allCases

        let dt: DrivetrainChoice
        let mp: ManipulatorChoice

        switch role {
        case .scorer:
            dt = rng.nextDouble() < 0.4 ? .swerve : (rng.nextDouble() < 0.7 ? .tank : .mecanum)
            let r = rng.nextDouble()
            mp = r < 0.40 ? .elevator : (r < 0.75 ? .arm : (r < 0.90 ? .shooter : .simple))
        case .cycler:
            dt = rng.nextDouble() < 0.50 ? .swerve : (rng.nextDouble() < 0.7 ? .mecanum : .tank)
            let r = rng.nextDouble()
            mp = r < 0.10 ? .elevator : (r < 0.40 ? .arm : (r < 0.55 ? .shooter : .simple))
        case .defender:
            dt = rng.nextDouble() < 0.20 ? .swerve : (rng.nextDouble() < 0.3 ? .mecanum : .tank)
            let r = rng.nextDouble()
            mp = r < 0.05 ? .elevator : (r < 0.25 ? .arm : (r < 0.30 ? .shooter : .simple))
        }

        let fr = frs[rng.nextInt(0..<frs.count)]
        let ink = inks[rng.nextInt(0..<inks.count)]

        return RobotBuild(drivetrain: dt, frame: fr, manipulator: mp, intake: ink)
    }

    static func superstructureFor(_ build: RobotBuild, role: RobotRole) -> SuperstructureType {
        if role == .defender && build.manipulator == .simple { return .wedge }
        switch build.manipulator {
        case .elevator: return .elevator
        case .arm:      return .arm
        case .shooter:  return .shooter
        case .simple:   return .intake
        }
    }

    static func previewConfig(build: RobotBuild, role: RobotRole = .scorer) -> RobotConfig {
        RobotConfig(
            id: 99, alliance: .red, role: role,
            stats: statsForBuild(build, role: role, boost: false),
            superstructure: superstructureFor(build, role: role),
            build: build, teamNumber: "0000", startPosition: SIMD2(0, 0)
        )
    }

    private static func complementRole1(for strategy: AllianceStrategy, playerRole: RobotRole) -> RobotRole {
        switch strategy {
        case .aggressive: return playerRole == .scorer ? .cycler : .scorer
        case .balanced:   return .cycler
        case .defensive:  return playerRole == .defender ? .cycler : .defender
        }
    }

    private static func complementRole2(for strategy: AllianceStrategy, playerRole: RobotRole) -> RobotRole {
        switch strategy {
        case .aggressive: return .cycler
        case .balanced:   return playerRole == .defender ? .scorer : .cycler
        case .defensive:  return .cycler
        }
    }
}

// ============================================================================
// MARK: - Progression System
// ============================================================================

// MARK: - Round Record

struct RoundRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let gameName: String
    let archetype: String
    let buildMatchScore: Int
    let won: Bool
    let tied: Bool
    let redScore: Int
    let blueScore: Int
    let date: Date

    init(from result: MatchResult) {
        self.id = UUID()
        self.gameName = result.game.name
        self.archetype = result.game.archetype.rawValue
        self.buildMatchScore = result.buildMatchScore
        self.won = result.playerWon
        self.tied = result.margin == 0
        self.redScore = result.redScore
        self.blueScore = result.blueScore
        self.date = Date()
    }
}

// MARK: - Achievement

enum Achievement: String, CaseIterable, Identifiable, Codable {
    case firstMatch       = "Rookie"
    case firstWin         = "Victor"
    case analyzer         = "Analyzer"
    case perfectBuild     = "Perfect Engineer"
    case strategist       = "Strategist"
    case speedDemon       = "Speed Demon"
    case skyReacher       = "Sky Reacher"
    case winStreak5       = "On Fire"
    case veteran          = "Veteran"
    case masterBuilder    = "Master Builder"
    case fullArsenal      = "Full Arsenal"
    case comebacker       = "Comeback Kid"
    case tournamentWinner = "Champion"
    case tournamentSweep  = "Clean Sweep"
    case endgameClutch    = "Clutch Player"
    case defenseAce       = "Iron Wall"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .firstMatch:       return "star.fill"
        case .firstWin:         return "trophy.fill"
        case .analyzer:         return "magnifyingglass"
        case .perfectBuild:     return "wrench.and.screwdriver.fill"
        case .strategist:       return "megaphone.fill"
        case .speedDemon:       return "hare.fill"
        case .skyReacher:       return "arrow.up.circle.fill"
        case .winStreak5:       return "flame.fill"
        case .veteran:          return "shield.fill"
        case .masterBuilder:    return "hammer.fill"
        case .fullArsenal:      return "shippingbox.fill"
        case .comebacker:       return "arrow.turn.up.right"
        case .tournamentWinner: return "crown.fill"
        case .tournamentSweep:  return "medal.fill"
        case .endgameClutch:    return "flag.checkered"
        case .defenseAce:       return "shield.lefthalf.filled"
        }
    }

    var description: String {
        switch self {
        case .firstMatch:       return "Complete your first match"
        case .firstWin:         return "Win a match"
        case .analyzer:         return "Score 75+ on build match"
        case .perfectBuild:     return "Score 90+ on build match"
        case .strategist:       return "Use 3+ callouts in a match"
        case .speedDemon:       return "Win a Speed Rush game"
        case .skyReacher:       return "Win a Vertical Challenge game"
        case .winStreak5:       return "Win 5 matches in a row"
        case .veteran:          return "Play 10 rounds"
        case .masterBuilder:    return "Reach level 10"
        case .fullArsenal:      return "Unlock all robot parts"
        case .comebacker:       return "Win after trailing by 10+"
        case .tournamentWinner: return "Win a tournament series"
        case .tournamentSweep:  return "Win all matches in a tournament"
        case .endgameClutch:    return "Win an Endgame Focus game"
        case .defenseAce:       return "Win a Defense Arena game"
        }
    }

    var color: Color {
        switch self {
        case .firstMatch:       return .gray
        case .firstWin:         return .yellow
        case .analyzer:         return .cyan
        case .perfectBuild:     return .purple
        case .strategist:       return .orange
        case .speedDemon:       return .mint
        case .skyReacher:       return .indigo
        case .winStreak5:       return .red
        case .veteran:          return .green
        case .masterBuilder:    return .blue
        case .fullArsenal:      return .pink
        case .comebacker:       return .teal
        case .tournamentWinner: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case .tournamentSweep:  return Color(red: 0.85, green: 0.65, blue: 0.13)
        case .endgameClutch:    return .indigo
        case .defenseAce:       return .pink
        }
    }

    var xpReward: Int {
        switch self {
        case .tournamentWinner, .tournamentSweep: return 100
        default: return 50
        }
    }
}

// MARK: - XP Rewards

enum XPReward {
    static let matchComplete = 20
    static let matchWin = 30
    static let buildScoreBonus = 1  // per build match point above 50
    static let calloutUsed = 5
    static let noStall = 10
    static let achievementBonus = 50

    static func calculate(from result: MatchResult) -> (total: Int, breakdown: [(String, Int)]) {
        var items: [(String, Int)] = []
        items.append(("Match Complete", matchComplete))
        if result.playerWon {
            items.append(("Victory Bonus", matchWin))
        }
        if result.buildMatchScore > 50 {
            let bonus = (result.buildMatchScore - 50) * buildScoreBonus
            items.append(("Build Match (\(result.buildMatchScore)/100)", bonus))
        }
        if !result.calloutsUsed.isEmpty {
            let bonus = result.calloutsUsed.count * calloutUsed
            items.append(("Callouts Used (\(result.calloutsUsed.count))", bonus))
        }
        if !result.didPlayerStall {
            items.append(("No Stalls", noStall))
        }
        let total = items.reduce(0) { $0 + $1.1 }
        return (total, items)
    }
}

// MARK: - Player Profile

struct PlayerProfile: Codable, Equatable {
    var level: Int = 1
    var xp: Int = 0
    var totalRounds: Int = 0
    var wins: Int = 0
    var losses: Int = 0
    var ties: Int = 0
    var bestBuildScore: Int = 0
    var totalBuildScore: Int = 0
    var winStreak: Int = 0
    var bestWinStreak: Int = 0
    var earnedAchievements: Set<String> = []
    var roundHistory: [RoundRecord] = []

    var averageBuildScore: Int {
        totalRounds > 0 ? totalBuildScore / totalRounds : 0
    }

    var xpForNextLevel: Int { level * 80 + 40 }
    var xpProgress: Double { Double(xp) / Double(xpForNextLevel) }

    var winRate: Double {
        totalRounds > 0 ? Double(wins) / Double(totalRounds) * 100 : 0
    }

    mutating func addXP(_ amount: Int) -> Bool {
        xp += amount
        var didLevel = false
        while xp >= xpForNextLevel {
            xp -= xpForNextLevel
            level += 1
            didLevel = true
        }
        return didLevel
    }

    func isUnlocked(_ drivetrain: DrivetrainChoice) -> Bool { level >= drivetrain.unlockLevel }
    func isUnlocked(_ frame: FrameChoice) -> Bool { level >= frame.unlockLevel }
    func isUnlocked(_ manipulator: ManipulatorChoice) -> Bool { level >= manipulator.unlockLevel }
    func isUnlocked(_ intake: IntakeChoice) -> Bool { level >= intake.unlockLevel }

    var allPartsUnlocked: Bool {
        DrivetrainChoice.allCases.allSatisfy { isUnlocked($0) } &&
        FrameChoice.allCases.allSatisfy { isUnlocked($0) } &&
        ManipulatorChoice.allCases.allSatisfy { isUnlocked($0) } &&
        IntakeChoice.allCases.allSatisfy { isUnlocked($0) }
    }

    var hasAchievement: (Achievement) -> Bool {
        { [earnedAchievements] a in earnedAchievements.contains(a.rawValue) }
    }

    mutating func recordMatch(_ result: MatchResult) {
        totalRounds += 1
        totalBuildScore += result.buildMatchScore
        bestBuildScore = max(bestBuildScore, result.buildMatchScore)

        if result.playerWon {
            wins += 1
            winStreak += 1
            bestWinStreak = max(bestWinStreak, winStreak)
        } else if result.margin == 0 {
            ties += 1
            winStreak = 0
        } else {
            losses += 1
            winStreak = 0
        }

        let record = RoundRecord(from: result)
        roundHistory.insert(record, at: 0)
        if roundHistory.count > 20 { roundHistory = Array(roundHistory.prefix(20)) }
    }

    mutating func checkAchievements(result: MatchResult) -> [Achievement] {
        var newlyEarned: [Achievement] = []

        let checks: [(Achievement, Bool)] = [
            (.firstMatch, totalRounds >= 1),
            (.firstWin, wins >= 1),
            (.analyzer, result.buildMatchScore >= 75),
            (.perfectBuild, result.buildMatchScore >= 90),
            (.strategist, result.calloutsUsed.count >= 3),
            (.speedDemon, result.playerWon && result.game.archetype == .speed),
            (.skyReacher, result.playerWon && result.game.archetype == .vertical),
            (.endgameClutch, result.playerWon && result.game.archetype == .endgameFocus),
            (.defenseAce, result.playerWon && result.game.archetype == .defenseArena),
            (.winStreak5, winStreak >= 5),
            (.veteran, totalRounds >= 10),
            (.masterBuilder, level >= 10),
            (.fullArsenal, allPartsUnlocked),
            (.comebacker, result.playerWon && result.calloutEvents.contains {
                $0.redScoreAtTime < $0.blueScoreAtTime - 10
            }),
        ]

        for (achievement, condition) in checks {
            if condition && !earnedAchievements.contains(achievement.rawValue) {
                earnedAchievements.insert(achievement.rawValue)
                newlyEarned.append(achievement)
            }
        }

        return newlyEarned
    }
}

// MARK: - Profile Manager

@MainActor
final class ProfileManager: ObservableObject {
    @Published var profile: PlayerProfile

    private static let storageKey = "playerProfile"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(PlayerProfile.self, from: data) {
            self.profile = decoded
        } else {
            self.profile = PlayerProfile()
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    struct MatchRewards {
        let xpTotal: Int
        let xpBreakdown: [(String, Int)]
        let didLevelUp: Bool
        let newLevel: Int
        let newAchievements: [Achievement]
    }

    func processMatchResult(_ result: MatchResult) -> MatchRewards {
        profile.recordMatch(result)

        let (xpTotal, xpBreakdown) = XPReward.calculate(from: result)
        let newAchievements = profile.checkAchievements(result: result)
        let achievementXP = newAchievements.count * XPReward.achievementBonus
        let totalXP = xpTotal + achievementXP
        let didLevel = profile.addXP(totalXP)

        // Check master builder achievement after level-up
        _ = profile.checkAchievements(result: result)

        save()

        var fullBreakdown = xpBreakdown
        for a in newAchievements {
            fullBreakdown.append(("Achievement: \(a.rawValue)", a.xpReward))
        }

        return MatchRewards(
            xpTotal: totalXP,
            xpBreakdown: fullBreakdown,
            didLevelUp: didLevel,
            newLevel: profile.level,
            newAchievements: newAchievements
        )
    }

    func resetProfile() {
        profile = PlayerProfile()
        save()
    }
}

// ============================================================================
// MARK: - Tournament Mode
// ============================================================================

/// Tournament configuration: defines a series of matches
struct TournamentConfig: Equatable {
    let roundCount: Int          // 3, 5, or 7
    let difficulty: TournamentDifficulty
    let name: String
    let baseSeed: UInt64

    static func quickPlay(seed: UInt64) -> TournamentConfig {
        TournamentConfig(roundCount: 3, difficulty: .normal, name: "Quick Cup", baseSeed: seed)
    }

    static func standard(seed: UInt64) -> TournamentConfig {
        TournamentConfig(roundCount: 5, difficulty: .normal, name: "Regional", baseSeed: seed)
    }

    static func championship(seed: UInt64) -> TournamentConfig {
        TournamentConfig(roundCount: 7, difficulty: .hard, name: "Championship", baseSeed: seed)
    }

    /// Generate a unique game for each round in the tournament
    func gameForRound(_ round: Int) -> GeneratedGame {
        GameGenerator.generate(seed: baseSeed &+ UInt64(round * 7919))
    }
}

enum TournamentDifficulty: String, Equatable {
    case easy   = "Rookie"
    case normal = "Varsity"
    case hard   = "Elite"

    var opponentSkillBoost: Float {
        switch self { case .easy: return -0.15; case .normal: return 0; case .hard: return 0.15 }
    }

    var xpMultiplier: Double {
        switch self { case .easy: return 0.8; case .normal: return 1.0; case .hard: return 1.5 }
    }
}

/// Tracks state of an in-progress tournament
@MainActor
final class TournamentState: ObservableObject {
    let config: TournamentConfig

    @Published var currentRound: Int = 0
    @Published var playerWins: Int = 0
    @Published var opponentWins: Int = 0
    @Published var matchResults: [MatchResult] = []
    @Published var isComplete: Bool = false
    @Published var currentGame: GeneratedGame?

    init(config: TournamentConfig) {
        self.config = config
        self.currentGame = config.gameForRound(0)
    }

    var winsNeeded: Int { (activeConfig.roundCount / 2) + 1 }

    var playerWonTournament: Bool { playerWins >= winsNeeded }
    var playerLostTournament: Bool { opponentWins >= winsNeeded }
    var isSweep: Bool { playerWonTournament && opponentWins == 0 }

    var seriesRecord: String { "\(playerWins)-\(opponentWins)" }

    var roundLabel: String {
        "Match \(currentRound + 1) of \(activeConfig.roundCount)"
    }

    func recordResult(_ result: MatchResult) {
        matchResults.append(result)
        if result.playerWon {
            playerWins += 1
        } else {
            opponentWins += 1
        }
        currentRound += 1

        if playerWins >= winsNeeded || opponentWins >= winsNeeded || currentRound >= activeConfig.roundCount {
            isComplete = true
        } else {
            currentGame = activeConfig.gameForRound(currentRound)
        }
    }

    var totalPlayerScore: Int { matchResults.reduce(0) { $0 + $1.redScore } }
    var totalOpponentScore: Int { matchResults.reduce(0) { $0 + $1.blueScore } }
    var averageBuildScore: Int {
        guard !matchResults.isEmpty else { return 0 }
        return matchResults.reduce(0) { $0 + $1.buildMatchScore } / matchResults.count
    }

    /// Reset tournament for a new series
    func resetWith(config newConfig: TournamentConfig) {
        // We re-initialize by copying config values
        // Since config is let, we use a new approach: reset all mutable state
        currentRound = 0
        playerWins = 0
        opponentWins = 0
        matchResults = []
        isComplete = false
        currentGame = newConfig.gameForRound(0)
        // Store new config reference via a workaround
        _storedConfig = newConfig
    }

    private var _storedConfig: TournamentConfig?

    /// Access the current config (supports reset)
    var activeConfig: TournamentConfig {
        _storedConfig ?? config
    }
}

// ============================================================================
// MARK: - Part Tuning
// ============================================================================

/// Fine-tuning adjustments applied on top of the base robot build.
/// Each slider goes from -1.0 to +1.0 (0 = default).
struct PartTuning: Equatable {
    /// Speed vs Torque trade-off: positive = faster but weaker push
    var speedTorque: Float = 0.0

    /// Aggression vs Caution: positive = more aggressive scoring attempts
    var aggression: Float = 0.0

    /// Weight distribution: positive = front-heavy (better intake), negative = rear-heavy (better stability)
    var weightBalance: Float = 0.0

    /// Apply tuning modifiers to base robot stats
    func applyTo(_ stats: RobotStats) -> RobotStats {
        let speedMod = speedTorque * 0.3
        let pushMod = -speedTorque * 0.2
        let reliabilityMod = -abs(aggression) * 0.03
        let scoringMod = aggression * 0.15

        return RobotStats(
            maxSpeed: max(1.0, stats.maxSpeed + speedMod),
            acceleration: stats.acceleration,
            turnRate: stats.turnRate,
            scoringTime: max(0.3, stats.scoringTime - Double(scoringMod)),
            pickupTime: stats.pickupTime,
            reliability: min(0.98, max(0.50, stats.reliability + Double(reliabilityMod))),
            maxReachHeight: stats.maxReachHeight,
            pushPower: max(0.1, stats.pushPower + pushMod),
            canDeepClimb: stats.canDeepClimb,
            canStrafe: stats.canStrafe,
            canShoot: stats.canShoot,
            totalWeight: stats.totalWeight
        )
    }

    var isDefault: Bool {
        speedTorque == 0 && aggression == 0 && weightBalance == 0
    }
}

// ============================================================================
// MARK: - Build Recommendation
// ============================================================================

/// AI coach build recommendation based on the generated game
struct BuildRecommendation {
    let drivetrain: DrivetrainChoice
    let frame: FrameChoice
    let manipulator: ManipulatorChoice
    let intake: IntakeChoice
    let reasoning: String
    let expectedScore: Int

    /// Generate a recommendation for a given game
    static func forGame(_ game: GeneratedGame) -> BuildRecommendation {
        var bestBuild = RobotBuild()
        var bestScore = 0
        var bestReason = ""

        // Evaluate all realistic combinations
        for dt in DrivetrainChoice.allCases {
            for fr in FrameChoice.allCases {
                for mp in ManipulatorChoice.allCases {
                    for ink in IntakeChoice.allCases {
                        let build = RobotBuild(drivetrain: dt, frame: fr, manipulator: mp, intake: ink)
                        let score = game.buildMatchScore(build: build)
                        if score > bestScore {
                            bestScore = score
                            bestBuild = build
                        }
                    }
                }
            }
        }

        // Generate reasoning
        var reasons: [String] = []
        switch game.archetype {
        case .vertical, .precision:
            reasons.append("\(bestBuild.manipulator.shortLabel) reaches \(bestBuild.manipulator.maxReach.displayName) targets")
        case .speed:
            reasons.append("\(bestBuild.drivetrain.shortLabel) provides speed for fast cycling")
        case .power, .defenseArena:
            reasons.append("\(bestBuild.drivetrain.shortLabel) + \(bestBuild.frame.shortLabel) for pushing power")
        case .endgameFocus:
            reasons.append("Built around the high-value endgame challenge")
        case .hybrid:
            reasons.append("Versatile combo handles mixed scoring types")
        case .classic:
            reasons.append("Balanced build suits the all-round challenge")
        }

        if let piece = game.gamePieces.first, piece.idealIntake == bestBuild.intake {
            reasons.append("\(bestBuild.intake.shortLabel) is ideal for \(piece.rawValue)")
        }

        bestReason = reasons.joined(separator: ". ")

        return BuildRecommendation(
            drivetrain: bestBuild.drivetrain,
            frame: bestBuild.frame,
            manipulator: bestBuild.manipulator,
            intake: bestBuild.intake,
            reasoning: bestReason,
            expectedScore: bestScore
        )
    }
}
