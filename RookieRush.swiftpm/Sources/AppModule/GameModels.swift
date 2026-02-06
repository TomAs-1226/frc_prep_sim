import Foundation
import SwiftUI

// MARK: - Game Phase

/// Top-level flow states for the app experience.
enum GamePhase: Equatable {
    case intro
    case preMatch
    case simulation
    case results
}

// MARK: - Alliance

/// The two competing alliances in an FRC match.
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

/// Functional roles a robot can take in a match.
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
            return "Specializes in placing game pieces accurately. Slower but scores efficiently at reef nodes."
        case .cycler:
            return "Fast pick-up and delivery. Cycles pieces rapidly between source and scoring zones."
        case .defender:
            return "Disrupts opponents by blocking lanes and slowing their cycles. Scores opportunistically."
        }
    }
}

// MARK: - Alliance Strategy

/// High-level strategy packages the player chooses for their alliance.
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
            return "All-in on scoring. High risk, high reward. Leaves defense to luck."
        case .balanced:
            return "Mix of scoring and defense. Adaptable mid-match."
        case .defensive:
            return "One bot defends while others cycle. Slows opponents, wins by margin."
        }
    }

    /// Base strategy weights for this package.
    var basePolicy: StrategyPolicy {
        switch self {
        case .aggressive: return StrategyPolicy(scoringWeight: 0.9, defenseWeight: 0.05, endgameWeight: 0.05)
        case .balanced:   return StrategyPolicy(scoringWeight: 0.6, defenseWeight: 0.2, endgameWeight: 0.2)
        case .defensive:  return StrategyPolicy(scoringWeight: 0.4, defenseWeight: 0.45, endgameWeight: 0.15)
        }
    }
}

// MARK: - Auto Plan

/// Autonomous routine complexity for the player's robot.
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
            return "Cross the auto line + score 1 piece. Reliable, guaranteed points."
        case .moderate:
            return "Score 2 pieces during auto. Needs decent speed and accuracy."
        case .risky:
            return "Attempt 3 pieces in auto. High ceiling but real stall chance."
        }
    }

    var piecesAttempted: Int {
        switch self {
        case .safe: return 1
        case .moderate: return 2
        case .risky: return 3
        }
    }

    var successRate: Double {
        switch self {
        case .safe: return 0.95
        case .moderate: return 0.75
        case .risky: return 0.45
        }
    }
}

// MARK: - Strategy Policy

/// Weighted strategy policy that governs robot AI decision-making.
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
        if endgameWeight >= scoringWeight && endgameWeight >= defenseWeight {
            return "Endgame Push"
        } else if defenseWeight >= scoringWeight {
            return "Defense Mode"
        } else {
            return "Scoring Mode"
        }
    }
}

// MARK: - Callout

/// Mid-match strategic callouts the player can trigger (max 3 per match).
enum Callout: String, CaseIterable, Identifiable {
    case prioritizeReef = "Prioritize Reef"
    case switchDefense  = "Switch to Defense"
    case endgameEarly   = "Endgame Early"

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
    let scoringTime: Double
    let pickupTime: Double
    let reliability: Double
}

// MARK: - Superstructure Type

enum SuperstructureType: String {
    case elevator
    case arm
    case intake
    case dualRail
    case turretIntake
    case wedge
}

// MARK: - Robot Configuration

struct RobotConfig: Identifiable {
    let id: Int
    let alliance: Alliance
    let role: RobotRole
    let stats: RobotStats
    let superstructure: SuperstructureType
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

    enum PieceState {
        case onField
        case carried
        case scored
    }
}

// MARK: - Field Constants

enum FieldLayout {
    static let fieldWidth: Float = 8.0
    static let fieldLength: Float = 4.5
    static let halfWidth: Float = fieldWidth / 2
    static let halfLength: Float = fieldLength / 2

    static let redSource  = SIMD2<Float>(3.2, 0.0)
    static let blueSource = SIMD2<Float>(-3.2, 0.0)

    static let reefNodes: [SIMD2<Float>] = [
        SIMD2(-0.6, -0.5), SIMD2(0.0, -0.5), SIMD2(0.6, -0.5),
        SIMD2(-0.6,  0.5), SIMD2(0.0,  0.5), SIMD2(0.6,  0.5),
    ]

    static let redProcessor  = SIMD2<Float>(2.0, -1.5)
    static let blueProcessor = SIMD2<Float>(-2.0, -1.5)
    static let redBarge  = SIMD2<Float>(2.5, 1.8)
    static let blueBarge = SIMD2<Float>(-2.5, 1.8)

    static let redStarts: [SIMD2<Float>] = [
        SIMD2(2.8, -0.8), SIMD2(3.2, 0.0), SIMD2(2.8, 0.8)
    ]
    static let blueStarts: [SIMD2<Float>] = [
        SIMD2(-2.8, -0.8), SIMD2(-3.2, 0.0), SIMD2(-2.8, 0.8)
    ]
}

