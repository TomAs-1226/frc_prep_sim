# Match Coach: Reefscape Strategy Lab

A Swift Playground App (.swiftpm) that teaches FRC (FIRST Robotics Competition) strategy through an interactive 6-robot match simulation. Act as alliance strategist, make real-time decisions, and learn from AI-powered coaching.

## Fix Summary

- Replaced the update loop with a fixed-timestep CADisplayLink accumulator, unified sim speed multiplier, and an in-app diagnostics overlay for FPS/dt and robot AI state.
- Corrected swerve module hierarchy (module → steer pivot → wheel roll), matched wheel roll rate to linear velocity, and enforced wheel ground clearance.
- Implemented kinematic robot motion with acceleration limits, pure heading steering, and non-clipping constraints for robots vs. robots and field structures.
- Added a deterministic coral state machine (OnGround → InIntake → Carried → ScoringAnim → Scored/Dropped) with attachment, scoring path, and drop bounce.
- Rebuilt AI as a deterministic FSM with utility scoring and role-specific weights (SeekPickup, Acquire, SeekScore, Score, Defend, Endgame).
- Refactored robot construction into a unified RobotFactory that builds preview and match entities with validation; preview errors show an on-screen card.
- Polished slow-mo coaching with a resume button and highlight rings for key robots.

## The Problem

New FRC students are overwhelmed by strategy decisions, robot roles, autonomous routines, and alliance coordination. Match Coach provides a fast, low-pressure, interactive simulation where users experience these concepts firsthand — leading a 3-robot alliance against 3 opponents in under 3 minutes.

## How the 3-Minute Loop Works

### 1. Welcome + Onboarding (~15 seconds)
First-launch onboarding introduces FRC concepts. The intro screen explains the three-step flow: pick strategy, choose role & auto, watch the match.

### 2. Pre-Match Strategy (~30-45 seconds)
Three sequential choices determine how the match plays out:

**Alliance Strategy** — How your 3-robot team approaches the match:
| Strategy | Scoring Weight | Defense Weight | Style |
|----------|---------------|----------------|-------|
| **Aggressive Scoring** | 90% | 5% | All-in offense, high risk |
| **Balanced** | 60% | 20% | Adaptable, mix of both |
| **Defense + Cycles** | 40% | 45% | Slow opponents, efficient cycling |

**Robot Role** — Your robot's function on the alliance:
- **Scorer** — Accurate piece placement, slower but efficient
- **Cycler** — Fast pickup and delivery, high throughput
- **Defender** — Blocks opponents, scores opportunistically

**Auto Routine** — 15-second autonomous program:
- **Safe** — Cross line + 1 piece (95% success)
- **Moderate** — 2 pieces (75% success)
- **Risky** — 3 pieces (45% success)

### 3. Match Simulation (~45-60 seconds)
A compressed 150-second match runs at 2x speed on a 3D REEFSCAPE-inspired field:
- 6 robots (3 red, 3 blue) with AI state machines driving simultaneously
- Auto, Teleop, and Endgame periods with distinct behaviors
- Robots pick up, deliver, and score game pieces at reef nodes and processors
- Collision avoidance and defender interactions slow opponents
- Endgame barge parking for bonus points

**Player Controls During Match:**
- **Slow-Mo Coaching** — Activates 0.3x speed with contextual coaching tips
- **3 Callouts** — Strategic mid-match adjustments:
  - "Prioritize Reef" — Boost scoring weight
  - "Switch to Defense" — Shift to defensive play
  - "Endgame Early" — Rush to barge for climb points

### 4. Results + AI Coaching (~20-30 seconds)
- Red vs Blue score comparison with animated reveal
- Score breakdown: Auto / Teleop / Endgame for each alliance
- Player robot stats: pieces scored, cycles, stalls
- Strategy choices recap
- Personalized AI coaching analysis

**AI Coaching:** On iOS 26+ with Apple Intelligence, coaching uses on-device Foundation Models for natural-language feedback. Falls back to comprehensive rule-based analysis on all other devices — fully offline either way.

## How Choices Affect the Simulation

