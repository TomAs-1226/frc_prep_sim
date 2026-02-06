import Foundation
import SwiftUI

// MARK: - Game State Machine

/// The primary states the app flows through linearly.
enum GamePhase: Equatable {
    case welcome
    case buildChoice
    case autoChoice
    case simulation
    case results
}

// MARK: - Robot Archetypes

/// Three build archetypes with distinct strategy tradeoffs.
enum RobotArchetype: String, CaseIterable, Identifiable {
    case speedy   = "Speedy Drivetrain"
    case balanced = "Balanced"
    case heavy    = "Heavy Scorer"

    var id: String { rawValue }

    var stats: RobotStats {
        switch self {
        case .speedy:
            return RobotStats(
                maxSpeed: 3.0,
                acceleration: 2.5,
                turnRate: 4.0,
                scoringTime: 2.5,
                pickupTime: 1.5,
                reliability: 0.75
            )
        case .balanced:
            return RobotStats(
                maxSpeed: 2.0,
                acceleration: 1.8,
                turnRate: 3.0,
                scoringTime: 1.8,
                pickupTime: 1.2,
                reliability: 0.90
            )
        case .heavy:
            return RobotStats(
                maxSpeed: 1.2,
                acceleration: 1.0,
                turnRate: 2.0,
                scoringTime: 1.0,
                pickupTime: 0.8,
                reliability: 0.97
            )
        }
    }

    var icon: String {
        switch self {
        case .speedy:   return "hare.fill"
        case .balanced: return "scalemass.fill"
        case .heavy:    return "hammer.fill"
        }
    }

    var color: Color {
        switch self {
        case .speedy:   return .cyan
        case .balanced: return .orange
        case .heavy:    return .red
        }
    }

    var description: String {
        switch self {
        case .speedy:
            return "Fast traversal, but limited scoring ability. Great for taxi points and quick cycles — if you can line up."
        case .balanced:
            return "Medium speed and scoring. A reliable all-rounder that adapts to any match situation."
        case .heavy:
            return "Slow but powerful scorer. Dominates the Reef Zone when it arrives, but takes time getting there."
        }
    }

    /// Visual scale factors for the 3D preview robot per archetype.
    var chassisScale: SIMD3<Float> {
        switch self {
        case .speedy:   return SIMD3<Float>(0.7, 0.3, 1.0)
        case .balanced: return SIMD3<Float>(0.8, 0.45, 0.85)
        case .heavy:    return SIMD3<Float>(1.0, 0.6, 0.8)
        }
    }
}

// MARK: - Robot Stats

/// Numeric stats that govern simulation behavior.
struct RobotStats {
    let maxSpeed: Double       // meters/sec in sim
    let acceleration: Double   // meters/sec²
    let turnRate: Double       // radians/sec
    let scoringTime: Double    // seconds to score at a node
    let pickupTime: Double     // seconds to pick up a game piece
    let reliability: Double    // 0…1, probability of NOT stalling
}

// MARK: - Auto Plans

/// Three autonomous routine choices with varying risk/reward.
enum AutoPlanType: String, CaseIterable, Identifiable {
    case taxiPlusOne = "Taxi + 1 Score"
    case twoScore    = "2 Score"
    case riskySprint = "Risky Sprint"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .taxiPlusOne: return "shield.fill"
        case .twoScore:    return "target"
        case .riskySprint: return "bolt.fill"
        }
    }

    var color: Color {
        switch self {
        case .taxiPlusOne: return .green
        case .twoScore:    return .yellow
        case .riskySprint: return .red
        }
    }

    var riskLabel: String {
        switch self {
        case .taxiPlusOne: return "Low Risk"
        case .twoScore:    return "Medium Risk"
        case .riskySprint: return "High Risk"
        }
    }

    var description: String {
        switch self {
        case .taxiPlusOne:
            return "Drive out of the Start Zone for taxi points, score 1 piece at the nearest node. Safe and consistent."
        case .twoScore:
            return "Score 2 pieces by visiting two nodes. Requires decent speed and reliability."
        case .riskySprint:
            return "Sprint across the field and attempt all 3 nodes. High reward but a real chance of stalling mid-run."
        }
    }

    var pointsPossible: Int {
        switch self {
        case .taxiPlusOne: return 7   // 2 taxi + 5 score
        case .twoScore:    return 12  // 2 taxi + 10 score
        case .riskySprint: return 17  // 2 taxi + 15 score
        }
    }
}

