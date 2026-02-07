import Foundation
import SwiftUI

// MARK: - Game Phase

enum GamePhase: Equatable {
    case intro
    case preMatch
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
        case .scorer:
            return "Places coral on higher reef levels. Slower but scores big per piece."
        case .cycler:
            return "Rapid coral delivery focusing on L1-L2. Fast cycles, high volume."
        case .defender:
            return "Disrupts opponents by blocking lanes. Tough and fast, scores when open."
        }
    }
}

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
        case .aggressive:
            return "All-in on scoring. High risk, high reward. No dedicated defense."
        case .balanced:
            return "Mix of scoring and defense. Adaptable mid-match."
        case .defensive:
            return "One bot defends while others cycle. Slows opponents, wins by margin."
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
        switch self {
        case .safe:     return .green
        case .moderate: return .yellow
        case .risky:    return .red
        }
    }

    var description: String {
        switch self {
        case .safe:
            return "Cross auto line + score 1 coral. Reliable guaranteed points."
        case .moderate:
            return "Score 2 coral during auto. Needs decent speed and accuracy."
        case .risky:
            return "Attempt 3 coral in auto. High ceiling but real stall chance."
        }
    }

    var piecesAttempted: Int {
        switch self {
        case .safe: return 1; case .moderate: return 2; case .risky: return 3
        }
    }

    var successRate: Double {
        switch self {
        case .safe: return 0.95; case .moderate: return 0.75; case .risky: return 0.45
        }
    }
}

// MARK: - Robot Build Configuration

struct RobotBuild: Equatable {
    var drivetrain: DrivetrainType = .swerve
    var mechanism: MechanismType = .elevator
    var intake: IntakeType = .claw
}

// MARK: - Drivetrain Type
//
// Balance philosophy:
//   Swerve = fast + agile but fragile, weak pushing, shallow climb only (6pts)
//   Tank   = slower but reliable, strong pushing, deep climb capable (12pts)

enum DrivetrainType: String, CaseIterable, Identifiable {
    case swerve = "Swerve Drive"
    case tank   = "Tank Drive"

    var id: String { rawValue }
    var icon: String {
        switch self { case .swerve: return "rotate.3d"; case .tank: return "rectangle.on.rectangle" }
    }
    var shortLabel: String {
        switch self { case .swerve: return "Swerve"; case .tank: return "Tank" }
    }
    var description: String {
        switch self {
        case .swerve: return "Fast omnidirectional movement with strafing ability."
        case .tank:   return "Strong pushing power with high reliability."
        }
    }
    var pros: String {
        switch self {
        case .swerve: return "Fastest speed, can strafe, agile turning"
        case .tank:   return "Very reliable, strong defense/pushing, deep climb (12pts)"
        }
    }
    var cons: String {
        switch self {
        case .swerve: return "Less reliable, weak pushing, shallow climb only (6pts)"
        case .tank:   return "Slower, no strafing, wider turns"
        }
    }
    var color: Color {
        switch self { case .swerve: return .cyan; case .tank: return .orange }
    }
}

// MARK: - Mechanism Type
//
// Balance philosophy:
//   Elevator = reaches L4 (5pts) but heavy (speed penalty), slow scoring, less reliable
//   Arm      = reaches L3 (4pts), moderate speed, good all-rounder
//   Simple   = only L1-L2 but fastest scoring, most reliable, lightweight (speed bonus!)

enum MechanismType: String, CaseIterable, Identifiable {
    case elevator = "Cascading Elevator"
    case arm      = "Pivot Arm"
    case simple   = "Low Intake"

    var id: String { rawValue }
    var icon: String {
        switch self { case .elevator: return "arrow.up.and.down"; case .arm: return "arrow.up.right"; case .simple: return "tray.fill" }
    }
    var shortLabel: String {
        switch self { case .elevator: return "Elevator"; case .arm: return "Arm"; case .simple: return "Low" }
    }
    var description: String {
        switch self {
        case .elevator: return "Cascading stages reach all levels L1-L4."
        case .arm:      return "Pivot arm reaches L1-L3. Versatile all-rounder."
        case .simple:   return "Ground-level intake, L1-L2 only. Volume over height."
        }
    }
    var pros: String {
        switch self {
        case .elevator: return "Reaches L4 (5pts/piece), highest scoring ceiling"
        case .arm:      return "Reaches L3, balanced speed, moderate scoring"
        case .simple:   return "Fastest scoring (0.6s), lightweight speed bonus, most reliable"
        }
    }
    var cons: String {
        switch self {
        case .elevator: return "Heavy (slows robot), slow scoring (1.6s), less reliable"
        case .arm:      return "Can't reach L4, middle-of-the-road stats"
        case .simple:   return "Only L1-L2 (2-3pts/piece), low ceiling"
        }
    }
    var color: Color {
        switch self { case .elevator: return .purple; case .arm: return .orange; case .simple: return .green }
    }
    var maxLevel: Int {
        switch self { case .elevator: return 4; case .arm: return 3; case .simple: return 2 }
    }
}

