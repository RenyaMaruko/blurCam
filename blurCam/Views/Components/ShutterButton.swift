import SwiftUI

/// A circular shutter button that adapts to photo and video modes.
/// In photo mode: white circle (like iOS Camera).
/// In video mode: red circle that transforms to a red square when recording.
/// Provides visual feedback during capture with scale and opacity animations.
struct ShutterButton: View {
    let captureState: CaptureState
    let cameraMode: CameraMode
    let action: () -> Void

    /// Pulsing animation state for recording indicator
    @State private var isPulsing: Bool = false

    /// Corner radius for morphing animation (circle -> rounded square)
    private var innerCornerRadius: CGFloat {
        captureState == .recording
            ? DesignTokens.Radius.small
            : DesignTokens.Shutter.innerSize / 2
    }

    /// Size of the inner shape (shrinks to square during recording)
    private var morphInnerSize: CGFloat {
        captureState == .recording ? 28 : innerSize
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(
                        outerRingColor,
                        lineWidth: DesignTokens.Shutter.strokeWidth
                    )
                    .frame(
                        width: DesignTokens.Shutter.outerSize,
                        height: DesignTokens.Shutter.outerSize
                    )

                // Inner shape — uses a single RoundedRectangle for smooth morphing
                if cameraMode == .video {
                    RoundedRectangle(cornerRadius: innerCornerRadius)
                        .fill(DesignTokens.Colors.error)
                        .frame(width: morphInnerSize, height: morphInnerSize)
                        .scaleEffect(captureState == .recording ? (isPulsing ? 1.05 : 0.95) : 1.0)
                        .animation(
                            captureState == .recording
                                ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true)
                                : .easeInOut(duration: DesignTokens.Motion.normal),
                            value: isPulsing
                        )
                        .animation(
                            .spring(response: 0.35, dampingFraction: 0.7),
                            value: captureState
                        )
                        .onChange(of: captureState) { _, newValue in
                            if newValue == .recording {
                                isPulsing = true
                            } else {
                                isPulsing = false
                            }
                        }
                } else {
                    // Photo mode: white circle
                    Circle()
                        .fill(innerColor)
                        .frame(
                            width: innerSize,
                            height: innerSize
                        )
                        .scaleEffect(captureState == .capturing ? 0.85 : 1.0)
                        .animation(
                            .easeInOut(duration: DesignTokens.Motion.fast),
                            value: captureState
                        )
                }
            }
            .opacity(captureState == .capturing || captureState == .stoppingRecording ? 0.7 : 1.0)
            .animation(
                .easeInOut(duration: DesignTokens.Motion.fast),
                value: captureState
            )
        }
        .disabled(captureState == .capturing || captureState == .stoppingRecording)
        .accessibilityIdentifier("shutterButton")
        .accessibilityLabel(shutterAccessibilityLabel)
        .accessibilityHint(shutterAccessibilityHint)
    }

    // MARK: - Computed Properties

    private var outerRingColor: Color {
        switch cameraMode {
        case .photo:
            return DesignTokens.Colors.textPrimary.opacity(0.9)
        case .video:
            return captureState == .recording
                ? DesignTokens.Colors.textPrimary.opacity(0.35)
                : DesignTokens.Colors.textPrimary.opacity(0.9)
        }
    }

    private var innerColor: Color {
        switch cameraMode {
        case .photo:
            switch captureState {
            case .idle, .captured, .failed:
                return DesignTokens.Colors.textPrimary
            case .capturing:
                return DesignTokens.Colors.textPrimary.opacity(0.6)
            case .recording, .stoppingRecording:
                return DesignTokens.Colors.textPrimary
            }
        case .video:
            return DesignTokens.Colors.error
        }
    }

    private var innerSize: CGFloat {
        switch cameraMode {
        case .photo:
            return DesignTokens.Shutter.innerSize
        case .video:
            return DesignTokens.Shutter.innerSize - 4
        }
    }

    private var shutterAccessibilityLabel: String {
        switch cameraMode {
        case .photo:
            return "シャッター"
        case .video:
            return captureState == .recording ? "録画停止" : "録画開始"
        }
    }

    private var shutterAccessibilityHint: String {
        switch cameraMode {
        case .photo:
            return "タップして写真を撮影"
        case .video:
            return captureState == .recording ? "タップして録画を停止" : "タップして録画を開始"
        }
    }
}
