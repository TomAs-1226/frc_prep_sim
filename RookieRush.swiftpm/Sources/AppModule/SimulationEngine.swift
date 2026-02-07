import Foundation
import QuartzCore
import SceneKit
import simd

// MARK: - Utility Helper

private func distance2D(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
    let d = a - b
    return sqrt(d.x * d.x + d.y * d.y)
}

private struct KeepOutCircle {
    let center: SIMD2<Float>
    let radius: Float
}

private struct KeepOutRect {
    let center: SIMD2<Float>
    let halfSize: SIMD2<Float>

    func nearestPoint(to point: SIMD2<Float>) -> SIMD2<Float> {
        let clampedX = max(center.x - halfSize.x, min(center.x + halfSize.x, point.x))
        let clampedZ = max(center.y - halfSize.y, min(center.y + halfSize.y, point.y))
        return SIMD2<Float>(clampedX, clampedZ)
    }
}

private enum CoralState {
    case onGround
    case inIntake
    case carried
    case scoringAnim
    case scored
    case dropped
}

private struct CoralSocketKey: Hashable {
    let alliance: Alliance
    let face: Int
    let level: Int
    let slot: Int
}

private struct CoralSocket {
    let position: SIMD3<Float>
    let yaw: Float
}

private final class CoralPiece {
    let id: Int
    let node: SCNNode
    var position: SIMD2<Float>
    var height: Float
    var verticalVelocity: Float
    var state: CoralState
    weak var carriedBy: RobotAgent?
    var socketKey: CoralSocketKey?
    var animProgress: Float
    var animStart: SIMD3<Float>
    var animEnd: SIMD3<Float>

    init(id: Int, node: SCNNode, position: SIMD2<Float>) {
        self.id = id
        self.node = node
        self.position = position
        self.height = max(0.0, node.position.y)
        self.verticalVelocity = 0
        self.state = .onGround
        self.animProgress = 0
        self.animStart = node.simdPosition
        self.animEnd = node.simdPosition
    }
}

// MARK: - Robot Agent

final class WheelModuleController {
    let steerPivot: SCNNode
    let wheelRoll: SCNNode
    let wheelRadius: Float
    var steerAngle: Float = 0
    var rollAngle: Float = 0

    init(ref: WheelModuleRef) {
        self.steerPivot = ref.steerPivot
        self.wheelRoll = ref.wheelRoll
        self.wheelRadius = ref.wheelRadius
    }
}

class RobotAgent {
    let config: RobotConfig
    var state: RobotState = .idle
    var aiState: AIState = .seekPickup
    var position: SIMD2<Float>
    var heading: Float = 0
    var speed: Float = 0
    var velocity: SIMD2<Float> = .zero
    var angularVelocity: Float = 0
    var hasPiece: Bool = false
    var piecesScored: Int = 0
    var piecesCycled: Int = 0
    var isStalled: Bool = false
    var stallTimer: Double = 0
    var actionTimer: Double = 0
    var targetPosition: SIMD2<Float>?
    var currentTargetLevel: Int = 1
    var hasCrossedAutoLine: Bool = false
    var isParkedEndgame: Bool = false
    var didStall: Bool = false
    var autoPhase: Int = 0
    var lastFaceUsed: Int = -1
    weak var sceneNode: SCNNode?

    // Score awareness (updated each tick by MatchEngine)
    var teamScore: Int = 0
    var opponentScore: Int = 0

    // Cached component nodes for animation
    var swerveModules: [WheelModuleController] = []
    var tankWheels: [SCNNode] = []
    var mechanismNode: SCNNode?   // elevator_stage or pivot_arm
    var intakeNode: SCNNode?      // intake_roller
    var intakeAnchor: SCNNode?
    var goalDescription: String = "--"
    var carriedPieceId: Int?

    init(config: RobotConfig) {
        self.config = config
        self.position = config.startPosition
        self.heading = config.alliance == .red ? Float.pi : 0
    }

    /// Cache references to animatable child nodes.
    func configureSceneNodes(from entity: RobotMatchEntity) {
        sceneNode = entity.root
        swerveModules = entity.swerveModules.map { WheelModuleController(ref: $0) }
        tankWheels = entity.tankWheels
        mechanismNode = entity.mechanismNode
        intakeNode = entity.intakeRoller
        intakeAnchor = entity.intakeAnchor
    }

    // MARK: - Utility-Based Goal Selection (Deterministic FSM)

    func decideGoal(simTime: Double, policy: StrategyPolicy, allAgents: [RobotAgent],
                    pickupTargets: [SIMD2<Float>]) {
        guard state == .idle || state == .driving else { return }

        let timeRemaining = MatchTiming.totalDuration - simTime
        let period = currentPeriod(simTime)

        // --- Score-aware policy adjustment ---
        let scoreDiff = teamScore - opponentScore
        var adjustedPolicy = policy
        if scoreDiff < -10 {
            adjustedPolicy.scoringWeight = min(1.0, policy.scoringWeight + 0.2)
            adjustedPolicy.endgameWeight = max(0.05, policy.endgameWeight - 0.1)
        } else if scoreDiff > 15 {
            adjustedPolicy.defenseWeight = min(1.0, policy.defenseWeight + 0.15)
            adjustedPolicy.endgameWeight = min(1.0, policy.endgameWeight + 0.1)
        }

        // --- Endgame urgency ---
        let endgameUrgency = max(0, 1.0 - timeRemaining / 25.0)
        if (period == .endgame || endgameUrgency > 0.7) && !isParkedEndgame {
            let endgameUtil = adjustedPolicy.endgameWeight + endgameUrgency * 1.5
            if endgameUtil > 0.8 || timeRemaining < 10 {
                let barge = config.alliance == .red ? FieldLayout.redBarge : FieldLayout.blueBarge
                targetPosition = barge
                aiState = .endgame
                goalDescription = "Endgame"
                state = .headingEndgame
                return
            }
        }

        // --- Defense utility (defenders prefer blocking) ---
        if config.role == .defender {
            let defUtil = adjustedPolicy.defenseWeight * 1.5
            let scoreUtil = adjustedPolicy.scoringWeight
            if defUtil > scoreUtil {
                if let target = bestDefenseTarget(allAgents: allAgents) {
                    targetPosition = target
                    aiState = .defend
                    goalDescription = "Defend"
                    state = .defending
                    return
                }
            }
        }

        if hasPiece {
            let best = chooseBestScoringTarget(policy: adjustedPolicy, allAgents: allAgents)
            targetPosition = best.position
            currentTargetLevel = best.level
            lastFaceUsed = best.face
            aiState = .seekScore
            goalDescription = best.goalId
            state = .driving
        } else {
            let target = choosePickupTarget(pickupTargets: pickupTargets)
            targetPosition = target
            aiState = .seekPickup
            goalDescription = "Pickup"
            state = .driving
        }
    }

    // MARK: - Defender Targeting

    private func bestDefenseTarget(allAgents: [RobotAgent]) -> SIMD2<Float>? {
        let opponents = allAgents.filter {
            $0.config.alliance != config.alliance && !$0.isParkedEndgame
        }
        guard let target = opponents.max(by: { defenderPriority($0) < defenderPriority($1) }) else {
            return nil
        }
        let theirReef = config.alliance == .red ? FieldSpec.blueReefCenter : FieldSpec.redReefCenter
        return SIMD2<Float>(
            target.position.x * 0.6 + theirReef.x * 0.4,
            target.position.y * 0.6 + theirReef.y * 0.4
        )
    }

