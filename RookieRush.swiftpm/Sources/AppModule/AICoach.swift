import Foundation
import SwiftUI

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - AI Coach

/// Provides coaching feedback using Apple's on-device Foundation Models (iOS 26+).
/// Gracefully falls back to comprehensive rule-based feedback when the model
/// is unavailable (older devices, Apple Intelligence disabled, or non-iOS 26 SDK).
@MainActor
final class AICoach: ObservableObject {
    @Published var coachingText: String = ""
    @Published var isGenerating: Bool = false
    @Published var isAIAvailable: Bool = false

    init() {
        checkAvailability()
    }

    // MARK: - Availability Check

    /// Determine if on-device Foundation Models are available.
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

    /// Prewarm the model to reduce first-token latency.
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

    // MARK: - Generate Feedback

    /// Generate coaching feedback for a simulation result.
    /// Attempts AI-powered generation first, falls back to rules if unavailable.
    func generateFeedback(for result: SimulationResult) async {
        isGenerating = true
        defer { isGenerating = false }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), isAIAvailable {
            do {
                let text = try await generateAIFeedback(for: result)
                coachingText = text
                return
            } catch {
                // AI generation failed — fall through to rule-based
            }
        }
        #endif

        // Fallback: rule-based coaching (always works, offline, instant)
        coachingText = generateRuleBasedFeedback(for: result)
    }

    // MARK: - Foundation Models AI Generation (iOS 26+)

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func generateAIFeedback(for result: SimulationResult) async throws -> String {
        let session = LanguageModelSession(
            instructions: """
            You are a friendly, encouraging FRC (FIRST Robotics Competition) mentor \
            coaching a brand-new rookie student. They just ran a simplified match simulation \
            in an educational app called "Rookie Rush." \
            \
            Give a 2-3 sentence response that: \
            1. Acknowledges what went well in their run. \
            2. Gives one specific, actionable suggestion for their next attempt. \
            \
            Be warm but concise. Use simple language — they're new to robotics. \
            Don't use jargon without briefly explaining it. \
            Never be discouraging. Frame failures as learning opportunities.
            """
        )

        let prompt = buildPrompt(for: result)
        let response = try await session.respond(to: prompt)
        return response.content
    }
    #endif

    // MARK: - Prompt Builder

    private func buildPrompt(for result: SimulationResult) -> String {
        let stallNote = result.didStall
            ? "The robot stalled (temporarily froze) during the run, losing time."
            : "The robot did not stall — it ran smoothly the whole time."

        return """
        The student chose the "\(result.archetype.rawValue)" robot and the \
        "\(result.autoPlan.rawValue)" autonomous routine.

        Match results:
        - Scored \(result.nodesScored) out of \(result.totalNodes) available scoring nodes
        - Earned \(result.totalPoints) total points
        - Used \(String(format: "%.0f", result.timeUsed)) seconds of \(String(format: "%.0f", result.totalTime)) total match time
        - \(stallNote)

        What coaching feedback would you give?
        """
    }

    // MARK: - Rule-Based Fallback Feedback

    /// Generates deterministic coaching feedback based on the result.
    /// This runs instantly and works on all devices, no AI required.
    func generateRuleBasedFeedback(for result: SimulationResult) -> String {
        var lines: [String] = []

        let scoringRatio = result.totalNodes > 0
            ? Double(result.nodesScored) / Double(result.totalNodes)
            : 0

        // -- Performance summary --
        if scoringRatio >= 0.9 {
            lines.append("Excellent run! You scored \(result.nodesScored) out of \(result.totalNodes) nodes for \(result.totalPoints) points — that's a strong performance for a rookie.")
        } else if scoringRatio >= 0.5 {
            lines.append("Solid effort! You scored \(result.nodesScored) out of \(result.totalNodes) nodes for \(result.totalPoints) points. You're getting the hang of this!")
        } else {
            lines.append("You scored \(result.nodesScored) out of \(result.totalNodes) nodes for \(result.totalPoints) points. Every FRC team starts here — the key is learning from each run.")
        }

        // -- Stall feedback --
        if result.didStall {
            lines.append("Your robot stalled mid-match, costing valuable seconds. In real FRC, reliability is often more important than raw speed. Risky autos are exciting, but teams that stall lose matches.")
        }

        // -- Archetype + Auto combo advice --
        switch (result.archetype, result.autoPlan) {
        case (.speedy, .riskySprint):
            lines.append("Coaching tip: The Speedy Drivetrain is fast but fragile under pressure. Pair it with 'Taxi + 1 Score' for consistent early points, or try the Balanced bot with '2 Score' for a safer multi-node run.")

        case (.speedy, .taxiPlusOne):
            lines.append("Coaching tip: Speed + a safe auto is a reliable formula. You secured taxi points and a quick score. Next, try the Balanced bot with '2 Score' to explore how medium speed handles more ambitious routes.")

        case (.speedy, .twoScore):
            lines.append("Coaching tip: The Speedy bot covers ground fast, but its scoring ability is limited. At the nodes, it takes longer to score than the Balanced or Heavy bots. Try Balanced for a better all-around 2-score run.")

        case (.balanced, .taxiPlusOne):
            lines.append("Coaching tip: You played it safe — and that's smart for learning! But the Balanced bot can handle more. Try '2 Score' next to use its well-rounded stats and score more points without much extra risk.")

        case (.balanced, .twoScore):
            lines.append("Coaching tip: This is one of the strongest combos! The Balanced bot's medium speed and good reliability make 2-score autos very consistent. Many real FRC teams aim for exactly this kind of setup.")

        case (.balanced, .riskySprint):
            lines.append("Coaching tip: The Balanced bot can handle some risk, but the Risky Sprint pushes it hard. If you want to go for all 3 nodes, try the Heavy Scorer — its high reliability helps it power through without stalling.")

        case (.heavy, .taxiPlusOne):
            lines.append("Coaching tip: The Heavy Scorer is a powerhouse at the nodes, but Taxi + 1 doesn't fully use that strength. Try '2 Score' — the Heavy bot's fast scoring time at nodes more than compensates for its slower drive.")

        case (.heavy, .twoScore):
            lines.append("Coaching tip: Great strategy! The Heavy Scorer's reliability and fast scoring make 2-node runs very achievable. Watch the clock though — in tight matches, every second of drive time counts.")

        case (.heavy, .riskySprint):
            if result.nodesScored >= 2 {
                lines.append("Coaching tip: The Heavy Scorer's reliability helped it survive the risky sprint! But notice how close to the time limit you got — in a real match, the 3rd node might not happen. Two reliable scores often beats a risky three.")
            } else {
                lines.append("Coaching tip: The Heavy Scorer is simply too slow for a full-field sprint. Its superpower is dominating when it arrives at a node — pair it with '2 Score' to play to its strengths.")
            }
        }

        // -- Time management insight --
        let timeRatio = result.timeUsed / result.totalTime
        if timeRatio < 0.65 && result.nodesScored < result.totalNodes {
            lines.append("You finished with time to spare. In FRC, unused time means unused potential — consider a slightly more aggressive auto on your next run!")
        }

        return lines.joined(separator: "\n\n")
    }
}
