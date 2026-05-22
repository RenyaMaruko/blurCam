import SwiftUI

/// A flow view for adding a new face from the settings screen.
/// Reuses FaceCaptureView with appropriate callbacks for the settings context.
/// Completion screen styled consistently with RegistrationCompleteView.
struct FaceAdditionFlowView: View {

    let onFaceAdded: () -> Void
    let onCancel: () -> Void

    @State private var faceCaptured: Bool = false
    @State private var checkmarkScale: CGFloat = 0.3
    @State private var contentOpacity: Double = 0.0
    @State private var ringExpanded: Bool = false

    var body: some View {
        NavigationStack {
            if faceCaptured {
                // Completion screen -- matches RegistrationCompleteView style
                ZStack {
                    DesignTokens.Colors.primary
                        .ignoresSafeArea()

                    VStack(spacing: 0) {
                        Spacer()

                        // Success icon -- thin checkmark matching reference
                        ZStack {
                            Circle()
                                .stroke(DesignTokens.Colors.success.opacity(0.08), lineWidth: 1)
                                .frame(
                                    width: ringExpanded ? 120 : 80,
                                    height: ringExpanded ? 120 : 80
                                )

                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 64, weight: .thin))
                                .foregroundStyle(DesignTokens.Colors.textPrimary)
                                .scaleEffect(checkmarkScale)
                        }

                        Spacer()
                            .frame(height: DesignTokens.Spacing.space8)

                        // Message
                        VStack(spacing: DesignTokens.Spacing.space3) {
                            Text("顔の登録が完了しました")
                                .font(.system(size: DesignTokens.Typography.xxl, weight: DesignTokens.Typography.Weight.bold))
                                .foregroundStyle(DesignTokens.Colors.textPrimary)
                                .tracking(-0.4)

                            Text("設定画面に戻って確認できます。")
                                .font(.system(size: DesignTokens.Typography.base, weight: DesignTokens.Typography.Weight.normal))
                                .foregroundStyle(DesignTokens.Colors.textSecondary)
                        }
                        .opacity(contentOpacity)

                        Spacer()

                        // Done button -- consistent with other CTA buttons
                        Button {
                            onFaceAdded()
                        } label: {
                            Text("完了")
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
                        .accessibilityIdentifier("faceAdditionDoneButton")
                    }
                }
                .transition(.opacity)
                .onAppear {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                        checkmarkScale = 1.0
                    }
                    withAnimation(.easeOut(duration: DesignTokens.Motion.slow)) {
                        contentOpacity = 1.0
                    }
                    withAnimation(.easeOut(duration: 0.6).delay(0.15)) {
                        ringExpanded = true
                    }
                }
            } else {
                FaceCaptureView(
                    onFaceCaptured: {
                        withAnimation(.easeInOut(duration: DesignTokens.Motion.normal)) {
                            faceCaptured = true
                        }
                    },
                    onBack: {
                        onCancel()
                    }
                )
            }
        }
        .preferredColorScheme(.dark)
    }
}