    private func defenderPriority(_ opp: RobotAgent) -> Double {
        var score = 0.0
        if opp.hasPiece { score += 10.0 }
        if opp.state == .scoring { score += 5.0 }
        if opp.state == .driving && opp.hasPiece { score += 3.0 }
        if opp.config.role == .scorer { score += 3.0 }
        if opp.config.role == .cycler { score += 2.0 }
        score += Double(opp.piecesScored) * 0.5
        score -= Double(distance2D(position, opp.position)) * 0.3
        return score
    }

    // MARK: - Scoring Target Selection (Utility)

    private func chooseBestScoringTarget(policy: StrategyPolicy,
                                          allAgents: [RobotAgent]) -> (position: SIMD2<Float>, level: Int, face: Int, goalId: String) {
        let maxLevel = config.stats.maxReefLevel
        let reefCenter = config.alliance == .red ? FieldSpec.redReefCenter : FieldSpec.blueReefCenter
        var best: (SIMD2<Float>, Int, Int, String, Double) = (
            config.alliance == .red ? FieldLayout.redReefApproach(0) : FieldLayout.blueReefApproach(0),
            1, 0, "Reef L1", -1
        )

        let teammates = allAgents.filter {
            $0.config.alliance == config.alliance && $0.config.id != config.id
        }

        for face in 0..<6 {
            let approach = config.alliance == .red
                ? FieldLayout.redReefApproach(face)
                : FieldLayout.blueReefApproach(face)
            let dist = distance2D(position, approach)
            let congestion = Double(teammates.filter {
                if let target = $0.targetPosition {
                    return distance2D(target, approach) < 0.35
                }
                return distance2D($0.position, approach) < 0.4
            }.count)

            for level in 1...maxLevel {
                let basePoints: Double
                switch level {
                case 1: basePoints = 2
                case 2: basePoints = 3
                case 3: basePoints = 4
                default: basePoints = 5
                }

                let roleBias: Double
                switch config.role {
                case .cycler:
                    roleBias = level <= 2 ? 1.4 : 0.4
                case .scorer:
                    roleBias = level >= 3 ? 1.5 : 0.7
                case .defender:
                    roleBias = 1.0
                }

                let preferHigh = policy.preferHighLevel && level >= 3 ? 0.5 : 0.0
                let spreadBonus = policy.spreadOut && face != lastFaceUsed ? 0.2 : 0.0
                let timeCost = Double(dist) / Double(max(0.5, config.stats.maxSpeed)) + config.stats.scoringTime
                let risk = (1.0 - config.stats.reliability) + congestion * 0.15
                let util = (basePoints * roleBias + preferHigh + spreadBonus) /
                    max(0.3, timeCost + risk + congestion * 0.4)

                let tieBreaker = Double(config.id) * 0.0001
                if util + tieBreaker > best.4 {
                    best = (approach, level, face, "Reef L\(level) F\(face + 1)", util)
                }
            }
        }

        let proc = config.alliance == .red ? FieldLayout.redProcessor : FieldLayout.blueProcessor
        let procDist = distance2D(position, proc)
        let procTimeCost = Double(procDist) / Double(max(0.5, config.stats.maxSpeed)) + 1.0
        let procUtil = 6.0 / max(0.3, procTimeCost)
        if procUtil > best.4 {
            return (proc, 0, 0, "Processor", procUtil)
        }

        return (best.0, best.1, best.2, best.3)
    }

    // MARK: - Pickup Targeting

    private func choosePickupTarget(pickupTargets: [SIMD2<Float>]) -> SIMD2<Float> {
        guard !pickupTargets.isEmpty else {
            return config.alliance == .red ? FieldLayout.redSource : FieldLayout.blueSource
        }
        let best = pickupTargets.min {
            distance2D(position, $0) < distance2D(position, $1)
        }
        return best ?? pickupTargets[0]
    }

    // MARK: - Period

    func currentPeriod(_ simTime: Double) -> MatchPeriod {
        if simTime < MatchTiming.teleopStart { return .auto }
        if simTime < MatchTiming.endgameStart { return .teleop }
        if simTime < MatchTiming.totalDuration { return .endgame }
        return .finished
    }

    // MARK: - Movement

    func updateMovement(dt: Float, keepOutCircles: [KeepOutCircle], keepOutRects: [KeepOutRect]) {
        guard let target = targetPosition else { return }
        let toTarget = SIMD2<Float>(target.x - position.x, target.y - position.y)
        let dist = sqrt(toTarget.x * toTarget.x + toTarget.y * toTarget.y)

        if dist < 0.12 {
            speed = 0
            velocity = .zero
            return
        }

        var desiredDir = SIMD2<Float>(toTarget.x / max(0.001, dist), toTarget.y / max(0.001, dist))
        var avoidance = SIMD2<Float>(0, 0)

        for circle in keepOutCircles {
            let delta = position - circle.center
            let d = sqrt(delta.x * delta.x + delta.y * delta.y)
            let buffer = circle.radius + 0.35
            if d < buffer {
                let push = (buffer - d) / max(0.01, buffer)
                avoidance += SIMD2<Float>(delta.x / max(0.001, d), delta.y / max(0.001, d)) * push
            }
        }

        for rect in keepOutRects {
            let nearest = rect.nearestPoint(to: position)
            let delta = position - nearest
            let d = sqrt(delta.x * delta.x + delta.y * delta.y)
            let buffer: Float = 0.30
            if d < buffer {
                let push = (buffer - d) / max(0.01, buffer)
                avoidance += SIMD2<Float>(delta.x / max(0.001, d), delta.y / max(0.001, d)) * push
            }
        }

        if avoidance.x != 0 || avoidance.y != 0 {
            desiredDir += avoidance * 1.4
            let len = sqrt(desiredDir.x * desiredDir.x + desiredDir.y * desiredDir.y)
            if len > 0.001 {
                desiredDir /= len
            }
        }

        let targetHeading = atan2(desiredDir.x, desiredDir.y)
        var angleDiff = targetHeading - heading
        while angleDiff > Float.pi { angleDiff -= 2 * Float.pi }
        while angleDiff < -Float.pi { angleDiff += 2 * Float.pi }
        let maxTurn = config.stats.turnRate * dt
        let turnAmount = max(-maxTurn, min(maxTurn, angleDiff))
        heading += turnAmount
        angularVelocity = turnAmount / max(0.001, dt)

        let targetSpeed = min(config.stats.maxSpeed, dist * 2.2)
        let speedDelta = targetSpeed - speed
        let maxDelta = config.stats.acceleration * dt
        speed += max(-maxDelta, min(maxDelta, speedDelta))

        velocity = SIMD2<Float>(sin(heading), cos(heading)) * speed
        position += velocity * dt

        // Clamp to field bounds
        position.x = max(-FieldLayout.halfWidth + 0.20, min(FieldLayout.halfWidth - 0.20, position.x))
        position.y = max(-FieldLayout.halfLength + 0.20, min(FieldLayout.halfLength - 0.20, position.y))
    }

    var hasReachedTarget: Bool {
        guard let target = targetPosition else { return false }
        return distance2D(position, target) < 0.2
    }

    // MARK: - Scene Sync

