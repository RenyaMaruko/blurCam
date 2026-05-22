import SwiftUI

/// Face capture screen that displays the front camera preview with a face guide overlay.
/// The user aligns their face within the circular guide and taps the capture button.
/// The capture button is disabled when no face is detected.
struct FaceCaptureView: View {

    @StateObject private var viewModel = FaceCaptureViewModel()

    /// Called when the face has been successfully captured and saved
    let onFaceCaptured: () -> Void

    /// Called when user navigates back
    let onBack: () -> Void

    @State private var controlsOpacity: Double = 0.0

    var body: some View {
        ZStack {
            // Full-screen camera preview (front camera)
            CameraPreviewView(session: viewModel.captureSession)
                .ignoresSafeArea()

            // Semi-transparent overlay with cutout for face guide
            faceGuideOverlay

            // UI controls overlay
            VStack(spacing: 0) {
                // Top bar with back button and title
                topBar

                Spacer()

                // Guidance text
                guidanceSection

                // Capture button
                captureButton
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.setupCamera()
            withAnimation(.easeOut(duration: DesignTokens.Motion.normal)) {
                controlsOpacity = 1.0
            }
        }
        .onDisappear {
            viewModel.stopCamera()
        }
        .onChange(of: viewModel.isFaceSaved) { _, saved in
            if saved {
                onFaceCaptured()
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Subviews

    private var topBar: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: DesignTokens.Typography.xl, weight: DesignTokens.Typography.Weight.medium))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("backButton")
            .accessibilityLabel("戻る")

            Spacer()

            Text("顔の登録")
                .font(.system(size: DesignTokens.Typography.base, weight: DesignTokens.Typography.Weight.semibold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .accessibilityIdentifier("faceCaptureTitle")

            Spacer()

            // Invisible spacer to balance the back button
            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, DesignTokens.Spacing.space3)
        .padding(.top, DesignTokens.Spacing.space2)
        .opacity(controlsOpacity)
    }

    private var faceGuideOverlay: some View {
        GeometryReader { geometry in
            let guideSize: CGFloat = min(geometry.size.width, geometry.size.height) * 0.58
            let centerX = geometry.size.width / 2
            let centerY = geometry.size.height * 0.42

            ZStack {
                // Semi-transparent dark overlay with vignette feel
                Color.black.opacity(0.45)
                    .ignoresSafeArea()

                // Clear circle cutout
                Circle()
                    .frame(width: guideSize, height: guideSize)
                    .position(x: centerX, y: centerY)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()

            // Face guide ring — thin, clean stroke
            Circle()
                .stroke(
                    viewModel.isFaceDetected
                        ? DesignTokens.Colors.success
                        : Color.white.opacity(0.4),
                    lineWidth: 2
                )
                .frame(width: guideSize, height: guideSize)
                .position(x: centerX, y: centerY)
                .animation(.easeInOut(duration: DesignTokens.Motion.normal), value: viewModel.isFaceDetected)
                .accessibilityIdentifier("faceGuideCircle")
        }
    }

    private var guidanceSection: some View {
        VStack(spacing: DesignTokens.Spacing.space3) {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(size: DesignTokens.Typography.sm, weight: DesignTokens.Typography.Weight.medium))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .padding(.horizontal, DesignTokens.Spacing.space5)
                    .padding(.vertical, DesignTokens.Spacing.space2)
                    .background(
                        Capsule()
                            .fill(DesignTokens.Colors.error.opacity(0.85))
                    )
                    .accessibilityIdentifier("faceCaptureError")
            }

            Text(viewModel.guidanceText)
                .font(.system(size: DesignTokens.Typography.sm, weight: DesignTokens.Typography.Weight.medium))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .padding(.horizontal, DesignTokens.Spacing.space5)
                .padding(.vertical, DesignTokens.Spacing.space2)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.55))
                )
                .accessibilityIdentifier("guidanceText")

            // Step progress indicator
            HStack(spacing: DesignTokens.Spacing.space2) {
                ForEach(1...viewModel.totalSteps, id: \.self) { step in
                    Circle()
                        .fill(step <= viewModel.currentStep ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: DesignTokens.Motion.normal), value: viewModel.currentStep)
                }
            }
            .padding(.top, DesignTokens.Spacing.space2)
        }
        .padding(.bottom, DesignTokens.Spacing.space8)
        .opacity(controlsOpacity)
    }

    private var captureButton: some View {
        Button {
            Task {
                await viewModel.captureAndSaveFace()
            }
        } label: {
            ZStack {
                // Outer ring — matches iPhone camera shutter style
                Circle()
                    .stroke(
                        Color.white.opacity(
                            viewModel.isFaceDetected ? 0.85 : 0.25
                        ),
                        lineWidth: DesignTokens.Shutter.strokeWidth
                    )
                    .frame(
                        width: DesignTokens.Shutter.outerSize,
                        height: DesignTokens.Shutter.outerSize
                    )

                // Inner filled circle
                Circle()
                    .fill(
                        viewModel.isFaceDetected
                            ? Color.white
                            : Color.white.opacity(0.25)
                    )
                    .frame(
                        width: DesignTokens.Shutter.innerSize,
                        height: DesignTokens.Shutter.innerSize
                    )
                    .scaleEffect(viewModel.isCapturing ? 0.85 : 1.0)
                    .animation(.easeInOut(duration: DesignTokens.Motion.fast), value: viewModel.isCapturing)
            }
            .opacity(viewModel.isCapturing ? 0.6 : 1.0)
            .animation(.easeInOut(duration: DesignTokens.Motion.fast), value: viewModel.isCapturing)
        }
        .disabled(!viewModel.isFaceDetected || viewModel.isCapturing)
        .padding(.bottom, DesignTokens.Spacing.space12)
        .opacity(controlsOpacity)
        .accessibilityIdentifier("faceCaptureButton")
        .accessibilityLabel("顔を撮影")
        .accessibilityHint(viewModel.isFaceDetected ? "タップして顔を撮影" : "顔をフレーム内に合わせてください")
    }
}
