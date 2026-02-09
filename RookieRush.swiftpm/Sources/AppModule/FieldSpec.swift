import Foundation
import SceneKit

// MARK: - Shared Materials

/// Pre-built SceneKit materials for consistent low-poly aesthetic across the procedural field.
enum FieldMaterials {

    // MARK: - Floor & Walls

    static func floor(theme: FieldTheme) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = theme.floorColor
        m.roughness.contents = NSNumber(value: 0.8)
        m.lightingModel = .physicallyBased
        return m
    }

    static let wall: SCNMaterial = {
        let m = SCNMaterial(); m.diffuse.contents = UIColor(white: 0.55, alpha: 1); return m
    }()

    static func allianceWall(_ alliance: Alliance) -> SCNMaterial {
        let m = SCNMaterial(); m.diffuse.contents = alliance.uiColor.withAlphaComponent(0.5); return m
    }

    // MARK: - Scoring Zone Materials

    static func targetBase(_ height: ScoringHeight) -> SCNMaterial {
        let m = SCNMaterial()
        switch height {
        case .ground: m.diffuse.contents = UIColor(red: 0.3, green: 0.6, blue: 0.3, alpha: 1)
        case .low:    m.diffuse.contents = UIColor(red: 0.2, green: 0.6, blue: 0.7, alpha: 1)
        case .mid:    m.diffuse.contents = UIColor(red: 0.8, green: 0.7, blue: 0.2, alpha: 1)
        case .high:   m.diffuse.contents = UIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1)
        }
        m.roughness.contents = NSNumber(value: 0.6)
        m.lightingModel = .physicallyBased
        return m
    }

    static func targetGoal(_ alliance: Alliance) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = alliance.uiColor.withAlphaComponent(0.8)
        m.emission.contents = alliance.uiColor.withAlphaComponent(0.15)
        m.roughness.contents = NSNumber(value: 0.4)
        m.lightingModel = .physicallyBased
        return m
    }

    // MARK: - Obstacle Materials

    static let bridge: SCNMaterial = {
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(white: 0.35, alpha: 1)
        m.roughness.contents = NSNumber(value: 0.7)
        m.lightingModel = .physicallyBased
        return m
    }()

    static let barrier: SCNMaterial = {
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(red: 0.5, green: 0.35, blue: 0.2, alpha: 1)
        m.roughness.contents = NSNumber(value: 0.8)
        m.lightingModel = .physicallyBased
        return m
    }()

    static let rampMat: SCNMaterial = {
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(white: 0.45, alpha: 1)
        m.roughness.contents = NSNumber(value: 0.5)
        m.lightingModel = .physicallyBased
        return m
    }()

    // MARK: - Robot Materials — Core

    static let chassis: SCNMaterial = {
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(white: 0.22, alpha: 1)
        m.metalness.contents = NSNumber(value: 0.4)
        m.roughness.contents = NSNumber(value: 0.6)
        m.lightingModel = .physicallyBased
        return m
    }()

    static func bumper(_ alliance: Alliance) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = alliance.uiColor.withAlphaComponent(0.9)
        m.roughness.contents = NSNumber(value: 0.7)
        m.lightingModel = .physicallyBased
        return m
    }

    static let wheel: SCNMaterial = {
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(white: 0.12, alpha: 1)
        m.roughness.contents = NSNumber(value: 0.92)
        return m
    }()

    static let metal: SCNMaterial = {
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(white: 0.5, alpha: 1)
        m.metalness.contents = NSNumber(value: 0.6)
        m.roughness.contents = NSNumber(value: 0.4)
        m.lightingModel = .physicallyBased
        return m
    }()

    static let teal: SCNMaterial = {
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(red: 0.1, green: 0.7, blue: 0.6, alpha: 1)
        return m
    }()

    // MARK: - Robot Materials — Enhanced Frame Parts

    /// Aluminum tube frame rails (lighter, slightly reflective)
    static let frameTube: SCNMaterial = {
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(white: 0.58, alpha: 1)
        m.metalness.contents = NSNumber(value: 0.55)
        m.roughness.contents = NSNumber(value: 0.35)
        m.lightingModel = .physicallyBased
        return m
    }()

    /// Bellypan — dark aluminum sheet
    static let bellypan: SCNMaterial = {
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(white: 0.18, alpha: 1)
        m.metalness.contents = NSNumber(value: 0.3)
        m.roughness.contents = NSNumber(value: 0.7)
        m.lightingModel = .physicallyBased
        return m
    }()

    /// Electronics board (dark green PCB)
    static let electronics: SCNMaterial = {
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(red: 0.08, green: 0.28, blue: 0.12, alpha: 1)
        m.roughness.contents = NSNumber(value: 0.8)
        m.lightingModel = .physicallyBased
        return m
    }()

    /// Battery box (dark blue/black)
    static let battery: SCNMaterial = {
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(red: 0.10, green: 0.10, blue: 0.20, alpha: 1)
        m.roughness.contents = NSNumber(value: 0.6)
        m.lightingModel = .physicallyBased
        return m
    }()

    /// Chain/belt — black rubber-like
    static let chain: SCNMaterial = {
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(white: 0.08, alpha: 1)
        m.roughness.contents = NSNumber(value: 0.95)
        return m
    }()

    /// Gusset plates — lighter aluminum
    static let gusset: SCNMaterial = {
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(white: 0.62, alpha: 1)
        m.metalness.contents = NSNumber(value: 0.5)
        m.roughness.contents = NSNumber(value: 0.3)
        m.lightingModel = .physicallyBased
        return m
    }()

    /// Polycarbonate — translucent plastic
    static let polycarbonate: SCNMaterial = {
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(white: 0.7, alpha: 0.4)
        m.transparency = 0.6
        m.roughness.contents = NSNumber(value: 0.2)
        m.lightingModel = .physicallyBased
        return m
    }()

    /// Motor housing — dark with slight sheen
    static let motorHousing: SCNMaterial = {
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(white: 0.18, alpha: 1)
        m.metalness.contents = NSNumber(value: 0.35)
        m.roughness.contents = NSNumber(value: 0.55)
        m.lightingModel = .physicallyBased
        return m
    }()

    /// Bearing block — shiny steel
    static let bearing: SCNMaterial = {
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(white: 0.65, alpha: 1)
        m.metalness.contents = NSNumber(value: 0.7)
        m.roughness.contents = NSNumber(value: 0.25)
        m.lightingModel = .physicallyBased
        return m
    }()

    /// Flywheel green accent
    static let flywheel: SCNMaterial = {
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(red: 0.15, green: 0.75, blue: 0.2, alpha: 1)
        m.roughness.contents = NSNumber(value: 0.5)
        m.lightingModel = .physicallyBased
        return m
    }()

    /// Steel frame — darker, heavier looking
    static let steelFrame: SCNMaterial = {
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(white: 0.35, alpha: 1)
        m.metalness.contents = NSNumber(value: 0.65)
        m.roughness.contents = NSNumber(value: 0.45)
        m.lightingModel = .physicallyBased
        return m
    }()

    /// Composite frame — carbon fiber look
    static let compositeFrame: SCNMaterial = {
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(white: 0.15, alpha: 1)
        m.metalness.contents = NSNumber(value: 0.2)
        m.roughness.contents = NSNumber(value: 0.3)
        m.lightingModel = .physicallyBased
        return m
    }()

    /// Bumper fabric — slightly soft looking
    static func bumperFabric(_ alliance: Alliance) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = alliance.uiColor.withAlphaComponent(0.85)
        m.roughness.contents = NSNumber(value: 0.85)
        m.lightingModel = .physicallyBased
        return m
    }

    /// Pool noodle core for bumper
    static let bumperFoam: SCNMaterial = {
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(white: 0.75, alpha: 1)
        m.roughness.contents = NSNumber(value: 0.95)
        return m
    }()

    // MARK: - Particle Materials

    /// Bright scoring flash
    static func scoreParticle(_ alliance: Alliance) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = alliance.uiColor
        m.emission.contents = alliance.uiColor.withAlphaComponent(0.6)
        return m
    }

    /// Dust/spark material
    static let dustParticle: SCNMaterial = {
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(white: 0.7, alpha: 0.5)
        return m
    }()

    // MARK: - Game Pieces

    static func gamePiece(_ kind: GamePieceKind) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = kind.uiColor
        m.roughness.contents = NSNumber(value: 0.5)
        m.lightingModel = .physicallyBased
        return m
    }

    // MARK: - Endgame Materials

    static let climbBar: SCNMaterial = {
        let m = SCNMaterial()
        m.diffuse.contents = UIColor.systemYellow.withAlphaComponent(0.8)
        m.metalness.contents = NSNumber(value: 0.5)
        m.roughness.contents = NSNumber(value: 0.4)
        m.lightingModel = .physicallyBased
        return m
    }()

    static let balancePlatform: SCNMaterial = {
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(red: 0.3, green: 0.3, blue: 0.5, alpha: 1)
        m.roughness.contents = NSNumber(value: 0.5)
        m.lightingModel = .physicallyBased
        return m
    }()

    static func parkZone(_ alliance: Alliance) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = alliance.uiColor.withAlphaComponent(0.25)
        return m
    }

    static func zoneRing(_ height: ScoringHeight) -> SCNMaterial {
        let m = SCNMaterial()
        let uiColor: UIColor
        switch height {
        case .ground: uiColor = .systemGreen
        case .low:    uiColor = .systemCyan
        case .mid:    uiColor = .systemYellow
        case .high:   uiColor = .systemRed
        }
        m.diffuse.contents = uiColor.withAlphaComponent(0.25)
        m.emission.contents = uiColor.withAlphaComponent(0.08)
        return m
    }

    static func pickupStation(_ alliance: Alliance) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = alliance.uiColor.withAlphaComponent(0.3)
        return m
    }

    /// Frame material based on frame choice
    static func frameForChoice(_ frame: FrameChoice) -> SCNMaterial {
        switch frame {
        case .aluminum:  return frameTube
        case .steel:     return steelFrame
        case .composite: return compositeFrame
        }
    }
}