    func syncToScene(dt: Float) {
        guard let node = sceneNode else { return }
        node.position = SCNVector3(position.x, 0.0, position.y)
        node.eulerAngles.y = heading

        // Animate wheels proportional to linear velocity
        let linearSpeed = sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
        if !swerveModules.isEmpty {
            let velHeading = atan2(velocity.x, velocity.y)
            var localSteer = velHeading - heading
            while localSteer > Float.pi { localSteer -= 2 * Float.pi }
            while localSteer < -Float.pi { localSteer += 2 * Float.pi }

            for module in swerveModules {
                let maxSteerRate: Float = 6.0
                let steerDelta = localSteer - module.steerAngle
                let clamped = max(-maxSteerRate * dt, min(maxSteerRate * dt, steerDelta))
                module.steerAngle += clamped
                module.steerPivot.eulerAngles.y = module.steerAngle

                if module.wheelRadius > 0 {
                    let rollRate = linearSpeed / module.wheelRadius
                    module.rollAngle += rollRate * dt
                    module.wheelRoll.eulerAngles.x = module.rollAngle
                }
            }
        } else if !tankWheels.isEmpty {
            let rollRate: Float = 12.0 * (linearSpeed / max(0.01, config.stats.maxSpeed))
            for wheel in tankWheels {
                wheel.eulerAngles.x += rollRate * dt
            }
        }

        // Animate intake roller when picking up
        if state == .pickingUp, let intake = intakeNode {
            intake.eulerAngles.x += Float.pi * 6.0 * dt
        }

        // Animate mechanism during scoring
        if state == .scoring, let mech = mechanismNode {
            if mech.name == "elevator_stage" {
                // Extend elevator upward based on target level
                let targetY: Float
                switch currentTargetLevel {
                case 1: targetY = 0.08   // base position
                case 2: targetY = 0.14
                case 3: targetY = 0.22
                default: targetY = 0.30  // L4 full extension
                }
                let baseY = config.build.mechanism == .elevator ? Float(0.08) : Float(0.08)
                mech.position.y += (targetY + baseY - mech.position.y) * 0.08
            } else if mech.name == "pivot_arm" {
                // Tilt arm forward during scoring
                let targetAngle: Float = -0.4  // tilt forward
                mech.eulerAngles.x += (targetAngle - mech.eulerAngles.x) * 0.06
            }
        } else if let mech = mechanismNode {
            // Return to rest position when not scoring
            if mech.name == "elevator_stage" {
                let baseY: Float = 0.08 + 0.08
                mech.position.y += (baseY - mech.position.y) * 0.05
            } else if mech.name == "pivot_arm" {
                mech.eulerAngles.x += (0.35 - mech.eulerAngles.x) * 0.05
            }
        }
    }
}

// MARK: - Match Engine

@MainActor
final class MatchEngine: ObservableObject {

    @Published var simTime: Double = 0
    @Published var period: MatchPeriod = .auto
    @Published var redScore: Int = 0
    @Published var blueScore: Int = 0
    @Published var redBreakdown = ScoreBreakdown()
    @Published var blueBreakdown = ScoreBreakdown()
    @Published var isRunning: Bool = false
    @Published var isFinished: Bool = false
    @Published var speedMultiplier: Double = 2.0
    @Published var strategyMode: String = "Scoring Mode"
    @Published var robotStates: [Int: RobotState] = [:]
    @Published var currentTip: CoachingTip?
    @Published var isSlowMo: Bool = false
    @Published var activeCallouts: Set<Callout> = []  // Currently active callouts
    @Published var calloutCooldown: Double = 0        // Seconds until next callout available

    let configs: [RobotConfig]
    let playerAutoPlan: AutoPlan
    var redPolicy: StrategyPolicy
    let bluePolicy = StrategyPolicy(scoringWeight: 0.6, defenseWeight: 0.2, endgameWeight: 0.2)

    var agents: [RobotAgent] = []
    var rng: SeededRNG
    private var calloutsUsed: [Callout] = []
    private var calloutEvents: [CalloutEvent] = []
    private var slowMoTimer: Double = 0
    private var slowMoUsed: Bool = false
    private var scene: SCNScene?
    private var reefNodeTargets: [SCNNode] = []
    private let robotRadius: Float = 0.22
    private var coralPieces: [CoralPiece] = []
    private var occupiedSockets: Set<CoralSocketKey> = []
    private var nextCoralId: Int = 0
    private var displayLink: CADisplayLink?
    private var accumulator: Double = 0
    private let fixedTimeStep: Double = 1.0 / 60.0
    private var lastFrameTimestamp: CFTimeInterval?
    @Published var fps: Double = 0
    @Published var frameDt: Double = 0
    @Published var robotDebugInfo: [RobotDebugInfo] = []
    @Published var showDiagnostics: Bool = false

    init(configs: [RobotConfig], strategy: AllianceStrategy, playerAuto: AutoPlan, seed: UInt64 = 42) {
        self.configs = configs
        self.playerAutoPlan = playerAuto
        self.redPolicy = strategy.basePolicy
        self.rng = SeededRNG(seed: seed)

        for config in configs {
            agents.append(RobotAgent(config: config))
        }
    }

    private var keepOutCircles: [KeepOutCircle] {
        [
            KeepOutCircle(center: FieldSpec.redReefCenter, radius: FieldSpec.reefRadius + 0.25),
            KeepOutCircle(center: FieldSpec.blueReefCenter, radius: FieldSpec.reefRadius + 0.25),
        ]
    }

    private var keepOutRects: [KeepOutRect] {
        [
            KeepOutRect(
                center: FieldSpec.bargeCenter,
                halfSize: SIMD2<Float>(
                    FieldSpec.bargeTrussDepth / 2 + 0.20,
                    FieldSpec.bargeTrussSpan / 2 + 0.25
                )
            ),
            KeepOutRect(
                center: FieldSpec.redProcessor,
                halfSize: SIMD2<Float>(FieldSpec.processorDepth / 2 + 0.18, FieldSpec.processorWidth / 2 + 0.18)
            ),
            KeepOutRect(
                center: FieldSpec.blueProcessor,
                halfSize: SIMD2<Float>(FieldSpec.processorDepth / 2 + 0.18, FieldSpec.processorWidth / 2 + 0.18)
            ),
        ]
    }

    // MARK: - Scene Binding

    func attach(scene: SCNScene, robotEntities: [RobotMatchEntity], reefNodes: [SCNNode]) {
        self.scene = scene
        self.reefNodeTargets = reefNodes
        for (i, agent) in agents.enumerated() where i < robotEntities.count {
            let entity = robotEntities[i]
            agent.configureSceneNodes(from: entity)
            agent.syncToScene(dt: Float(fixedTimeStep))
        }
        registerCoralPieces(in: scene)
        for agent in agents {
            robotStates[agent.config.id] = .idle
        }
    }

    // MARK: - Start / Stop

