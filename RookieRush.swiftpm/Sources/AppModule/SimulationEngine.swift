import Foundation
import SceneKit

// MARK: - Utility Helper

private func distance2D(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
    let d = a - b
    return sqrt(d.x * d.x + d.y * d.y)
}

// MARK: - Robot Agent

/// Individual robot AI with utility-based decision-making.
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
    weak var sceneNode: SCNNode?

    init(config: RobotConfig) {
        self.config = config
        self.position = config.startPosition
        self.heading = config.alliance == .red ? Float.pi : 0
    }

    // MARK: - Utility-Based Goal Selection

    func decideGoal(simTime: Double, policy: StrategyPolicy, allAgents: [RobotAgent], rng: inout SeededRNG) {
        guard state == .idle || state == .driving else { return }

        let timeRemaining = MatchTiming.totalDuration - simTime
        let period = currentPeriod(simTime)

        // --- Endgame urgency ---
        let endgameUrgency = max(0, 1.0 - timeRemaining / 25.0)
        if (period == .endgame || endgameUrgency > 0.7) && !isParkedEndgame {
            let endgameUtil = policy.endgameWeight + endgameUrgency * 1.5
            if endgameUtil > 0.8 || timeRemaining < 10 {
                let barge = config.alliance == .red ? FieldLayout.redBarge : FieldLayout.blueBarge
                targetPosition = barge
                state = .headingEndgame
                return
            }
        }

        // --- Defense utility (defenders prefer blocking) ---
        if config.role == .defender {
            let defUtil = policy.defenseWeight * 1.5
            let scoreUtil = policy.scoringWeight

            if defUtil > scoreUtil {
                let opponents = allAgents.filter {
                    $0.config.alliance != config.alliance && $0.config.role != .defender
                }
                // Block the nearest active opponent scorer
                if let target = opponents.min(by: {
                    distance2D(position, $0.position) < distance2D(position, $1.position)
                }) {
                    let reefCenter = config.alliance == .red
                        ? FieldSpec.blueReefCenter : FieldSpec.redReefCenter
                    let blockPos = SIMD2<Float>(
                        (target.position.x + reefCenter.x) / 2,
                        (target.position.y + reefCenter.y) / 2
                    )
                    let jitter = SIMD2<Float>(
                        rng.nextFloat() * 0.2 - 0.1,
                        rng.nextFloat() * 0.2 - 0.1
                    )
                    targetPosition = blockPos + jitter
                    state = .defending
                    return
                }
            }
        }

        // --- Scoring: pick up or deliver ---
        if hasPiece {
            let best = chooseBestScoringTarget(rng: &rng)
            targetPosition = best.position
            currentTargetLevel = best.level
            state = .driving
        } else {
            targetPosition = nearestSource(rng: &rng)
            state = .driving
        }
    }

    // MARK: - Best Scoring Target

    private func chooseBestScoringTarget(rng: inout SeededRNG) -> (position: SIMD2<Float>, level: Int) {
        let maxLevel = config.stats.maxReefLevel
        var bestPos: SIMD2<Float> = config.alliance == .red
            ? FieldLayout.redReefApproach(0) : FieldLayout.blueReefApproach(0)
        var bestLevel = 1
        var bestUtil: Double = -1

        // Evaluate each reef face × level
        for face in 0..<6 {
            let approach = config.alliance == .red
                ? FieldLayout.redReefApproach(face)
                : FieldLayout.blueReefApproach(face)
            let dist = distance2D(position, approach)

            for level in 1...maxLevel {
                let points: Double
                switch level {
                case 1: points = 2
                case 2: points = 3
                case 3: points = 4
                default: points = 5
                }
                let timeCost = Double(dist) / Double(max(0.5, config.stats.maxSpeed)) + config.stats.scoringTime
                let util = points / max(0.3, timeCost)

                if util > bestUtil {
                    bestUtil = util
                    bestPos = approach
                    bestLevel = level
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
            bestLevel = 0  // 0 = processor
        }

        // 15% chance to vary target for diversity
        if rng.nextDouble() < 0.15 {
            let randomFace = Int(rng.next() % 6)
            bestPos = config.alliance == .red
                ? FieldLayout.redReefApproach(randomFace)
                : FieldLayout.blueReefApproach(randomFace)
            bestLevel = rng.nextInt(1..<(maxLevel + 1))
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

        let dx = target.x - position.x
        let dz = target.y - position.y
        let dist = sqrt(dx * dx + dz * dz)

        if dist < 0.15 {
            speed = 0
            return
        }

        // Rotate toward target
        let targetHeading = atan2(dx, dz)
        var angleDiff = targetHeading - heading
        while angleDiff > Float.pi { angleDiff -= 2 * Float.pi }
        while angleDiff < -Float.pi { angleDiff += 2 * Float.pi }
        let turnAmount = min(abs(angleDiff), config.stats.turnRate * dt)
        heading += angleDiff > 0 ? turnAmount : -turnAmount

        // Accelerate toward max, slow near target
        let targetSpeed = min(config.stats.maxSpeed, dist * 2.5)
        if speed < targetSpeed {
            speed = min(speed + config.stats.acceleration * dt, targetSpeed)
        } else {
            speed = max(speed - config.stats.acceleration * dt * 2, targetSpeed)
        }

        position.x += sin(heading) * speed * dt
        position.y += cos(heading) * speed * dt

        // Clamp to field
        position.x = max(-FieldLayout.halfWidth + 0.15, min(FieldLayout.halfWidth - 0.15, position.x))
        position.y = max(-FieldLayout.halfLength + 0.15, min(FieldLayout.halfLength - 0.15, position.y))
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
    }
}

// MARK: - Match Engine

@MainActor
final class MatchEngine: ObservableObject {

    // MARK: Published State
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

    // MARK: Configuration
    let configs: [RobotConfig]
    let playerAutoPlan: AutoPlan
    var redPolicy: StrategyPolicy
    let bluePolicy = StrategyPolicy(scoringWeight: 0.6, defenseWeight: 0.2, endgameWeight: 0.2)

    // MARK: Internal
    var agents: [RobotAgent] = []
    var rng: SeededRNG
    private var updateTimer: Timer?
    private var calloutsUsed: [Callout] = []
    private var calloutsRemaining: Int = 3
    private var slowMoTimer: Double = 0
    private var slowMoUsed: Bool = false
    private var lastUpdateTime: Date?
    private var scene: SCNScene?
    private var reefNodeTargets: [SCNNode] = []

    init(configs: [RobotConfig], strategy: AllianceStrategy, playerAuto: AutoPlan, seed: UInt64 = 42) {
        self.configs = configs
        self.playerAutoPlan = playerAuto
        self.redPolicy = strategy.basePolicy
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

    var canUseCallout: Bool { calloutsRemaining > 0 && isRunning && !isFinished }

    func useCallout(_ callout: Callout) {
        guard canUseCallout else { return }
        calloutsRemaining -= 1
        calloutsUsed.append(callout)
        redPolicy = redPolicy.applying(callout: callout)
        strategyMode = redPolicy.dominantMode
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

        // Clamp dt to prevent physics explosions
        let clampedWallDt = min(wallDt, 0.1)
        let simDt = clampedWallDt * speedMultiplier
        simTime += simDt

        // Update period
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

        // Slow-mo countdown (uses wall time)
        if isSlowMo {
            slowMoTimer -= clampedWallDt
            if slowMoTimer <= 0 { deactivateSlowMo() }
        }

        let dt = Float(simDt)

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
        // Stall recovery
        if agent.isStalled {
            agent.stallTimer -= simDt
            if agent.stallTimer <= 0 {
                agent.isStalled = false
                agent.state = .idle
            }
            return
        }

        // Timed action completion
        if agent.actionTimer > 0 {
            agent.actionTimer -= simDt
            if agent.actionTimer <= 0 {
                completeAction(agent)
            }
            return
        }

        let policy = agent.config.alliance == .red ? redPolicy : bluePolicy

        // Auto period: scripted path
        if period == .auto {
            runAutoRoutine(agent, dt: dt)
            return
        }

        // Teleop/Endgame: utility-based decisions
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
            // Phase 0: Pre-loaded, drive toward reef to score
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
            // Phase 1: Driving to score first piece
            agent.updateMovement(dt: dt)
            checkAutoLine(agent)
            if agent.hasReachedTarget && agent.hasPiece {
                if isPlayer && rng.nextDouble() > autoPlan.successRate {
                    triggerStall(agent, duration: 3.0)
                    agent.autoPhase = 99
                    return
                }
                agent.state = .scoring
                agent.actionTimer = agent.config.stats.scoringTime * 0.8  // auto is slightly faster
                agent.autoPhase = 2
            }

        case 2:
            // Phase 2: Scored first piece, attempt more?
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
            // Phase 3: Driving to source for second piece
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
            // Phase 4: Driving to score second piece
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
            // Phase 5: Third piece attempt (risky auto)
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
            // Auto done — idle until teleop
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
            agent.actionTimer = 3.0
            return
        }

        if agent.state == .defending {
            agent.state = .idle
            return
        }

        // At source: pick up
        if !agent.hasPiece && isNearSource(agent) {
            if rng.nextDouble() > agent.config.stats.reliability {
                triggerStall(agent, duration: 2.0)
                return
            }
            agent.state = .pickingUp
            agent.actionTimer = agent.config.stats.pickupTime
            return
        }

        // At scoring target: score
        if agent.hasPiece && isNearScoringTarget(agent) {
            if rng.nextDouble() > agent.config.stats.reliability {
                triggerStall(agent, duration: 1.5)
                return
            }
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
        // Near any reef approach
        for face in 0..<6 {
            let approach = FieldSpec.scoringApproach(center: reefCenter, faceIndex: face)
            if distance2D(agent.position, approach) < 0.4 { return true }
        }
        // Near processor
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

                if isProcessor {
                    let pts = isAuto ? FieldSpec.Scoring.autoProcessor : FieldSpec.Scoring.teleopProcessor
                    addScore(alliance: agent.config.alliance, points: pts,
                             period: isAuto ? .auto : .teleop, isProcessor: true)
                } else {
                    let pts = scoringPoints(level: level, isAuto: isAuto)
                    addScore(alliance: agent.config.alliance, points: pts,
                             period: isAuto ? .auto : .teleop, reefLevel: level)
                }
            }
            agent.state = .idle

        case .climbing:
            // Climbing complete — award endgame points
            let pts = agent.config.build.drivetrain == .swerve
                ? FieldSpec.Scoring.shallowClimb : FieldSpec.Scoring.deepClimb
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
    }

    // MARK: - Separation

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
                    agents[i].position.x -= nx * overlap
                    agents[i].position.y -= nz * overlap
                    agents[j].position.x += nx * overlap
                    agents[j].position.y += nz * overlap

                    // Defenders slow opponents on contact
                    if agents[i].config.role == .defender && agents[i].config.alliance != agents[j].config.alliance {
                        agents[j].speed *= 0.4
                    }
                    if agents[j].config.role == .defender && agents[j].config.alliance != agents[i].config.alliance {
                        agents[i].speed *= 0.4
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
                let opp = def.config.alliance == .red ? "blue" : "red"
                return CoachingTip(
                    headline: "Defense in Action",
                    detail: "Notice how #\(def.config.teamNumber) positions between opponents and their reef. Good defense slows the other alliance's cycles without needing to score.",
                    highlightRobotId: def.config.id
                )
            },
            { [self] in
                let scorers = agents.filter { $0.state == .scoring }
                guard let s = scorers.first else { return nil }
                return CoachingTip(
                    headline: "Scoring Cycle",
                    detail: "Team \(s.config.teamNumber) is placing coral! Their \(s.config.build.mechanism.shortLabel) mechanism takes ~\(String(format: "%.1f", s.config.stats.scoringTime))s per score. Faster mechanisms cycle more but reach lower levels.",
                    highlightRobotId: s.config.id
                )
            },
            { [self] in
                return CoachingTip(
                    headline: "Strategy Impact",
                    detail: "Your alliance is in \"\(strategyMode)\" — this adjusts whether robots prioritize scoring, defense, or endgame prep. Use callouts to shift mid-match!",
                    highlightRobotId: nil
                )
            },
            { [self] in
                let topScorer = agents.filter { $0.config.alliance == .red }.max(by: { $0.piecesScored < $1.piecesScored })
                guard let t = topScorer, t.piecesScored > 0 else { return nil }
                return CoachingTip(
                    headline: "Top Performer",
                    detail: "Team \(t.config.teamNumber) leads your alliance with \(t.piecesScored) pieces scored. Their \(t.config.role.rawValue) role and \(t.config.build.drivetrain.shortLabel) drive are a strong combo.",
                    highlightRobotId: t.config.id
                )
            },
            { [self] in
                let diff = redScore - blueScore
                let comparison = diff > 0 ? "leading by \(diff)" : (diff < 0 ? "trailing by \(-diff)" : "tied")
                let timeLeft = Int(max(0, MatchTiming.totalDuration - simTime))
                return CoachingTip(
                    headline: "Score Check",
                    detail: "Your red alliance is \(comparison) points with \(timeLeft)s left. In FRC, endgame climbing can swing 12+ points per robot!",
                    highlightRobotId: nil
                )
            },
            { [self] in
                let cyclers = agents.filter { $0.config.role == .cycler }
                guard let c = cyclers.first else { return nil }
                return CoachingTip(
                    headline: "Cycle Speed",
                    detail: "Cycler #\(c.config.teamNumber) has completed \(c.piecesCycled) cycles. Cyclers focus on L1-L2 for fast turnaround — fewer points per piece but more total cycles.",
                    highlightRobotId: c.config.id
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
            detail: "Pay attention to robot paths. Teams that avoid traffic jams and cycle efficiently score more. The hexagonal reef has 6 faces — spreading out prevents congestion!",
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
            playerRobotScored: playerAgent?.piecesScored ?? 0,
            playerRobotCycled: playerAgent?.piecesCycled ?? 0,
            didPlayerStall: playerAgent?.didStall ?? false,
            matchDuration: simTime,
            slowMoUsed: slowMoUsed
        )
    }
}
