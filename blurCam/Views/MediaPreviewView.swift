import AVKit
import SwiftUI

/// Full-screen preview for captured photos and videos.
/// Photos are displayed full-screen with aspect fit.
/// Videos show a play button and use AVPlayer for playback.
struct MediaPreviewView: View {
    let mediaItem: MediaItem
    let onDismiss: () -> Void

    /// Full-resolution image loaded asynchronously (for photos)
    @State private var fullImage: UIImage?
    /// Video player for video playback
    @State private var player: AVPlayer?
    /// Whether the video is currently playing
    @State private var isPlaying: Bool = false
    /// Loading state
    @State private var isLoading: Bool = true

    /// Injected photo repository for loading full media
    var photoRepository: PhotoRepositoryProtocol = PhotoRepository()

    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()

            // Media content
            if mediaItem.mediaType == .photo {
                photoContent
            } else {
                videoContent
            }

            // Top navigation bar
            VStack {
                topBar
                Spacer()
            }
        }
        .statusBarHidden(false)
        .preferredColorScheme(.dark)
        .onAppear {
            loadMedia()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    // MARK: - Photo Content

    private var photoContent: some View {
        Group {
            if let image = fullImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .accessibilityIdentifier("previewPhoto")
            } else if let thumbnail = mediaItem.thumbnail {
                // Show thumbnail while loading full image
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .ignoresSafeArea()
                    .blur(radius: 3)
                    .overlay {
                        if isLoading {
                            ProgressView()
                                .tint(DesignTokens.Colors.textSecondary)
                                .scaleEffect(1.1)
                        }
                    }
            } else if isLoading {
                ProgressView()
                    .tint(DesignTokens.Colors.textSecondary)
                    .scaleEffect(1.1)
            }
        }
        .animation(.easeInOut(duration: DesignTokens.Motion.normal), value: fullImage != nil)
    }

    // MARK: - Video Content

    private var videoContent: some View {
        ZStack {
            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .accessibilityIdentifier("previewVideoPlayer")
            } else if let thumbnail = mediaItem.thumbnail {
                // Show thumbnail with play button while loading
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(DesignTokens.Colors.textSecondary)
                        .scaleEffect(1.1)
                } else {
                    // Play button overlay when video URL failed to load
                    playButtonOverlay
                }
            } else if isLoading {
                ProgressView()
                    .tint(DesignTokens.Colors.textSecondary)
                    .scaleEffect(1.1)
            }

            // Play button overlay when not playing and player exists
            if player != nil && !isPlaying {
                playButtonOverlay
                    .onTapGesture {
                        startPlayback()
                    }
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: DesignTokens.Motion.normal), value: isPlaying)
    }

    private var playButtonOverlay: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 72, height: 72)
                .overlay(
                    Circle()
                        .stroke(DesignTokens.Colors.border, lineWidth: 0.5)
                )

            Image(systemName: "play.fill")
                .font(.system(size: 28, weight: DesignTokens.Typography.Weight.medium))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .offset(x: 2) // Visual centering for play icon
        }
        .shadow(color: DesignTokens.Colors.primary.opacity(0.5), radius: DesignTokens.Spacing.space4, x: 0, y: DesignTokens.Spacing.space1)
        .accessibilityIdentifier("videoPlayButton")
        .accessibilityLabel("動画を再生")
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button(action: onDismiss) {
                HStack(spacing: DesignTokens.Spacing.space1) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: DesignTokens.Typography.lg, weight: DesignTokens.Typography.Weight.semibold))
                    Text("戻る")
                        .font(.system(size: DesignTokens.Typography.base, weight: DesignTokens.Typography.Weight.medium))
                }
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .padding(.horizontal, DesignTokens.Spacing.space3)
                .padding(.vertical, DesignTokens.Spacing.space2)
                .contentShape(Rectangle())
            }
            .accessibilityIdentifier("previewBackButton")
            .accessibilityLabel("カメラに戻る")

            Spacer()
        }
        .padding(.leading, DesignTokens.Spacing.space2)
        .padding(.top, DesignTokens.Spacing.space2)
        .frame(height: 48)
        .background(
            LinearGradient(
                colors: [
                    DesignTokens.Colors.primary.opacity(0.65),
                    DesignTokens.Colors.primary.opacity(0.3),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 88)
            .allowsHitTesting(false)
        )
    }

    // MARK: - Actions

    private func loadMedia() {
        Task {
            if mediaItem.mediaType == .photo {
                if let image = mediaItem.fullImage {
                    fullImage = image
                    isLoading = false
                } else {
                    let image = await photoRepository.fetchFullImage(for: mediaItem.id)
                    await MainActor.run {
                        fullImage = image
                        isLoading = false
                    }
                }
            } else {
                if let existingURL = mediaItem.videoURL {
                    await MainActor.run {
                        setupPlayer(with: existingURL)
                        isLoading = false
                    }
                } else {
                    let url = await photoRepository.fetchVideoURL(for: mediaItem.id)
                    await MainActor.run {
                        if let url {
                            setupPlayer(with: url)
                        }
                        isLoading = false
                    }
                }
            }
        }
    }

    private func setupPlayer(with url: URL) {
        let avPlayer = AVPlayer(url: url)
        player = avPlayer

        // Observe when video ends to reset play state
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: avPlayer.currentItem,
            queue: .main
        ) { _ in
            isPlaying = false
            avPlayer.seek(to: .zero)
        }
    }

    private func startPlayback() {
        player?.play()
        isPlaying = true
    }
}
