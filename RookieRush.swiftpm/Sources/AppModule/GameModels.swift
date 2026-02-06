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
            return "Places coral accurately on higher reef levels. Slower but scores big."
        case .cycler:
            return "Rapid coral delivery between source and reef. Fast cycles, L1-L2 focus."
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

/// Player-configurable robot build options using simple labels.
struct RobotBuild: Equatable {
    var drivetrain: DrivetrainType = .swerve
    var mechanism: MechanismType = .elevator
    var intake: IntakeType = .claw
}

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
        case .swerve: return "Omnidirectional movement. Fast, agile, can strafe. Most competitive teams use swerve."
        case .tank:   return "Forward/backward + turn. More pushing force, simpler, higher reliability."
        }
    }
    var color: Color {
        switch self { case .swerve: return .cyan; case .tank: return .orange }
    }
}

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
        case .elevator: return "Reaches all levels L1-L4. Cascading stages extend vertically. Slower but max scoring."
        case .arm:      return "Pivot arm reaches L1-L3. Versatile and moderate speed. Good all-rounder."
        case .simple:   return "Ground-level intake, L1-L2 only. Fastest cycle time. Volume over height."
        }
    }
    var color: Color {
        switch self { case .elevator: return .purple; case .arm: return .orange; case .simple: return .green }
    }
    /// Maximum reef level this mechanism can score on
    var maxLevel: Int {
        switch self { case .elevator: return 4; case .arm: return 3; case .simple: return 2 }
    }
}

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
        case .claw:   return "Precise grip on coral. Slower pickup but very reliable placement."
        case .roller: return "Spinning rollers grab coral fast. Quick cycles, slightly less accurate."
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

    func applying(callout: Callout) -> StrategyPolicy {
        var p = self
        switch callout {
        case .prioritizeReef: p.scoringWeight += 0.3
        case .switchDefense:  p.defenseWeight += 0.4
        case .endgameEarly:   p.endgameWeight += 0.5
        }
        return p
    }

    var dominantMode: String {
        if endgameWeight >= scoringWeight && endgameWeight >= defenseWeight { return "Endgame Push" }
        else if defenseWeight >= scoringWeight { return "Defense Mode" }
        else { return "Scoring Mode" }
    }
}

// MARK: - Callout