// MARK: - Intake Type
//
// Balance philosophy:
//   Claw   = reliable scoring (rarely drops), precise placement, but slow pickup
//   Roller = lightning fast pickup, great ground game, but less reliable scoring

enum IntakeType: String, CaseIterable, Identifiable {
    case claw   = "Claw Grabber"
    case roller = "Roller Intake"

    var id: String { rawValue }
    var icon: String {
        switch self { case .claw: return "hand.point.up.fill"; case .roller: return "gearshape.2.fill" }
    }
    var shortLabel: String {
        switch self { case .claw: return "Claw"; case .roller: return "Rollers" }
    }
    var description: String {
        switch self {
        case .claw:   return "Precise grip for reliable placement."
        case .roller: return "Spinning rollers for fast ground pickup."
        }
    }
    var pros: String {
        switch self {
        case .claw:   return "Very reliable scoring (+8%), precise placement"
        case .roller: return "Fast pickup (0.5s vs 1.0s), great ground game"
        }
    }
    var cons: String {
        switch self {
        case .claw:   return "Slow pickup (1.0s), loses time each cycle"
        case .roller: return "Less reliable scoring (-5%), can drop coral"
        }
    }
    var color: Color {
        switch self { case .claw: return .yellow; case .roller: return .teal }
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
        case .prioritizeReef: p.scoringWeight += 0.3
        case .switchDefense:  p.defenseWeight += 0.4
        case .endgameEarly:   p.endgameWeight += 0.5
        case .focusHigh:      p.preferHighLevel = true; p.scoringWeight += 0.15
        case .spreadOut:      p.spreadOut = true
        case .allOutAttack:   p.scoringWeight = 1.0; p.defenseWeight = 0
        }
        return p
    }

    var dominantMode: String {
        if endgameWeight >= scoringWeight && endgameWeight >= defenseWeight { return "Endgame Push" }
        else if defenseWeight >= scoringWeight { return "Defense Mode" }
        else { return "Scoring Mode" }
    }
}

// MARK: - Callout (6 strategic options)

enum Callout: String, CaseIterable, Identifiable {
    case prioritizeReef = "Push Reef"
    case switchDefense  = "Play Defense"
    case endgameEarly   = "Endgame Now"
    case focusHigh      = "Focus High"
    case spreadOut      = "Switch Sides"
    case allOutAttack   = "All Out"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .prioritizeReef: return "scope"
        case .switchDefense:  return "shield.fill"
        case .endgameEarly:   return "flag.checkered"
        case .focusHigh:      return "arrow.up.to.line"
        case .spreadOut:      return "arrow.left.and.right"
        case .allOutAttack:   return "flame.fill"
        }
    }
    var color: Color {
        switch self {
        case .prioritizeReef: return .orange
        case .switchDefense:  return .green
        case .endgameEarly:   return .purple
        case .focusHigh:      return .red
        case .spreadOut:      return .cyan
        case .allOutAttack:   return .yellow
        }
    }
    var subtitle: String {
        switch self {
        case .prioritizeReef: return "Boost scoring"
        case .switchDefense:  return "Block opponents"
        case .endgameEarly:   return "Rush to climb"
        case .focusHigh:      return "Target L3-L4"
        case .spreadOut:      return "Reduce congestion"
        case .allOutAttack:   return "Max aggression"
        }
    }
}

// MARK: - Match Period

enum MatchPeriod: String {
    case auto     = "AUTO"
    case teleop   = "TELEOP"
    case endgame  = "ENDGAME"
    case finished = "FINAL"
}

// MARK: - Robot Stats

