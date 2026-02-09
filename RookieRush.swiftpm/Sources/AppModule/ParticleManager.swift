import SceneKit

// MARK: - Particle Manager
// Procedural SCNParticleSystem creation — no imported assets.
// Provides celebration, spark, and exhaust effects for the match simulation.

enum ParticleManager {

    // MARK: - Score Celebration

    /// Burst of bright particles when a game piece is scored successfully.
    static func scoreParticles(color: UIColor) -> SCNParticleSystem {
        let ps = SCNParticleSystem()
        ps.birthRate = 80
        ps.emissionDuration = 0.3
        ps.loops = false
        ps.particleLifeSpan = 0.8
        ps.particleLifeSpanVariation = 0.3
        ps.spreadingAngle = 45
        ps.emittingDirection = SCNVector3(0, 1, 0)
        ps.particleVelocity = 2.0
        ps.particleVelocityVariation = 1.0
        ps.acceleration = SCNVector3(0, -4.0, 0)  // gravity
        ps.particleSize = 0.015
        ps.particleSizeVariation = 0.008
        ps.particleColor = color
        ps.particleColorVariation = SCNVector4(0.1, 0.1, 0.1, 0)
        ps.blendMode = .additive
        ps.isAffectedByGravity = false  // We use acceleration instead
        ps.isAffectedByPhysicsFields = false
        return ps
    }

    /// Smaller confetti burst for high-level scores (L3-L4).
    static func highScoreParticles(alliance: UIColor) -> SCNParticleSystem {
        let ps = SCNParticleSystem()
        ps.birthRate = 150
        ps.emissionDuration = 0.4
        ps.loops = false
        ps.particleLifeSpan = 1.2
        ps.particleLifeSpanVariation = 0.4
        ps.spreadingAngle = 60
        ps.emittingDirection = SCNVector3(0, 1, 0)
        ps.particleVelocity = 3.0
        ps.particleVelocityVariation = 1.5
        ps.acceleration = SCNVector3(0, -3.0, 0)
        ps.particleSize = 0.012
        ps.particleSizeVariation = 0.006
        ps.particleColor = alliance
        ps.particleColorVariation = SCNVector4(0.15, 0.15, 0.1, 0)
        ps.blendMode = .additive
        return ps
    }

    // MARK: - Collision Sparks

    /// Quick spark burst when two robots collide.
    static func collisionSparks() -> SCNParticleSystem {
        let ps = SCNParticleSystem()
        ps.birthRate = 40
        ps.emissionDuration = 0.1
        ps.loops = false
        ps.particleLifeSpan = 0.3
        ps.particleLifeSpanVariation = 0.15
        ps.spreadingAngle = 90
        ps.emittingDirection = SCNVector3(0, 0.5, 0)
        ps.particleVelocity = 1.5
        ps.particleVelocityVariation = 0.8
        ps.acceleration = SCNVector3(0, -5.0, 0)
        ps.particleSize = 0.008
        ps.particleSizeVariation = 0.004
        ps.particleColor = UIColor(red: 1.0, green: 0.8, blue: 0.3, alpha: 1)
        ps.particleColorVariation = SCNVector4(0.1, 0.2, 0.3, 0)
        ps.blendMode = .additive
        return ps
    }

    // MARK: - Climb Effect

    /// Upward shimmer when a robot parks/climbs.
    static func climbParticles(color: UIColor) -> SCNParticleSystem {
        let ps = SCNParticleSystem()
        ps.birthRate = 30
        ps.emissionDuration = 2.0
        ps.loops = false
        ps.particleLifeSpan = 1.0
        ps.particleLifeSpanVariation = 0.3
        ps.spreadingAngle = 15
        ps.emittingDirection = SCNVector3(0, 1, 0)
        ps.particleVelocity = 0.8
        ps.particleVelocityVariation = 0.3
        ps.particleSize = 0.01
        ps.particleSizeVariation = 0.005
        ps.particleColor = color.withAlphaComponent(0.7)
        ps.blendMode = .additive
        return ps
    }

    // MARK: - Stall Smoke

    /// Puff of smoke when a robot stalls.
    static func stallSmoke() -> SCNParticleSystem {
        let ps = SCNParticleSystem()
        ps.birthRate = 25
        ps.emissionDuration = 0.8
        ps.loops = false
        ps.particleLifeSpan = 1.5
        ps.particleLifeSpanVariation = 0.5
        ps.spreadingAngle = 30
        ps.emittingDirection = SCNVector3(0, 1, 0)
        ps.particleVelocity = 0.4
        ps.particleVelocityVariation = 0.2
        ps.particleSize = 0.03
        ps.particleSizeVariation = 0.015
        ps.particleColor = UIColor(white: 0.5, alpha: 0.4)
        ps.blendMode = .alpha
        return ps
    }

    // MARK: - Match Start Flash

    /// Brief flash at match start.
    static func matchStartFlash() -> SCNParticleSystem {
        let ps = SCNParticleSystem()
        ps.birthRate = 200
        ps.emissionDuration = 0.2
        ps.loops = false
        ps.particleLifeSpan = 0.6
        ps.particleLifeSpanVariation = 0.3
        ps.spreadingAngle = 180
        ps.particleVelocity = 4.0
        ps.particleVelocityVariation = 2.0
        ps.acceleration = SCNVector3(0, -2, 0)
        ps.particleSize = 0.02
        ps.particleSizeVariation = 0.01
        ps.particleColor = UIColor(red: 1.0, green: 0.9, blue: 0.6, alpha: 1.0)
        ps.blendMode = .additive
        return ps
    }

    // MARK: - Spawn Helper

    /// Attach a particle system at a world position, auto-remove after completion.
    @discardableResult
    static func emit(_ system: SCNParticleSystem, at position: SCNVector3, in scene: SCNScene) -> SCNNode {
        let node = SCNNode()
        node.position = position
        node.addParticleSystem(system)
        scene.rootNode.addChildNode(node)

        let lifetime = system.emissionDuration + system.particleLifeSpan + system.particleLifeSpanVariation
        DispatchQueue.main.asyncAfter(deadline: .now() + lifetime + 0.5) {
            node.removeFromParentNode()
        }
        return node
    }
}
