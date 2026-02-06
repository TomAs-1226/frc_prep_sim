import Foundation
import SceneKit
import Combine

// MARK: - Simulation Engine

/// Drives the robot through waypoints in the SceneKit scene,
/// applying stats from the chosen archetype and auto plan.
@MainActor
final class SimulationEngine: ObservableObject {

    // MARK: Published State
    @Published var activity: RobotActivity = .idle
    @Published var currentPoints: Int = 0
    @Published var nodesScored: Int = 0
    @Published var elapsedTime: Double = 0
    @Published var statusMessage: String = "Preparing..."
    @Published var isRunning: Bool = false
    @Published var isFinished: Bool = false
    @Published var didStall: Bool = false

    // MARK: Configuration
    let archetype: RobotArchetype
    let stats: RobotStats
    let plan: AutoPlan
    let matchDuration: Double = 30.0 // compressed match time in real seconds
    let speedMultiplier: Double

    // MARK: Scene References
    private var robotNode: SCNNode?
    private var nodeTargets: [SCNNode] = []
    private var scene: SCNScene?

    // MARK: Internal
    private var rng: SeededRandomGenerator
    private var currentWaypointIndex: Int = 0
    private var waypointTimer: Timer?
    private var matchTimer: Timer?
    private var actionTimer: Timer?
    private var startTime: Date?
    private let totalNodesInPlan: Int
    private var taxiEarned: Bool = false

    init(archetype: RobotArchetype, autoPlanType: AutoPlanType, seed: UInt64 = 42, speedMultiplier: Double = 2.0) {
        self.archetype = archetype
        self.stats = archetype.stats
        self.plan = buildAutoPlan(for: autoPlanType)
        self.rng = SeededRandomGenerator(seed: seed)
        self.speedMultiplier = speedMultiplier
        self.totalNodesInPlan = plan.waypoints.filter { $0.action == .score }.count
    }

    // MARK: - Attach Scene

    /// Connect the engine to the SceneKit scene after it's built.
    func attach(scene: SCNScene, robotNode: SCNNode, nodeTargets: [SCNNode]) {
        self.scene = scene
        self.robotNode = robotNode
        self.nodeTargets = nodeTargets

        // Place robot at start position
        robotNode.position = SCNVector3(-2.5, 0.15, 0.0)
        robotNode.eulerAngles.y = 0
    }

    // MARK: - Run Simulation