struct RobotStats {
    let maxSpeed: Float
    let acceleration: Float
    let turnRate: Float
    let scoringTime: Double
    let pickupTime: Double
    let reliability: Double   // 0-1
    let maxReefLevel: Int
    let pushPower: Float      // 0-1, affects defense collisions
    let canDeepClimb: Bool    // true = 12pts endgame, false = 6pts
}

// MARK: - Superstructure Type (visual)

enum SuperstructureType: String {
    case elevator
    case arm
    case intake
    case wedge
}

// MARK: - Robot Configuration

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

// MARK: - Game Piece

struct GamePiece: Identifiable {
    let id: Int
    var position: SIMD2<Float>
    var state: PieceState
    var carriedBy: Int?

    enum PieceState { case onField, carried, scored }
}

// MARK: - Field Layout (references FieldSpec)

enum FieldLayout {
    static let fieldWidth: Float  = FieldSpec.fieldLength
    static let fieldLength: Float = FieldSpec.fieldWidth
    static let halfWidth: Float   = FieldSpec.halfLength
    static let halfLength: Float  = FieldSpec.halfWidth

    static let redSource: SIMD2<Float>  = SIMD2(3.50, 0.0)
    static let blueSource: SIMD2<Float> = SIMD2(-3.50, 0.0)

    static func redReefApproach(_ faceIndex: Int) -> SIMD2<Float> {
        FieldSpec.scoringApproach(center: FieldSpec.redReefCenter, faceIndex: faceIndex)
    }
    static func blueReefApproach(_ faceIndex: Int) -> SIMD2<Float> {
        FieldSpec.scoringApproach(center: FieldSpec.blueReefCenter, faceIndex: faceIndex)
    }

    static let redProcessor  = FieldSpec.redProcessor
    static let blueProcessor = FieldSpec.blueProcessor

    static let redBarge  = SIMD2<Float>( 0.35, 0.0)
    static let blueBarge = SIMD2<Float>(-0.35, 0.0)

    static let redStarts  = FieldSpec.redStarts
    static let blueStarts = FieldSpec.blueStarts
}

// MARK: - Match Timing

enum MatchTiming {
    static let autoDuration: Double = 15.0
    static let teleopStart: Double = 15.0
    static let endgameStart: Double = 135.0
    static let totalDuration: Double = 150.0
}

// MARK: - Match Result

struct MatchResult {
    let playerStrategy: AllianceStrategy
    let playerRole: RobotRole
    let playerAuto: AutoPlan
    let playerBuild: RobotBuild
    let redScore: Int
    let blueScore: Int
    let redBreakdown: ScoreBreakdown
    let blueBreakdown: ScoreBreakdown
    let calloutsUsed: [Callout]
    let playerRobotScored: Int
    let playerRobotCycled: Int
    let didPlayerStall: Bool
    let matchDuration: Double
    let slowMoUsed: Bool

    var playerWon: Bool { redScore > blueScore }
    var margin: Int { abs(redScore - blueScore) }
}

struct ScoreBreakdown {
    var autoPoints: Int = 0
    var teleopPoints: Int = 0
    var endgamePoints: Int = 0
    var totalPieces: Int = 0
    var processorPieces: Int = 0
    var coralL1: Int = 0
    var coralL2: Int = 0
    var coralL3: Int = 0
    var coralL4: Int = 0
    var total: Int { autoPoints + teleopPoints + endgamePoints }
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
}

// MARK: - Coaching Tip

struct CoachingTip: Equatable {
    let headline: String
    let detail: String
    let highlightRobotId: Int?
}

// MARK: - Robot Factory

enum RobotFactory {

    private static let redTeamNumbers  = ["9999", "2468", "1357"]
    private static let blueTeamNumbers = ["254", "1678", "118"]

