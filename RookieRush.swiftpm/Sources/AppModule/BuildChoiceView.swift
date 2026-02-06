import SwiftUI
import SceneKit

// MARK: - Build Choice View

/// Lets the user select one of three robot archetypes with a 3D preview.
struct BuildChoiceView: View {
    let onSelect: (RobotArchetype) -> Void
    @State private var selectedArchetype: RobotArchetype = .balanced
    @State private var previewScene: SCNScene

    init(onSelect: @escaping (RobotArchetype) -> Void) {
        self.onSelect = onSelect
        self._previewScene = State(initialValue: RobotBuilder.buildPreviewScene(archetype: .balanced))
    }

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.1)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                // Header
                VStack(spacing: 4) {
                    Text("STEP 1: CHOOSE YOUR BUILD")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                        .tracking(1.5)

                    Text("Select a Robot Archetype")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                }
                .padding(.top, 12)

                // 3D Preview
                SceneView(
                    scene: previewScene,
                    options: [.allowsCameraControl, .autoenablesDefaultLighting]
                )
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(selectedArchetype.color.opacity(0.4), lineWidth: 1)
                )
                .padding(.horizontal, 20)
                .accessibilityLabel("3D preview of \(selectedArchetype.rawValue) robot")

                // Archetype selector cards
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(RobotArchetype.allCases) { archetype in
                            archetypeCard(archetype)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Stats display
                statsView(for: selectedArchetype)
                    .padding(.horizontal, 20)

                Spacer()

                // Confirm button
                Button(action: { onSelect(selectedArchetype) }) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Confirm: \(selectedArchetype.rawValue)")
                            .font(.headline)
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: 300)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(selectedArchetype.color)
                    )
                }
                .accessibilityLabel("Confirm selection: \(selectedArchetype.rawValue)")
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Archetype Card

    @ViewBuilder
    private func archetypeCard(_ archetype: RobotArchetype) -> some View {
        let isSelected = archetype == selectedArchetype

        Button(action: {
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedArchetype = archetype
                previewScene = RobotBuilder.buildPreviewScene(archetype: archetype)
            }
        }) {
            VStack(spacing: 10) {
                Image(systemName: archetype.icon)
                    .font(.title2)
                    .foregroundStyle(archetype.color)
                    .accessibilityHidden(true)

                Text(archetype.rawValue)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(shortDescription(archetype))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 130, height: 120)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? archetype.color.opacity(0.15) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                isSelected ? archetype.color : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
        }
        .accessibilityLabel("\(archetype.rawValue): \(shortDescription(archetype))")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func shortDescription(_ archetype: RobotArchetype) -> String {
        switch archetype {
        case .speedy:   return "Fast, low scoring"
        case .balanced: return "Medium all-around"
        case .heavy:    return "Slow, high scoring"
        }
    }

    // MARK: - Stats View

    @ViewBuilder
    private func statsView(for archetype: RobotArchetype) -> some View {
        let stats = archetype.stats

        VStack(spacing: 8) {
            statBar(label: "Speed", value: stats.maxSpeed / 3.0, color: .cyan)
            statBar(label: "Scoring", value: 1.0 - (stats.scoringTime / 3.0), color: .green)
            statBar(label: "Reliability", value: stats.reliability, color: .yellow)
            statBar(label: "Pickup", value: 1.0 - (stats.pickupTime / 2.0), color: .orange)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
        )
    }

    @ViewBuilder
    private func statBar(label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 72, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: max(0, geo.size.width * CGFloat(min(value, 1.0))), height: 8)
                }
            }
            .frame(height: 8)

            Text("\(Int(value * 100))%")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 36, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(Int(value * 100)) percent")
    }
}