    func start() {
        guard !isRunning else { return }
        isRunning = true
        isFinished = false
        simTime = 0
        strategyMode = redPolicy.dominantMode
        speedMultiplier = 2.0
        accumulator = 0
        lastFrameTimestamp = nil

        displayLink?.invalidate()
        displayLink = CADisplayLink(target: self, selector: #selector(stepFrame))
        displayLink?.preferredFramesPerSecond = 60
        displayLink?.add(to: .main, forMode: .common)
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        isRunning = false
    }

    // MARK: - Callouts

    /// Per-callout availability: must be correct period, off cooldown, and not already active.
    func canUseCallout(_ callout: Callout) -> Bool {
        guard isRunning, !isFinished, calloutCooldown <= 0 else { return false }
        guard callout.isAvailable(during: period) else { return false }
        return !activeCallouts.contains(callout)
    }

    /// Legacy computed property for basic "any callout available" check.
    var canUseAnyCallout: Bool {
        guard isRunning, !isFinished, calloutCooldown <= 0 else { return false }
        return Callout.allCases.contains { canUseCallout($0) }
    }

    func useCallout(_ callout: Callout) {
        guard canUseCallout(callout) else { return }
        calloutsUsed.append(callout)
        activeCallouts.insert(callout)
        calloutCooldown = 5.0  // 5-second cooldown between callouts

        // Record event for decision map
        calloutEvents.append(CalloutEvent(
            callout: callout,
            matchTime: simTime,
            redScoreAtTime: redScore,
            blueScoreAtTime: blueScore
        ))

        // Apply strategy policy change
        redPolicy = redPolicy.applying(callout: callout)
        strategyMode = redPolicy.dominantMode

        // Immediately apply behavioral changes to agents
        applyCalloutEffects(callout)
    }

    /// Force agents to naturally react to the callout.
    private func applyCalloutEffects(_ callout: Callout) {
        let redAgents = agents.filter { $0.config.alliance == .red && !$0.isParkedEndgame }

        switch callout {
        case .prioritizeReef:
            // All red agents re-evaluate goals → prioritize scoring
            for agent in redAgents where agent.state == .idle || agent.state == .driving || agent.state == .defending {
                agent.state = .idle  // Force re-goal with new policy
                agent.aiState = agent.hasPiece ? .seekScore : .seekPickup
            }

        case .switchDefense:
            // Find best candidate to switch to defense (non-defender that isn't carrying a piece)
            if let candidate = redAgents.first(where: {
                $0.config.role != .defender && !$0.hasPiece && $0.config.id != 0
                && ($0.state == .idle || $0.state == .driving)
            }) {
                // Immediately set to defending
                let opponents = agents.filter { $0.config.alliance == .blue && !$0.isParkedEndgame }
                if let target = opponents.max(by: { $0.piecesScored < $1.piecesScored }) {
                    let theirReef = FieldSpec.blueReefCenter
                    candidate.targetPosition = SIMD2<Float>(
                        target.position.x * 0.6 + theirReef.x * 0.4,
                        target.position.y * 0.6 + theirReef.y * 0.4
                    )
                    candidate.state = .defending
                    candidate.aiState = .defend
                }
            }

        case .endgameEarly:
            // All red agents head to endgame positions immediately
            for agent in redAgents where !agent.isParkedEndgame && agent.state != .climbing {
                agent.targetPosition = FieldLayout.redBarge
                agent.state = .headingEndgame
                agent.aiState = .endgame
            }

        case .focusHigh:
            // Scorers re-evaluate to pick higher targets
            for agent in redAgents where (agent.state == .idle || agent.state == .driving) {
                agent.state = .idle  // Force re-goal with preferHighLevel
                agent.aiState = agent.hasPiece ? .seekScore : .seekPickup
            }

        case .spreadOut:
            // Reset lastFaceUsed so all agents pick new faces
            for agent in redAgents {
                agent.lastFaceUsed = -1
                if agent.state == .idle || agent.state == .driving {
                    agent.state = .idle  // Force re-goal
                    agent.aiState = agent.hasPiece ? .seekScore : .seekPickup
                }
            }

        case .allOutAttack:
            // Defenders switch to scoring, everyone re-evaluates
            for agent in redAgents {
                if agent.state == .defending {
                    agent.state = .idle
                    agent.aiState = agent.hasPiece ? .seekScore : .seekPickup
                }
            }
        }
    }

    // MARK: - Slow-Mo

    func activateSlowMo(duration: Double = 9.0) {
        guard isRunning, !isSlowMo else { return }
        isSlowMo = true
        slowMoUsed = true
        slowMoTimer = duration
        speedMultiplier = 0.5
        generateCoachingTip()
    }

    private func deactivateSlowMo() {
        isSlowMo = false
        speedMultiplier = 2.0
        currentTip = nil
    }

    func resumeNormalSpeed() {
        deactivateSlowMo()
    }

    // MARK: - Main Tick

    @objc private func stepFrame(_ link: CADisplayLink) {
        guard isRunning else { return }
        let now = link.timestamp
        let wallDt = lastFrameTimestamp.map { now - $0 } ?? fixedTimeStep
        lastFrameTimestamp = now

        let clampedWallDt = min(wallDt, 1.0 / 20.0)
        frameDt = clampedWallDt
        fps = clampedWallDt > 0 ? 1.0 / clampedWallDt : 0

        if isSlowMo {
            slowMoTimer -= clampedWallDt
            if slowMoTimer <= 0 { deactivateSlowMo() }
        }

        accumulator += clampedWallDt * speedMultiplier
        let maxSteps = 5
        var steps = 0
        while accumulator >= fixedTimeStep && steps < maxSteps {
            stepSimulation(simDt: fixedTimeStep)
            accumulator -= fixedTimeStep
            steps += 1
        }
    }

    private func stepSimulation(simDt: Double) {
        simTime += simDt

        if simTime < MatchTiming.teleopStart {
            period = .auto
        } else if simTime < MatchTiming.endgameStart {
            period = .teleop
        } else if simTime < MatchTiming.totalDuration {
            period = .endgame
        } else {
            finishMatch()
            return
        }

        if calloutCooldown > 0 {
            calloutCooldown = max(0, calloutCooldown - simDt)
        }

        let dt = Float(simDt)

        for agent in agents {
            if agent.config.alliance == .red {
                agent.teamScore = redScore
                agent.opponentScore = blueScore
            } else {
                agent.teamScore = blueScore
                agent.opponentScore = redScore
            }
        }

        let pickupTargets = availablePickupTargets()
        for agent in agents {
            updateAgent(agent, dt: dt, simDt: simDt, pickupTargets: pickupTargets)
        }

        resolveSeparation()
        resolveStructureConstraints()

        for agent in agents {
            agent.syncToScene(dt: dt)
            robotStates[agent.config.id] = agent.state
        }

        updateCoralPieces(dt: dt)
        updateHighlights()

        robotDebugInfo = agents.map { agent in
            RobotDebugInfo(
                id: agent.config.id,
                teamNumber: agent.config.teamNumber,
                alliance: agent.config.alliance,
                role: agent.config.role,
                aiState: agent.aiState,
                goal: agent.goalDescription,
                hasPiece: agent.hasPiece,
                speed: agent.speed
            )
        }
    }

    private func updateHighlights() {
        for agent in agents {
            agent.sceneNode?.childNode(withName: "highlight_ring", recursively: false)?.removeFromParentNode()
        }
        guard isSlowMo, let highlightId = currentTip?.highlightRobotId else { return }
        guard let agent = agents.first(where: { $0.config.id == highlightId }),
              let node = agent.sceneNode else { return }

        let ring = SCNTorus(ringRadius: 0.22, pipeRadius: 0.01)
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.systemOrange
        mat.emission.contents = UIColor.orange
        ring.materials = [mat]
        let ringNode = SCNNode(geometry: ring)
        ringNode.name = "highlight_ring"
        ringNode.eulerAngles.x = -.pi / 2
        ringNode.position = SCNVector3(0, 0.01, 0)
        node.addChildNode(ringNode)

        let pulseUp = SCNAction.scale(to: 1.1, duration: 0.4)
        let pulseDown = SCNAction.scale(to: 0.95, duration: 0.4)
        ringNode.runAction(SCNAction.repeatForever(SCNAction.sequence([pulseUp, pulseDown])))
    }

    // MARK: - Agent Update

    private func updateAgent(_ agent: RobotAgent, dt: Float, simDt: Double,
                             pickupTargets: [SIMD2<Float>]) {
        if agent.isStalled {
            agent.stallTimer -= simDt
            if agent.stallTimer <= 0 {
                agent.isStalled = false
                agent.state = .idle
                agent.aiState = .seekPickup
            }
            return
        }

        if agent.actionTimer > 0 {
            agent.actionTimer -= simDt
            if agent.actionTimer <= 0 {
                completeAction(agent)
            }
            return
        }

        let policy = agent.config.alliance == .red ? redPolicy : bluePolicy

        if period == .auto {
            runAutoRoutine(agent, dt: dt)
            return
        }

        if agent.state == .idle || (agent.state == .driving && agent.hasReachedTarget) {
            agent.decideGoal(simTime: simTime, policy: policy, allAgents: agents, pickupTargets: pickupTargets)
        }

        if agent.state == .driving || agent.state == .defending || agent.state == .headingEndgame {
            agent.updateMovement(dt: dt, keepOutCircles: keepOutCircles, keepOutRects: keepOutRects)
            if agent.hasReachedTarget {
                handleArrival(agent)
            }
        }
    }

    // MARK: - Auto Routine

    private func runAutoRoutine(_ agent: RobotAgent, dt: Float) {
        let isPlayer = agent.config.id == 0
        let autoPlan = isPlayer ? playerAutoPlan : .moderate
        agent.aiState = agent.hasPiece ? .seekScore : .seekPickup

        switch agent.autoPhase {
        case 0:
            agent.state = .autoPath
            agent.hasPiece = true
            ensurePreloadedCoral(for: agent)
            let faceIdx = agent.config.id % 6
            let approach = agent.config.alliance == .red
                ? FieldLayout.redReefApproach(faceIdx)
                : FieldLayout.blueReefApproach(faceIdx)
            agent.targetPosition = approach
            agent.currentTargetLevel = min(agent.config.stats.maxReefLevel, 2)
            agent.autoPhase = 1

        case 1:
            agent.updateMovement(dt: dt, keepOutCircles: keepOutCircles, keepOutRects: keepOutRects)
            checkAutoLine(agent)
            if agent.hasReachedTarget && agent.hasPiece {
                if isPlayer && rng.nextDouble() > autoPlan.successRate {
                    triggerStall(agent, duration: 3.0)
                    agent.autoPhase = 99
                    return
                }
                agent.state = .scoring
                agent.actionTimer = agent.config.stats.scoringTime * 0.8
                agent.autoPhase = 2
            }

        case 2:
            if autoPlan.piecesAttempted > 1 {
                var source = agent.config.alliance == .red
                    ? FieldLayout.redSource : FieldLayout.blueSource
                source.y += Float(agent.config.id % 3) * 0.25 - 0.25
                agent.targetPosition = source
                agent.state = .autoPath
                agent.autoPhase = 3
            } else {
                agent.state = .idle
                agent.autoPhase = 99
            }

        case 3:
            agent.updateMovement(dt: dt, keepOutCircles: keepOutCircles, keepOutRects: keepOutRects)
            checkAutoLine(agent)
            if agent.hasReachedTarget {
                agent.hasPiece = true
                ensurePreloadedCoral(for: agent)
                agent.piecesCycled += 1
                let faceIdx = (agent.config.id + 3) % 6
                agent.targetPosition = agent.config.alliance == .red
                    ? FieldLayout.redReefApproach(faceIdx)
                    : FieldLayout.blueReefApproach(faceIdx)
                agent.currentTargetLevel = 1
                agent.state = .autoPath
                agent.autoPhase = 4
            }

        case 4:
            agent.updateMovement(dt: dt, keepOutCircles: keepOutCircles, keepOutRects: keepOutRects)
            if agent.hasReachedTarget && agent.hasPiece {
                if isPlayer && rng.nextDouble() > autoPlan.successRate {
                    triggerStall(agent, duration: 2.5)
                    agent.autoPhase = 99
                    return
                }
                agent.state = .scoring
                agent.actionTimer = agent.config.stats.scoringTime * 0.8
                agent.autoPhase = autoPlan.piecesAttempted > 2 ? 5 : 99
            }

        case 5:
            var source = agent.config.alliance == .red
                ? FieldLayout.redSource : FieldLayout.blueSource
            source.y += Float(agent.config.id % 2) * 0.3
            agent.targetPosition = source
            agent.state = .autoPath
            agent.autoPhase = 6

        case 6:
            agent.updateMovement(dt: dt, keepOutCircles: keepOutCircles, keepOutRects: keepOutRects)
            if agent.hasReachedTarget {
                agent.hasPiece = true
                ensurePreloadedCoral(for: agent)
                agent.piecesCycled += 1
                let faceIdx = (agent.config.id + 1) % 6
                agent.targetPosition = agent.config.alliance == .red
                    ? FieldLayout.redReefApproach(faceIdx)
                    : FieldLayout.blueReefApproach(faceIdx)
                agent.currentTargetLevel = 1
                agent.state = .autoPath
                agent.autoPhase = 7
            }

        case 7:
            agent.updateMovement(dt: dt, keepOutCircles: keepOutCircles, keepOutRects: keepOutRects)
            if agent.hasReachedTarget && agent.hasPiece {
                if isPlayer && rng.nextDouble() > autoPlan.successRate * 0.7 {
                    triggerStall(agent, duration: 2.0)
                    agent.autoPhase = 99
                    return
                }
                agent.state = .scoring
                agent.actionTimer = agent.config.stats.scoringTime
                agent.autoPhase = 99
            }

        default:
            if agent.state != .scoring && agent.state != .stalled {
                agent.state = .idle
            }
        }
    }

    private func checkAutoLine(_ agent: RobotAgent) {
        guard !agent.hasCrossedAutoLine else { return }
        let crossed: Bool
        if agent.config.alliance == .red {
            crossed = agent.position.x < FieldSpec.redAutoLine
        } else {
            crossed = agent.position.x > FieldSpec.blueAutoLine
        }
        if crossed {
            agent.hasCrossedAutoLine = true
            addScore(alliance: agent.config.alliance,
                     points: FieldSpec.Scoring.autoLeave, period: .auto)
        }
    }

    // MARK: - Arrival Handling

    private func handleArrival(_ agent: RobotAgent) {
        if agent.state == .headingEndgame {
            agent.state = .climbing
            // Deep climb takes longer but worth more
            agent.actionTimer = agent.config.stats.canDeepClimb ? 5.0 : 3.0
            return
        }

        if agent.state == .defending {
            agent.state = .idle
            return
        }

        if !agent.hasPiece {
            if let pickup = nearestPickupPiece(to: agent.position, range: 0.45) {
                if rng.nextDouble() > agent.config.stats.reliability {
                    triggerStall(agent, duration: 2.0)
                    return
                }
                beginPickup(agent, coral: pickup)
                agent.state = .pickingUp
                agent.aiState = .acquire
                agent.actionTimer = agent.config.stats.pickupTime
                return
            }
        }

        if agent.hasPiece {
            let target = agent.targetPosition
            if let target, distance2D(agent.position, target) < 0.25 {
                agent.state = .scoring
                agent.aiState = .score
                agent.actionTimer = agent.config.stats.scoringTime
                pulseNearestReefNode(to: agent.position)
                return
            }
        }

        agent.state = .idle
    }

    // MARK: - Action Completion

    private func completeAction(_ agent: RobotAgent) {
        switch agent.state {
        case .pickingUp:
            if let piece = coralPieces.first(where: { $0.id == agent.carriedPieceId }) {
                attachCoral(piece, to: agent)
                agent.hasPiece = true
                agent.piecesCycled += 1
            }
            agent.state = .idle
            agent.aiState = agent.hasPiece ? .seekScore : .seekPickup

        case .scoring:
            if agent.hasPiece {
                agent.hasPiece = false
                agent.piecesScored += 1

                let isAuto = period == .auto
                let isProcessor = isNearProcessor(agent)
                let level = agent.currentTargetLevel

                // Determine scoring success
                let scoringSuccess = rng.nextDouble() <= agent.config.stats.reliability

                if isProcessor {
                    if scoringSuccess {
                        let pts = isAuto ? FieldSpec.Scoring.autoProcessor : FieldSpec.Scoring.teleopProcessor
                        addScore(alliance: agent.config.alliance, points: pts,
                                 period: isAuto ? .auto : .teleop, isProcessor: true)
                    }
                    if let piece = coralPieces.first(where: { $0.id == agent.carriedPieceId }) {
                        dropCoral(piece)
                    }
                } else {
                    if scoringSuccess {
                        let pts = scoringPoints(level: level, isAuto: isAuto)
                        addScore(alliance: agent.config.alliance, points: pts,
                                 period: isAuto ? .auto : .teleop, reefLevel: level)
                        if let piece = coralPieces.first(where: { $0.id == agent.carriedPieceId }) {
                            beginScoringAnimation(piece, for: agent, level: level)
                        }
                    } else if let piece = coralPieces.first(where: { $0.id == agent.carriedPieceId }) {
                        dropCoral(piece)
                    }
                }
                agent.carriedPieceId = nil
            }
            agent.state = .idle
            agent.aiState = .seekPickup

        case .climbing:
            // Award endgame points based on climb type
            let pts: Int
            if agent.config.stats.canDeepClimb {
                pts = FieldSpec.Scoring.deepClimb
            } else {
                pts = FieldSpec.Scoring.shallowClimb
            }
            addScore(alliance: agent.config.alliance, points: pts, period: .endgame)
            agent.isParkedEndgame = true
            agent.state = .parked

        case .parked:
            break

        default:
            agent.state = .idle
        }
    }

    private func scoringPoints(level: Int, isAuto: Bool) -> Int {
        if isAuto {
            switch level {
            case 1: return FieldSpec.Scoring.autoCoralL1
            case 2: return FieldSpec.Scoring.autoCoralL2
            case 3: return FieldSpec.Scoring.autoCoralL3
            default: return FieldSpec.Scoring.autoCoralL4
            }
        } else {
            switch level {
            case 1: return FieldSpec.Scoring.teleopCoralL1
            case 2: return FieldSpec.Scoring.teleopCoralL2
            case 3: return FieldSpec.Scoring.teleopCoralL3
            default: return FieldSpec.Scoring.teleopCoralL4
            }
        }
    }

    private func isNearProcessor(_ agent: RobotAgent) -> Bool {
        let proc = agent.config.alliance == .red
            ? FieldLayout.redProcessor : FieldLayout.blueProcessor
        return distance2D(agent.position, proc) < 0.5
    }

    // MARK: - Coral Pieces

    private func registerCoralPieces(in scene: SCNScene) {
        coralPieces.removeAll()
        occupiedSockets.removeAll()
        var id = 0

        scene.rootNode.enumerateChildNodes { node, _ in
            guard let name = node.name, name.hasPrefix("prestaged_coral_") else { return }
            node.name = "coral_piece_\(id)"
            node.eulerAngles.x = Float.pi / 2
            node.position.y = FieldSpec.coralRadius
            let pos = SIMD2<Float>(node.position.x, node.position.z)
            coralPieces.append(CoralPiece(id: id, node: node, position: pos))
            id += 1
        }

        let stationPositions = [
            FieldSpec.redCoralNear,
            FieldSpec.redCoralFar,
            FieldSpec.blueCoralNear,
            FieldSpec.blueCoralFar
        ]

        for station in stationPositions {
            for offsetIndex in 0..<2 {
                let node = FieldBuilder.makeCoral()
                node.name = "coral_piece_\(id)"
                node.eulerAngles.x = Float.pi / 2
                node.position = SCNVector3(
                    station.x + Float(offsetIndex) * 0.07 - 0.035,
                    FieldSpec.coralRadius,
                    station.y + 0.05
                )
                scene.rootNode.addChildNode(node)
                let pos = SIMD2<Float>(node.position.x, node.position.z)
                coralPieces.append(CoralPiece(id: id, node: node, position: pos))
                id += 1
            }
        }
        nextCoralId = id
    }

    private func availablePickupTargets() -> [SIMD2<Float>] {
        coralPieces.compactMap { piece in
            switch piece.state {
            case .onGround, .dropped:
                return piece.position
            default:
                return nil
            }
        }
    }

    private func nearestPickupPiece(to position: SIMD2<Float>, range: Float) -> CoralPiece? {
        coralPieces
            .filter { $0.state == .onGround || $0.state == .dropped }
            .filter { distance2D($0.position, position) < range }
            .min { distance2D($0.position, position) < distance2D($1.position, position) }
    }

    private func beginPickup(_ agent: RobotAgent, coral: CoralPiece) {
        coral.state = .inIntake
        coral.carriedBy = agent
        agent.carriedPieceId = coral.id
    }

    private func attachCoral(_ coral: CoralPiece, to agent: RobotAgent) {
        guard let anchor = agent.intakeAnchor else { return }
        coral.state = .carried
        coral.carriedBy = agent
        coral.node.removeFromParentNode()
        anchor.addChildNode(coral.node)
        coral.node.position = SCNVector3(0, 0, 0.02)
        coral.node.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
    }

    private func dropCoral(_ coral: CoralPiece) {
        coral.state = .dropped
        coral.carriedBy = nil
        let world = coral.node.simdWorldPosition
        coral.position = SIMD2<Float>(world.x, world.z)
        coral.node.removeFromParentNode()
        scene?.rootNode.addChildNode(coral.node)
        coral.verticalVelocity = 0.25
        coral.height = max(coral.height, FieldSpec.coralRadius + 0.02)
    }

    private func beginScoringAnimation(_ coral: CoralPiece, for agent: RobotAgent, level: Int) {
        let reefCenter = agent.config.alliance == .red ? FieldSpec.redReefCenter : FieldSpec.blueReefCenter
        let face = agent.lastFaceUsed >= 0 ? agent.lastFaceUsed : 0
        let socket = selectSocket(for: agent.config.alliance, center: reefCenter, face: face, level: level)
        coral.socketKey = socket.key
        occupiedSockets.insert(socket.key)

        coral.state = .scoringAnim
        coral.carriedBy = nil
        coral.node.removeFromParentNode()
        scene?.rootNode.addChildNode(coral.node)

        coral.animProgress = 0
        coral.animStart = coral.node.simdWorldPosition
        coral.animEnd = socket.socket.position
        coral.node.eulerAngles = SCNVector3(Float.pi / 2, socket.socket.yaw, 0)
    }

    private func ensurePreloadedCoral(for agent: RobotAgent) {
        guard agent.carriedPieceId == nil, let anchor = agent.intakeAnchor else { return }
        let node = FieldBuilder.makeCoral()
        node.name = "coral_piece_\(nextCoralId)"
        node.eulerAngles.x = Float.pi / 2
        anchor.addChildNode(node)
        node.position = SCNVector3(0, 0, 0.02)
        let piece = CoralPiece(id: nextCoralId, node: node, position: agent.position)
        piece.state = .carried
        piece.carriedBy = agent
        coralPieces.append(piece)
        agent.carriedPieceId = nextCoralId
        nextCoralId += 1
    }

    private func selectSocket(for alliance: Alliance, center: SIMD2<Float>, face: Int, level: Int)
        -> (key: CoralSocketKey, socket: CoralSocket) {
        let slots = 2
        for slot in 0..<slots {
            let key = CoralSocketKey(alliance: alliance, face: face, level: level, slot: slot)
            if !occupiedSockets.contains(key) {
                let socket = FieldSpec.scoringSocket(center: center, faceIndex: face, level: level, slot: slot)
                return (key, CoralSocket(position: socket.position, yaw: socket.yaw))
            }
        }
        let key = CoralSocketKey(alliance: alliance, face: face, level: level, slot: 0)
        let socket = FieldSpec.scoringSocket(center: center, faceIndex: face, level: level, slot: 0)
        return (key, CoralSocket(position: socket.position, yaw: socket.yaw))
    }

    private func updateCoralPieces(dt: Float) {
        let restHeight = FieldSpec.coralRadius
        let gravity: Float = 2.4

        for piece in coralPieces {
            switch piece.state {
            case .onGround:
                piece.height = restHeight
                avoidRobotOverlap(for: piece)
                piece.node.position = SCNVector3(piece.position.x, restHeight, piece.position.y)
                piece.node.eulerAngles.x = Float.pi / 2

            case .inIntake:
                if let agent = piece.carriedBy, let anchor = agent.intakeAnchor {
                    let targetWorld = anchor.simdWorldPosition + SIMD3<Float>(0, 0, 0.02)
                    let current = piece.node.simdWorldPosition
                    piece.node.simdWorldPosition = simd_mix(current, targetWorld, SIMD3<Float>(repeating: 0.25))
                    piece.node.eulerAngles = SCNVector3(Float.pi / 2, agent.heading, 0)
                    piece.position = SIMD2<Float>(piece.node.position.x, piece.node.position.z)
                } else {
                    dropCoral(piece)
                }

            case .carried:
                if let agent = piece.carriedBy, let anchor = agent.intakeAnchor {
                    if piece.node.parent != anchor {
                        attachCoral(piece, to: agent)
                    }
                    let targetLocal = SIMD3<Float>(0, 0, 0.02)
                    let current = piece.node.simdPosition
                    piece.node.simdPosition = simd_mix(current, targetLocal, SIMD3<Float>(repeating: 0.35))
                    piece.node.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
                    let worldPos = piece.node.simdWorldPosition
                    piece.position = SIMD2<Float>(worldPos.x, worldPos.z)
                } else {
                    dropCoral(piece)
                }

            case .scoringAnim:
                let duration: Float = 0.6
                piece.animProgress = min(1.0, piece.animProgress + dt / duration)
                let t = piece.animProgress
                let mid = (piece.animStart + piece.animEnd) / 2 + SIMD3<Float>(0, 0.18, 0)
                let inv = 1 - t
                let position = inv * inv * piece.animStart + 2 * inv * t * mid + t * t * piece.animEnd
                piece.node.simdWorldPosition = position
                if t >= 1.0 {
                    piece.state = .scored
                    piece.node.simdWorldPosition = piece.animEnd
                }

            case .scored:
                piece.node.simdWorldPosition = piece.animEnd

            case .dropped:
                piece.verticalVelocity -= gravity * dt
                piece.height = max(restHeight, piece.height + piece.verticalVelocity * dt)
                if piece.height <= restHeight + 0.001 {
                    piece.height = restHeight
                    piece.verticalVelocity = 0
                    piece.state = .onGround
                }
                avoidRobotOverlap(for: piece)
                piece.node.position = SCNVector3(piece.position.x, piece.height, piece.position.y)
                piece.node.eulerAngles.x = Float.pi / 2
            }
        }
    }

    private func avoidRobotOverlap(for coral: CoralPiece) {
        let buffer = robotRadius + FieldSpec.coralRadius + 0.02
        for agent in agents {
            let delta = coral.position - agent.position
            let dist = sqrt(delta.x * delta.x + delta.y * delta.y)
            if dist < buffer && dist > 0.001 {
                let push = (buffer - dist)
                let nx = delta.x / dist
                let nz = delta.y / dist
                coral.position += SIMD2<Float>(nx * push, nz * push)
            }
        }
    }

    // MARK: - Structure Constraints

    private func resolveStructureConstraints() {
        for agent in agents {
            for circle in keepOutCircles {
                let delta = agent.position - circle.center
                let dist = sqrt(delta.x * delta.x + delta.y * delta.y)
                let minDist = circle.radius + robotRadius
                if dist < minDist && dist > 0.001 {
                    let nx = delta.x / dist
                    let nz = delta.y / dist
                    let push = minDist - dist
                    agent.position += SIMD2<Float>(nx * push, nz * push)
                    agent.velocity *= 0.6
                    agent.speed *= 0.6
                }
            }

            for rect in keepOutRects {
                let nearest = rect.nearestPoint(to: agent.position)
                let delta = agent.position - nearest
                let dist = sqrt(delta.x * delta.x + delta.y * delta.y)
                let minDist: Float = robotRadius + 0.02
                if dist < minDist {
                    let nx = dist > 0.001 ? delta.x / dist : 1
                    let nz = dist > 0.001 ? delta.y / dist : 0
                    let push = minDist - dist
                    agent.position += SIMD2<Float>(nx * push, nz * push)
                    agent.velocity *= 0.6
                    agent.speed *= 0.6
                }
            }
        }
    }

    // MARK: - Scoring

    private func addScore(alliance: Alliance, points: Int, period: MatchPeriod,
                          isProcessor: Bool = false, reefLevel: Int = 0) {
        if alliance == .red {
            redScore += points
            switch period {
            case .auto:    redBreakdown.autoPoints += points
            case .endgame: redBreakdown.endgamePoints += points
            default:       redBreakdown.teleopPoints += points
            }
            if reefLevel > 0 || isProcessor {
                redBreakdown.totalPieces += 1
                if isProcessor { redBreakdown.processorPieces += 1 }
                switch reefLevel {
                case 1: redBreakdown.coralL1 += 1
                case 2: redBreakdown.coralL2 += 1
                case 3: redBreakdown.coralL3 += 1
                case 4: redBreakdown.coralL4 += 1
                default: break
                }
            }
        } else {
            blueScore += points
            switch period {
            case .auto:    blueBreakdown.autoPoints += points
            case .endgame: blueBreakdown.endgamePoints += points
            default:       blueBreakdown.teleopPoints += points
            }
            if reefLevel > 0 || isProcessor {
                blueBreakdown.totalPieces += 1
                if isProcessor { blueBreakdown.processorPieces += 1 }
                switch reefLevel {
                case 1: blueBreakdown.coralL1 += 1
                case 2: blueBreakdown.coralL2 += 1
                case 3: blueBreakdown.coralL3 += 1
                case 4: blueBreakdown.coralL4 += 1
                default: break
                }
            }
        }
    }

    // MARK: - Stall

    private func triggerStall(_ agent: RobotAgent, duration: Double) {
        agent.isStalled = true
        agent.didStall = true
        agent.stallTimer = duration
        agent.state = .stalled
        agent.aiState = .seekPickup
        agent.speed = 0
    }

    // MARK: - Separation (with push power)

    private func resolveSeparation() {
        let minDist: Float = robotRadius * 2.0
        for i in 0..<agents.count {
            for j in (i + 1)..<agents.count {
                let dx = agents[j].position.x - agents[i].position.x
                let dz = agents[j].position.y - agents[i].position.y
                let dist = sqrt(dx * dx + dz * dz)
                if dist < minDist && dist > 0.001 {
                    let overlap = (minDist - dist) / 2
                    let nx = dx / dist
                    let nz = dz / dist

                    // Push power determines who moves more in collision
                    let pushI = agents[i].config.stats.pushPower
                    let pushJ = agents[j].config.stats.pushPower
                    let totalPush = max(0.1, pushI + pushJ)
                    let ratioI = pushJ / totalPush  // i moves proportional to j's push
                    let ratioJ = pushI / totalPush

                    agents[i].position.x -= nx * overlap * 2 * ratioI
                    agents[i].position.y -= nz * overlap * 2 * ratioI
                    agents[j].position.x += nx * overlap * 2 * ratioJ
                    agents[j].position.y += nz * overlap * 2 * ratioJ

                    agents[i].velocity *= 0.7
                    agents[j].velocity *= 0.7
                    agents[i].speed *= 0.7
                    agents[j].speed *= 0.7

                    // Defenders slow opponents on contact
                    let isOpposing = agents[i].config.alliance != agents[j].config.alliance
                    if isOpposing {
                        if agents[i].config.role == .defender {
                            agents[j].speed *= 0.3
                        }
                        if agents[j].config.role == .defender {
                            agents[i].speed *= 0.3
                        }
                        // Push power advantage slows the weaker bot
                        if pushI > pushJ * 1.5 {
                            agents[j].speed *= 0.5
                        } else if pushJ > pushI * 1.5 {
                            agents[i].speed *= 0.5
                        }
                    }
                }
            }
        }
    }

    // MARK: - Visual Feedback

    private func pulseNearestReefNode(to pos: SIMD2<Float>) {
        var closestNode: SCNNode?
        var closestDist: Float = .greatestFiniteMagnitude
        for node in reefNodeTargets {
            let dx = node.position.x - pos.x
            let dz = node.position.z - pos.y
            let dist = sqrt(dx * dx + dz * dz)
            if dist < closestDist {
                closestDist = dist
                closestNode = node
            }
        }
        guard let target = closestNode else { return }

        let up = SCNAction.scale(to: 1.3, duration: 0.12)
        let down = SCNAction.scale(to: 1.0, duration: 0.25)
        down.timingMode = .easeOut
        target.runAction(SCNAction.sequence([up, down]))

        if let mat = target.geometry?.firstMaterial {
            mat.emission.contents = UIColor.yellow
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                mat.emission.contents = UIColor.black
            }
        }
    }

