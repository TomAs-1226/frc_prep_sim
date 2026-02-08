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

    // MARK: - Robot Materials

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
        m.diffuse.contents = UIColor(white: 0.15, alpha: 1)
        m.roughness.contents = NSNumber(value: 0.9)
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
}
