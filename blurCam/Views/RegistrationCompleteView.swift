import SwiftUI

/// Screen displayed after successful face registration.
/// Informs the user that privacy protection is now active and
/// provides a button to proceed to the camera screen.
struct RegistrationCompleteView: View {

    /// Action to perform when the user taps "Start" to proceed to the camera
    let onComplete: () -> Void

    @State private var contentOpacity: Double = 0.0
    @State private var contentOffset: CGFloat = 20
    @State private var checkmarkScale: CGFloat = 0.3
    @State private var ringExpanded: Bool = false

    var body: some View {
        ZStack {
            DesignTokens.Colors.primary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                    .frame(maxHeight: .infinity)

                // Success icon
                successIcon

                Spacer()
                    .frame(height: DesignTokens.Spacing.space10)

                // Completion message
                messageSection

                Spacer()
                    .frame(maxHeight: .infinity)

                // Start button
                startButton
            }
        }
        .navigationBarHidden(true)
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                checkmarkScale = 1.0
            }
            withAnimation(.easeOut(duration: DesignTokens.Motion.slow)) {
                contentOpacity = 1.0
                contentOffset = 0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.15)) {
                ringExpanded = true
            }
        }
    }

    // MARK: - Subviews

    private var successIcon: some View {
        ZStack {
            // Outer expanding ring — subtle confirmation effect
            Circle()
                .stroke(DesignTokens.Colors.success.opacity(0.08), lineWidth: 1)
                .frame(width: ringExpanded ? 140 : 96, height: ringExpanded ? 140 : 96)

            // Large clean checkmark — matches reference image style
            Image(systemName: "checkmark.circle")
                .font(.system(size: 80, weight: .thin))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .scaleEffect(checkmarkScale)
        }
        .opacity(contentOpacity)
        .accessibilityIdentifier("registrationCompleteIcon")
    }

    private var messageSection: some View {
        VStack(spacing: DesignTokens.Spacing.space4) {
            Text("登録が完了しました")
                .font(.system(size: DesignTokens.Typography.xxl, weight: DesignTokens.Typography.Weight.bold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .tracking(-0.4)
                .accessibilityIdentifier("registrationCompleteTitle")

            Text("これ以降、あなた以外の人物は\n自動的に保護されます。")
                .font(.system(size: DesignTokens.Typography.base, weight: DesignTokens.Typography.Weight.normal))
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .accessibilityIdentifier("registrationCompleteMessage")
        }
        .offset(y: contentOffset)
        .opacity(contentOpacity)
    }

    private var startButton: some View {
        Button(action: onComplete) {
            Text("はじめる")
                .font(.system(size: DesignTokens.Typography.lg, weight: DesignTokens.Typography.Weight.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.space4)
                .background(DesignTokens.Colors.accent)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
        }
        .padding(.horizontal, DesignTokens.Spacing.space6)
        .padding(.bottom, DesignTokens.Spacing.space12)
        .opacity(contentOpacity)
        .accessibilityIdentifier("startButton")
        .accessibilityLabel("はじめる")
    }
}
