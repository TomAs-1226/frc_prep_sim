import SwiftUI

// MARK: - Coaching Panel

/// Overlay panel shown during slow-mo with contextual coaching tips.
struct CoachingPanel: View {
    let tip: CoachingTip?
    let isVisible: Bool

    @State private var pulse = false

    var body: some View {
        if isVisible, let tip = tip {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .scaleEffect(pulse ? 1.15 : 1.0)
                    Text(tip.headline)
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                    Spacer()
                    if let botId = tip.highlightRobotId {
                        Text("Bot #\(botId)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.white.opacity(0.1)))
                    }
                    // Slow-mo indicator
                    HStack(spacing: 3) {
                        Circle().fill(.orange).frame(width: 5, height: 5)
                            .opacity(pulse ? 1 : 0.4)
                        Text("COACHING")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.orange.opacity(0.6))
                    }
                }

                Text(tip.detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black.opacity(0.75))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.orange.opacity(0.4), lineWidth: 1.5)
                    )
            )
            .modifier(GlassModifier(shape: RoundedRectangle(cornerRadius: 14)))
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Coaching tip: \(tip.headline). \(tip.detail)")
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
            .onDisappear { pulse = false }
        }
    }
}
