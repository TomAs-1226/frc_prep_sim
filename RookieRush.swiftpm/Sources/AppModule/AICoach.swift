import Foundation
import SwiftUI

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - AI Coach

/// Provides coaching feedback using Apple's on-device Foundation Models (iOS 26+).
/// Falls back to comprehensive rule-based feedback when the model is unavailable.
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
            coaching a brand-new rookie student. They just ran a 6-robot match simulation \
            in an educational app called "Match Coach" inspired by FRC Reefscape. \
            \
            Give a 3-4 sentence response that: \
            1. Comments on their strategy choices and the match outcome. \
            2. Highlights one thing that worked well. \
            3. Gives one specific, actionable suggestion for their next match. \
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
        let buildNote = "They built a \(result.playerBuild.drivetrain.shortLabel) drive robot " +
            "with a \(result.playerBuild.mechanism.shortLabel) mechanism (max L\(result.playerBuild.mechanism.maxLevel)) " +
            "and \(result.playerBuild.intake.shortLabel) intake."

        return """
        The student chose "\(result.playerStrategy.rawValue)" alliance strategy, \
        "\(result.playerRole.rawValue)" robot role, and "\(result.playerAuto.rawValue)" auto routine.
        \(buildNote)

        Match results:
        - Red alliance (player's team) \(outcome)
        - Red score: \(result.redScore) (Auto: \(result.redBreakdown.autoPoints), \
        Teleop: \(result.redBreakdown.teleopPoints), Endgame: \(result.redBreakdown.endgamePoints))
        - Blue score: \(result.blueScore) (Auto: \(result.blueBreakdown.autoPoints), \
        Teleop: \(result.blueBreakdown.teleopPoints), Endgame: \(result.blueBreakdown.endgamePoints))
        - Player's robot scored \(result.playerRobotScored) pieces and completed \(result.playerRobotCycled) cycles
        - Coral scored: L1=\(result.redBreakdown.coralL1), L2=\(result.redBreakdown.coralL2), \
        L3=\(result.redBreakdown.coralL3), L4=\(result.redBreakdown.coralL4)
        - \(stallNote)
        - \(calloutNote)
        - \(result.slowMoUsed ? "They used the slow-mo coaching feature." : "They didn't use slow-mo coaching.")

        What coaching feedback would you give?
        """
    }

    // MARK: - Rule-Based Fallback

    func generateRuleBasedFeedback(for result: MatchResult) -> String {
        var lines: [String] = []

        // Match outcome
        if result.playerWon && result.margin > 15 {
            lines.append("Dominant victory! Your red alliance crushed it with \(result.redScore) points vs \(result.blueScore). Your strategy choices paid off big time.")
        } else if result.playerWon {
            lines.append("Nice win! \(result.redScore)-\(result.blueScore) — a \(result.margin)-point margin shows your strategy worked, though there's room to widen the gap.")
        } else if result.margin == 0 {
            lines.append("A tie at \(result.redScore)-\(result.blueScore)! In FRC, ties are rare and exciting. A small adjustment to your strategy could tip the balance next time.")
        } else if result.margin < 10 {
            lines.append("Close match! \(result.redScore)-\(result.blueScore) — just \(result.margin) points separated the alliances. Small strategic changes can flip a close loss into a win.")
        } else {
            lines.append("Tough loss at \(result.redScore)-\(result.blueScore). Don't worry — even top FRC teams lose matches. The key is analyzing what happened and adapting.")
        }

        // Strategy analysis
        switch result.playerStrategy {
        case .aggressive:
            if result.playerWon {
                lines.append("Your aggressive strategy delivered high scoring. Watch out though — against teams with strong defense, this approach can backfire.")
            } else {
                lines.append("The aggressive strategy generated offense but left you exposed. Consider \"Balanced\" or \"Defense + Cycles\" to control the match tempo.")
            }
        case .balanced:
            lines.append("The balanced strategy is versatile — you had both scoring and some defensive coverage. To optimize, try tilting toward aggressive if opponents are weak scorers, or defensive if they're strong.")
        case .defensive:
            if result.playerWon {
                lines.append("Defense won this match! Slowing opponents while your cyclers scored efficiently is a classic FRC strategy. Great call.")
            } else {
                lines.append("Your defense slowed opponents, but your scorers couldn't generate enough points. Defense only works when your alliance still cycles well — consider upgrading your scorer's role.")
            }
        }

        // Role feedback
        switch result.playerRole {
        case .scorer:
            if result.playerRobotScored >= 4 {
                lines.append("Your scorer put up \(result.playerRobotScored) pieces — excellent output! Scorers win matches when they stay consistent.")
            } else {
                lines.append("Your scorer only placed \(result.playerRobotScored) pieces. Try the Cycler role for faster piece delivery, or pair a Scorer with an aggressive strategy for more opportunities.")
            }
        case .cycler:
            if result.playerRobotCycled >= 5 {
                lines.append("Great cycling! \(result.playerRobotCycled) cycles shows strong field movement. Cyclers are the backbone of high-scoring alliances.")
            } else {
                lines.append("With \(result.playerRobotCycled) cycles, there's room to improve throughput. Cyclers need clear lanes — try defensive strategy to open paths.")
            }
        case .defender:
            lines.append("As a defender, your job was to slow opponents. Look at the blue score breakdown — if their teleop scoring was low, your defense worked!")
        }

        // Stall feedback
        if result.didPlayerStall {
            lines.append("Your robot stalled during the match. In FRC, reliability beats everything. Consider a safer auto routine — consistent points beat risky zeros.")
        }

        // Auto feedback
        switch result.playerAuto {
        case .safe:
            if !result.didPlayerStall {
                lines.append("Your safe auto delivered consistent points. Once you're comfortable, try moderate to push for more auto scoring.")
            }
        case .moderate:
            lines.append("The moderate auto is a solid middle ground. In real FRC, this is what many competitive teams run — enough points without the stall risk.")
        case .risky:
            if result.didPlayerStall {
                lines.append("The risky auto caused a stall. In competition, failed autos can cost matches. Try moderate next time — the reliability is worth more than the extra piece attempt.")
            } else {
                lines.append("You pulled off the risky auto without stalling — impressive! But remember, in a best-of-3 playoff, consistency matters more than one hot run.")
            }
        }

        // Callout feedback
        if result.calloutsUsed.isEmpty {
            lines.append("Tip: Try using callouts during the match! They let you shift your alliance's strategy mid-game — a key skill for real FRC drive coaches.")
        } else {
            lines.append("Good use of callouts! You used \(result.calloutsUsed.count) strategic adjustments. In real FRC, drive coaches constantly adapt — you're thinking like one.")
        }

        // Build-specific recommendations
        lines.append(buildRecommendation(for: result))

        // Tuning advice
        let tuning = result.playerBuild.tuning
        if tuning.gearRatio != 0.5 || tuning.weightBalance != 0.5 || tuning.mechanismTuning != 0.5 {
            lines.append(tuningAdvice(for: result))
        }

        return lines.joined(separator: "\n\n")
    }

    // MARK: - Build Recommendations

    func buildRecommendation(for result: MatchResult) -> String {
        let build = result.playerBuild
        let scored = result.playerRobotScored
        let cycles = result.playerRobotCycled

        // Suggest alternative builds based on performance
        if build.mechanism == .elevator && scored < 3 {
            return "Build tip: Your Elevator reached L4 but only scored \(scored) pieces. Consider Arm mechanism — it's faster (L3 max) and often scores more total points through quicker cycles."
        }

        if build.mechanism == .simple && result.playerRole == .scorer {
            return "Build tip: Simple mechanism as a Scorer only reaches L2 (\(scored) scored). Upgrade to Arm (L3, +1pt/piece) or Elevator (L4, +2pts/piece) for a scorer role."
        }

        if build.drivetrain == .swerve && result.playerRole == .defender {
            return "Build tip: Swerve drive is fast but weak for pushing. Defenders benefit from Tank drive's push power — try Tank + Simple/Arm with a defender role."
        }

        if build.intake == .roller && result.didPlayerStall {
            return "Build tip: Roller intake is fast but less reliable. Consider Claw intake — it's 8% more reliable, which matters when your robot stalled this match."
        }

        if cycles > 5 && build.mechanism != .simple {
            return "Build tip: Great cycling (\(cycles) cycles)! Your \(build.mechanism.shortLabel) works well. To cycle even faster, consider Simple mechanism — it trades reach for speed."
        }

        return ""
    }

    func tuningAdvice(for result: MatchResult) -> String {
        let tuning = result.playerBuild.tuning

        if tuning.gearRatio > 0.7 && result.playerRobotScored < 3 {
            return "Tuning tip: Your speed-biased gear ratio (%.0f%%) didn't translate to more scores. Try 50%% for balanced acceleration — getting to scoring position fast matters more than top speed."
        }

        if tuning.mechanismTuning < 0.3 && result.didPlayerStall {
            return "Tuning tip: Fast mechanism tuning increases stall risk. Raise precision to 60-70%% for more consistent scoring."
        }

        if tuning.weightBalance > 0.7 && result.playerRole != .defender {
            return "Tuning tip: Rear-heavy weight balance boosts pushing but reduces traction. As a \(result.playerRole.rawValue), try 50%% balance for smoother driving."
        }

        return "Your custom tuning affected the match. Experiment with different slider positions to find your optimal setup!"
    }
}
