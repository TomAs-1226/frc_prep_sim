# Rookie Rush: Level 1

A Swift Playground App (.swiftpm) that teaches new FRC (FIRST Robotics Competition) students the core loop of **Strategy + Build + Run** through an interactive, guided simulation experience.

## The Problem

New FRC students are overwhelmed by the complexity of competitive robotics — strategy decisions, robot design tradeoffs, autonomous routines, and match dynamics all hit at once. Rookie Rush provides a fast, low-pressure, interactive introduction where users experience these concepts firsthand in under 3 minutes.

## How the 3-Minute Loop Works

The experience flows through 5 guided steps:

### 1. Welcome + Tutorial (~15 seconds)
A single screen explains the three-step loop: choose a build, choose an auto, run the sim, get feedback. Simple step cards with icons guide the user.

### 2. Build Choice (~30–45 seconds)
Select one of three robot archetypes, each with distinct tradeoffs:

| Archetype | Speed | Scoring | Reliability |
|-----------|-------|---------|-------------|
| **Speedy Drivetrain** | High | Low | 75% |
| **Balanced** | Medium | Medium | 90% |
| **Heavy Scorer** | Low | High | 97% |

A 3D preview (procedural SceneKit geometry) shows each robot rotating in real-time. Stat bars visualize the tradeoffs.

### 3. Auto Choice (~30–45 seconds)
Select one of three autonomous routines:

- **Taxi + 1 Score** — Low risk, safe points (up to 7 pts)
- **2 Score** — Medium risk, more nodes (up to 12 pts)
- **Risky Sprint** — High risk, all 3 nodes (up to 17 pts)

A strategy tip explains risk vs. reward tradeoffs.

### 4. Run Simulation (~45–60 seconds)
A compressed match simulation runs at 2x speed on a simplified 3D field:
- Robot moves along waypoints with smooth interpolation
- Speed, scoring time, and reliability are driven by build stats
- Scoring triggers visual pulses on field nodes
- A live scoreboard shows points, time, and current robot activity
- Stalls can occur based on reliability + auto risk

### 5. Results + Coaching (~20–30 seconds)
Results screen shows total points, nodes scored, and stall status. Personalized coaching feedback explains what worked and suggests one improvement.

**AI Coaching:** On iOS 26+ devices with Apple Intelligence enabled, coaching uses Apple's on-device Foundation Models (LanguageModelSession) for natural-language feedback. Falls back to comprehensive rule-based coaching on all other devices — fully offline either way.

## How Build + Auto Choices Affect the Sim

- **maxSpeed** → Travel time between waypoints (faster = less time driving)
- **scoringTime** → Dwell time at each scoring node (lower = more efficient scoring)
- **reliability** → Probability of avoiding stalls during risky autos
- **failureChance** → Per-auto risk of triggering a stall (higher for aggressive autos)
- **pickupTime** → Time to pick up game pieces at field locations

The combination creates 9 distinct play experiences (3 archetypes x 3 autos) with meaningfully different outcomes.

## Technical Architecture

```
RookieRush.swiftpm/
  Package.swift                    # Swift Package targeting iOS 26
  Sources/AppModule/
    RookieRushApp.swift            # App entry point with onboarding gate
    ContentView.swift              # Main flow coordinator (state machine)
    GameModels.swift               # GamePhase, RobotArchetype, AutoPlan, etc.
    SimulationEngine.swift         # Core sim: waypoints, timing, scoring
    FieldBuilder.swift             # Procedural 3D field (SceneKit)
    AICoach.swift                  # Foundation Models + rule-based fallback
    GlassModifier.swift            # iOS 26 Liquid Glass conditional effects
    OnboardingView.swift           # First-launch onboarding
    WelcomeView.swift              # Tutorial/welcome screen
    BuildChoiceView.swift          # Robot archetype selector + 3D preview
    AutoChoiceView.swift           # Auto routine selector
    SimulationView.swift           # 3D sim view + live scoreboard
    ResultsView.swift              # Results + AI coaching feedback
    SettingsView.swift             # User settings (speed, seed, AI toggle)
```

### Key Design Decisions

- **SceneKit** for 3D rendering — more stable in Swift Playgrounds than RealityKit, fully supports code-only scene construction
- **Procedural geometry only** — all robots and field elements built from SCNBox, SCNCylinder, SCNTorus, SCNText primitives. Zero imported assets
- **Seeded RNG** (xorshift64) for deterministic simulation runs — same seed produces identical results for judging
- **Kinematic movement** via SCNAction waypoint interpolation with easing curves
- **SwiftUI overlays** on SceneKit for all UI (menus, scoreboard, buttons)
- **iOS 26 Liquid Glass** applied conditionally via `GlassModifier` — graceful degradation on older iOS
- **Foundation Models** integration with `#if canImport(FoundationModels)` guards and `@available(iOS 26.0, *)` checks

### Accessibility

- All buttons include `.accessibilityLabel()` for VoiceOver
- Scoreboard elements are grouped with `.accessibilityElement(children: .combine)`
- High contrast mode option in Settings
- Legible text with high contrast against dark backgrounds
- Simple tap-based controls — no complex gestures required

## Requirements

- Swift Playgrounds 4+ or Xcode 26+
- iOS 26.0+ (for Foundation Models and Liquid Glass)
- Falls back gracefully on iOS 17+ (without AI and glass effects)
- No network access required — fully offline

## Credits

Built for the Apple Swift Student Challenge 2026. Inspired by the FRC community's spirit of helping rookies learn through hands-on experience.