// MARK: - Match Timing

enum MatchTiming {
    static let autoDuration: Double = 15.0
    static let teleopStart: Double = 15.0
    static let endgameStart: Double = 135.0
    static let totalDuration: Double = 150.0
}

// MARK: - Score Values

enum ScoreValues {
    static let autoTaxi: Int = 3
    static let autoReefNode: Int = 6
    static let teleopReefNode: Int = 3
    static let processorScore: Int = 6
    static let bargeClimb: Int = 12
}

// MARK: - Match Result

struct MatchResult {
    let playerStrategy: AllianceStrategy
    let playerRole: RobotRole
    let playerAuto: AutoPlan
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
    var total: Int { autoPoints + teleopPoints + endgamePoints }
}

// MARK: - Seeded RNG

struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64 = 42) {
        state = seed == 0 ? 1 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    mutating func nextDouble() -> Double {
        Double(next() & 0x1FFFFFFFFFFFFF) / Double(1 << 53)
    }

    mutating func nextFloat() -> Float {
        Float(nextDouble())
    }
}

// MARK: - Coaching Tip

struct CoachingTip {
    let headline: String
    let detail: String
    let highlightRobotId: Int?
}

// MARK: - Robot Factory

/// Builds the 6 robot configurations for a match.
enum RobotFactory {

    static func buildRobots(playerRole: RobotRole, strategy: AllianceStrategy) -> [RobotConfig] {
        var configs: [RobotConfig] = []

        // --- Red Alliance (player's team) ---
        let playerStats = statsForRole(playerRole, boost: true)
        configs.append(RobotConfig(
            id: 0, alliance: .red, role: playerRole,
            stats: playerStats, superstructure: superstructureForRole(playerRole),
            teamNumber: "9999", startPosition: FieldLayout.redStarts[0]
        ))

        let comp1 = complementRole1(for: strategy, playerRole: playerRole)
        configs.append(RobotConfig(
            id: 1, alliance: .red, role: comp1,
            stats: statsForRole(comp1, boost: false),
            superstructure: superstructureForRole(comp1),
            teamNumber: "2468", startPosition: FieldLayout.redStarts[1]
        ))

        let comp2 = complementRole2(for: strategy, playerRole: playerRole)
        configs.append(RobotConfig(
            id: 2, alliance: .red, role: comp2,
            stats: statsForRole(comp2, boost: false),
            superstructure: superstructureForRole(comp2),
            teamNumber: "1357", startPosition: FieldLayout.redStarts[2]
        ))

        // --- Blue Alliance (opponent, fixed balanced strategy) ---
        configs.append(RobotConfig(
            id: 3, alliance: .blue, role: .scorer,
            stats: RobotStats(maxSpeed: 1.8, acceleration: 1.2, turnRate: 2.5,
                              scoringTime: 1.2, pickupTime: 1.0, reliability: 0.92),
            superstructure: .elevator, teamNumber: "254",
            startPosition: FieldLayout.blueStarts[0]
        ))

        configs.append(RobotConfig(
            id: 4, alliance: .blue, role: .cycler,
            stats: RobotStats(maxSpeed: 2.8, acceleration: 2.0, turnRate: 3.5,
                              scoringTime: 1.8, pickupTime: 0.8, reliability: 0.88),
            superstructure: .turretIntake, teamNumber: "1678",
            startPosition: FieldLayout.blueStarts[1]
        ))

        configs.append(RobotConfig(
            id: 5, alliance: .blue, role: .defender,
            stats: RobotStats(maxSpeed: 3.0, acceleration: 2.5, turnRate: 4.0,
                              scoringTime: 2.5, pickupTime: 1.5, reliability: 0.95),
            superstructure: .wedge, teamNumber: "118",
            startPosition: FieldLayout.blueStarts[2]
        ))

        return configs
    }

    private static func statsForRole(_ role: RobotRole, boost: Bool) -> RobotStats {
        let b: Float = boost ? 0.15 : 0.0
        switch role {
        case .scorer:
            return RobotStats(maxSpeed: 1.6 + b, acceleration: 1.2, turnRate: 2.5,
                              scoringTime: 1.0, pickupTime: 1.0, reliability: 0.93)
        case .cycler:
            return RobotStats(maxSpeed: 2.8 + b, acceleration: 2.2, turnRate: 3.5,
                              scoringTime: 1.6, pickupTime: 0.7, reliability: 0.87)
        case .defender:
            return RobotStats(maxSpeed: 3.2 + b, acceleration: 2.8, turnRate: 4.2,
                              scoringTime: 2.5, pickupTime: 1.5, reliability: 0.95)
        }
    }

    private static func superstructureForRole(_ role: RobotRole) -> SuperstructureType {
        switch role {
        case .scorer:   return .dualRail
        case .cycler:   return .arm
        case .defender: return .wedge
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