// MARK: - Auto Plan (waypoints + scoring sequence)

/// A concrete auto plan with waypoints for the simulation to follow.
struct AutoPlan {
    let type: AutoPlanType
    let waypoints: [Waypoint]
    let failureChance: Double  // probability of stall during auto

    struct Waypoint {
        let position: SIMD2<Float>   // x, z on the field
        let action: WaypointAction
        let label: String
    }

    enum WaypointAction {
        case drive           // just move here
        case score           // score a game piece at this location
        case pickup          // pick up a game piece
    }
}

/// Builds the concrete auto plan waypoints for a given type.
func buildAutoPlan(for type: AutoPlanType) -> AutoPlan {
    // Field coordinates: origin at center, field is ~6m x 3m
    // Start zone: x = -2.5, Reef zone: x = 1.5..2.5
    // Nodes at roughly: (-0.5, -0.8), (1.0, 0.0), (2.0, 0.8)

    switch type {
    case .taxiPlusOne:
        return AutoPlan(
            type: type,
            waypoints: [
                .init(position: SIMD2(-2.0, 0.0), action: .drive, label: "Leave Start Zone"),
                .init(position: SIMD2(-1.0, 0.0), action: .pickup, label: "Grab Piece"),
                .init(position: SIMD2(-0.5, -0.8), action: .score, label: "Score Node 1"),
            ],
            failureChance: 0.05
        )
    case .twoScore:
        return AutoPlan(
            type: type,
            waypoints: [
                .init(position: SIMD2(-2.0, 0.0), action: .drive, label: "Leave Start Zone"),
                .init(position: SIMD2(-1.0, 0.0), action: .pickup, label: "Grab Piece"),
                .init(position: SIMD2(-0.5, -0.8), action: .score, label: "Score Node 1"),
                .init(position: SIMD2(0.0, 0.0), action: .pickup, label: "Grab Piece 2"),
                .init(position: SIMD2(1.0, 0.0), action: .score, label: "Score Node 2"),
            ],
            failureChance: 0.15
        )
    case .riskySprint:
        return AutoPlan(
            type: type,
            waypoints: [
                .init(position: SIMD2(-2.0, 0.0), action: .drive, label: "Sprint Start"),
                .init(position: SIMD2(-1.0, 0.0), action: .pickup, label: "Grab Piece"),
                .init(position: SIMD2(-0.5, -0.8), action: .score, label: "Score Node 1"),
                .init(position: SIMD2(0.2, 0.3), action: .pickup, label: "Grab Piece 2"),
                .init(position: SIMD2(1.0, 0.0), action: .score, label: "Score Node 2"),
                .init(position: SIMD2(1.5, 0.5), action: .pickup, label: "Grab Piece 3"),
                .init(position: SIMD2(2.0, 0.8), action: .score, label: "Score Node 3"),
            ],
            failureChance: 0.40
        )
    }
}

// MARK: - Simulation State

/// Tracks the robot's current activity during simulation.
enum RobotActivity: String {
    case idle       = "Idle"
    case driving    = "Driving"
    case scoring    = "Scoring"
    case pickingUp  = "Picking Up"
    case stalled    = "Stalled!"
    case finished   = "Finished"
}

// MARK: - Simulation Result

/// Final outcome of a simulation run for the results screen.
struct SimulationResult {
    let archetype: RobotArchetype
    let autoPlan: AutoPlanType
    let totalPoints: Int
    let nodesScored: Int
    let totalNodes: Int
    let didStall: Bool
    let timeUsed: Double       // simulated seconds used
    let totalTime: Double      // total match time
}

// MARK: - Seeded Random Number Generator

/// Deterministic RNG for reproducible simulation runs (important for judging).
struct SeededRandomGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64 = 42) {
        state = seed
    }

    mutating func next() -> UInt64 {
        // xorshift64
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    /// Returns a Double in [0, 1).
    mutating func nextDouble() -> Double {
        return Double(next() & 0x1FFFFFFFFFFFFF) / Double(1 << 53)
    }
}

// Note: Settings are accessed directly via @AppStorage in individual views
// (SettingsView, RookieRushApp) to avoid unnecessary shared state objects.
