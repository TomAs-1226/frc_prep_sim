import Foundation
import SceneKit

// MARK: - Robot Agent

/// Individual robot AI that runs a state machine, picks goals, and drives.
/// Each of the 6 robots in the match has its own RobotAgent instance.
class RobotAgent {
    let config: RobotConfig
    var state: RobotState = .idle
    var position: SIMD2<Float>
    var heading: Float = 0           // radians, 0 = +x
    var speed: Float = 0
    var hasPiece: Bool = false
    var piecesScored: Int = 0
    var piecesCycled: Int = 0
    var isStalled: Bool = false
    var stallTimer: Double = 0
    var actionTimer: Double = 0
    var targetPosition: SIMD2<Float>?
    var hasCrossedAutoLine: Bool = false
    var isParkedEndgame: Bool = false
    var didStall: Bool = false
    weak var sceneNode: SCNNode?

    init(config: RobotConfig) {
        self.config = config
        self.position = config.startPosition
        // Face toward field center
        self.heading = config.alliance == .red ? Float.pi : 0
    }

    // MARK: - AI Decision Making

    /// Choose next goal based on strategy policy, match state, and role.
    func decideGoal(simTime: Double, policy: StrategyPolicy, rng: inout SeededRNG) {
        guard state == .idle || state == .driving else { return }

        let period = currentPeriod(simTime)

        // Endgame: head to barge if endgame weight is dominant or time is running out
        if period == .endgame || (policy.endgameWeight > 0.5 && simTime > MatchTiming.endgameStart - 10) {
            if !isParkedEndgame {
                let barge = config.alliance == .red ? FieldLayout.redBarge : FieldLayout.blueBarge
                targetPosition = barge
                state = .headingEndgame
                return
            }
        }

        // Defense: if defender role or defense weight is high
        if config.role == .defender && policy.defenseWeight > 0.3 {
            // Move toward opponent scoring area to block
            let blockTarget: SIMD2<Float>
            if config.alliance == .red {
                // Block blue robots near reef
                let offset = SIMD2<Float>(rng.nextFloat() * 0.6 - 0.3, rng.nextFloat() * 0.6 - 0.3)
                blockTarget = SIMD2(-0.3, 0) + offset
            } else {
                let offset = SIMD2<Float>(rng.nextFloat() * 0.6 - 0.3, rng.nextFloat() * 0.6 - 0.3)
                blockTarget = SIMD2(0.3, 0) + offset
            }
            targetPosition = blockTarget
            state = .defending
            return
        }

        // Scoring: pick up or deliver
        if hasPiece {
            // Go score at reef or processor
            let scoringTarget = chooseScoringTarget(rng: &rng)
            targetPosition = scoringTarget
            state = .driving
        } else {
            // Go pick up from source
            let source = config.alliance == .red ? FieldLayout.redSource : FieldLayout.blueSource
            let offset = SIMD2<Float>(rng.nextFloat() * 0.4 - 0.2, rng.nextFloat() * 0.8 - 0.4)
            targetPosition = source + offset
            state = .driving
        }
    }

    private func chooseScoringTarget(rng: inout SeededRNG) -> SIMD2<Float> {
        // Prefer reef nodes; sometimes go to processor for variety
        let useProcessor = rng.nextDouble() < 0.2
        if useProcessor {
            return config.alliance == .red ? FieldLayout.redProcessor : FieldLayout.blueProcessor
        }
        let nodeIndex = Int(rng.next() % UInt64(FieldLayout.reefNodes.count))
        return FieldLayout.reefNodes[nodeIndex]
    }

    private func currentPeriod(_ simTime: Double) -> MatchPeriod {
        if simTime < MatchTiming.teleopStart { return .auto }
        if simTime < MatchTiming.endgameStart { return .teleop }
        if simTime < MatchTiming.totalDuration { return .endgame }
        return .finished
    }

    // MARK: - Movement Update

