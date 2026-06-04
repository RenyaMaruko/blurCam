import Foundation
import SwiftUI

/// ViewModel responsible for managing YouTube API-based live streaming.
/// Handles Google Sign-In authentication, broadcast/stream creation,
/// RTMP auto-connection, lifecycle management (testing->live->complete),
/// stream health monitoring, metadata updates, and thumbnail uploads.
@MainActor
final class YouTubeStreamingViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Current Google authentication state
    @Published private(set) var authState: GoogleAuthState = .signedOut

    /// Whether a YouTube API operation is in progress
    @Published private(set) var isLoading: Bool = false

    /// Error message to display
    @Published var errorMessage: String?

    /// Whether the user needs to re-authenticate
    @Published private(set) var needsReAuth: Bool = false

    /// YouTube broadcast configuration
    @Published var broadcastTitle: String = "blurCam Live"
    @Published var broadcastDescription: String = ""
    @Published var broadcastPrivacy: YouTubeBroadcastPrivacy = .unlisted

    /// Last created RTMP info (after successful setup)
    @Published private(set) var lastRTMPInfo: YouTubeRTMPInfo?

    /// Whether the YouTube setup completed and streaming can start
    @Published private(set) var isReadyToStream: Bool = false

    /// Current broadcast lifecycle status
    @Published private(set) var broadcastStatus: YouTubeBroadcastLifecycleStatus = .created

    /// Current stream health status
    @Published private(set) var streamHealth: YouTubeStreamHealthStatus = .noData

    /// Whether a noData timeout warning should be shown
    @Published private(set) var showNoDataWarning: Bool = false

    /// Whether the lifecycle is transitioning (testing->live)
    @Published private(set) var isTransitioning: Bool = false

    /// Whether metadata is being updated
    @Published private(set) var isUpdatingMetadata: Bool = false

    /// Success message after metadata update
    @Published var metadataUpdateSuccess: Bool = false

    /// Selected thumbnail image data
    @Published var selectedThumbnailData: Data?

    /// Selected thumbnail MIME type
    @Published var selectedThumbnailMimeType: String = "image/jpeg"

    /// Whether the thumbnail is being uploaded
    @Published private(set) var isUploadingThumbnail: Bool = false

    /// Whether the thumbnail upload succeeded
    @Published private(set) var thumbnailUploadSuccess: Bool = false

    /// Live chat messages from YouTube Live Chat API
    @Published private(set) var liveChatMessages: [LiveChatMessage] = []


    // MARK: - Dependencies

    private let googleAuthService: GoogleAuthServiceProtocol
    private let youTubeAPIService: YouTubeAPIServiceProtocol
    private var liveChatService: YouTubeLiveChatServiceProtocol?

    // MARK: - Lifecycle Manager

    private(set) var lifecycleManager: YouTubeBroadcastLifecycleManager?

    private let maxChatMessages = 50

    // MARK: - Initialization

    init(
        googleAuthService: GoogleAuthServiceProtocol? = nil,
        youTubeAPIService: YouTubeAPIServiceProtocol? = nil
    ) {
        let resolvedAuth = googleAuthService ?? GoogleAuthService()
        let resolvedAPI = youTubeAPIService ?? YouTubeAPIService()
        self.googleAuthService = resolvedAuth
        self.youTubeAPIService = resolvedAPI
        self.liveChatService = YouTubeLiveChatService(apiService: resolvedAPI, authService: resolvedAuth)

        setupAuthStateCallback()
    }

    // MARK: - Authentication

    /// Sign in with Google
    func signIn() async {
        errorMessage = nil
        do {
            try await googleAuthService.signIn()
        } catch let error as GoogleAuthError {
            if error != .signInCancelled {
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Sign out from Google
    func signOut() {
        googleAuthService.signOut()
        authState = .signedOut
        lastRTMPInfo = nil
        isReadyToStream = false
        needsReAuth = false
        lifecycleManager?.reset()
        lifecycleManager = nil
    }

    /// Restore previous sign-in session
    func restorePreviousSignIn() async {
        _ = await googleAuthService.restorePreviousSignIn()
    }

    // MARK: - YouTube API Operations

    /// Create a YouTube live broadcast + stream and get RTMP info.
    /// Returns the RTMP info on success.
    func setupLiveStream() async -> YouTubeRTMPInfo? {
        guard authState.isSignedIn else {
            errorMessage = GoogleAuthError.noCurrentUser.localizedDescription
            return nil
        }

        isLoading = true
        errorMessage = nil
        lastRTMPInfo = nil
        isReadyToStream = false

        defer { isLoading = false }

        do {
            let accessToken = try await googleAuthService.getAccessToken()

            let broadcastConfig = YouTubeBroadcastConfig(
                title: broadcastTitle.isEmpty ? "blurCam Live" : broadcastTitle,
                description: broadcastDescription,
                privacy: broadcastPrivacy
            )

            let streamConfig = YouTubeStreamConfig()

            let rtmpInfo = try await youTubeAPIService.setupLiveStream(
                broadcastConfig: broadcastConfig,
                streamConfig: streamConfig,
                accessToken: accessToken
            )

            lastRTMPInfo = rtmpInfo
            isReadyToStream = true

            // Set up lifecycle manager
            let manager = YouTubeBroadcastLifecycleManager(
                apiService: youTubeAPIService,
                authService: googleAuthService
            )
            manager.delegate = self
            manager.configure(broadcastId: rtmpInfo.broadcastId, streamId: rtmpInfo.streamId)
            self.lifecycleManager = manager

            // Upload thumbnail if selected (non-blocking: errors shown but don't prevent streaming)
            if let thumbnailData = selectedThumbnailData {
                Task {
                    await uploadThumbnailForBroadcast(
                        broadcastId: rtmpInfo.broadcastId,
                        imageData: thumbnailData,
                        mimeType: selectedThumbnailMimeType
                    )
                }
            }

            return rtmpInfo

        } catch let error as GoogleAuthError {
            handleAuthError(error)
            return nil
        } catch let error as YouTubeAPIError {
            handleAPIError(error)
            return nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Lifecycle Management

    /// Start the broadcast lifecycle (testing -> live) after RTMP connection is established
    func startBroadcastLifecycle() {
        guard let manager = lifecycleManager else { return }

        isTransitioning = true
        Task {
            do {
                try await manager.startLifecycle()
                isTransitioning = false
            } catch {
                isTransitioning = false
                errorMessage = error.localizedDescription
            }
        }

        // Start live chat polling
        if let broadcastId = manager.broadcastId {
            startLiveChatPolling(broadcastId: broadcastId)
        }
    }

    /// Complete the broadcast (called when stopping streaming)
    func completeBroadcast() {
        guard let manager = lifecycleManager else { return }

        stopLiveChatPolling()

        Task {
            await manager.completeBroadcast()
            broadcastStatus = .complete
            streamHealth = .noData
            showNoDataWarning = false
            isReadyToStream = false
        }
    }

    /// Stop monitoring (called when RTMP streaming stops)
    func stopLifecycleMonitoring() {
        lifecycleManager?.stopMonitoring()
        streamHealth = .noData
        showNoDataWarning = false
        stopLiveChatPolling()
    }

    // MARK: - Live Chat

    private func startLiveChatPolling(broadcastId: String) {
        print("[LiveChat-YT] Starting for broadcast: \(broadcastId)")
        guard let chatService = liveChatService else {
            print("[LiveChat-YT] No chat service")
            return
        }

        chatService.onNewMessages = { [weak self] newMessages in
            print("[LiveChat-YT] Received \(newMessages.count) messages")
            guard let self else { return }
            self.liveChatMessages.append(contentsOf: newMessages)
            if self.liveChatMessages.count > self.maxChatMessages {
                self.liveChatMessages = Array(self.liveChatMessages.suffix(self.maxChatMessages))
            }
        }

        chatService.onError = { error in
            print("[LiveChat-YT] Error: \(error)")
        }

        Task {
            do {
                let accessToken = try await googleAuthService.getAccessToken()
                print("[LiveChat-YT] Got token, calling startPolling...")
                try await chatService.startPolling(broadcastId: broadcastId, accessToken: accessToken)
                print("[LiveChat-YT] Polling started successfully")
            } catch {
                print("[LiveChat-YT] Failed to start: \(error)")
            }
        }
    }

    private func stopLiveChatPolling() {
        liveChatService?.stopPolling()
        liveChatMessages.removeAll()
    }

    // MARK: - Metadata Update

    /// Update the broadcast title and description during streaming
    func updateMetadata(title: String, description: String) async {
        guard let manager = lifecycleManager else {
            errorMessage = "配信が開始されていません"
            return
        }

        isUpdatingMetadata = true
        metadataUpdateSuccess = false
        errorMessage = nil

        do {
            try await manager.updateMetadata(title: title, description: description)
            broadcastTitle = title
            broadcastDescription = description
            metadataUpdateSuccess = true
            isUpdatingMetadata = false
        } catch {
            errorMessage = error.localizedDescription
            isUpdatingMetadata = false
        }
    }

    // MARK: - Thumbnail

    /// Upload a thumbnail for the current broadcast
    private func uploadThumbnailForBroadcast(broadcastId: String, imageData: Data, mimeType: String) async {
        isUploadingThumbnail = true
        thumbnailUploadSuccess = false

        do {
            let accessToken = try await googleAuthService.getAccessToken()
            try await youTubeAPIService.uploadThumbnail(
                broadcastId: broadcastId,
                imageData: imageData,
                mimeType: mimeType,
                accessToken: accessToken
            )
            thumbnailUploadSuccess = true
            isUploadingThumbnail = false
        } catch {
            // Thumbnail upload failure is non-fatal
            errorMessage = error.localizedDescription
            isUploadingThumbnail = false
        }
    }

    // MARK: - Error Handling

    private func handleAuthError(_ error: GoogleAuthError) {
        errorMessage = error.localizedDescription
        if case .tokenRefreshFailed = error {
            needsReAuth = true
        } else if case .noCurrentUser = error {
            needsReAuth = true
        }
    }

    private func handleAPIError(_ error: YouTubeAPIError) {
        errorMessage = error.localizedDescription

        switch error.category {
        case .authentication:
            needsReAuth = true
        case .network, .quota, .other:
            break
        }
    }

    // MARK: - Private Methods

    private func setupAuthStateCallback() {
        googleAuthService.onAuthStateChanged = { [weak self] newState in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.authState = newState
                self.needsReAuth = self.googleAuthService.needsReAuthentication
            }
        }
        // Set initial state
        authState = googleAuthService.authState
    }
}

// MARK: - YouTubeBroadcastLifecycleDelegate

extension YouTubeStreamingViewModel: YouTubeBroadcastLifecycleDelegate {

    nonisolated func lifecycleManager(_ manager: YouTubeBroadcastLifecycleManager, didUpdateStreamHealth health: YouTubeStreamHealthStatus) {
        Task { @MainActor in
            self.streamHealth = health
            if health != .noData {
                self.showNoDataWarning = false
            }
        }
    }

    nonisolated func lifecycleManager(_ manager: YouTubeBroadcastLifecycleManager, didUpdateBroadcastStatus status: YouTubeBroadcastLifecycleStatus) {
        Task { @MainActor in
            self.broadcastStatus = status
        }
    }

    nonisolated func lifecycleManager(_ manager: YouTubeBroadcastLifecycleManager, didEncounterError error: Error) {
        Task { @MainActor in
            // Only show error if it's not a polling error during active streaming
            if self.broadcastStatus != .live {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    nonisolated func lifecycleManagerDidDetectNoDataTimeout(_ manager: YouTubeBroadcastLifecycleManager) {
        Task { @MainActor in
            self.showNoDataWarning = true
        }
    }
}
