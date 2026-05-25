import SwiftUI

/// Displays recording status with a red blinking dot and elapsed time.
/// Shown at the top of the camera screen during video recording.
/// Shares the same capsule-in-capsule layout as the LIVE streaming indicator.
struct RecordingIndicatorView: View {
    let duration: String

    var body: some View {
        HStack(spacing: 0) {
            // REC label group (dot + text) with tinted background
            HStack(spacing: DesignTokens.Spacing.space1) {
                Circle()
                    .fill(DesignTokens.Colors.textPrimary)
                    .frame(width: 6, height: 6)
                    .modifier(BlinkingModifier())
                    .accessibilityIdentifier("recordingDot")

                Text("REC")
                    .font(.system(
                        size: DesignTokens.Typography.xs,
                        weight: DesignTokens.Typography.Weight.bold
                    ))
                    .kerning(1.0)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
            }
            .padding(.horizontal, DesignTokens.Spacing.space2)
            .padding(.vertical, DesignTokens.Spacing.space1)
            .background(
                Capsule()
                    .fill(DesignTokens.Colors.error.opacity(0.85))
            )

            // Elapsed time — sits adjacent
            Text(duration)
                .font(.system(
                    size: DesignTokens.Typography.xs,
                    weight: DesignTokens.Typography.Weight.medium
                ))
                .monospacedDigit()
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .padding(.leading, DesignTokens.Spacing.space2)
                .padding(.trailing, DesignTokens.Spacing.space3)
                .accessibilityIdentifier("recordingTimer")
        }
        .padding(.vertical, DesignTokens.Spacing.space1)
        .background(
            Capsule()
                .fill(DesignTokens.Colors.primary.opacity(0.5))
                .overlay(
                    Capsule()
                        .stroke(DesignTokens.Colors.border, lineWidth: 0.5)
                )
        )
        .accessibilityIdentifier("recordingIndicator")
        .accessibilityLabel("録画中 \(duration)")
    }
}