    /// Move toward target, handling rotation and acceleration.
    func updateMovement(dt: Float) {
        guard let target = targetPosition else { return }

        let dx = target.x - position.x
        let dz = target.y - position.y  // y in SIMD2 = z in scene
        let distance = sqrt(dx * dx + dz * dz)

        // Arrived at target?
        if distance < 0.15 {
            speed = 0
            return
        }

        // Rotate toward target
        let targetHeading = atan2(dx, dz)
        var angleDiff = targetHeading - heading
        // Normalize to [-π, π]
        while angleDiff > Float.pi { angleDiff -= 2 * Float.pi }
        while angleDiff < -Float.pi { angleDiff += 2 * Float.pi }
        let turnAmount = min(abs(angleDiff), config.stats.turnRate * dt)
        heading += angleDiff > 0 ? turnAmount : -turnAmount

        // Accelerate toward max speed
        let targetSpeed = min(config.stats.maxSpeed, distance * 2) // slow down near target
        if speed < targetSpeed {
            speed = min(speed + config.stats.acceleration * dt, targetSpeed)
        } else {
            speed = max(speed - config.stats.acceleration * dt * 2, targetSpeed)
        }

        // Move forward
        let moveX = sin(heading) * speed * dt
        let moveZ = cos(heading) * speed * dt
        position.x += moveX
        position.y += moveZ

        // Clamp to field bounds
        position.x = max(-FieldLayout.halfWidth + 0.2, min(FieldLayout.halfWidth - 0.2, position.x))
        position.y = max(-FieldLayout.halfLength + 0.2, min(FieldLayout.halfLength - 0.2, position.y))
    }

    /// Check if robot has reached its current target.
    var hasReachedTarget: Bool {
        guard let target = targetPosition else { return false }
        let dx = target.x - position.x
        let dz = target.y - position.y
        return sqrt(dx * dx + dz * dz) < 0.2
    }

    // MARK: - Scene Sync

    /// Update the SceneKit node to match agent state.
    func syncToScene() {
        guard let node = sceneNode else { return }
        node.position = SCNVector3(position.x, 0.15, position.y)
        node.eulerAngles.y = heading
    }
}

// MARK: - Match Engine