    static func buildRobots(playerRole: RobotRole, strategy: AllianceStrategy,
                            playerBuild: RobotBuild, seed: UInt64 = 42) -> [RobotConfig] {
        var rng = SeededRNG(seed: seed)
        var configs: [RobotConfig] = []

        // --- Red Alliance (player's team) ---
        let playerStats = statsForBuild(playerBuild, role: playerRole, boost: true)
        configs.append(RobotConfig(
            id: 0, alliance: .red, role: playerRole,
            stats: playerStats,
            superstructure: superstructureFor(playerBuild, role: playerRole),
            build: playerBuild,
            teamNumber: redTeamNumbers[0], startPosition: FieldLayout.redStarts[0]
        ))

        // Red teammates — randomized builds matching their role
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

        // --- Blue Alliance (opponents — randomized with varied roles) ---
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

    // MARK: - Balanced Stats

    static func statsForBuild(_ build: RobotBuild, role: RobotRole, boost: Bool) -> RobotStats {
        let b: Float = boost ? 0.1 : 0.0

        // --- Drivetrain base ---
        let baseSpeed: Float
        let baseTurn: Float
        let baseAccel: Float
        let baseReliability: Double
        let basePush: Float
        let deepClimb: Bool

        switch build.drivetrain {
        case .swerve:
            baseSpeed = 2.3; baseTurn = 3.5; baseAccel = 2.0
            baseReliability = 0.84; basePush = 0.3; deepClimb = false
        case .tank:
            baseSpeed = 1.85; baseTurn = 1.8; baseAccel = 1.5
            baseReliability = 0.94; basePush = 1.0; deepClimb = true
        }

        // --- Mechanism modifiers ---
        let mechSpeedMod: Float
        let mechScoringTime: Double
        let mechReliabilityMod: Double
        switch build.mechanism {
        case .elevator: mechSpeedMod = -0.25; mechScoringTime = 1.6; mechReliabilityMod = -0.05
        case .arm:      mechSpeedMod = -0.10; mechScoringTime = 1.2; mechReliabilityMod =  0.0
        case .simple:   mechSpeedMod =  0.15; mechScoringTime = 0.6; mechReliabilityMod =  0.05
        }

        // --- Intake modifiers ---
        let pickupTime: Double
        let intakeReliabilityMod: Double
        switch build.intake {
        case .claw:   pickupTime = 1.0; intakeReliabilityMod =  0.08
        case .roller: pickupTime = 0.5; intakeReliabilityMod = -0.05
        }

        // --- Role adjustments ---
        let roleSpeedMod: Float
        let roleScoringMod: Double
        switch role {
        case .scorer:   roleSpeedMod = -0.15; roleScoringMod = -0.10
        case .cycler:   roleSpeedMod =  0.20; roleScoringMod =  0.05
        case .defender: roleSpeedMod =  0.30; roleScoringMod =  0.30
        }

        let finalReliability = min(0.98, max(0.50,
            baseReliability + mechReliabilityMod + intakeReliabilityMod))

        return RobotStats(
            maxSpeed: max(1.0, baseSpeed + mechSpeedMod + roleSpeedMod + b),
            acceleration: baseAccel,
            turnRate: baseTurn,
            scoringTime: max(0.4, mechScoringTime + roleScoringMod),
            pickupTime: pickupTime,
            reliability: finalReliability,
            maxReefLevel: build.mechanism.maxLevel,
            pushPower: basePush,
            canDeepClimb: deepClimb
        )
    }

    // MARK: - Randomized Build Generation

    private static func randomBuild(for role: RobotRole, rng: inout SeededRNG) -> RobotBuild {
        let dt: DrivetrainType
        let mech: MechanismType
        let intake: IntakeType

        switch role {
        case .scorer:
            // Scorers lean toward higher mechanisms
            dt = rng.nextDouble() < 0.5 ? .swerve : .tank
            let mr = rng.nextDouble()
            mech = mr < 0.45 ? .elevator : (mr < 0.80 ? .arm : .simple)
            intake = rng.nextDouble() < 0.60 ? .claw : .roller

        case .cycler:
            // Cyclers lean toward speed + lower mechanisms
            dt = rng.nextDouble() < 0.55 ? .swerve : .tank
            let mr = rng.nextDouble()
            mech = mr < 0.15 ? .elevator : (mr < 0.50 ? .arm : .simple)
            intake = rng.nextDouble() < 0.35 ? .claw : .roller

        case .defender:
            // Defenders lean toward tank + simple
            dt = rng.nextDouble() < 0.30 ? .swerve : .tank
            let mr = rng.nextDouble()
            mech = mr < 0.10 ? .elevator : (mr < 0.40 ? .arm : .simple)
            intake = rng.nextDouble() < 0.40 ? .claw : .roller
        }

        return RobotBuild(drivetrain: dt, mechanism: mech, intake: intake)
    }

    private static func superstructureFor(_ build: RobotBuild, role: RobotRole) -> SuperstructureType {
        if role == .defender && build.mechanism == .simple { return .wedge }
        switch build.mechanism {
        case .elevator: return .elevator
        case .arm:      return .arm
        case .simple:   return .intake
        }
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
