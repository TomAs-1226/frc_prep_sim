import Foundation
import SceneKit

// MARK: - Utility Helper

private func distance2D(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
    let d = a - b
    return sqrt(d.x * d.x + d.y * d.y)
}

// MARK: - Robot Agent

class RobotAgent {
    let config: RobotConfig
    var state: RobotState = .idle
    var position: SIMD2<Float>
    var heading: Float = 0
    var speed: Float = 0
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
    var wheelNodes: [SCNNode] = []
    var mechanismNode: SCNNode?   // elevator_stage or pivot_arm
    var intakeNode: SCNNode?      // intake_roller

    init(config: RobotConfig) {
        self.config = config
        self.position = config.startPosition
        self.heading = config.alliance == .red ? Float.pi : 0
    }

    /// Cache references to animatable child nodes.
    func cacheComponentNodes() {
        guard let root = sceneNode else { return }
        wheelNodes = []
        root.enumerateChildNodes { child, _ in
            if let name = child.name {
                if name.hasPrefix("wheel_") { self.wheelNodes.append(child) }
                else if name == "elevator_stage" { self.mechanismNode = child }
                else if name == "pivot_arm" { self.mechanismNode = child }
                else if name == "intake_roller" { self.intakeNode = child }
            }
        }
    }

    // MARK: - Utility-Based Goal Selection

    func decideGoal(simTime: Double, policy: StrategyPolicy, allAgents: [RobotAgent], rng: inout SeededRNG) {
        guard state == .idle || state == .driving else { return }

        let timeRemaining = MatchTiming.totalDuration - simTime
        let period = currentPeriod(simTime)

        // --- Score-aware policy adjustment ---
        let scoreDiff = teamScore - opponentScore
        var adjustedPolicy = policy
        if scoreDiff < -10 {
            // Losing badly: boost scoring, reduce endgame weight (need to catch up)
            adjustedPolicy.scoringWeight = min(1.0, policy.scoringWeight + 0.2)
            adjustedPolicy.endgameWeight = max(0.05, policy.endgameWeight - 0.1)
        } else if scoreDiff > 15 {
            // Winning big: can afford more defense, earlier endgame
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
                state = .headingEndgame
                return
            }
        }

        // --- Defense utility (defenders prefer blocking) ---
        if config.role == .defender {
            let defUtil = adjustedPolicy.defenseWeight * 1.5
            let scoreUtil = adjustedPolicy.scoringWeight

            if defUtil > scoreUtil {
                // Smart targeting: prioritize opponents carrying pieces or high scorers
                let opponents = allAgents.filter {
                    $0.config.alliance != config.alliance && !$0.isParkedEndgame
                }
                if let target = opponents.max(by: { defenderPriority($0) < defenderPriority($1) }) {
                    // Position between the target and THEIR reef
                    let theirReef = config.alliance == .red
                        ? FieldSpec.blueReefCenter : FieldSpec.redReefCenter
                    let blockPos = SIMD2<Float>(
                        target.position.x * 0.6 + theirReef.x * 0.4,
                        target.position.y * 0.6 + theirReef.y * 0.4
                    )
                    let jitter = SIMD2<Float>(
                        rng.nextFloat() * 0.15 - 0.075,
                        rng.nextFloat() * 0.15 - 0.075
                    )
                    targetPosition = blockPos + jitter
                    state = .defending
                    return
                }
            }
        }

