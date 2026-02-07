import SwiftUI

// MARK: - Settings View

/// User-configurable settings for simulation, AI, and accessibility.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("simulationSpeed") private var simulationSpeed: Double = 2.0
    @AppStorage("soundEnabled") private var soundEnabled: Bool = true
    @AppStorage("highContrastMode") private var highContrastMode: Bool = false
    @AppStorage("randomSeed") private var randomSeed: Int = 42
    @AppStorage("aiCoachingEnabled") private var aiCoachingEnabled: Bool = true
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Default Speed")
                            Spacer()
                            Text("\(String(format: "%.1f", simulationSpeed))x")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $simulationSpeed, in: 1.0...4.0, step: 0.5)
                            .tint(.orange)
                            .accessibilityLabel("Simulation speed: \(String(format: "%.1f", simulationSpeed))x")
                    }

                    HStack {
                        Text("Random Seed")
                        Spacer()
                        TextField("Seed", value: $randomSeed, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .accessibilityLabel("Random seed value")
                    }

                    Toggle("Sound Effects", isOn: $soundEnabled)
                        .tint(.orange)
                } header: {
                    Label("Match Simulation", systemImage: "play.circle.fill")
                }

                Section {
                    Toggle("AI Coaching", isOn: $aiCoachingEnabled)
                        .tint(.orange)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("About AI Coaching")
                            .font(.subheadline.bold())
                        Text("When available, post-match feedback is powered by Apple's on-device Foundation Models. All processing happens locally — nothing is sent to the cloud. Falls back to rule-based coaching on unsupported devices.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Label("Intelligence", systemImage: "brain.head.profile.fill")
                }

                Section {
                    Toggle("High Contrast Mode", isOn: $highContrastMode)
                        .tint(.orange)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Accessibility")
                            .font(.subheadline.bold())
                        Text("All controls include VoiceOver labels. The scoreboard and coaching panel are accessible. High contrast mode increases UI element visibility.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Label("Accessibility", systemImage: "accessibility")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Match Coach: Robotics Strategy Lab")
                            .font(.headline)
                        Text("An interactive robotics strategy experience where you lead a 3-robot alliance through a simulated competition match. Choose strategy, role, and auto — then watch how your decisions play out.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Built for Swift Student Challenge 2026")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Button("Reset Onboarding") {
                        hasCompletedOnboarding = false
                        dismiss()
                    }
                    .foregroundStyle(.red)
                    .accessibilityLabel("Reset onboarding to see the welcome screens again")
                } header: {
                    Label("About", systemImage: "info.circle.fill")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.headline)
                        .foregroundStyle(.orange)
                        .accessibilityLabel("Close settings")
                }
            }
        }
    }
}
