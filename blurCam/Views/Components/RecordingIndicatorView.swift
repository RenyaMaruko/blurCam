import SwiftUI

/// Displays recording status with a red blinking dot and elapsed time.
/// Shown at the top of the camera screen during video recording.
struct RecordingIndicatorView: View {
    let duration: String

    /// Blinking animation state
    @State private var isBlinking: Bool = true

    var body: some View {
        HStack(spacing: 6) {
            // Red recording dot
            Circle()
                .fill(DesignTokens.Colors.error)
                .frame(width: 8, height: 8)
                .opacity(isBlinking ? 1.0 : 0.15)
                .animation(
                    .easeInOut(duration: 0.7).repeatForever(autoreverses: true),
                    value: isBlinking
                )
                .onAppear {
                    isBlinking = false
                }
                .accessibilityIdentifier("recordingDot")

            // Elapsed time
            Text(duration)
                .font(.system(
                    size: DesignTokens.Typography.sm,
                    weight: DesignTokens.Typography.Weight.medium
                ))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .monospacedDigit()
                .accessibilityIdentifier("recordingTimer")
        }
        .padding(.horizontal, DesignTokens.Spacing.space3)
        .padding(.vertical, DesignTokens.Spacing.space1 + 2)
        .background(
            Capsule()
                .fill(DesignTokens.Colors.error.opacity(0.4))
                .overlay(
                    Capsule()
                        .stroke(DesignTokens.Colors.error.opacity(0.2), lineWidth: 0.5)
                )
        )
        .shadow(color: DesignTokens.Colors.primary.opacity(0.3), radius: DesignTokens.Spacing.space2, x: 0, y: 2)
        .accessibilityIdentifier("recordingIndicator")
        .accessibilityLabel("録画中 \(duration)")
    }
}