        // --- Scoring: pick up or deliver ---
        if hasPiece {
            let best = chooseBestScoringTarget(policy: adjustedPolicy, allAgents: allAgents, rng: &rng)
            targetPosition = best.position
            currentTargetLevel = best.level
            state = .driving
        } else {
            targetPosition = nearestSource(rng: &rng)
            state = .driving
        }
    }

    // MARK: - Defender Priority Scoring

    private func defenderPriority(_ opp: RobotAgent) -> Double {
        var score = 0.0
        if opp.hasPiece { score += 10.0 }
        if opp.state == .scoring { score += 5.0 }  // About to score — high priority
        if opp.state == .driving && opp.hasPiece { score += 3.0 }  // Heading to score
        if opp.config.role == .scorer { score += 3.0 }
        if opp.config.role == .cycler { score += 2.0 }
        score += Double(opp.piecesScored) * 0.5
        // Closer opponents are higher priority
        score -= Double(distance2D(position, opp.position)) * 0.3
        return score
    }

    // MARK: - Best Scoring Target (role-aware + congestion avoidance)

    private func chooseBestScoringTarget(policy: StrategyPolicy, allAgents: [RobotAgent],
                                          rng: inout SeededRNG) -> (position: SIMD2<Float>, level: Int) {
        let maxLevel = config.stats.maxReefLevel
        let reefCenter = config.alliance == .red ? FieldSpec.redReefCenter : FieldSpec.blueReefCenter
        var bestPos = config.alliance == .red
            ? FieldLayout.redReefApproach(0) : FieldLayout.blueReefApproach(0)
        var bestLevel = 1
        var bestUtil: Double = -1

        // Teammates for congestion check
        let teammates = allAgents.filter {
            $0.config.alliance == config.alliance && $0.config.id != config.id
        }

        for face in 0..<6 {
            let approach = config.alliance == .red
                ? FieldLayout.redReefApproach(face)
                : FieldLayout.blueReefApproach(face)
            let dist = distance2D(position, approach)

            // Congestion penalty: count teammates near this face
            let nearbyTeammates = teammates.filter {
                distance2D($0.position, approach) < 0.5 ||
                ($0.targetPosition != nil && distance2D($0.targetPosition!, approach) < 0.3)
            }.count
            let congestionPenalty = Double(nearbyTeammates) * 0.5

            // Spread bonus from callout
            let spreadBonus: Double = (policy.spreadOut && face != lastFaceUsed) ? 0.3 : 0.0

            for level in 1...maxLevel {
                let basePoints: Double
                switch level {
                case 1: basePoints = 2
                case 2: basePoints = 3
                case 3: basePoints = 4
                default: basePoints = 5
                }

                // Role bias: cyclers prefer low levels, scorers prefer high
                let roleBias: Double
                switch config.role {
                case .cycler:
                    roleBias = level <= 2 ? 1.5 : 0.3
                case .scorer:
                    roleBias = level >= 3 ? 1.4 : 0.7
                case .defender:
                    roleBias = 1.0
                }

                // Focus High callout bonus
                let highBonus: Double = (policy.preferHighLevel && level >= 3) ? 0.5 : 0.0

                let timeCost = Double(dist) / Double(max(0.5, config.stats.maxSpeed)) + config.stats.scoringTime
                let util = (basePoints * roleBias + highBonus + spreadBonus) / max(0.3, timeCost + congestionPenalty)

                if util > bestUtil {
                    bestUtil = util
                    bestPos = approach
                    bestLevel = level
                    lastFaceUsed = face
                }
            }
        }

        // Also consider processor
        let proc = config.alliance == .red ? FieldLayout.redProcessor : FieldLayout.blueProcessor
        let procDist = distance2D(position, proc)
        let procTimeCost = Double(procDist) / Double(max(0.5, config.stats.maxSpeed)) + 1.0
        let procUtil = 6.0 / max(0.3, procTimeCost)
        if procUtil > bestUtil {
            bestPos = proc
            bestLevel = 0
        }

        // Small random variation for diversity
        if rng.nextDouble() < 0.12 {
            let randomFace = Int(rng.next() % 6)
            bestPos = config.alliance == .red
                ? FieldLayout.redReefApproach(randomFace)
                : FieldLayout.blueReefApproach(randomFace)
            bestLevel = rng.nextInt(1..<(maxLevel + 1))
            lastFaceUsed = randomFace
        }

        return (bestPos, bestLevel)
    }

    // MARK: - Nearest Source

    private func nearestSource(rng: inout SeededRNG) -> SIMD2<Float> {
        let jitter = SIMD2<Float>(rng.nextFloat() * 0.2 - 0.1, rng.nextFloat() * 0.3 - 0.15)
        if config.alliance == .red {
            let near = SIMD2<Float>(FieldSpec.redCoralNear.x - 0.3, FieldSpec.redCoralNear.y)
            let far  = SIMD2<Float>(FieldSpec.redCoralFar.x - 0.3, FieldSpec.redCoralFar.y)
            return (distance2D(position, near) < distance2D(position, far) ? near : far) + jitter
        } else {
            let near = SIMD2<Float>(FieldSpec.blueCoralNear.x + 0.3, FieldSpec.blueCoralNear.y)
            let far  = SIMD2<Float>(FieldSpec.blueCoralFar.x + 0.3, FieldSpec.blueCoralFar.y)
            return (distance2D(position, near) < distance2D(position, far) ? near : far) + jitter
        }
    }

    // MARK: - Period

    func currentPeriod(_ simTime: Double) -> MatchPeriod {
        if simTime < MatchTiming.teleopStart { return .auto }
        if simTime < MatchTiming.endgameStart { return .teleop }
        if simTime < MatchTiming.totalDuration { return .endgame }
        return .finished
    }

    // MARK: - Movement

    func updateMovement(dt: Float) {
        guard let target = targetPosition else { return }

        // --- Obstacle avoidance: center skybridge ---
        let obstacleHalf: Float = FieldSpec.bargeTrussDepth / 2 + 0.20
        let obstacleSpanHalf: Float = FieldSpec.bargeTrussSpan / 2 + 0.15
        var effectiveTarget: SIMD2<Float>
        let crossingCenter = (position.x > obstacleHalf && target.x < -obstacleHalf) ||
                             (position.x < -obstacleHalf && target.x > obstacleHalf)
        if crossingCenter && abs(position.y) < obstacleSpanHalf {
            let detourZ: Float = position.y >= 0
                ? obstacleSpanHalf + 0.25
                : -(obstacleSpanHalf + 0.25)
            effectiveTarget = SIMD2<Float>(position.x > 0 ? obstacleHalf + 0.15 : -(obstacleHalf + 0.15), detourZ)
        } else if abs(position.x) < obstacleHalf && abs(position.y) < obstacleSpanHalf {
            let pushX: Float = position.x >= 0 ? obstacleHalf + 0.15 : -(obstacleHalf + 0.15)
            effectiveTarget = SIMD2<Float>(pushX, position.y)
        } else {
            effectiveTarget = target
        }

        // --- Obstacle avoidance: reef hexagons ---
        for center in [FieldSpec.redReefCenter, FieldSpec.blueReefCenter] {
            let reefDist = distance2D(position, center)
            let reefRadius = FieldSpec.reefApothem + 0.22  // Keep outside reef + bumper clearance
            if reefDist < reefRadius && reefDist > 0.01 {
                // Only push away if not targeting this reef's face
                let targetToReef = distance2D(effectiveTarget, center)
                if targetToReef > reefRadius * 0.8 {
                    // Push radially outward from reef center
                    let nx = (position.x - center.x) / reefDist
                    let nz = (position.y - center.y) / reefDist
                    let pushDist = (reefRadius - reefDist) * 0.5
                    effectiveTarget = SIMD2<Float>(
                        position.x + nx * pushDist + (effectiveTarget.x - position.x) * 0.5,
                        position.y + nz * pushDist + (effectiveTarget.y - position.y) * 0.5
                    )
                }
            }
        }

        let dx = effectiveTarget.x - position.x
        let dz = effectiveTarget.y - position.y
        let dist = sqrt(dx * dx + dz * dz)

        if dist < 0.15 {
            speed = 0
            return
        }

        let targetHeading = atan2(dx, dz)
        var angleDiff = targetHeading - heading
        while angleDiff > Float.pi { angleDiff -= 2 * Float.pi }
        while angleDiff < -Float.pi { angleDiff += 2 * Float.pi }
        let turnAmount = min(abs(angleDiff), config.stats.turnRate * dt)
        heading += angleDiff > 0 ? turnAmount : -turnAmount

        let targetSpeed = min(config.stats.maxSpeed, dist * 2.5)
        if speed < targetSpeed {
            speed = min(speed + config.stats.acceleration * dt, targetSpeed)
        } else {
            speed = max(speed - config.stats.acceleration * dt * 2, targetSpeed)
        }

        position.x += sin(heading) * speed * dt
        position.y += cos(heading) * speed * dt

        // Clamp to field bounds (with bumper clearance)
        let wallMargin: Float = 0.20
        position.x = max(-FieldLayout.halfWidth + wallMargin, min(FieldLayout.halfWidth - wallMargin, position.x))
        position.y = max(-FieldLayout.halfLength + wallMargin, min(FieldLayout.halfLength - wallMargin, position.y))

        // Hard repulsion from center obstacle
        if abs(position.x) < obstacleHalf && abs(position.y) < obstacleSpanHalf {
            let pushStrength: Float = 0.04
            position.x += (position.x >= 0 ? pushStrength : -pushStrength)
        }

        // Hard repulsion from reef centers
        for center in [FieldSpec.redReefCenter, FieldSpec.blueReefCenter] {
            let reefDist = distance2D(position, center)
            let hardReefRadius = FieldSpec.reefApothem + 0.15
            if reefDist < hardReefRadius && reefDist > 0.01 {
                let nx = (position.x - center.x) / reefDist
                let nz = (position.y - center.y) / reefDist
                let pushOut = (hardReefRadius - reefDist) * 0.6
                position.x += nx * pushOut
                position.y += nz * pushOut
            }
        }
    }

    var hasReachedTarget: Bool {
        guard let target = targetPosition else { return false }
        return distance2D(position, target) < 0.2
    }

    // MARK: - Scene Sync

    func syncToScene() {
        guard let node = sceneNode else { return }
        node.position = SCNVector3(position.x, 0.0, position.y)
        node.eulerAngles.y = heading

        // Animate wheels proportional to speed
        let spinRate = speed * 3.0  // radians per second visual
        for wheel in wheelNodes {
            wheel.eulerAngles.x += spinRate * (1.0 / 30.0)  // ~30fps tick
        }

        // Animate intake roller when picking up
        if state == .pickingUp, let intake = intakeNode {
            intake.eulerAngles.x += Float.pi * 4.0 * (1.0 / 30.0)
        }

        // Animate mechanism during scoring
        // Clearance: swerve=0.064, tank=0.076
        let wheelClearance: Float = config.build.drivetrain == .swerve ? 0.064 : 0.076
        let deckHeight: Float = 0.06
        let mechBaseY: Float = wheelClearance + deckHeight + 0.06

        if state == .scoring, let mech = mechanismNode {
            if mech.name == "elevator_stage" {
                let targetY: Float
                switch currentTargetLevel {
                case 1: targetY = mechBaseY + 0.02
                case 2: targetY = mechBaseY + 0.10
                case 3: targetY = mechBaseY + 0.18
                default: targetY = mechBaseY + 0.26
                }
                mech.position.y += (targetY - mech.position.y) * 0.08
            } else if mech.name == "pivot_arm" {
                let targetAngle: Float = -0.4
                mech.eulerAngles.x += (targetAngle - mech.eulerAngles.x) * 0.06
            }
        } else if let mech = mechanismNode {
            if mech.name == "elevator_stage" {
                mech.position.y += (mechBaseY - mech.position.y) * 0.05
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
    let bluePolicy: StrategyPolicy

    var agents: [RobotAgent] = []
    var rng: SeededRNG
    private var updateTimer: Timer?
    private var calloutsUsed: [Callout] = []
    private var calloutEvents: [CalloutEvent] = []
    private var slowMoTimer: Double = 0
    private var slowMoUsed: Bool = false
    private var lastUpdateTime: Date?
    private var scene: SCNScene?
    private var reefNodeTargets: [SCNNode] = []
    private var lastCollisionParticleTime: Double = 0
    private var lastPeriod: MatchPeriod = .auto

    init(configs: [RobotConfig], strategy: AllianceStrategy, playerAuto: AutoPlan,
         seed: UInt64 = 42, bluePolicy: StrategyPolicy? = nil) {
        self.configs = configs
        self.playerAutoPlan = playerAuto
        self.redPolicy = strategy.basePolicy
        self.bluePolicy = bluePolicy ?? StrategyPolicy(scoringWeight: 0.6, defenseWeight: 0.2, endgameWeight: 0.2)
        self.rng = SeededRNG(seed: seed)

        for config in configs {
            agents.append(RobotAgent(config: config))
        }
    }

    // MARK: - Scene Binding

    func attach(scene: SCNScene, robotNodes: [SCNNode], reefNodes: [SCNNode]) {
        self.scene = scene
        self.reefNodeTargets = reefNodes
        for (i, agent) in agents.enumerated() where i < robotNodes.count {
            agent.sceneNode = robotNodes[i]
            agent.cacheComponentNodes()
            agent.syncToScene()
        }
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
        lastUpdateTime = Date()
        strategyMode = redPolicy.dominantMode
        SoundManager.shared.play(.matchStart)

        if let scene = scene {
            ParticleManager.emit(ParticleManager.matchStartFlash(),
                                  at: SCNVector3(0, 0.5, 0), in: scene)
        }

        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    func stop() {
        updateTimer?.invalidate()
        updateTimer = nil
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
        calloutCooldown = 5.0
        SoundManager.shared.play(.callout)

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
                }
            }

        case .endgameEarly:
            // All red agents head to endgame positions immediately
            for agent in redAgents where !agent.isParkedEndgame && agent.state != .climbing {
                agent.targetPosition = FieldLayout.redBarge
                agent.state = .headingEndgame
            }

        case .focusHigh:
            // Scorers re-evaluate to pick higher targets
            for agent in redAgents where (agent.state == .idle || agent.state == .driving) {
                agent.state = .idle  // Force re-goal with preferHighLevel
            }

        case .spreadOut:
            // Reset lastFaceUsed so all agents pick new faces
            for agent in redAgents {
                agent.lastFaceUsed = -1
                if agent.state == .idle || agent.state == .driving {
                    agent.state = .idle  // Force re-goal
                }
            }

        case .allOutAttack:
            // Defenders switch to scoring, everyone re-evaluates
            for agent in redAgents {
                if agent.state == .defending {
                    agent.state = .idle
                }
            }
        }
    }

    // MARK: - Slow-Mo

    func activateSlowMo(duration: Double = 8.0) {
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

    // MARK: - Main Tick

    private func tick() {
        guard isRunning else { return }

        let now = Date()
        let wallDt = lastUpdateTime.map { now.timeIntervalSince($0) } ?? (1.0 / 30.0)
        lastUpdateTime = now

        let clampedWallDt = min(wallDt, 0.1)
        let simDt = clampedWallDt * speedMultiplier
        simTime += simDt

        let previousPeriod = period
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

        // Period transition sound
        if period != previousPeriod && previousPeriod != .finished {
            SoundManager.shared.play(.periodChange)
        }

        // Countdown beeps in last 5 seconds
        let remaining = MatchTiming.totalDuration - simTime
        if remaining <= 5.0 && remaining > 0 {
            let sec = Int(remaining)
            let prevRemaining = MatchTiming.totalDuration - (simTime - simDt)
            if Int(prevRemaining) != sec {
                SoundManager.shared.play(.countdown)
            }
        }

        if isSlowMo {
            slowMoTimer -= clampedWallDt
            if slowMoTimer <= 0 { deactivateSlowMo() }
        }

        // Decrement callout cooldown
        if calloutCooldown > 0 {
            calloutCooldown = max(0, calloutCooldown - simDt)
        }

        let dt = Float(simDt)

        // Update score awareness for all agents
        for agent in agents {
            if agent.config.alliance == .red {
                agent.teamScore = redScore
                agent.opponentScore = blueScore
            } else {
                agent.teamScore = blueScore
                agent.opponentScore = redScore
            }
        }

        for agent in agents {
            updateAgent(agent, dt: dt, simDt: simDt)
        }

        resolveSeparation()

        for agent in agents {
            agent.syncToScene()
            robotStates[agent.config.id] = agent.state
        }
    }

    // MARK: - Agent Update

    private func updateAgent(_ agent: RobotAgent, dt: Float, simDt: Double) {
        if agent.isStalled {
            agent.stallTimer -= simDt
            if agent.stallTimer <= 0 {
                agent.isStalled = false
                agent.state = .idle
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
            agent.decideGoal(simTime: simTime, policy: policy, allAgents: agents, rng: &rng)
        }

        if agent.state == .driving || agent.state == .defending || agent.state == .headingEndgame {
            agent.updateMovement(dt: dt)
            if agent.hasReachedTarget {
                handleArrival(agent)
            }
        }
    }

    // MARK: - Auto Routine

    private func runAutoRoutine(_ agent: RobotAgent, dt: Float) {
        let isPlayer = agent.config.id == 0
        let autoPlan = isPlayer ? playerAutoPlan : .moderate

        switch agent.autoPhase {
        case 0:
            agent.state = .autoPath
            agent.hasPiece = true
            let faceIdx = agent.config.id % 6
            let approach = agent.config.alliance == .red
                ? FieldLayout.redReefApproach(faceIdx)
                : FieldLayout.blueReefApproach(faceIdx)
            agent.targetPosition = approach
            agent.currentTargetLevel = min(agent.config.stats.maxReefLevel, 2)
            agent.autoPhase = 1

        case 1:
            agent.updateMovement(dt: dt)
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
            agent.updateMovement(dt: dt)
            checkAutoLine(agent)
            if agent.hasReachedTarget {
                agent.hasPiece = true
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
            agent.updateMovement(dt: dt)
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
            agent.updateMovement(dt: dt)
            if agent.hasReachedTarget {
                agent.hasPiece = true
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
            agent.updateMovement(dt: dt)
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

        if !agent.hasPiece && isNearSource(agent) {
            if rng.nextDouble() > agent.config.stats.reliability {
                triggerStall(agent, duration: 2.0)
                return
            }
            agent.state = .pickingUp
            agent.actionTimer = agent.config.stats.pickupTime
            return
        }

        if agent.hasPiece && isNearScoringTarget(agent) {
            // Scoring attempt — ring physics in completeAction determines hit/miss
            agent.state = .scoring
            agent.actionTimer = agent.config.stats.scoringTime
            pulseNearestReefNode(to: agent.position)
            return
        }

        agent.state = .idle
    }

    private func isNearSource(_ agent: RobotAgent) -> Bool {
        if agent.config.alliance == .red {
            let d1 = distance2D(agent.position, SIMD2(FieldSpec.redCoralNear.x, FieldSpec.redCoralNear.y))
            let d2 = distance2D(agent.position, SIMD2(FieldSpec.redCoralFar.x, FieldSpec.redCoralFar.y))
            return min(d1, d2) < 0.8
        } else {
            let d1 = distance2D(agent.position, SIMD2(FieldSpec.blueCoralNear.x, FieldSpec.blueCoralNear.y))
            let d2 = distance2D(agent.position, SIMD2(FieldSpec.blueCoralFar.x, FieldSpec.blueCoralFar.y))
            return min(d1, d2) < 0.8
        }
    }

    private func isNearScoringTarget(_ agent: RobotAgent) -> Bool {
        let reefCenter = agent.config.alliance == .red
            ? FieldSpec.redReefCenter : FieldSpec.blueReefCenter
        for face in 0..<6 {
            let approach = FieldSpec.scoringApproach(center: reefCenter, faceIndex: face)
            if distance2D(agent.position, approach) < 0.4 { return true }
        }
        let proc = agent.config.alliance == .red
            ? FieldLayout.redProcessor : FieldLayout.blueProcessor
        return distance2D(agent.position, proc) < 0.5
    }

    // MARK: - Action Completion

    private func completeAction(_ agent: RobotAgent) {
        switch agent.state {
        case .pickingUp:
            agent.hasPiece = true
            agent.piecesCycled += 1
            agent.state = .idle

        case .scoring:
            if agent.hasPiece {
                agent.hasPiece = false
                agent.piecesScored += 1

                let isAuto = period == .auto
                let isProcessor = isNearProcessor(agent)
                let level = agent.currentTargetLevel

                // Determine scoring success for ring physics
                let scoringSuccess = rng.nextDouble() <= agent.config.stats.reliability

                if isProcessor {
                    if scoringSuccess {
                        let pts = isAuto ? FieldSpec.Scoring.autoProcessor : FieldSpec.Scoring.teleopProcessor
                        addScore(alliance: agent.config.alliance, points: pts,
                                 period: isAuto ? .auto : .teleop, isProcessor: true)
                        SoundManager.shared.play(.score)
                        if let scene = scene {
                            let pos = SCNVector3(agent.position.x, 0.15, agent.position.y)
                            ParticleManager.emit(ParticleManager.scoreParticles(color: agent.config.alliance.uiColor),
                                                  at: pos, in: scene)
                        }
                    } else {
                        SoundManager.shared.play(.miss)
                    }
                } else {
                    // Compute target position for ring projectile
                    let reefCenter = agent.config.alliance == .red
                        ? FieldSpec.redReefCenter : FieldSpec.blueReefCenter
                    let face = agent.lastFaceUsed >= 0 ? agent.lastFaceUsed : 0
                    let targetPos = FieldSpec.scoringApproach(center: reefCenter, faceIndex: face)

                    // Spawn visual ring projectile
                    spawnRingProjectile(
                        from: agent.position, to: targetPos,
                        level: level, success: scoringSuccess
                    )

                    if scoringSuccess {
                        let pts = scoringPoints(level: level, isAuto: isAuto)
                        addScore(alliance: agent.config.alliance, points: pts,
                                 period: isAuto ? .auto : .teleop, reefLevel: level)
                        SoundManager.shared.play(.score)
                        if let scene = scene {
                            let h: Float = level >= 3 ? FieldSpec.branchL3 : 0.15
                            let pos = SCNVector3(agent.position.x, h, agent.position.y)
                            let particles = level >= 3
                                ? ParticleManager.highScoreParticles(alliance: agent.config.alliance.uiColor)
                                : ParticleManager.scoreParticles(color: agent.config.alliance.uiColor)
                            ParticleManager.emit(particles, at: pos, in: scene)
                        }
                    } else {
                        SoundManager.shared.play(.miss)
                    }
                }
            }
            agent.state = .idle

        case .climbing:
            let pts: Int
            if agent.config.stats.canDeepClimb {
                pts = FieldSpec.Scoring.deepClimb
            } else {
                pts = FieldSpec.Scoring.shallowClimb
            }
            addScore(alliance: agent.config.alliance, points: pts, period: .endgame)
            agent.isParkedEndgame = true
            agent.state = .parked
            SoundManager.shared.play(.climb)
            if let scene = scene {
                ParticleManager.emit(
                    ParticleManager.climbParticles(color: agent.config.alliance.uiColor),
                    at: SCNVector3(agent.position.x, 0.1, agent.position.y), in: scene)
            }

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
        agent.speed = 0
        SoundManager.shared.play(.stall)
        if let scene = scene {
            let pos = SCNVector3(agent.position.x, 0.12, agent.position.y)
            ParticleManager.emit(ParticleManager.stallSmoke(), at: pos, in: scene)
        }
    }

    // MARK: - Separation (with push power)

    private func resolveSeparation() {
        let minDist: Float = 0.35
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

                    // Defenders slow opponents on contact
                    let isOpposing = agents[i].config.alliance != agents[j].config.alliance
                    if isOpposing {
                        if agents[i].config.role == .defender {
                            agents[j].speed *= 0.3
                        }
                        if agents[j].config.role == .defender {
                            agents[i].speed *= 0.3
                        }
                        if pushI > pushJ * 1.5 {
                            agents[j].speed *= 0.5
                        } else if pushJ > pushI * 1.5 {
                            agents[i].speed *= 0.5
                        }

                        // Collision particles (rate-limited)
                        if let scene = scene, simTime - lastCollisionParticleTime > 0.5 {
                            let midX = (agents[i].position.x + agents[j].position.x) / 2
                            let midZ = (agents[i].position.y + agents[j].position.y) / 2
                            ParticleManager.emit(ParticleManager.collisionSparks(),
                                                  at: SCNVector3(midX, 0.06, midZ), in: scene)
                            SoundManager.shared.play(.collision)
                            lastCollisionParticleTime = simTime
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

    // MARK: - Ring Projectile Physics

    /// Spawn a game piece ring that arcs toward the scoring target.
    /// On success: ring lands on the tower and stays.
    /// On miss: ring arcs off-target, falls with gravity, bounces, and fades out.
    private func spawnRingProjectile(from agentPos: SIMD2<Float>, to targetPos: SIMD2<Float>,
                                      level: Int, success: Bool) {
        guard let scene = scene else { return }

        let ring = FieldBuilder.makeRingProjectile()
        let startPos = SCNVector3(agentPos.x, 0.18, agentPos.y)  // robot top height
        ring.position = startPos
        ring.scale = SCNVector3(0.8, 0.8, 0.8)
        scene.rootNode.addChildNode(ring)

        // Target height based on level
        let targetHeight: Float
        switch level {
        case 1: targetHeight = FieldSpec.troughL1 + 0.06
        case 2: targetHeight = FieldSpec.branchL2 + 0.02
        case 3: targetHeight = FieldSpec.branchL3 + 0.02
        default: targetHeight = FieldSpec.branchL4 + 0.02
        }

        if success {
            // Parabolic arc to target (quadratic bezier)
            let endPos = SCNVector3(targetPos.x, targetHeight, targetPos.y)
            let midY = max(targetHeight + 0.25, 0.5)
            let midPos = SCNVector3(
                (agentPos.x + targetPos.x) / 2,
                midY,
                (agentPos.y + targetPos.y) / 2
            )

            let duration: TimeInterval = 0.55
            let arc = SCNAction.customAction(duration: duration) { node, elapsed in
                let t = Float(elapsed / duration)
                let inv = 1 - t
                node.position.x = inv * inv * startPos.x + 2 * inv * t * midPos.x + t * t * endPos.x
                node.position.y = inv * inv * startPos.y + 2 * inv * t * midPos.y + t * t * endPos.y
                node.position.z = inv * inv * startPos.z + 2 * inv * t * midPos.z + t * t * endPos.z
                // Spin during flight
                node.eulerAngles.z += 0.15
            }

            // Land: slight scale bump, then stay
            let land = SCNAction.sequence([
                SCNAction.scale(to: 1.1, duration: 0.06),
                SCNAction.scale(to: 0.85, duration: 0.15)
            ])

            ring.runAction(SCNAction.sequence([arc, land]))
        } else {
            // Miss: offset target, arc, then fall and bounce
            let missX = targetPos.x + (Float.random(in: -0.2...0.2))
            let missZ = targetPos.y + (Float.random(in: -0.2...0.2))
            let overshootH = targetHeight * 0.65  // doesn't reach full height
            let midY = max(overshootH + 0.15, 0.4)
            let missEnd = SCNVector3(missX, overshootH, missZ)
            let midPos = SCNVector3(
                (agentPos.x + missX) / 2,
                midY,
                (agentPos.y + missZ) / 2
            )

            // Arc to miss point
            let arcDuration: TimeInterval = 0.45
            let arc = SCNAction.customAction(duration: arcDuration) { node, elapsed in
                let t = Float(elapsed / arcDuration)
                let inv = 1 - t
                node.position.x = inv * inv * startPos.x + 2 * inv * t * midPos.x + t * t * missEnd.x
                node.position.y = inv * inv * startPos.y + 2 * inv * t * midPos.y + t * t * missEnd.y
                node.position.z = inv * inv * startPos.z + 2 * inv * t * midPos.z + t * t * missEnd.z
                node.eulerAngles.z += 0.2
            }

            // Fall with gravity (easeIn = accelerating)
            let fallTarget = SCNVector3(missEnd.x, 0.03, missEnd.z)
            let fall = SCNAction.move(to: fallTarget, duration: 0.3)
            fall.timingMode = .easeIn

            // Bounce
            let bounce = SCNAction.moveBy(x: 0, y: 0.06, z: 0, duration: 0.12)
            bounce.timingMode = .easeOut
            let settle = SCNAction.moveBy(x: 0, y: -0.06, z: 0, duration: 0.10)
            settle.timingMode = .easeIn

            // Small second bounce
            let bounce2 = SCNAction.moveBy(x: 0, y: 0.025, z: 0, duration: 0.08)
            bounce2.timingMode = .easeOut
            let settle2 = SCNAction.moveBy(x: 0, y: -0.025, z: 0, duration: 0.06)
            settle2.timingMode = .easeIn

            // Fade and remove
            let fade = SCNAction.fadeOut(duration: 1.0)
            let remove = SCNAction.removeFromParentNode()

            ring.runAction(SCNAction.sequence([
                arc, fall, bounce, settle, bounce2, settle2,
                SCNAction.wait(duration: 0.3),
                fade, remove
            ]))
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
        SoundManager.shared.play(.matchEnd)
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
