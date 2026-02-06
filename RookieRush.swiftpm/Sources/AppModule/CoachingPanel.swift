import SwiftUI

// MARK: - Coaching Panel

/// Side/bottom panel shown during slow-mo with contextual coaching tips.
struct CoachingPanel: View {
    let tip: CoachingTip?
    let isVisible: Bool

    var body: some View {
        if isVisible, let tip = tip {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
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
                }

                Text(tip.detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
            .modifier(GlassModifier(shape: RoundedRectangle(cornerRadius: 14)))
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Coaching tip: \(tip.headline). \(tip.detail)")
        }
    }
}