    func start() {
        guard !isRunning else { return }
        isRunning = true
        isFinished = false
        activity = .driving
        currentPoints = 0
        nodesScored = 0
        elapsedTime = 0
        didStall = false
        currentWaypointIndex = 0
        taxiEarned = false
        statusMessage = "Auto starting..."
        startTime = Date()

        // Start match clock
        matchTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateClock()
            }
        }

        // Begin waypoint sequence
        driveToNextWaypoint()
    }

    func stop() {
        isRunning = false
        waypointTimer?.invalidate()
        matchTimer?.invalidate()
        actionTimer?.invalidate()
    }

    // MARK: - Clock

    private func updateClock() {
        guard let startTime else { return }
        elapsedTime = Date().timeIntervalSince(startTime) * speedMultiplier
        if elapsedTime >= matchDuration {
            finishMatch()
        }
    }

    // MARK: - Waypoint Navigation

    private func driveToNextWaypoint() {
        guard isRunning,
              currentWaypointIndex < plan.waypoints.count else {
            finishMatch()
            return
        }

        // Check time
        if elapsedTime >= matchDuration {
            finishMatch()
            return
        }

        let waypoint = plan.waypoints[currentWaypointIndex]
        activity = .driving
        statusMessage = waypoint.label

        guard let robotNode else { return }

        // Calculate movement
        let targetPos = SCNVector3(waypoint.position.x, 0.15, waypoint.position.y)
        let currentPos = robotNode.position
        let dx = targetPos.x - currentPos.x
        let dz = targetPos.z - currentPos.z
        let distance = sqrt(dx * dx + dz * dz)

        // Time to travel based on robot speed (adjusted for sim speed)
        let travelTime = Double(distance) / stats.maxSpeed / speedMultiplier

        // Calculate facing angle
        let targetAngle = atan2(dx, dz)

        // Animate rotation then translation
        let rotateAction = SCNAction.rotateTo(
            x: 0,
            y: CGFloat(targetAngle),
            z: 0,
            duration: 0.2 / speedMultiplier,
            usesShortestUnitArc: true
        )
        let moveAction = SCNAction.move(to: targetPos, duration: max(0.1, travelTime))
        moveAction.timingMode = .easeInEaseOut

        let sequence = SCNAction.sequence([rotateAction, moveAction])

        robotNode.runAction(sequence) { [weak self] in
            Task { @MainActor in
                self?.arrivedAtWaypoint()
            }
        }

        // Award taxi points when leaving start zone
        if !taxiEarned && waypoint.position.x > -2.0 {
            taxiEarned = true
            currentPoints += 2
        }
    }

    private func arrivedAtWaypoint() {
        guard isRunning, currentWaypointIndex < plan.waypoints.count else {
            finishMatch()
            return
        }

        let waypoint = plan.waypoints[currentWaypointIndex]

        // Check for stall (reliability failure)
        let rollValue = rng.nextDouble()
        let failThreshold = plan.failureChance * (1.0 - stats.reliability)
        if rollValue < failThreshold {
            triggerStall()
            return
        }

        switch waypoint.action {
        case .drive:
            currentWaypointIndex += 1
            driveToNextWaypoint()

        case .pickup:
            activity = .pickingUp
            statusMessage = "Picking up game piece..."
            let pickupDuration = stats.pickupTime / speedMultiplier
            actionTimer = Timer.scheduledTimer(withTimeInterval: pickupDuration, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.currentWaypointIndex += 1
                    self?.driveToNextWaypoint()
                }
            }

        case .score:
            activity = .scoring
            statusMessage = "Scoring at node!"
            let scoreDuration = stats.scoringTime / speedMultiplier

            // Visual feedback: pulse the nearest node target
            pulseNearestNode()

            actionTimer = Timer.scheduledTimer(withTimeInterval: scoreDuration, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.currentPoints += 5
                    self.nodesScored += 1
                    self.currentWaypointIndex += 1
                    self.driveToNextWaypoint()
                }
            }
        }
    }

    // MARK: - Stall

    private func triggerStall() {
        didStall = true
        activity = .stalled
        statusMessage = "Robot stalled! Recovering..."

        // Stall for 3 sim-seconds
        let stallDuration = 3.0 / speedMultiplier
        actionTimer = Timer.scheduledTimer(withTimeInterval: stallDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.activity = .driving
                self.statusMessage = "Recovered — continuing..."
                self.currentWaypointIndex += 1
                self.driveToNextWaypoint()
            }
        }
    }

    // MARK: - Visual Feedback

    private func pulseNearestNode() {
        guard let robotNode else { return }
        let robotPos = robotNode.position

        // Find closest node target
        var closestNode: SCNNode?
        var closestDist: Float = .greatestFiniteMagnitude
        for node in nodeTargets {
            let dx = node.position.x - robotPos.x
            let dz = node.position.z - robotPos.z
            let dist = sqrt(dx * dx + dz * dz)
            if dist < closestDist {
                closestDist = dist
                closestNode = node
            }
        }

        guard let target = closestNode else { return }

        // Pulse: scale up, glow, then return
        let pulseUp = SCNAction.scale(to: 1.4, duration: 0.15)
        let pulseDown = SCNAction.scale(to: 1.0, duration: 0.3)
        pulseDown.timingMode = .easeOut
        target.runAction(SCNAction.sequence([pulseUp, pulseDown]))

        // Brief color flash
        if let material = target.geometry?.firstMaterial {
            let originalColor = material.diffuse.contents
            material.emission.contents = UIColor.yellow
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                material.emission.contents = UIColor.black
                _ = originalColor // keep reference alive
            }
        }
    }

    // MARK: - Finish

    private func finishMatch() {
        guard isRunning else { return }
        stop()
        activity = .finished
        isFinished = true
        statusMessage = "Match complete!"
    }

    /// Build the final result for the results screen.
    var result: SimulationResult {
        SimulationResult(
            archetype: archetype,
            autoPlan: plan.type,
            totalPoints: currentPoints,
            nodesScored: nodesScored,
            totalNodes: totalNodesInPlan,
            didStall: didStall,
            timeUsed: min(elapsedTime, matchDuration),
            totalTime: matchDuration
        )
    }
}
