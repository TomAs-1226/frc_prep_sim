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
    let game: GeneratedGame
    var state: RobotState = .idle
    var position: SIMD2<Float>
    var heading: Float = 0
    var speed: Float = 0
    var hasPiece: Bool = false
    var piecesScored: Int = 0
    var piecesCycled: Int = 0
    var didStall: Bool = false
    var isStalled: Bool = false
    var stallTimer: Double = 0
    var actionTimer: Double = 0
    var currentGoal: SIMD2<Float>?
    var lastZoneId: Int = -1
    var currentTargetZone: ScoringZone?
    var hasCrossedAutoLine: Bool = false
    var isParkedEndgame: Bool = false
    var autoPhase: Int = 0

    // Score awareness (updated each tick by MatchEngine)
    var teamScore: Int = 0
    var opponentScore: Int = 0

    // Cached component nodes for animation (Model Contract hierarchy)
    weak var sceneNode: SCNNode?
    var steerPivotNodes: [SCNNode] = []   // SteerPivot nodes for steering
    var wheelRollNodes: [SCNNode] = []    // WheelRoll nodes for rolling
    var mechanismNode: SCNNode?           // elevator_stage or pivot_arm
    var intakeNode: SCNNode?              // intake_roller
    var smoothedSteerAngle: Float = 0     // Smoothed steering angle

    init(config: RobotConfig, game: GeneratedGame) {
        self.config = config
        self.game = game
        self.position = config.startPosition
        self.heading = config.alliance == .red ? Float.pi : 0
    }

    /// Cache references to animatable child nodes using Model Contract hierarchy.
    func cacheComponentNodes() {
        guard let root = sceneNode else { return }
        steerPivotNodes = []
        wheelRollNodes = []
        mechanismNode = nil
        intakeNode = nil

        // Find modules by name (Model Contract: ModuleFL/FR/BL/BR)
        let moduleNames = ["ModuleFL", "ModuleFR", "ModuleBL", "ModuleBR"]
        for moduleName in moduleNames {
            if let module = root.childNode(withName: moduleName, recursively: false),
               let steerPivot = module.childNode(withName: "SteerPivot", recursively: false),
               let wheelRoll = steerPivot.childNode(withName: "WheelRoll", recursively: false) {
                steerPivotNodes.append(steerPivot)
                wheelRollNodes.append(wheelRoll)
            }
        }

        // Cache superstructure components
        root.enumerateChildNodes { child, _ in
            if let name = child.name {
                if name == "elevator_stage" { self.mechanismNode = child }
                else if name == "pivot_arm" { self.mechanismNode = child }
                else if name == "intake_roller" { self.intakeNode = child }
            }
        }
    }

    // MARK: - Alliance Helpers

    var allianceZones: [ScoringZone] {
        game.scoringZones.filter { $0.alliance == config.alliance }
    }

    var reachableZones: [ScoringZone] {
        allianceZones.filter { $0.height <= config.stats.maxReachHeight }
    }

    var alliancePickups: [PickupStation] {
        game.pickupStations.filter { $0.alliance == config.alliance }
    }

    // MARK: - Utility-Based Goal Selection

    func decideGoal(simTime: Double, policy: StrategyPolicy, allAgents: [RobotAgent],
                    rng: inout SeededRNG) {
        guard state == .idle || state == .driving else { return }

        let timeRemaining = MatchTiming.totalDuration - simTime
        let period = currentPeriod(simTime)

        // --- Score-aware policy adjustment ---
        let scoreDiff = teamScore - opponentScore
        var adjustedPolicy = policy
        if scoreDiff < -10 {
            // Losing badly: boost scoring, reduce endgame weight
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
                let endgamePos = config.alliance == .red
                    ? FieldLayout.endgameRedPos : FieldLayout.endgameBluePos
                currentGoal = endgamePos
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
                if let target = opponents.max(by: {
                    defenderPriority($0) < defenderPriority($1)
                }) {
                    // Position between the target and THEIR scoring zones
                    let opponentZones = game.scoringZones.filter {
                        $0.alliance != config.alliance
                    }
                    let zoneCenter = zoneCentroid(opponentZones)
                    let blockPos = SIMD2<Float>(
                        target.position.x * 0.6 + zoneCenter.x * 0.4,
                        target.position.y * 0.6 + zoneCenter.y * 0.4
                    )
                    let jitter = SIMD2<Float>(
                        rng.nextFloat() * 0.15 - 0.075,
                        rng.nextFloat() * 0.15 - 0.075
                    )
                    currentGoal = blockPos + jitter
                    state = .defending
                    return
                }
            }
        }

        // --- Scoring: pick up or deliver ---
        if hasPiece {
            let best = chooseBestScoringTarget(policy: adjustedPolicy,
                                                allAgents: allAgents, rng: &rng)
            currentGoal = best.position
            currentTargetZone = best.zone
            state = .driving
        } else {
            currentGoal = nearestPickupStation(rng: &rng)
            state = .driving
        }
    }

    // MARK: - Defender Priority Scoring

    private func defenderPriority(_ opp: RobotAgent) -> Double {
        var score = 0.0
        if opp.hasPiece { score += 10.0 }
        if opp.state == .scoring { score += 5.0 }
        if opp.state == .driving && opp.hasPiece { score += 3.0 }
        if opp.config.role == .scorer { score += 3.0 }
        if opp.config.role == .cycler { score += 2.0 }
        score += Double(opp.piecesScored) * 0.5
        // Closer opponents are higher priority
        score -= Double(distance2D(position, opp.position)) * 0.3
        return score
    }

    // MARK: - Best Scoring Target (role-aware + congestion avoidance)

    private func chooseBestScoringTarget(
        policy: StrategyPolicy,
        allAgents: [RobotAgent],
        rng: inout SeededRNG
    ) -> (position: SIMD2<Float>, zone: ScoringZone?) {
        let zones = reachableZones
        guard !zones.isEmpty else {
            // Fallback: head to any alliance zone even if can't reach height
            let fallback = allianceZones.min {
                distance2D(position, $0.position) < distance2D(position, $1.position)
            }
            return (fallback?.position ?? position, fallback)
        }

        // Teammates for congestion check
        let teammates = allAgents.filter {
            $0.config.alliance == config.alliance && $0.config.id != config.id
        }

        var bestZone: ScoringZone?
        var bestUtil: Double = -1

        for zone in zones {
            let dist = distance2D(position, zone.position)

            // Congestion penalty: count teammates near this zone
            let nearbyTeammates = teammates.filter {
                distance2D($0.position, zone.position) < 0.5 ||
                ($0.currentGoal != nil && distance2D($0.currentGoal!, zone.position) < 0.3)
            }.count
            let congestionPenalty = Double(nearbyTeammates) * 0.5

            // Spread bonus from callout
            let spreadBonus: Double = (policy.spreadOut && zone.id != lastZoneId) ? 0.3 : 0.0

            let basePoints = Double(zone.pointsTeleop)

            // Role bias: cyclers prefer low zones, scorers prefer high
            let roleBias: Double
            switch config.role {
            case .cycler:
                roleBias = zone.height <= .low ? 1.5 : 0.3
            case .scorer:
                roleBias = zone.height >= .mid ? 1.4 : 0.7
            case .defender:
                roleBias = 1.0
            }

            // Focus High callout bonus
            let highBonus: Double = (policy.preferHighLevel && zone.height >= .mid) ? 0.5 : 0.0

            let timeCost = Double(dist) / Double(max(0.5, config.stats.maxSpeed))
                + config.stats.scoringTime
            let util = (basePoints * roleBias + highBonus + spreadBonus)
                / max(0.3, timeCost + congestionPenalty)

            if util > bestUtil {
                bestUtil = util
                bestZone = zone
            }
        }

        // Small random variation for diversity
        if rng.nextDouble() < 0.12, !zones.isEmpty {
            let randomIdx = rng.nextInt(0..<zones.count)
            bestZone = zones[randomIdx]
        }

        if let zone = bestZone {
            lastZoneId = zone.id
            return (zone.position, zone)
        }
        return (position, nil)
    }

    // MARK: - Nearest Pickup Station

    private func nearestPickupStation(rng: inout SeededRNG) -> SIMD2<Float> {
        let stations = alliancePickups
        let jitter = SIMD2<Float>(
            rng.nextFloat() * 0.2 - 0.1,
            rng.nextFloat() * 0.3 - 0.15
        )
        if let nearest = stations.min(by: {
            distance2D(position, $0.position) < distance2D(position, $1.position)
        }) {
            return nearest.position + jitter
        }
        // Fallback: move toward own side
        let fallbackX: Float = config.alliance == .red ? 3.5 : -3.5
        return SIMD2<Float>(fallbackX, 0) + jitter
    }

    // MARK: - Zone Centroid

    func zoneCentroid(_ zones: [ScoringZone]) -> SIMD2<Float> {
        guard !zones.isEmpty else { return SIMD2(0, 0) }
        let sum = zones.reduce(SIMD2<Float>(0, 0)) { $0 + $1.position }
        return sum / Float(zones.count)
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
        guard let target = currentGoal else { return }

        // --- Obstacle avoidance ---
        var effectiveTarget = target

        // Barrier avoidance: if path crosses a barrier, route around it
        for obs in game.obstacles where obs.kind == .barrier {
            let hx = obs.size.x / 2 + 0.28
            let hz = obs.size.y / 2 + 0.28
            let relX = position.x - obs.position.x
            let relZ = position.y - obs.position.y

            // Push out if currently inside barrier zone
            if abs(relX) < hx && abs(relZ) < hz {
                if abs(relX) / hx > abs(relZ) / hz {
                    position.x = obs.position.x + (relX >= 0 ? hx : -hx)
                } else {
                    position.y = obs.position.y + (relZ >= 0 ? hz : -hz)
                }
                speed *= 0.4
            }

            // If direct path crosses barrier, add detour
            let crossingX = (position.x < obs.position.x - hx && target.x > obs.position.x + hx)
                || (position.x > obs.position.x + hx && target.x < obs.position.x - hx)
            if crossingX && abs(position.y - obs.position.y) < hz {
                let detourZ = position.y >= obs.position.y
                    ? obs.position.y + hz + 0.2
                    : obs.position.y - hz - 0.2
                let detourX = position.x > obs.position.x
                    ? obs.position.x + hx + 0.1
                    : obs.position.x - hx - 0.1
                effectiveTarget = SIMD2<Float>(detourX, detourZ)
            }
        }

        // Bridge: mild slowdown when under the beam structure
        for obs in game.obstacles where obs.kind == .bridge {
            let bridgeHalfX = obs.size.x / 2
            if abs(position.x - obs.position.x) < bridgeHalfX {
                speed *= 0.9
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
        position.x = max(-FieldLayout.halfWidth + 0.22,
                         min(FieldLayout.halfWidth - 0.22, position.x))
        position.y = max(-FieldLayout.halfLength + 0.22,
                         min(FieldLayout.halfLength - 0.22, position.y))
    }

    var hasReachedTarget: Bool {
        guard let target = currentGoal else { return false }
        return distance2D(position, target) < 0.2
    }

    // MARK: - Scene Sync

    func syncToScene() {
        guard let node = sceneNode else { return }
        node.position = SCNVector3(position.x, 0.0, position.y)
        node.eulerAngles.y = heading

        let dt: Float = 1.0 / 30.0
        let wheelR = PartLibrary.wheelRadius

        // Wheel animation: rollSpeed = linearSpeed / wheelRadius
        let rollSpeed = speed / wheelR
        let rollSign: Float = 1.0  // positive = forward
        for wheelRoll in wheelRollNodes {
            wheelRoll.eulerAngles.x += rollSpeed * rollSign * dt
        }

        // Steer angle = heading of velocity vector (smoothed)
        // For swerve: steer pivots point in movement direction
        // For tank/mecanum: steer pivots stay at 0
        if !steerPivotNodes.isEmpty {
            let targetSteer: Float = 0  // relative to body frame, always 0
            // Smooth steer transitions
            smoothedSteerAngle += (targetSteer - smoothedSteerAngle) * 0.15
            for pivot in steerPivotNodes {
                pivot.eulerAngles.y = smoothedSteerAngle
            }
        }

        // Animate intake roller when picking up
        if state == .pickingUp, let intake = intakeNode {
            intake.eulerAngles.x += Float.pi * 4.0 * dt
        }

        // Animate mechanism during scoring
        if state == .scoring, let mech = mechanismNode {
            if mech.name == "elevator_stage" {
                let targetY: Float
                if let zone = currentTargetZone {
                    targetY = zone.height.sceneHeight * 0.25
                } else {
                    targetY = 0.14
                }
                let baseY: Float = PartLibrary.chassisHeight
                mech.position.y += (targetY + baseY - mech.position.y) * 0.08
            } else if mech.name == "pivot_arm" {
                let targetAngle: Float = -0.4
                mech.eulerAngles.z += (targetAngle - mech.eulerAngles.z) * 0.06
            }
        } else if let mech = mechanismNode {
            if mech.name == "elevator_stage" {
                let restY: Float = PartLibrary.chassisHeight + PartLibrary.chassisHeight
                mech.position.y += (restY - mech.position.y) * 0.05
            } else if mech.name == "pivot_arm" {
                mech.eulerAngles.z += (0.30 - mech.eulerAngles.z) * 0.05
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
    @Published var activeCallouts: Set<Callout> = []
    @Published var calloutCooldown: Double = 0

    let configs: [RobotConfig]
    let game: GeneratedGame
    let playerAutoPlan: AutoPlan
    let playerStrategy: AllianceStrategy
    var redPolicy: StrategyPolicy
    let bluePolicy = StrategyPolicy(scoringWeight: 0.6, defenseWeight: 0.2,
                                     endgameWeight: 0.2)

    var agents: [RobotAgent] = []
    var rng: SeededRNG
    private var updateTimer: Timer?
    private var calloutsUsed: [Callout] = []
    private var calloutEvents: [CalloutEvent] = []
    private var slowMoTimer: Double = 0
    private var slowMoUsed: Bool = false
    private var lastUpdateTime: Date?
    private var scene: SCNScene?
    private var zoneNodes: [Int: SCNNode] = [:]

    init(configs: [RobotConfig], strategy: AllianceStrategy, playerAuto: AutoPlan,
         game: GeneratedGame, seed: UInt64 = 42) {
        self.configs = configs
        self.game = game
        self.playerAutoPlan = playerAuto
        self.playerStrategy = strategy
        self.redPolicy = strategy.basePolicy
        self.rng = SeededRNG(seed: seed)

        for config in configs {
            agents.append(RobotAgent(config: config, game: game))
        }
    }

    // MARK: - Scene Binding

    func attach(scene: SCNScene, robotNodes: [SCNNode], zoneNodes: [Int: SCNNode]) {
        self.scene = scene
        self.zoneNodes = zoneNodes
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

        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0,
                                            repeats: true) { [weak self] _ in
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

    /// Computed property for basic "any callout available" check.
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
        case .pushScoring:
            // All red agents re-evaluate goals with boosted scoring weight
            for agent in redAgents where agent.state == .idle
                || agent.state == .driving || agent.state == .defending {
                agent.state = .idle
            }

        case .playDefense:
            // Find best candidate to switch to defense
            if let candidate = redAgents.first(where: {
                $0.config.role != .defender && !$0.hasPiece && $0.config.id != 0
                && ($0.state == .idle || $0.state == .driving)
            }) {
                let opponents = agents.filter {
                    $0.config.alliance == .blue && !$0.isParkedEndgame
                }
                if let target = opponents.max(by: {
                    $0.piecesScored < $1.piecesScored
                }) {
                    let blueZones = game.blueZones
                    let zoneCenter = candidate.zoneCentroid(blueZones)
                    candidate.currentGoal = SIMD2<Float>(
                        target.position.x * 0.6 + zoneCenter.x * 0.4,
                        target.position.y * 0.6 + zoneCenter.y * 0.4
                    )
                    candidate.state = .defending
                }
            }

        case .endgameNow:
            // All red agents head to endgame positions immediately
            for agent in redAgents where !agent.isParkedEndgame
                && agent.state != .climbing {
                agent.currentGoal = FieldLayout.endgameRedPos
                agent.state = .headingEndgame
            }

        case .focusHigh:
            // Scorers re-evaluate to pick higher targets
            for agent in redAgents where agent.state == .idle
                || agent.state == .driving {
                agent.state = .idle
            }

        case .spreadOut:
            // Reset lastZoneId so all agents pick new zones
            for agent in redAgents {
                agent.lastZoneId = -1
                if agent.state == .idle || agent.state == .driving {
                    agent.state = .idle
                }
            }

        case .allOut:
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
            agent.decideGoal(simTime: simTime, policy: policy,
                             allAgents: agents, rng: &rng)
        }

        if agent.state == .driving || agent.state == .defending
            || agent.state == .headingEndgame {
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

        let zones = agent.reachableZones.isEmpty ? agent.allianceZones : agent.reachableZones
        guard !zones.isEmpty else {
            agent.state = .idle
            agent.autoPhase = 99
            return
        }

        switch agent.autoPhase {
        case 0:
            // Pre-loaded piece, head to first scoring zone
            agent.state = .autoPath
            agent.hasPiece = true
            let zoneIdx = agent.config.id % zones.count
            let targetZone = zones[zoneIdx]
            agent.currentGoal = targetZone.position
            agent.currentTargetZone = targetZone
            agent.autoPhase = 1

        case 1:
            // Drive to first zone
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
            // After first score: head to pickup if more pieces planned
            if autoPlan.piecesAttempted > 1 {
                let stations = agent.alliancePickups
                if let nearest = stations.min(by: {
                    distance2D(agent.position, $0.position)
                        < distance2D(agent.position, $1.position)
                }) {
                    var pickupPos = nearest.position
                    pickupPos.y += Float(agent.config.id % 3) * 0.25 - 0.25
                    agent.currentGoal = pickupPos
                }
                agent.state = .autoPath
                agent.autoPhase = 3
            } else {
                agent.state = .idle
                agent.autoPhase = 99
            }

        case 3:
            // Drive to pickup station
            agent.updateMovement(dt: dt)
            checkAutoLine(agent)
            if agent.hasReachedTarget {
                agent.hasPiece = true
                agent.piecesCycled += 1
                // Pick a different zone for the second scoring attempt
                let zoneIdx = (agent.config.id + zones.count / 2) % zones.count
                let targetZone = zones[zoneIdx]
                agent.currentGoal = targetZone.position
                agent.currentTargetZone = targetZone
                agent.state = .autoPath
                agent.autoPhase = 4
            }

        case 4:
            // Drive to second zone and score
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
            // Head to pickup for third piece
            let stations = agent.alliancePickups
            if let nearest = stations.min(by: {
                distance2D(agent.position, $0.position)
                    < distance2D(agent.position, $1.position)
            }) {
                var pickupPos = nearest.position
                pickupPos.y += Float(agent.config.id % 2) * 0.3
                agent.currentGoal = pickupPos
            }
            agent.state = .autoPath
            agent.autoPhase = 6

        case 6:
            // Drive to pickup
            agent.updateMovement(dt: dt)
            if agent.hasReachedTarget {
                agent.hasPiece = true
                agent.piecesCycled += 1
                let zoneIdx = (agent.config.id + 1) % zones.count
                let targetZone = zones[zoneIdx]
                agent.currentGoal = targetZone.position
                agent.currentTargetZone = targetZone
                agent.state = .autoPath
                agent.autoPhase = 7
            }

        case 7:
            // Drive to third zone and score
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
            crossed = agent.position.x < FieldLayout.redAutoLine
        } else {
            crossed = agent.position.x > FieldLayout.blueAutoLine
        }
        if crossed {
            agent.hasCrossedAutoLine = true
            addScore(alliance: agent.config.alliance,
                     points: game.autoLeavePoints, period: .auto)
        }
    }

    // MARK: - Arrival Handling

    private func handleArrival(_ agent: RobotAgent) {
        if agent.state == .headingEndgame {
            agent.state = .climbing
            // Timer based on endgame challenge type
            switch game.endgameChallenge {
            case .climb(let difficulty, _):
                agent.actionTimer = difficulty.climbTime
            case .balance:
                agent.actionTimer = 3.0
            case .park:
                agent.actionTimer = 1.0
            }
            return
        }

        if agent.state == .defending {
            agent.state = .idle
            return
        }

        if !agent.hasPiece && isNearPickup(agent) {
            if rng.nextDouble() > agent.config.stats.reliability {
                triggerStall(agent, duration: 2.0)
                return
            }
            agent.state = .pickingUp
            agent.actionTimer = agent.config.stats.pickupTime
            return
        }

        if agent.hasPiece, let zone = nearestReachableZone(for: agent) {
            agent.currentTargetZone = zone
            agent.state = .scoring
            agent.actionTimer = agent.config.stats.scoringTime
            pulseZoneNode(zoneId: zone.id)
            return
        }

        agent.state = .idle
    }

    private func isNearPickup(_ agent: RobotAgent) -> Bool {
        let stations = game.pickupStations.filter {
            $0.alliance == agent.config.alliance
        }
        return stations.contains {
            distance2D(agent.position, $0.position) < 0.6
        }
    }

    /// Returns a nearby scoring zone the agent can reach (height-wise).
    private func nearestReachableZone(for agent: RobotAgent) -> ScoringZone? {
        let zones = game.scoringZones.filter {
            $0.alliance == agent.config.alliance
            && $0.height <= agent.config.stats.maxReachHeight
        }
        return zones.first { distance2D(agent.position, $0.position) < 0.5 }
    }

    /// Returns nearest alliance zone regardless of height (for visuals/fallback).
    private func nearestAllianceZone(for agent: RobotAgent) -> ScoringZone? {
        let zones = game.scoringZones.filter {
            $0.alliance == agent.config.alliance
        }
        return zones.min {
            distance2D(agent.position, $0.position)
                < distance2D(agent.position, $1.position)
        }
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

                // Determine scoring success based on reliability
                let scoringSuccess = rng.nextDouble() <= agent.config.stats.reliability

                // Find the zone being scored at
                let zone = agent.currentTargetZone
                    ?? nearestReachableZone(for: agent)
                    ?? nearestAllianceZone(for: agent)

                if let zone = zone {
                    let targetHeight = zone.height

                    // Spawn visual projectile
                    spawnProjectile(
                        from: agent.position, to: zone.position,
                        height: targetHeight, success: scoringSuccess
                    )

                    if scoringSuccess {
                        let pts = isAuto ? zone.pointsAuto : zone.pointsTeleop
                        addScore(
                            alliance: agent.config.alliance, points: pts,
                            period: isAuto ? .auto : .teleop,
                            height: targetHeight
                        )
                        // Spawn scoring particles
                        if let scene = scene {
                            FieldBuilder.spawnScoreParticles(
                                at: SCNVector3(zone.position.x, targetHeight.sceneHeight + 0.05, zone.position.y),
                                alliance: agent.config.alliance,
                                scene: scene
                            )
                        }
                    }
                }
            }
            agent.state = .idle

        case .climbing:
            // Award endgame points based on challenge type
            switch game.endgameChallenge {
            case .climb(let difficulty, let pts):
                // Only canDeepClimb robots get full points on high difficulty
                if difficulty == .high && !agent.config.stats.canDeepClimb {
                    addScore(alliance: agent.config.alliance,
                             points: pts / 2, period: .endgame)
                } else {
                    addScore(alliance: agent.config.alliance,
                             points: pts, period: .endgame)
                }
            case .balance(let pts):
                addScore(alliance: agent.config.alliance,
                         points: pts, period: .endgame)
            case .park(let pts):
                addScore(alliance: agent.config.alliance,
                         points: pts, period: .endgame)
            }
            agent.isParkedEndgame = true
            agent.state = .parked

        case .parked:
            break

        default:
            agent.state = .idle
        }
    }

    // MARK: - Scoring

    private func addScore(alliance: Alliance, points: Int, period: MatchPeriod,
                          height: ScoringHeight? = nil) {
        if alliance == .red {
            redScore += points
            switch period {
            case .auto:    redBreakdown.autoPoints += points
            case .endgame: redBreakdown.endgamePoints += points
            default:       redBreakdown.teleopPoints += points
            }
            if let h = height {
                redBreakdown.totalPieces += 1
                switch h {
                case .ground: redBreakdown.groundScores += 1
                case .low:    redBreakdown.lowScores += 1
                case .mid:    redBreakdown.midScores += 1
                case .high:   redBreakdown.highScores += 1
                }
            }
        } else {
            blueScore += points
            switch period {
            case .auto:    blueBreakdown.autoPoints += points
            case .endgame: blueBreakdown.endgamePoints += points
            default:       blueBreakdown.teleopPoints += points
            }
            if let h = height {
                blueBreakdown.totalPieces += 1
                switch h {
                case .ground: blueBreakdown.groundScores += 1
                case .low:    blueBreakdown.lowScores += 1
                case .mid:    blueBreakdown.midScores += 1
                case .high:   blueBreakdown.highScores += 1
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
    }

    // MARK: - Separation (with push power + collision particles)

    private var lastCollisionDustTime: Double = 0

    private func resolveSeparation() {
        let minDist: Float = 0.42  // increased from 0.35 to prevent clipping
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
                    let ratioI = pushJ / totalPush
                    let ratioJ = pushI / totalPush

                    agents[i].position.x -= nx * overlap * 2.2 * ratioI
                    agents[i].position.y -= nz * overlap * 2.2 * ratioI
                    agents[j].position.x += nx * overlap * 2.2 * ratioJ
                    agents[j].position.y += nz * overlap * 2.2 * ratioJ

                    // Spawn collision dust particles (throttled)
                    let isOpposing = agents[i].config.alliance
                        != agents[j].config.alliance
                    if isOpposing && overlap > 0.02 && simTime - lastCollisionDustTime > 0.5 {
                        lastCollisionDustTime = simTime
                        if let scene = scene {
                            let mid = SIMD2<Float>(
                                (agents[i].position.x + agents[j].position.x) / 2,
                                (agents[i].position.y + agents[j].position.y) / 2
                            )
                            FieldBuilder.spawnCollisionDust(
                                at: SCNVector3(mid.x, 0.06, mid.y),
                                scene: scene
                            )
                        }
                    }

                    // Defenders slow opponents on contact
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

    private func pulseZoneNode(zoneId: Int) {
        guard let target = zoneNodes[zoneId] else { return }

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

    // MARK: - Projectile Physics

    /// Spawn a game piece that arcs toward the scoring target.
    /// On success: piece lands on the target and stays.
    /// On miss: piece arcs off-target, falls with gravity, bounces, and fades out.
    private func spawnProjectile(from agentPos: SIMD2<Float>, to targetPos: SIMD2<Float>,
                                  height: ScoringHeight, success: Bool) {
        guard let scene = scene else { return }

        let pieceKind = game.gamePieces.first ?? .ball
        let piece = FieldBuilder.makeGamePiece(kind: pieceKind)
        let startPos = SCNVector3(agentPos.x, 0.18, agentPos.y)
        piece.position = startPos
        piece.scale = SCNVector3(0.8, 0.8, 0.8)
        scene.rootNode.addChildNode(piece)

        let targetHeight = height.sceneHeight

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
                node.position.x = inv * inv * startPos.x
                    + 2 * inv * t * midPos.x + t * t * endPos.x
                node.position.y = inv * inv * startPos.y
                    + 2 * inv * t * midPos.y + t * t * endPos.y
                node.position.z = inv * inv * startPos.z
                    + 2 * inv * t * midPos.z + t * t * endPos.z
                // Spin during flight
                node.eulerAngles.z += 0.15
            }

            // Land: slight scale bump, then stay
            let land = SCNAction.sequence([
                SCNAction.scale(to: 1.1, duration: 0.06),
                SCNAction.scale(to: 0.85, duration: 0.15)
            ])

            piece.runAction(SCNAction.sequence([arc, land]))
        } else {
            // Miss: offset target, arc, then fall and bounce
            let missX = targetPos.x + Float.random(in: -0.2...0.2)
            let missZ = targetPos.y + Float.random(in: -0.2...0.2)
            let overshootH = targetHeight * 0.65
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
                node.position.x = inv * inv * startPos.x
                    + 2 * inv * t * midPos.x + t * t * missEnd.x
                node.position.y = inv * inv * startPos.y
                    + 2 * inv * t * midPos.y + t * t * missEnd.y
                node.position.z = inv * inv * startPos.z
                    + 2 * inv * t * midPos.z + t * t * missEnd.z
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

            piece.runAction(SCNAction.sequence([
                arc, fall, bounce, settle, bounce2, settle2,
                SCNAction.wait(duration: 0.3),
                fade, remove
            ]))
        }
    }

    // MARK: - Coaching Tips

    private func generateCoachingTip() {
        let endgameDesc: String = {
            switch game.endgameChallenge {
            case .climb(let d, let p): return "\(d.rawValue) climb (\(p)pts)"
            case .balance(let p):      return "balance (\(p)pts)"
            case .park(let p):         return "park (\(p)pts)"
            }
        }()

        let tips: [() -> CoachingTip?] = [
            { [self] in
                let defenders = agents.filter {
                    $0.config.role == .defender && $0.state == .defending
                }
                guard let def = defenders.first else { return nil }
                return CoachingTip(
                    headline: "Defense in Action",
                    detail: "Notice how #\(def.config.teamNumber) positions between opponents and their scoring zones. Their \(def.config.build.drivetrain.shortLabel) drive gives them \(def.config.stats.canDeepClimb ? "deep climb ability" : "speed advantage") for endgame.",
                    highlightRobotId: def.config.id
                )
            },
            { [self] in
                let scorers = agents.filter { $0.state == .scoring }
                guard let s = scorers.first else { return nil }
                let maxHeight = s.config.stats.maxReachHeight.displayName
                return CoachingTip(
                    headline: "Scoring Cycle",
                    detail: "Team \(s.config.teamNumber)'s \(s.config.build.manipulator.shortLabel) scores in ~\(String(format: "%.1f", s.config.stats.scoringTime))s (reaches \(maxHeight)). \(s.config.build.intake.shortLabel) intake picks up in \(String(format: "%.1f", s.config.stats.pickupTime))s.",
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
                let topScorer = agents.filter { $0.config.alliance == .red }
                    .max(by: { $0.piecesScored < $1.piecesScored })
                guard let t = topScorer, t.piecesScored > 0 else { return nil }
                return CoachingTip(
                    headline: "Top Performer",
                    detail: "Team \(t.config.teamNumber) leads with \(t.piecesScored) pieces. Their \(t.config.build.drivetrain.shortLabel)+\(t.config.build.manipulator.shortLabel)+\(t.config.build.intake.shortLabel) build \(t.config.stats.canDeepClimb ? "can deep climb!" : "focuses on speed.").",
                    highlightRobotId: t.config.id
                )
            },
            { [self] in
                let diff = redScore - blueScore
                let comparison = diff > 0
                    ? "leading by \(diff)" : (diff < 0
                    ? "trailing by \(-diff)" : "tied")
                let timeLeft = Int(max(0, MatchTiming.totalDuration - simTime))
                return CoachingTip(
                    headline: "Score Check",
                    detail: "Your red alliance is \(comparison) with \(timeLeft)s left. Endgame is \(endgameDesc) — make sure to plan your approach!",
                    highlightRobotId: nil
                )
            },
            { [self] in
                let cyclers = agents.filter { $0.config.role == .cycler }
                guard let c = cyclers.first else { return nil }
                return CoachingTip(
                    headline: "Cycle Speed",
                    detail: "Cycler #\(c.config.teamNumber) has \(c.piecesCycled) cycles using \(c.config.build.manipulator.shortLabel)+\(c.config.build.intake.shortLabel). Cyclers target low zones for fast turnaround — fewer points per piece but more volume.",
                    highlightRobotId: c.config.id
                )
            },
            { [self] in
                let builds = agents.map {
                    "\($0.config.build.drivetrain.shortLabel)/\($0.config.build.manipulator.shortLabel)"
                }
                let unique = Set(builds).count
                let pieceNames = game.gamePieces.map(\.rawValue).joined(separator: " & ")
                return CoachingTip(
                    headline: "Build Variety",
                    detail: "There are \(unique) different build combos on the field playing with \(pieceNames). In real FRC, each team's robot is unique — some prioritize speed, others reliability or reach.",
                    highlightRobotId: nil
                )
            },
            { [self] in
                let maxZone = game.maxScoringHeight
                let highZoneCount = game.redZones.filter { $0.height == maxZone }.count
                return CoachingTip(
                    headline: "Game Analysis",
                    detail: "This game has \(highZoneCount) \(maxZone.displayName)-height targets per side. Robots need \(maxZone == .high ? "an Elevator" : maxZone == .mid ? "a Pivot Arm or Elevator" : "any manipulator") to reach them. The endgame is a \(endgameDesc).",
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
            detail: "Pay attention to robot paths. Teams that avoid traffic jams and cycle efficiently score more. Spreading out across scoring zones prevents congestion!",
            highlightRobotId: nil
        )
    }

    // MARK: - Finish

    private func finishMatch() {
        guard isRunning else { return }
        stop()
        period = .finished
        isFinished = true

        // End-of-match celebration: confetti burst for winning alliance
        if let scene = scene {
            let winColor: Alliance = redScore >= blueScore ? .red : .blue
            for _ in 0..<3 {
                let pos = SCNVector3(
                    Float.random(in: -1.5...1.5),
                    0.4,
                    Float.random(in: -1.0...1.0)
                )
                FieldBuilder.spawnScoreParticles(at: pos, alliance: winColor, scene: scene)
            }

            // Winning robots do a victory spin
            for agent in agents where agent.config.alliance == winColor {
                if let node = agent.sceneNode {
                    let spin = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 4, z: 0, duration: 2.0)
                    spin.timingMode = .easeInEaseOut
                    node.runAction(spin)
                }
            }
        }
    }

    // MARK: - Result

    var result: MatchResult {
        let playerAgent = agents.first { $0.config.id == 0 }
        return MatchResult(
            game: game,
            playerStrategy: playerStrategy,
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
            slowMoUsed: slowMoUsed,
            buildMatchScore: game.buildMatchScore(build: configs[0].build)
        )
    }
}
