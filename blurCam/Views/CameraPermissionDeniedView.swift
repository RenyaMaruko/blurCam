import SwiftUI

/// View displayed when camera permission has been denied.
/// Shows a message and a button to open iOS Settings.
struct CameraPermissionDeniedView: View {
    @ObservedObject var viewModel: PermissionViewModel

    @State private var contentOpacity: Double = 0.0
    @State private var contentOffset: CGFloat = 16

    var body: some View {
        ZStack {
            DesignTokens.Colors.primary
                .ignoresSafeArea()

            VStack(spacing: DesignTokens.Spacing.space8) {
                Spacer()

                // Icon with surface background
                ZStack {
                    Circle()
                        .fill(DesignTokens.Colors.surface)
                        .frame(width: 96, height: 96)

                    Image(systemName: "camera.badge.ellipsis")
                        .font(.system(size: DesignTokens.Typography.xxxl, weight: .light))
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .symbolRenderingMode(.hierarchical)
                }
                .opacity(contentOpacity)

                VStack(spacing: DesignTokens.Spacing.space3) {
                    Text("カメラへのアクセスを許可してください")
                        .font(.system(size: DesignTokens.Typography.xl, weight: DesignTokens.Typography.Weight.bold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .tracking(-0.3)
                        .accessibilityIdentifier("permissionDeniedMessage")

                    Text("設定アプリからblurCamの\nカメラアクセスを有効にしてください")
                        .font(.system(size: DesignTokens.Typography.base, weight: DesignTokens.Typography.Weight.normal))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .offset(y: contentOffset)
                .opacity(contentOpacity)

                Spacer()

                // Settings button
                Button {
                    viewModel.openAppSettings()
                } label: {
                    HStack(spacing: DesignTokens.Spacing.space2) {
                        Image(systemName: "gear")
                            .font(.system(size: DesignTokens.Typography.base, weight: DesignTokens.Typography.Weight.semibold))
                        Text("設定を開く")
                            .font(.system(size: DesignTokens.Typography.lg, weight: DesignTokens.Typography.Weight.semibold))
                    }
                    .foregroundStyle(DesignTokens.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.Spacing.space4)
                    .background(DesignTokens.Colors.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
                }
                .padding(.horizontal, DesignTokens.Spacing.space6)
                .padding(.bottom, DesignTokens.Spacing.space12)
                .accessibilityIdentifier("openSettingsButton")
            }
            .padding()
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeOut(duration: DesignTokens.Motion.slow)) {
                contentOpacity = 1.0
                contentOffset = 0
            }
        }
    }
}
