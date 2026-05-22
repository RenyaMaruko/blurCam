import SwiftUI

/// Main camera preview screen with full-screen camera view,
/// status bar area at top, and shutter button at bottom.
/// Displays processed camera frames with face blur applied in real-time.
/// Supports photo and video modes with mode switching,
/// camera switching, flash control, media preview, and settings access.
struct CameraPreviewScreen: View {
    @StateObject private var cameraViewModel = CameraViewModel()
    @StateObject private var settingsViewModel = SettingsViewModel()
    @ObservedObject var permissionViewModel: PermissionViewModel

    @State private var controlsOpacity: Double = 0.0
    @State private var showSettings: Bool = false

    /// Callback when all faces are deleted (return to onboarding)
    var onAllFacesDeleted: (() -> Void)?

    /// Rotation angle for the camera flip animation
    @State private var flipRotation: Double = 0

    var body: some View {
        ZStack {
            // Full-screen processed camera preview (with blur applied)
            ProcessedCameraPreviewView(
                framePublisher: cameraViewModel.framePublisher,
                detectedFaces: cameraViewModel.detectedFaces
            )
            .ignoresSafeArea()
            .rotation3DEffect(
                .degrees(flipRotation),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.4
            )
            .scaleEffect(cameraViewModel.isSwitchingCamera ? 0.92 : 1.0)
            .opacity(cameraViewModel.isSwitchingCamera ? 0.5 : 1.0)
            .animation(.easeInOut(duration: 0.3), value: cameraViewModel.isSwitchingCamera)

            // UI overlay
            VStack(spacing: 0) {
                // Top status bar area
                topStatusBar

                Spacer()

                // Bottom controls area
                bottomControls
            }

            // Media preview overlay
            if cameraViewModel.showMediaPreview, let mediaItem = cameraViewModel.latestMediaItem {
                MediaPreviewView(
                    mediaItem: mediaItem,
                    onDismiss: {
                        withAnimation(.easeInOut(duration: DesignTokens.Motion.normal)) {
                            cameraViewModel.showMediaPreview = false
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity
                ))
                .zIndex(10)
            }
        }
        .onAppear {
            setupSettingsCallbacks()
            if !cameraViewModel.isCameraConfigured {
                cameraViewModel.setupCamera()
            } else {
                cameraViewModel.startCamera()
            }
            // Apply saved blur intensity on appear
            cameraViewModel.applyBlurIntensity(settingsViewModel.blurIntensity)
            withAnimation(.easeOut(duration: DesignTokens.Motion.normal)) {
                controlsOpacity = 1.0
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                viewModel: settingsViewModel,
                onDismiss: {
                    showSettings = false
                }
            )
        }
        .onChange(of: settingsViewModel.allFacesDeleted) { _, deleted in
            if deleted {
                showSettings = false
                onAllFacesDeleted?()
            }
        }
        .statusBarHidden(false)
        .preferredColorScheme(.dark)
    }

    // MARK: - Settings Callbacks Setup

    private func setupSettingsCallbacks() {
        settingsViewModel.onBlurIntensityChanged = { [weak cameraViewModel] intensity in
            Task { @MainActor in
                cameraViewModel?.applyBlurIntensity(intensity)
            }
        }

        settingsViewModel.onFacesChanged = { [weak cameraViewModel] in
            Task { @MainActor in
                cameraViewModel?.reloadRegisteredFaces()
            }
        }
    }

    // MARK: - Top Status Bar

    private var topStatusBar: some View {
        ZStack {
            // Flash icon -- left aligned, hidden during recording
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: DesignTokens.Motion.fast)) {
                        cameraViewModel.toggleFlashMode()
                    }
                } label: {
                    HStack(spacing: DesignTokens.Spacing.space1) {
                        Image(systemName: cameraViewModel.flashMode.iconName)
                            .font(.system(size: DesignTokens.Typography.lg, weight: DesignTokens.Typography.Weight.medium))
                            .foregroundStyle(flashIconColor)
                            .contentTransition(.symbolEffect(.replace))

                        // Show flash mode label when not off
                        if cameraViewModel.flashMode != .off {
                            Text(cameraViewModel.flashMode == .auto ? "自動" : "オン")
                                .font(.system(
                                    size: DesignTokens.Typography.xs,
                                    weight: DesignTokens.Typography.Weight.semibold
                                ))
                                .foregroundStyle(flashIconColor)
                                .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.space3)
                    .padding(.vertical, DesignTokens.Spacing.space2)
                    .background(
                        Capsule()
                            .fill(cameraViewModel.flashMode != .off
                                ? DesignTokens.Colors.warning.opacity(0.15)
                                : Color.clear)
                    )
                }
                .disabled(!cameraViewModel.hasFlash || cameraViewModel.isRecording)
                .opacity(cameraViewModel.isRecording ? 0.0 : (cameraViewModel.hasFlash ? 1.0 : 0.3))
                .accessibilityIdentifier("flashButton")
                .accessibilityLabel(cameraViewModel.flashMode.accessibilityLabel)
                .accessibilityHint("タップしてフラッシュモードを切り替え")

                Spacer()

                // Settings gear icon -- right aligned, hidden during recording
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: DesignTokens.Typography.lg, weight: DesignTokens.Typography.Weight.medium))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .padding(DesignTokens.Spacing.space2)
                }
                .disabled(cameraViewModel.isRecording)
                .opacity(cameraViewModel.isRecording ? 0.0 : 1.0)
                .accessibilityIdentifier("settingsButton")
                .accessibilityLabel("設定")
                .accessibilityHint("タップして設定画面を開く")
            }
            .padding(.leading, DesignTokens.Spacing.space2)
            .padding(.trailing, DesignTokens.Spacing.space2)

            // Recording indicator -- centered
            if cameraViewModel.isRecording {
                RecordingIndicatorView(
                    duration: cameraViewModel.formattedRecordingDuration
                )
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .frame(height: 48)
        .padding(.top, DesignTokens.Spacing.space1)
        .background(
            LinearGradient(
                colors: [
                    DesignTokens.Colors.primary.opacity(0.6),
                    DesignTokens.Colors.primary.opacity(0.25),
                    DesignTokens.Colors.primary.opacity(0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 80)
            .allowsHitTesting(false)
        )
        .animation(.easeInOut(duration: DesignTokens.Motion.normal), value: cameraViewModel.isRecording)
        .opacity(controlsOpacity)
        .accessibilityIdentifier("statusBarArea")
    }

    // MARK: - Flash Icon Color

    private var flashIconColor: Color {
        switch cameraViewModel.flashMode {
        case .off:
            return DesignTokens.Colors.textPrimary
        case .auto:
            return DesignTokens.Colors.warning
        case .on:
            return DesignTokens.Colors.warning
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 0) {
            // Error message display
            if let errorMessage = cameraViewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(size: DesignTokens.Typography.sm, weight: DesignTokens.Typography.Weight.semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .padding(.horizontal, DesignTokens.Spacing.space4)
                    .padding(.vertical, DesignTokens.Spacing.space2)
                    .background(DesignTokens.Colors.error.opacity(0.9))
                    .clipShape(Capsule())
                    .shadow(color: DesignTokens.Colors.error.opacity(0.3), radius: DesignTokens.Spacing.space2, x: 0, y: 2)
                    .padding(.bottom, DesignTokens.Spacing.space3)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .accessibilityIdentifier("errorMessage")
            }

            // Bottom dark area mimicking iOS Camera
            VStack(spacing: DesignTokens.Spacing.space4) {
                // Mode selector area
                ModeSelectorView(
                    selectedMode: $cameraViewModel.cameraMode,
                    isRecording: cameraViewModel.isRecording
                )
                .opacity(cameraViewModel.isRecording ? 0.0 : 1.0)
                .animation(.easeInOut(duration: DesignTokens.Motion.normal), value: cameraViewModel.isRecording)

                // Shutter button and side controls
                HStack {
                    // Left side - gallery thumbnail
                    thumbnailButton
                        .opacity(cameraViewModel.isRecording ? 0.0 : 1.0)
                        .animation(.easeInOut(duration: DesignTokens.Motion.normal), value: cameraViewModel.isRecording)

                    Spacer()

                    // Center - Shutter button
                    ShutterButton(
                        captureState: cameraViewModel.captureState,
                        cameraMode: cameraViewModel.cameraMode
                    ) {
                        cameraViewModel.handleShutterAction()
                    }

                    Spacer()

                    // Right side - camera flip button
                    cameraFlipButton
                        .opacity(cameraViewModel.isRecording ? 0.0 : 1.0)
                        .animation(.easeInOut(duration: DesignTokens.Motion.normal), value: cameraViewModel.isRecording)
                }
                .padding(.horizontal, DesignTokens.Spacing.space8)
            }
            .padding(.bottom, DesignTokens.Spacing.space4)
            .background(
                LinearGradient(
                    stops: [
                        .init(color: DesignTokens.Colors.primary.opacity(0), location: 0),
                        .init(color: DesignTokens.Colors.primary.opacity(0.35), location: 0.35),
                        .init(color: DesignTokens.Colors.primary.opacity(0.7), location: 0.65),
                        .init(color: DesignTokens.Colors.primary.opacity(0.85), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
            )
        }
        .opacity(controlsOpacity)
    }

    // MARK: - Thumbnail Button

    private var thumbnailButton: some View {
        Button {
            guard cameraViewModel.latestMediaItem != nil else { return }
            withAnimation(.easeInOut(duration: DesignTokens.Motion.normal)) {
                cameraViewModel.showMediaPreview = true
            }
        } label: {
            Group {
                if let mediaItem = cameraViewModel.latestMediaItem,
                   let thumbnail = mediaItem.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 42, height: 42)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                                .stroke(DesignTokens.Colors.borderStrong, lineWidth: 1.5)
                        )
                        // Video indicator badge
                        .overlay(alignment: .bottomTrailing) {
                            if mediaItem.mediaType == .video {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 7, weight: DesignTokens.Typography.Weight.semibold))
                                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                                    .frame(width: 16, height: 16)
                                    .background(
                                        Circle()
                                            .fill(DesignTokens.Colors.primary.opacity(0.7))
                                    )
                                    .offset(x: -2, y: -2)
                            }
                        }
                        .shadow(color: DesignTokens.Colors.primary.opacity(0.4), radius: 4, x: 0, y: 2)
                } else {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                        .fill(DesignTokens.Colors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                                .stroke(DesignTokens.Colors.borderStrong, lineWidth: 1.5)
                        )
                        .frame(width: 42, height: 42)
                }
            }
        }
        .accessibilityIdentifier("mediaThumbnail")
        .accessibilityLabel(cameraViewModel.latestMediaItem != nil ? "最近の撮影を表示" : "撮影メディアなし")
    }

    // MARK: - Camera Flip Button

    @State private var flipButtonScale: CGFloat = 1.0

    private var cameraFlipButton: some View {
        Button {
            // Brief press feedback
            withAnimation(.easeOut(duration: DesignTokens.Motion.fast)) {
                flipButtonScale = 0.85
            }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.65).delay(DesignTokens.Motion.fast)) {
                flipRotation += 180
                flipButtonScale = 1.0
            }
            cameraViewModel.switchCamera()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 42, height: 42)

                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: DesignTokens.Typography.base, weight: DesignTokens.Typography.Weight.medium))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
            }
            .scaleEffect(flipButtonScale)
        }
        .disabled(cameraViewModel.isSwitchingCamera || cameraViewModel.isRecording)
        .opacity(cameraViewModel.isSwitchingCamera ? 0.5 : 1.0)
        .animation(.easeInOut(duration: DesignTokens.Motion.normal), value: cameraViewModel.isSwitchingCamera)
        .accessibilityIdentifier("cameraFlipButton")
        .accessibilityLabel("カメラ切替")
        .accessibilityHint("タップしてフロントカメラとバックカメラを切り替え")
    }
}
