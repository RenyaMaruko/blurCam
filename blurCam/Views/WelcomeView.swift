import SwiftUI

/// Welcome screen displayed on first launch when no face is registered.
/// Explains the app's purpose (privacy protection) and guides the user
/// to the face registration flow.
struct WelcomeView: View {

    /// Action to perform when the user taps the registration button
    let onStartRegistration: () -> Void

    @State private var contentOpacity: Double = 0.0
    @State private var contentOffset: CGFloat = 20

    var body: some View {
        ZStack {
            DesignTokens.Colors.primary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                    .frame(maxHeight: .infinity)

                // Face outline icon — minimal line drawing style matching reference
                iconSection

                Spacer()
                    .frame(height: DesignTokens.Spacing.space10)

                // Text content
                textSection

                Spacer()
                    .frame(maxHeight: .infinity)

                // Privacy note
                privacyNote

                // CTA button
                registrationButton
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeOut(duration: DesignTokens.Motion.slow)) {
                contentOpacity = 1.0
                contentOffset = 0
            }
        }
    }

    // MARK: - Subviews

    private var iconSection: some View {
        ZStack {
            // Thin circle outline — no filled background, just a ring
            Circle()
                .stroke(DesignTokens.Colors.borderStrong, lineWidth: 1.5)
                .frame(width: 120, height: 120)

            // Minimal face outline icon
            Image(systemName: "face.dashed")
                .font(.system(size: 52, weight: .ultraLight))
                .foregroundStyle(DesignTokens.Colors.textSecondary)
        }
        .opacity(contentOpacity)
        .accessibilityIdentifier("welcomeIcon")
    }

    private var textSection: some View {
        VStack(spacing: DesignTokens.Spacing.space4) {
            Text("はじめに\nあなたの顔を登録します")
                .font(.system(size: DesignTokens.Typography.xxl, weight: DesignTokens.Typography.Weight.bold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .tracking(-0.4)
                .lineSpacing(4)
                .accessibilityIdentifier("welcomeTitle")

            Text("登録すると、あなた以外の人物は\n撮影時に自動で保護されます。")
                .font(.system(size: DesignTokens.Typography.base, weight: DesignTokens.Typography.Weight.normal))
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .accessibilityIdentifier("welcomeDescription")
        }
        .offset(y: contentOffset)
        .opacity(contentOpacity)
    }

    private var privacyNote: some View {
        HStack(spacing: DesignTokens.Spacing.space2) {
            Image(systemName: "lock.fill")
                .font(.system(size: DesignTokens.Typography.xs))
                .foregroundStyle(DesignTokens.Colors.textTertiary)
            Text("顔データは端末内にのみ保存されます")
                .font(.system(size: DesignTokens.Typography.xs, weight: DesignTokens.Typography.Weight.medium))
                .foregroundStyle(DesignTokens.Colors.textTertiary)
        }
        .padding(.bottom, DesignTokens.Spacing.space5)
        .opacity(contentOpacity)
        .accessibilityIdentifier("privacyNote")
    }

    private var registrationButton: some View {
        Button(action: onStartRegistration) {
            Text("顔を登録する")
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
        .accessibilityIdentifier("startRegistrationButton")
        .accessibilityLabel("顔を登録する")
    }
}