    // MARK: - Coaching Tips

    private func generateCoachingTip() {
        let tips: [() -> CoachingTip?] = [
            { [self] in
                let defenders = agents.filter { $0.config.role == .defender && $0.state == .defending }
                guard let def = defenders.first else { return nil }
                return CoachingTip(
                    headline: "Defense in Action",
                    detail: "Notice how #\(def.config.teamNumber) positions between opponents and their tower. Their \(def.config.build.drivetrain.shortLabel) drive gives them \(def.config.stats.canDeepClimb ? "deep climb (12pts)" : "speed advantage") in endgame.",
                    highlightRobotId: def.config.id
                )
            },
            { [self] in
                let scorers = agents.filter { $0.state == .scoring }
                guard let s = scorers.first else { return nil }
                return CoachingTip(
                    headline: "Scoring Cycle",
                    detail: "Team \(s.config.teamNumber)'s \(s.config.build.mechanism.shortLabel) mechanism takes ~\(String(format: "%.1f", s.config.stats.scoringTime))s per score (max L\(s.config.stats.maxReefLevel)). \(s.config.build.intake.shortLabel) intake picks up in \(String(format: "%.1f", s.config.stats.pickupTime))s.",
                    highlightRobotId: s.config.id
                )
            },
            { [self] in
                return CoachingTip(
                    headline: "Strategy Impact",
                    detail: "Your alliance is in \"\(strategyMode)\". Use callouts to shift mid-match! \(activeCallouts.count) callout\(activeCallouts.count == 1 ? " is" : "s are") active. \(calloutCooldown > 0 ? String(format: "Cooldown: %.0fs", calloutCooldown) : "Ready to call!")",
                    highlightRobotId: nil
                )
            },
            { [self] in
                let topScorer = agents.filter { $0.config.alliance == .red }.max(by: { $0.piecesScored < $1.piecesScored })
                guard let t = topScorer, t.piecesScored > 0 else { return nil }
                return CoachingTip(
                    headline: "Top Performer",
                    detail: "Team \(t.config.teamNumber) leads with \(t.piecesScored) pieces. Their \(t.config.build.drivetrain.shortLabel)+\(t.config.build.mechanism.shortLabel)+\(t.config.build.intake.shortLabel) build \(t.config.stats.canDeepClimb ? "can deep climb!" : "is fast but shallow-climb only.").",
                    highlightRobotId: t.config.id
                )
            },
            { [self] in
                let diff = redScore - blueScore
                let comparison = diff > 0 ? "leading by \(diff)" : (diff < 0 ? "trailing by \(-diff)" : "tied")
                let timeLeft = Int(max(0, MatchTiming.totalDuration - simTime))
                return CoachingTip(
                    headline: "Score Check",
                    detail: "Your red alliance is \(comparison) with \(timeLeft)s left. Tank bots get deep climb (12pts) while swerve gets shallow (6pts) — big endgame swing!",
                    highlightRobotId: nil
                )
            },
            { [self] in
                let cyclers = agents.filter { $0.config.role == .cycler }
                guard let c = cyclers.first else { return nil }
                return CoachingTip(
                    headline: "Cycle Speed",
                    detail: "Cycler #\(c.config.teamNumber) has \(c.piecesCycled) cycles using \(c.config.build.mechanism.shortLabel)+\(c.config.build.intake.shortLabel). Cyclers target L1-L2 for fast turnaround — fewer points per piece but more volume.",
                    highlightRobotId: c.config.id
                )
            },
            { [self] in
                // Build diversity tip
                let builds = agents.map { "\($0.config.build.drivetrain.shortLabel)/\($0.config.build.mechanism.shortLabel)" }
                let unique = Set(builds).count
                return CoachingTip(
                    headline: "Build Variety",
                    detail: "There are \(unique) different build combos on the field. In real FRC, each team's robot is unique — some teams prioritize speed, others reliability or reach.",
                    highlightRobotId: nil
                )
            },
        ]

        let shuffled = tips.shuffled()
        for gen in shuffled {
            if let tip = gen() {
                currentTip = tip
                return
            }
        }

        currentTip = CoachingTip(
            headline: "Watch the Field",
            detail: "Pay attention to robot paths. Teams that avoid traffic jams and cycle efficiently score more. The hexagonal tower has 6 faces — spreading out prevents congestion!",
            highlightRobotId: nil
        )
    }

    // MARK: - Finish

    private func finishMatch() {
        guard isRunning else { return }
        stop()
        period = .finished
        isFinished = true
    }

    // MARK: - Result

    var result: MatchResult {
        let playerAgent = agents.first { $0.config.id == 0 }
        return MatchResult(
            playerStrategy: AllianceStrategy.allCases.first {
                $0.basePolicy.scoringWeight == redPolicy.scoringWeight
            } ?? .balanced,
            playerRole: configs[0].role,
            playerAuto: playerAutoPlan,
            playerBuild: configs[0].build,
            redScore: redScore,
            blueScore: blueScore,
            redBreakdown: redBreakdown,
            blueBreakdown: blueBreakdown,
            calloutsUsed: calloutsUsed,
            calloutEvents: calloutEvents,
            playerRobotScored: playerAgent?.piecesScored ?? 0,
            playerRobotCycled: playerAgent?.piecesCycled ?? 0,
            didPlayerStall: playerAgent?.didStall ?? false,
            matchDuration: simTime,
            slowMoUsed: slowMoUsed
        )
    }
}