/// Orchestrates a full 6-robot match simulation with game pieces, scoring, and strategy.
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
    var gamePieces: [GamePiece] = []
    var rng: SeededRNG
    private var updateTimer: Timer?
    private var calloutsUsed: [Callout] = []
    private var calloutsRemaining: Int = 3
    private var slowMoTimer: Double = 0
    private var slowMoUsed: Bool = false
    private var lastUpdateTime: Date?
    private var nextPieceId: Int = 100
    private var scene: SCNScene?
    private var pieceNodes: [Int: SCNNode] = [:]

    // Score node refs for pulse effects
    private var reefNodeTargets: [SCNNode] = []

    init(configs: [RobotConfig], strategy: AllianceStrategy, playerAuto: AutoPlan, seed: UInt64 = 42) {
        self.configs = configs
        self.playerAutoPlan = playerAuto
        self.redPolicy = strategy.basePolicy
        self.rng = SeededRNG(seed: seed)

        // Create agents
        for config in configs {
            agents.append(RobotAgent(config: config))
        }

        // Spawn initial game pieces at sources
        spawnPieces(count: 3, near: FieldLayout.redSource)
        spawnPieces(count: 3, near: FieldLayout.blueSource)
    }

    // MARK: - Scene Binding

    func attach(scene: SCNScene, robotNodes: [SCNNode], reefNodes: [SCNNode]) {
        self.scene = scene
        self.reefNodeTargets = reefNodes
        for (i, agent) in agents.enumerated() where i < robotNodes.count {
            agent.sceneNode = robotNodes[i]
            agent.syncToScene()
        }
        // Sync initial robot states
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
        speedMultiplier = 0.3
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
        let simDt = wallDt * speedMultiplier
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

        // Slow-mo countdown
        if isSlowMo {
            slowMoTimer -= wallDt
            if slowMoTimer <= 0 {
                deactivateSlowMo()
            }
        }

        let dt = Float(simDt)

        // Update each robot agent
        for agent in agents {
            updateAgent(agent, dt: dt, simDt: simDt)
        }

        // Resolve robot separation (prevent overlap)
        resolveSeparation()

        // Respawn pieces if sources are empty
        respawnPiecesIfNeeded()

        // Sync all to scene
        for agent in agents {
            agent.syncToScene()
            robotStates[agent.config.id] = agent.state
        }
    }

    // MARK: - Agent Update

    private func updateAgent(_ agent: RobotAgent, dt: Float, simDt: Double) {
        // Handle stall recovery
        if agent.isStalled {
            agent.stallTimer -= simDt
            if agent.stallTimer <= 0 {
                agent.isStalled = false
                agent.state = .idle
            }
            return
        }

        // Handle timed actions (pickup, scoring, endgame park)
        if agent.actionTimer > 0 {
            agent.actionTimer -= simDt
            if agent.actionTimer <= 0 {
                completeAction(agent)
            }
            return
        }

        let policy = agent.config.alliance == .red ? redPolicy : bluePolicy

        // Auto period: follow scripted path
        if period == .auto {
            runAutoRoutine(agent, dt: dt)
            return
        }

        // If idle or just driving with no goal, pick a new goal
        if agent.state == .idle || (agent.state == .driving && agent.hasReachedTarget) {
            agent.decideGoal(simTime: simTime, policy: policy, rng: &rng)
        }

        // Move toward target
        if agent.state == .driving || agent.state == .defending || agent.state == .headingEndgame {
            agent.updateMovement(dt: dt)

            // Check arrival
            if agent.hasReachedTarget {
                handleArrival(agent)
            }
        }
    }

    // MARK: - Auto Routine

    private func runAutoRoutine(_ agent: RobotAgent, dt: Float) {
        // Simple auto: move toward reef, score pieces
        if agent.state == .idle {
            agent.state = .autoPath

            // All robots drive toward center during auto
            let isPlayerBot = agent.config.id == 0
            let autoPlan = isPlayerBot ? playerAutoPlan : .moderate

            let reefTarget: SIMD2<Float>
            if agent.config.alliance == .red {
                reefTarget = SIMD2(0.6, Float(autoPlan.piecesAttempted - 2) * 0.4)
            } else {
                reefTarget = SIMD2(-0.6, Float(autoPlan.piecesAttempted - 2) * 0.4)
            }
            agent.targetPosition = reefTarget
            agent.hasPiece = true // pre-loaded for auto
        }

        agent.updateMovement(dt: dt)

        // Auto line check
        if !agent.hasCrossedAutoLine {
            let threshold: Float = agent.config.alliance == .red ? 1.5 : -1.5
            let crossed = agent.config.alliance == .red
                ? agent.position.x < threshold
                : agent.position.x > threshold
            if crossed {
                agent.hasCrossedAutoLine = true
                addScore(alliance: agent.config.alliance, points: ScoreValues.autoTaxi, isAuto: true)
            }
        }

        // Check arrival at scoring
        if agent.hasReachedTarget && agent.hasPiece {
            // Check stall during auto for player bot
            if agent.config.id == 0 {
                let roll = rng.nextDouble()
                if roll > playerAutoPlan.successRate {
                    triggerStall(agent, duration: 3.0)
                    return
                }
            }

            agent.state = .scoring
            agent.actionTimer = agent.config.stats.scoringTime
        }
    }

    // MARK: - Arrival Handling

    private func handleArrival(_ agent: RobotAgent) {
        if agent.state == .headingEndgame {
            agent.state = .parked
            agent.isParkedEndgame = true
            agent.actionTimer = 2.0
            return
        }

        if agent.state == .defending {
            // Stay in defense position, re-decide after a bit
            agent.state = .idle
            return
        }

        // At source: pick up piece
        if !agent.hasPiece && isNearSource(agent) {
            // Reliability check
            if rng.nextDouble() > agent.config.stats.reliability {
                triggerStall(agent, duration: 2.0)
                return
            }
            agent.state = .pickingUp
            agent.actionTimer = agent.config.stats.pickupTime
            return
        }

        // At scoring target: score piece
        if agent.hasPiece && isNearScoringTarget(agent) {
            if rng.nextDouble() > agent.config.stats.reliability {
                triggerStall(agent, duration: 2.0)
                return
            }
            agent.state = .scoring
            agent.actionTimer = agent.config.stats.scoringTime
            pulseNearestReefNode(to: agent.position)
            return
        }

        // Didn't match anything meaningful — re-decide
        agent.state = .idle
    }

    private func isNearSource(_ agent: RobotAgent) -> Bool {
        let source = agent.config.alliance == .red ? FieldLayout.redSource : FieldLayout.blueSource
        return distance2D(agent.position, source) < 0.8
    }

    private func isNearScoringTarget(_ agent: RobotAgent) -> Bool {
        // Near any reef node or processor
        for node in FieldLayout.reefNodes {
            if distance2D(agent.position, node) < 0.5 { return true }
        }
        let proc = agent.config.alliance == .red ? FieldLayout.redProcessor : FieldLayout.blueProcessor
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
                let points = isAuto ? ScoreValues.autoReefNode
                    : (isProcessor ? ScoreValues.processorScore : ScoreValues.teleopReefNode)
                addScore(alliance: agent.config.alliance, points: points, isAuto: isAuto, isProcessor: isProcessor)
            }
            agent.state = .idle

        case .parked:
            addScore(alliance: agent.config.alliance, points: ScoreValues.bargeClimb, isEndgame: true)
            agent.state = .parked // stay parked

        default:
            agent.state = .idle
        }
    }

    private func isNearProcessor(_ agent: RobotAgent) -> Bool {
        let proc = agent.config.alliance == .red ? FieldLayout.redProcessor : FieldLayout.blueProcessor
        return distance2D(agent.position, proc) < 0.5
    }

    // MARK: - Scoring

    private func addScore(alliance: Alliance, points: Int, isAuto: Bool = false, isProcessor: Bool = false, isEndgame: Bool = false) {
        if alliance == .red {
            redScore += points
            if isAuto { redBreakdown.autoPoints += points }
            else if isEndgame { redBreakdown.endgamePoints += points }
            else { redBreakdown.teleopPoints += points }
            redBreakdown.totalPieces += (isEndgame ? 0 : 1)
            if isProcessor { redBreakdown.processorPieces += 1 }
        } else {
            blueScore += points
            if isAuto { blueBreakdown.autoPoints += points }
            else if isEndgame { blueBreakdown.endgamePoints += points }
            else { blueBreakdown.teleopPoints += points }
            blueBreakdown.totalPieces += (isEndgame ? 0 : 1)
            if isProcessor { blueBreakdown.processorPieces += 1 }
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

                    // If a defender bumps an opponent, slow the opponent
                    if agents[i].config.role == .defender && agents[i].config.alliance != agents[j].config.alliance {
                        agents[j].speed *= 0.5
                    }
                    if agents[j].config.role == .defender && agents[j].config.alliance != agents[i].config.alliance {
                        agents[i].speed *= 0.5
                    }
                }
            }
        }
    }

    // MARK: - Piece Spawning

    private func spawnPieces(count: Int, near position: SIMD2<Float>) {
        for i in 0..<count {
            let offset = SIMD2<Float>(Float(i) * 0.25 - 0.25, Float(i % 2) * 0.3 - 0.15)
            let piece = GamePiece(id: nextPieceId, position: position + offset, state: .onField, carriedBy: nil)
            gamePieces.append(piece)
            nextPieceId += 1
        }
    }

    private func respawnPiecesIfNeeded() {
        // Periodically spawn pieces to keep the game flowing
        let redFieldCount = gamePieces.filter { $0.state == .onField && $0.position.x > 2.0 }.count
        let blueFieldCount = gamePieces.filter { $0.state == .onField && $0.position.x < -2.0 }.count
        if redFieldCount < 2 { spawnPieces(count: 2, near: FieldLayout.redSource) }
        if blueFieldCount < 2 { spawnPieces(count: 2, near: FieldLayout.blueSource) }
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
        // Generate a contextual tip based on current match state
        let tips: [() -> CoachingTip?] = [
            { [self] in
                // Tip about defense
                let defenders = agents.filter { $0.config.role == .defender && $0.state == .defending }
                guard let def = defenders.first else { return nil }
                let oppAlliance = def.config.alliance == .red ? "blue" : "red"
                return CoachingTip(
                    headline: "Defense in Action",
                    detail: "Notice how #\(def.config.teamNumber) is positioning near the reef to slow \(oppAlliance) alliance cycles. Defense doesn't score, but it prevents the other team from scoring.",
                    highlightRobotId: def.config.id
                )
            },
            { [self] in
                // Tip about scoring efficiency
                let scorers = agents.filter { $0.state == .scoring }
                guard let scorer = scorers.first else { return nil }
                return CoachingTip(
                    headline: "Scoring Cycle",
                    detail: "Team \(scorer.config.teamNumber) is at a reef node. Their scoring time is \(String(format: "%.1f", scorer.config.stats.scoringTime))s — faster scorers mean more cycles per match. That's why mechanism design matters!",
                    highlightRobotId: scorer.config.id
                )
            },
            { [self] in
                // Tip about strategy
                return CoachingTip(
                    headline: "Strategy Impact",
                    detail: "Your alliance is in \"\(strategyMode)\" mode. The strategy weights determine whether robots prioritize scoring, defense, or endgame setup. Try different callouts to see how it changes behavior!",
                    highlightRobotId: nil
                )
            },
            { [self] in
                // Tip about speed vs reliability
                let fastest = agents.max(by: { $0.config.stats.maxSpeed < $1.config.stats.maxSpeed })
                guard let f = fastest else { return nil }
                return CoachingTip(
                    headline: "Speed vs. Reliability",
                    detail: "Team \(f.config.teamNumber) has the highest speed (\(String(format: "%.1f", f.config.stats.maxSpeed)) m/s) but only \(Int(f.config.stats.reliability * 100))% reliability. Fast robots cover more ground but risk stalling.",
                    highlightRobotId: f.config.id
                )
            },
            { [self] in
                // Score comparison tip
                let diff = redScore - blueScore
                let comparison = diff > 0 ? "leading by \(diff)" : (diff < 0 ? "trailing by \(-diff)" : "tied")
                return CoachingTip(
                    headline: "Score Check",
                    detail: "Your red alliance is \(comparison) points. In FRC, matches are often decided in the final 30 seconds. Watch for endgame scoring opportunities!",
                    highlightRobotId: nil
                )
            },
        ]

        // Pick a relevant tip
        let shuffled = tips.shuffled()
        for tipGenerator in shuffled {
            if let tip = tipGenerator() {
                currentTip = tip
                return
            }
        }

        // Fallback
        currentTip = CoachingTip(
            headline: "Watch the Field",
            detail: "Pay attention to robot positioning. Teams that cycle efficiently and avoid traffic jams score more points.",
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

    // MARK: - Result Builder

    var result: MatchResult {
        let playerAgent = agents.first { $0.config.id == 0 }
        return MatchResult(
            playerStrategy: AllianceStrategy.allCases.first { $0.basePolicy.scoringWeight <= redPolicy.scoringWeight } ?? .balanced,
            playerRole: configs[0].role,
            playerAuto: playerAutoPlan,
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

    // MARK: - Helpers

    private func distance2D(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
        let d = a - b
        return sqrt(d.x * d.x + d.y * d.y)
    }
}