- **Alliance Strategy** sets policy weights for all 3 red robots (scoring vs defense vs endgame)
- **Robot Role** determines your robot's stats (speed, scoring time, pickup time, reliability)
- **Auto Plan** controls autonomous aggressiveness and stall risk
- **Callouts** dynamically modify policy weights mid-match
- **Slow-Mo** provides coaching insights without changing outcomes

The combination creates 27 distinct play experiences (3 strategies x 3 roles x 3 autos) with meaningfully different outcomes. Callouts add further variation.

## Technical Architecture

```
RookieRush.swiftpm/
  Package.swift                    # Swift Package targeting iOS 26
  Sources/AppModule/
    RookieRushApp.swift            # App entry point with onboarding gate
    ContentView.swift              # Main flow coordinator (state machine)
    GameModels.swift               # All data types, field layout, robot factory
    SimulationEngine.swift         # RobotAgent AI + MatchEngine (6-robot orchestrator)
    FieldBuilder.swift             # Procedural 3D field (SceneKit) + RobotBuilder
    AICoach.swift                  # Foundation Models + rule-based fallback
    GlassModifier.swift            # iOS 26 Liquid Glass conditional effects
    OnboardingView.swift           # First-launch onboarding
    IntroView.swift                # Welcome/intro screen
    PreMatchView.swift             # 3-step strategy selector
    MatchView.swift                # 3D sim view + scoreboard + controls
    CoachingPanel.swift            # Slow-mo coaching tip panel
    ResultsView.swift              # Results + AI coaching feedback
    SettingsView.swift             # User settings (speed, seed, AI toggle)
```

### Key Design Decisions

- **SceneKit** for 3D rendering — more stable in Swift Playgrounds than RealityKit
- **Procedural geometry only** — all 6 robot types and field elements built from SCNBox, SCNCylinder, SCNTorus, SCNSphere, SCNText. Zero imported assets
- **Fixed-timestep CADisplayLink loop** with accumulator for stable 6-robot kinematics
- **Deterministic AI FSM + utility planner** for pickup, scoring, defense, and endgame
- **Explicit non-clipping constraints** via keep-out regions and separation resolution
- **RobotFactory** for preview + match entities, with validation and error reporting
- **Seeded RNG** (xorshift64) for deterministic simulation runs
- **SwiftUI overlays** on SceneKit for all UI (scoreboard, callouts, coaching panel)
- **iOS 26 Liquid Glass** applied conditionally via `GlassModifier`
- **Foundation Models** integration with `#if canImport(FoundationModels)` guards
- **`swiftLanguageMode(.v5)`** to avoid strict concurrency issues with Timer/SceneKit callbacks

### Robot Superstructure Types

Each robot has a visually distinct superstructure built from primitives:
1. **Elevator** — Tall vertical rails with a claw at top
2. **Arm** — Articulated arm with gripper
3. **Intake** — Front roller with guard plate
4. **Dual Rail** — Double elevator with hopper tray
5. **Turret Intake** — Rotating turret base with extending arm
6. **Wedge** — Low wedge with push plate (defender)

### Accessibility

- All buttons include `.accessibilityLabel()` for VoiceOver
- Scoreboard and coaching panels use `.accessibilityElement(children: .combine)`
- High contrast mode option in Settings
- Selection cards have `.accessibilityAddTraits(.isSelected)`
- Simple tap-based controls — no complex gestures required

## Requirements

- Swift Playgrounds 4+ or Xcode 26+
- iOS 26.0+ (for Foundation Models and Liquid Glass)
- Falls back gracefully on iOS 17+ (without AI and glass effects)
- No network access required — fully offline

## Credits

Built for the Apple Swift Student Challenge 2026. Inspired by the FRC community's spirit of helping rookies learn through hands-on strategy experience.

## How to verify

- Wheels roll on the correct axis and steer smoothly toward travel direction.
- Robots avoid clipping into each other or into reefs/barge/walls.
- Coral motion follows: pickup → carry → score → seat (or drop to ground).
- AI decisions are deterministic and explainable in the diagnostics overlay.
- Build preview matches in-game robots and shows an error card if missing parts.