enum Callout: String, CaseIterable, Identifiable {
    case prioritizeReef = "Push Reef"
    case switchDefense  = "Play Defense"
    case endgameEarly   = "Endgame Now"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .prioritizeReef: return "scope"
        case .switchDefense:  return "shield.fill"
        case .endgameEarly:   return "flag.checkered"
        }
    }
    var color: Color {
        switch self {
        case .prioritizeReef: return .orange
        case .switchDefense:  return .green
        case .endgameEarly:   return .purple
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
    let scoringTime: Double   // seconds to place a piece
    let pickupTime: Double    // seconds to grab a piece
    let reliability: Double   // 0-1, chance of successful action
    let maxReefLevel: Int     // highest reef level reachable (1-4)
}

// MARK: - Superstructure Type (visual representation)

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
    static let fieldWidth: Float  = FieldSpec.fieldLength  // X extent
    static let fieldLength: Float = FieldSpec.fieldWidth   // Z extent
    static let halfWidth: Float   = FieldSpec.halfLength
    static let halfLength: Float  = FieldSpec.halfWidth

    // Coral station approach points (where robots go to pick up)
    static let redSource: SIMD2<Float>  = SIMD2(3.50, 0.0)
    static let blueSource: SIMD2<Float> = SIMD2(-3.50, 0.0)

    // Reef face approach points for scoring (6 per reef)
    static func redReefApproach(_ faceIndex: Int) -> SIMD2<Float> {
        FieldSpec.scoringApproach(center: FieldSpec.redReefCenter, faceIndex: faceIndex)
    }
    static func blueReefApproach(_ faceIndex: Int) -> SIMD2<Float> {
        FieldSpec.scoringApproach(center: FieldSpec.blueReefCenter, faceIndex: faceIndex)
    }

    static let redProcessor  = FieldSpec.redProcessor
    static let blueProcessor = FieldSpec.blueProcessor

    // Barge parking zones (one per alliance side of barge)
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

    static func buildRobots(playerRole: RobotRole, strategy: AllianceStrategy,
                            playerBuild: RobotBuild) -> [RobotConfig] {
        var configs: [RobotConfig] = []

        // --- Red Alliance (player's team) ---
        let playerStats = statsForBuild(playerBuild, role: playerRole, boost: true)
        configs.append(RobotConfig(
            id: 0, alliance: .red, role: playerRole,
            stats: playerStats,
            superstructure: superstructureForMechanism(playerBuild.mechanism),
            build: playerBuild,
            teamNumber: "9999", startPosition: FieldLayout.redStarts[0]
        ))

        let comp1Role = complementRole1(for: strategy, playerRole: playerRole)
        let comp1Build = defaultBuild(for: comp1Role)
        configs.append(RobotConfig(
            id: 1, alliance: .red, role: comp1Role,
            stats: statsForBuild(comp1Build, role: comp1Role, boost: false),
            superstructure: superstructureForMechanism(comp1Build.mechanism),
            build: comp1Build,
            teamNumber: "2468", startPosition: FieldLayout.redStarts[1]
        ))

        let comp2Role = complementRole2(for: strategy, playerRole: playerRole)
        let comp2Build = defaultBuild(for: comp2Role)
        configs.append(RobotConfig(
            id: 2, alliance: .red, role: comp2Role,
            stats: statsForBuild(comp2Build, role: comp2Role, boost: false),
            superstructure: superstructureForMechanism(comp2Build.mechanism),
            build: comp2Build,
            teamNumber: "1357", startPosition: FieldLayout.redStarts[2]
        ))

        // --- Blue Alliance (opponents, balanced strategy) ---
        let blueBuild1 = RobotBuild(drivetrain: .swerve, mechanism: .elevator, intake: .claw)
        configs.append(RobotConfig(
            id: 3, alliance: .blue, role: .scorer,
            stats: statsForBuild(blueBuild1, role: .scorer, boost: false),
            superstructure: .elevator, build: blueBuild1,
            teamNumber: "254", startPosition: FieldLayout.blueStarts[0]
        ))

        let blueBuild2 = RobotBuild(drivetrain: .swerve, mechanism: .simple, intake: .roller)
        configs.append(RobotConfig(
            id: 4, alliance: .blue, role: .cycler,
            stats: statsForBuild(blueBuild2, role: .cycler, boost: false),
            superstructure: .intake, build: blueBuild2,
            teamNumber: "1678", startPosition: FieldLayout.blueStarts[1]
        ))

        let blueBuild3 = RobotBuild(drivetrain: .tank, mechanism: .simple, intake: .roller)
        configs.append(RobotConfig(
            id: 5, alliance: .blue, role: .defender,
            stats: statsForBuild(blueBuild3, role: .defender, boost: false),
            superstructure: .wedge, build: blueBuild3,
            teamNumber: "118", startPosition: FieldLayout.blueStarts[2]
        ))

        return configs
    }

    static func statsForBuild(_ build: RobotBuild, role: RobotRole, boost: Bool) -> RobotStats {
        let b: Float = boost ? 0.15 : 0.0

        // Base speed from drivetrain
        let baseSpeed: Float = build.drivetrain == .swerve ? 2.4 : 1.9
        let baseTurn: Float = build.drivetrain == .swerve ? 3.5 : 2.0
        let baseReliability: Double = build.drivetrain == .tank ? 0.96 : 0.90

        // Scoring time from mechanism
        let baseScoringTime: Double
        switch build.mechanism {
        case .elevator: baseScoringTime = 1.4
        case .arm:      baseScoringTime = 1.1
        case .simple:   baseScoringTime = 0.7
        }

        // Pickup time from intake
        let basePickup: Double = build.intake == .roller ? 0.6 : 0.9
        let intakeReliability: Double = build.intake == .claw ? 0.05 : -0.02

        // Role adjustments
        let speedMod: Float
        let scoringMod: Double
        switch role {
        case .scorer:   speedMod = -0.2; scoringMod = -0.15
        case .cycler:   speedMod =  0.3; scoringMod =  0.1
        case .defender: speedMod =  0.5; scoringMod =  0.4
        }

        return RobotStats(
            maxSpeed: baseSpeed + speedMod + b,
            acceleration: build.drivetrain == .swerve ? 2.0 : 1.6,
            turnRate: baseTurn,
            scoringTime: max(0.5, baseScoringTime + scoringMod),
            pickupTime: basePickup,
            reliability: min(0.98, baseReliability + intakeReliability),
            maxReefLevel: build.mechanism.maxLevel
        )
    }

    private static func defaultBuild(for role: RobotRole) -> RobotBuild {
        switch role {
        case .scorer:   return RobotBuild(drivetrain: .swerve, mechanism: .elevator, intake: .claw)
        case .cycler:   return RobotBuild(drivetrain: .swerve, mechanism: .arm, intake: .roller)
        case .defender: return RobotBuild(drivetrain: .tank, mechanism: .simple, intake: .roller)
        }
    }

    private static func superstructureForMechanism(_ mech: MechanismType) -> SuperstructureType {
        switch mech {
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
