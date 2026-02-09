import Foundation
import SwiftUI

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - AI Coach

/// Provides coaching feedback using Apple's on-device Foundation Models (iOS 26+).
/// Falls back to comprehensive rule-based feedback when the model is unavailable.
/// Updated for procedural game system with build-match analysis.
@MainActor
final class AICoach: ObservableObject {
    @Published var coachingText: String = ""
    @Published var isGenerating: Bool = false
    @Published var isAIAvailable: Bool = false

    init() {
        checkAvailability()
    }

    // MARK: - Availability Check

    func checkAvailability() {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                isAIAvailable = true
            default:
                isAIAvailable = false
            }
        }
        #endif
    }

    func prewarm() {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), isAIAvailable {
            Task {
                let session = LanguageModelSession()
                session.prewarm()
            }
        }
        #endif
    }

    // MARK: - Generate Feedback (Match-Level)

    func generateFeedback(for result: MatchResult) async {
        isGenerating = true
        defer { isGenerating = false }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), isAIAvailable {
            do {
                let text = try await generateAIFeedback(for: result)
                coachingText = text
                return
            } catch {
                // Fall through to rule-based
            }
        }
        #endif

        coachingText = generateRuleBasedFeedback(for: result)
    }

    // MARK: - Foundation Models AI Generation (iOS 26+)

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func generateAIFeedback(for result: MatchResult) async throws -> String {
        let session = LanguageModelSession(
            instructions: """
            You are a friendly, encouraging FRC mentor \
            coaching a brand-new rookie student. They just ran a match simulation \
            in an educational app called "Rookie Workshop" that generates procedural \
            FRC-style games and teaches students to build robots that match each game. \
            \
            Give a 3-4 sentence response that: \
            1. Comments on how well their robot build fit the generated game (build match score). \
            2. Highlights one part selection that worked well or one that could improve. \
            3. Gives one specific, actionable suggestion for their next game. \
            \
            Be warm but concise. Use simple language. \
            Don't use jargon without briefly explaining it. \
            Frame losses as learning opportunities.
            """
        )

        let prompt = buildPrompt(for: result)
        let response = try await session.respond(to: prompt)
        return response.content
    }
    #endif

    // MARK: - Prompt Builder

    private func buildPrompt(for result: MatchResult) -> String {
        let outcome = result.playerWon ? "won by \(result.margin) points" :
            (result.margin == 0 ? "tied" : "lost by \(result.margin) points")
        let stallNote = result.didPlayerStall
            ? "Their robot stalled during the match."
            : "Their robot ran smoothly without stalling."
        let calloutNote = result.calloutsUsed.isEmpty
            ? "They didn't use any mid-match callouts."
            : "They used these callouts: \(result.calloutsUsed.map { $0.rawValue }.joined(separator: ", "))."

        let game = result.game
        let build = result.playerBuild
        let pieces = game.gamePieces.map(\.rawValue).joined(separator: ", ")
        let heights = Array(Set(game.scoringZones.map(\.height.displayName))).sorted()
        let endgame = game.endgameChallenge.displayName

        let buildNote = "They built a \(build.drivetrain.shortLabel) drive robot " +
            "with a \(build.frame.shortLabel) frame, " +
            "\(build.manipulator.shortLabel) manipulator (max reach: \(build.manipulator.maxReach.displayName)), " +
            "and \(build.intake.shortLabel) intake."

        return """
        PROCEDURAL GAME: "\(game.name)" (archetype: \(game.archetype.rawValue))
        - Game pieces: \(pieces)
        - Scoring heights: \(heights.joined(separator: ", "))
        - Endgame challenge: \(endgame)
        - Challenge hints: \(game.challengeHints.joined(separator: "; "))

        BUILD MATCH SCORE: \(result.buildMatchScore)/100

        The student chose "\(result.playerStrategy.rawValue)" alliance strategy, \
        "\(result.playerRole.rawValue)" robot role, and "\(result.playerAuto.rawValue)" auto routine.
        \(buildNote)

        Match results:
        - Red alliance (player's team) \(outcome)
        - Red score: \(result.redScore) (Auto: \(result.redBreakdown.autoPoints), \
        Teleop: \(result.redBreakdown.teleopPoints), Endgame: \(result.redBreakdown.endgamePoints))
        - Blue score: \(result.blueScore) (Auto: \(result.blueBreakdown.autoPoints), \
        Teleop: \(result.blueBreakdown.teleopPoints), Endgame: \(result.blueBreakdown.endgamePoints))
        - Scoring breakdown: Ground=\(result.redBreakdown.groundScores), Low=\(result.redBreakdown.lowScores), \
        Mid=\(result.redBreakdown.midScores), High=\(result.redBreakdown.highScores)
        - Player's robot scored \(result.playerRobotScored) pieces and completed \(result.playerRobotCycled) cycles
        - \(stallNote)
        - \(calloutNote)
        - \(result.slowMoUsed ? "They used the slow-mo coaching feature." : "They didn't use slow-mo coaching.")

        What coaching feedback would you give about their build choices and match performance?
        """
    }

    // MARK: - Rule-Based Fallback

    func generateRuleBasedFeedback(for result: MatchResult) -> String {
        var lines: [String] = []
        let game = result.game
        let build = result.playerBuild

        // Build match score summary
        if result.buildMatchScore >= 75 {
            lines.append("Great job matching your robot to \"\(game.name)\"! Your build scored \(result.buildMatchScore)/100 on the build match -- your parts were well-suited to this \(game.archetype.rawValue) game.")
        } else if result.buildMatchScore >= 50 {
            lines.append("Your build was a decent fit for \"\(game.name)\" (\(result.buildMatchScore)/100 match score), but there's room to improve. Analyzing the game carefully before building is the key to FRC success.")
        } else {
            lines.append("Your build didn't match \"\(game.name)\" very well (\(result.buildMatchScore)/100 match score). Don't worry -- learning to analyze a game and pick the right parts is the core FRC skill, and every round teaches you something new!")
        }

        // Manipulator reach analysis
        let maxZone = game.maxScoringHeight
        let maxReach = build.manipulator.maxReach
        if maxReach < maxZone {
            lines.append("Your \(build.manipulator.shortLabel) only reaches \(maxReach.displayName), but this game had \(maxZone.displayName) scoring zones worth big points. A taller manipulator like an elevator would unlock those high-value targets.")
        } else if maxReach == maxZone {
            lines.append("Your \(build.manipulator.shortLabel) perfectly matched the game's tallest scoring zones (\(maxZone.displayName)). Smart analysis!")
        } else {
            lines.append("Your \(build.manipulator.shortLabel) can reach \(maxReach.displayName), which exceeds what this game needed (\(maxZone.displayName)). A simpler, faster mechanism could have been more efficient.")
        }

        // Intake vs game pieces
        let idealIntakes = Set(game.gamePieces.map(\.idealIntake))
        if idealIntakes.contains(build.intake) {
            lines.append("Good intake choice! Your \(build.intake.shortLabel) works well with the \(game.gamePieces.map(\.rawValue).joined(separator: "/")) game pieces in this game.")
        } else {
            let suggestions = idealIntakes.map(\.shortLabel).joined(separator: " or ")
            lines.append("Your \(build.intake.shortLabel) wasn't ideal for the \(game.gamePieces.map(\.rawValue).joined(separator: "/")) pieces in this game. Try \(suggestions) next time for better pickup performance.")
        }

        // Endgame analysis
        switch game.endgameChallenge {
        case .climb(let difficulty, _):
            if difficulty == .high && !build.drivetrain.canDeepClimb {
                lines.append("The high climb was tough for your \(build.drivetrain.shortLabel) drive. Tank drive's deep climb ability is a big advantage for high climb endgame challenges.")
            } else if difficulty == .high && build.drivetrain.canDeepClimb {
                lines.append("Smart drivetrain pick! Tank drive's deep climb handled the high climb challenge perfectly.")
            }
        case .balance:
            if build.drivetrain.canStrafe {
                lines.append("Your \(build.drivetrain.shortLabel) can strafe, which is great for the balance endgame challenge. Precise positioning really matters.")
            } else {
                lines.append("The balance challenge rewards strafing ability. Swerve or Mecanum drives would give you better precision for balancing.")
            }
        case .park:
            break
        }

        // Frame analysis
        if game.archetype == .speed && build.frame.speedModifier < 0 {
            lines.append("For a speed-focused game, a lighter frame would help your robot cycle faster. The \(build.frame.shortLabel) frame slowed you down.")
        } else if (game.archetype == .power || game.archetype == .defenseArena) && build.frame.reliabilityModifier > 0 {
            lines.append("Good frame choice for a power-focused game! The \(build.frame.shortLabel) frame's durability helps in physical matches.")
        } else if game.archetype == .endgameFocus {
            lines.append("In Endgame Focus games, the endgame challenge is worth \(game.endgameChallenge.points) points -- plan your entire build around getting there reliably.")
        } else if game.archetype == .hybrid {
            lines.append("Hybrid Challenge games reward versatility. A mechanism that can handle multiple scoring heights gives you an edge.")
        } else if game.archetype == .defenseArena {
            lines.append("Defense Arena is all about pushing power and durability. Tank drive with a steel frame is king here.")
        }

        // Match outcome
        if result.playerWon && result.margin > 15 {
            lines.append("Dominant victory at \(result.redScore)-\(result.blueScore)! Your strategy and build came together perfectly for this game.")
        } else if result.playerWon {
            lines.append("Nice win at \(result.redScore)-\(result.blueScore)! A \(result.margin)-point margin shows your choices worked. Try to widen the gap next time.")
        } else if result.margin == 0 {
            lines.append("A tie at \(result.redScore)-\(result.blueScore)! One more score or a better endgame could tip it your way.")
        } else if result.margin < 10 {
            lines.append("Close loss at \(result.redScore)-\(result.blueScore). Just \(result.margin) points -- a better build match or one more callout could flip this.")
        } else {
            lines.append("Tough loss at \(result.redScore)-\(result.blueScore). Focus on the build match score -- improving part selection will make the biggest difference.")
        }

        // Stall feedback
        if result.didPlayerStall {
            lines.append("Your robot stalled during auto. In FRC, reliability beats everything. Try a safer auto routine -- consistent points beat risky zeros.")
        }

        // Callout feedback
        if result.calloutsUsed.isEmpty {
            lines.append("Tip: Try using callouts during the match! They let you adapt your alliance's strategy mid-game -- a key skill for real FRC drive coaches.")
        } else {
            lines.append("Good use of callouts (\(result.calloutsUsed.count) used)! Adapting mid-match is what separates great FRC drive coaches from good ones.")
        }

        return lines.joined(separator: "\n\n")
    }
}
