import SwiftUI

/// View displayed when camera permission has not been determined yet.
/// Prompts the user to grant camera access.
struct CameraPermissionRequestView: View {
    @ObservedObject var viewModel: PermissionViewModel

    @State private var iconOpacity: Double = 0.0
    @State private var contentOffset: CGFloat = 24

    var body: some View {
        ZStack {
            DesignTokens.Colors.primary
                .ignoresSafeArea()

            VStack(spacing: DesignTokens.Spacing.space8) {
                Spacer()

                // Camera icon with subtle outline style
                ZStack {
                    Circle()
                        .fill(DesignTokens.Colors.surface)
                        .frame(width: 96, height: 96)

                    Image(systemName: "camera")
                        .font(.system(size: DesignTokens.Typography.xxxxl, weight: .light))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                }
                .opacity(iconOpacity)

                VStack(spacing: DesignTokens.Spacing.space3) {
                    Text("カメラへのアクセス")
                        .font(.system(size: DesignTokens.Typography.xxl, weight: DesignTokens.Typography.Weight.bold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .tracking(-0.4)

                    Text("写真や動画を撮影するために\nカメラへのアクセスが必要です")
                        .font(.system(size: DesignTokens.Typography.base, weight: DesignTokens.Typography.Weight.normal))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .offset(y: contentOffset)
                .opacity(iconOpacity)

                Spacer()

                // CTA button positioned near bottom
                Button {
                    Task {
                        await viewModel.requestCameraPermission()
                    }
                } label: {
                    Text("カメラを許可する")
                        .font(.system(size: DesignTokens.Typography.lg, weight: DesignTokens.Typography.Weight.semibold))
                        .foregroundStyle(DesignTokens.Colors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.Spacing.space4)
                        .background(DesignTokens.Colors.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
                }
                .padding(.horizontal, DesignTokens.Spacing.space6)
                .padding(.bottom, DesignTokens.Spacing.space12)
                .accessibilityIdentifier("requestCameraPermissionButton")
            }
            .padding()
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeOut(duration: DesignTokens.Motion.slow)) {
                iconOpacity = 1.0
                contentOffset = 0
            }
        }
    }
}
