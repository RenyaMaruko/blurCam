import XCTest
@testable import blurCam

/// Integration tests for Sprint 13: YouTube End-to-End Streaming Flow,
/// Error Handling, Coexistence with Manual RTMP, and Background/Lifecycle.
@MainActor
final class Sprint13IntegrationTests: XCTestCase {

    // MARK: - Dependencies

    private var mockCameraService: MockCameraService!
    private var mockPhotoRepo: MockPhotoRepository!
    private var mockPermissionRepo: MockPermissionRepository!
    private var mockFaceRepo: MockFaceRepository!
    private var mockVideoFrameProcessor: MockVideoFrameProcessor!
    private var mockVideoRecordingService: MockVideoRecordingService!
    private var mockStreamingService: MockStreamingService!
    private var mockStreamingSettingsRepo: MockStreamingSettingsRepository!
    private var mockGoogleAuthService: MockGoogleAuthService!
    private var mockYouTubeAPIService: MockYouTubeAPIService!
    private var mockYouTubeLiveSettingsRepo: MockYouTubeLiveSettingsRepository!

    override func setUp() {
        super.setUp()
        mockCameraService = MockCameraService()
        mockPhotoRepo = MockPhotoRepository()
        mockPermissionRepo = MockPermissionRepository()
        mockFaceRepo = MockFaceRepository()
        mockVideoFrameProcessor = MockVideoFrameProcessor()
        mockVideoRecordingService = MockVideoRecordingService()
        mockStreamingService = MockStreamingService()
        mockStreamingSettingsRepo = MockStreamingSettingsRepository()
        mockGoogleAuthService = MockGoogleAuthService()
        mockYouTubeAPIService = MockYouTubeAPIService()
        mockYouTubeLiveSettingsRepo = MockYouTubeLiveSettingsRepository()
    }

    override func tearDown() {
        mockCameraService = nil
        mockPhotoRepo = nil
        mockPermissionRepo = nil
        mockFaceRepo = nil
        mockVideoFrameProcessor = nil
        mockVideoRecordingService = nil
        mockStreamingService = nil
        mockStreamingSettingsRepo = nil
        mockGoogleAuthService = nil
        mockYouTubeAPIService = nil
        mockYouTubeLiveSettingsRepo = nil
        super.tearDown()
    }

    private func makeCameraViewModel() -> CameraViewModel {
        CameraViewModel(
            cameraService: mockCameraService,
            photoRepository: mockPhotoRepo,
            permissionRepository: mockPermissionRepo,
            faceRepository: mockFaceRepo,
            videoFrameProcessor: mockVideoFrameProcessor,
            videoRecordingService: mockVideoRecordingService,
            streamingService: mockStreamingService,
            streamingSettingsRepository: mockStreamingSettingsRepo,
            googleAuthService: mockGoogleAuthService,
            youTubeAPIService: mockYouTubeAPIService,
            youTubeLiveSettingsRepository: mockYouTubeLiveSettingsRepo
        )
    }

    /// Helper: sets up a YouTube destination and selects it
    private func setupYouTubeDestination() {
        let dest = StreamingDestination(
            name: "YouTube Live",
            platform: .youTube,
            rtmpURL: "rtmp://a.rtmp.youtube.com/live2",
            streamKey: ""
        )
        mockStreamingSettingsRepo.destinations = [dest]
        mockStreamingSettingsRepo._selectedDestinationId = dest.id
    }

    /// Helper: sets up a Twitch destination and selects it
    private func setupTwitchDestination() {
        let dest = StreamingDestination(
            name: "Twitch Channel",
            platform: .twitch,
            rtmpURL: "rtmp://live.twitch.tv/app",
            streamKey: "twitch-key-abc123"
        )
        mockStreamingSettingsRepo.destinations = [dest]
        mockStreamingSettingsRepo._selectedDestinationId = dest.id
    }

    /// Helper: sets up a custom RTMP destination and selects it
    private func setupCustomRTMPDestination() {
        let dest = StreamingDestination(
            name: "Custom Server",
            platform: .custom,
            rtmpURL: "rtmp://custom.example.com/live",
            streamKey: "custom-key-xyz"
        )
        mockStreamingSettingsRepo.destinations = [dest]
        mockStreamingSettingsRepo._selectedDestinationId = dest.id
    }

    /// Helper: signs in with mock Google auth
    private func signInGoogle() {
        mockGoogleAuthService.authState = .signedIn(
            GoogleUserInfo(displayName: "Test User", email: "test@gmail.com", profileImageURL: nil)
        )
    }

    /// Helper: sets up YouTube live settings
    private func setupYouTubeLiveSettings(title: String = "blurCam Live") {
        mockYouTubeLiveSettingsRepo.savedSettings = YouTubeLiveSettings(
            title: title,
            description: "Test broadcast",
            privacy: .privateBroadcast
        )
    }

    // MARK: - End-to-End YouTube API Flow Tests

    func testYouTubeAPIFlow_cameraButton_fullAutoFlow() async {
        // Setup: YouTube destination selected, signed in, live settings configured
        setupYouTubeDestination()
        signInGoogle()
        setupYouTubeLiveSettings()
        let viewModel = makeCameraViewModel()

        // Act: press camera streaming button
        viewModel.startStreaming()

        // Wait for async YouTube API setup
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Assert: YouTube API was called to create broadcast/stream
        XCTAssertEqual(mockYouTubeAPIService.setupLiveStreamCallCount, 1, "YouTube API should create broadcast and stream")

        // Assert: RTMP streaming was started with auto-obtained URL/key
        XCTAssertEqual(mockStreamingService.startStreamingCallCount, 1, "RTMP should start")
        XCTAssertEqual(mockStreamingService.startStreamingURL, "rtmp://a.rtmp.youtube.com/live2")
        XCTAssertEqual(mockStreamingService.startStreamingStreamKey, "mock-stream-key-abc123")

        // Assert: session is marked as YouTube API
        XCTAssertTrue(viewModel.isYouTubeAPISession, "Should be YouTube API session")
    }

    func testYouTubeAPIFlow_showsConnectingState_duringSetup() async {
        setupYouTubeDestination()
        signInGoogle()
        setupYouTubeLiveSettings()

        // Make API call slow (do NOT use override)
        mockStreamingService.simulateSuccessfulConnection = false
        let viewModel = makeCameraViewModel()

        viewModel.startStreaming()

        // Should immediately show connecting
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(viewModel.streamingState, .connecting, "Should show connecting during API setup")
    }

    func testYouTubeAPIFlow_progressMessage_duringSetup() async {
        setupYouTubeDestination()
        signInGoogle()
        setupYouTubeLiveSettings()
        let viewModel = makeCameraViewModel()

        // Start streaming (async)
        viewModel.startStreaming()

        // After completion, progress message should be cleared
        try? await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertNil(viewModel.youTubeSetupProgressMessage, "Progress message should be cleared after setup")
    }

    func testYouTubeAPIFlow_liveIndicator_afterConnection() async {
        setupYouTubeDestination()
        signInGoogle()
        setupYouTubeLiveSettings()
        let viewModel = makeCameraViewModel()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 500_000_000)

        // After successful connection, streaming state should be .streaming
        XCTAssertEqual(viewModel.streamingState, .streaming, "Should be streaming after RTMP connect")
        XCTAssertTrue(viewModel.isStreaming, "isStreaming should be true")
    }

    func testYouTubeAPIFlow_stopButton_showsConfirmation() async {
        setupYouTubeDestination()
        signInGoogle()
        setupYouTubeLiveSettings()
        let viewModel = makeCameraViewModel()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Request stop
        viewModel.requestStopStreaming()
        XCTAssertTrue(viewModel.showStopStreamingConfirmation, "Should show stop confirmation dialog")
    }

    func testYouTubeAPIFlow_stopStreaming_transitionsBroadcastToComplete() async {
        setupYouTubeDestination()
        signInGoogle()
        setupYouTubeLiveSettings()
        let viewModel = makeCameraViewModel()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Stop streaming
        viewModel.stopStreaming()
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Verify broadcast was transitioned to complete
        let completeTransitions = mockYouTubeAPIService.transitionStatuses.filter { $0 == "complete" }
        XCTAssertFalse(completeTransitions.isEmpty, "Should transition broadcast to 'complete' on stop")

        // Verify state is idle
        XCTAssertEqual(viewModel.streamingState, .idle, "Should be idle after stop")
        XCTAssertFalse(viewModel.isYouTubeAPISession, "YouTube API session flag should be cleared")
    }

    func testYouTubeAPIFlow_lifecycleManager_isConfigured() async {
        setupYouTubeDestination()
        signInGoogle()
        setupYouTubeLiveSettings()
        let viewModel = makeCameraViewModel()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Internal lifecycle manager should be set
        // (We can't directly check it since it's private, but we can verify
        // the broadcast lifecycle transitions happened)
        let testingTransitions = mockYouTubeAPIService.transitionStatuses.filter { $0 == "testing" }
        let liveTransitions = mockYouTubeAPIService.transitionStatuses.filter { $0 == "live" }

        // If simulateSuccessfulConnection is true (default), streaming callback fires,
        // which triggers startInternalBroadcastLifecycle, which calls testing then live
        // Need to wait for the 3-second delay in startLifecycle
        try? await Task.sleep(nanoseconds: 4_000_000_000)

        let testingCount = mockYouTubeAPIService.transitionStatuses.filter { $0 == "testing" }.count
        let liveCount = mockYouTubeAPIService.transitionStatuses.filter { $0 == "live" }.count
        XCTAssertGreaterThanOrEqual(testingCount, 1, "Should transition to 'testing'")
        XCTAssertGreaterThanOrEqual(liveCount, 1, "Should transition to 'live'")
    }

    // MARK: - Error Handling Tests

    func testError_notLoggedIn_showsLoginMessage() {
        // YouTube destination with NO manual stream key (empty key)
        setupYouTubeDestination()
        // NOT signed in
        mockGoogleAuthService.authState = .signedOut
        setupYouTubeLiveSettings()
        let viewModel = makeCameraViewModel()

        viewModel.startStreaming()

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(
            viewModel.errorMessage?.contains("Googleアカウントにログインしてください") ?? false,
            "Should show login message, got: \(viewModel.errorMessage ?? "nil")"
        )
        XCTAssertEqual(mockStreamingService.startStreamingCallCount, 0, "Should not attempt streaming")
    }

    func testYouTubeDestination_withManualStreamKey_notSignedIn_fallsToManualRTMP() async {
        // YouTube destination WITH manual stream key but NOT signed in
        let dest = StreamingDestination(
            name: "YouTube Manual",
            platform: .youTube,
            rtmpURL: "rtmp://a.rtmp.youtube.com/live2",
            streamKey: "manual-stream-key-123"
        )
        mockStreamingSettingsRepo.destinations = [dest]
        mockStreamingSettingsRepo._selectedDestinationId = dest.id
        mockGoogleAuthService.authState = .signedOut
        let viewModel = makeCameraViewModel()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Should fall to manual RTMP (backward compatible)
        XCTAssertEqual(mockYouTubeAPIService.setupLiveStreamCallCount, 0, "Should not use YouTube API")
        XCTAssertEqual(mockStreamingService.startStreamingCallCount, 1, "Should use manual RTMP")
        XCTAssertEqual(mockStreamingService.startStreamingStreamKey, "manual-stream-key-123")
    }

    func testError_networkError_showsNetworkMessage() async {
        setupYouTubeDestination()
        signInGoogle()
        setupYouTubeLiveSettings()

        // Configure API to fail with network error
        mockYouTubeAPIService.setupLiveStreamResult = .failure(YouTubeAPIError.networkError("timeout"))
        let viewModel = makeCameraViewModel()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(
            viewModel.errorMessage?.contains("ネットワーク接続を確認してください") ?? false,
            "Should show network error message, got: \(viewModel.errorMessage ?? "nil")"
        )
        XCTAssertEqual(viewModel.streamingState, .idle, "Should revert to idle")
    }

    func testError_quotaExceeded_showsQuotaMessage() async {
        setupYouTubeDestination()
        signInGoogle()
        setupYouTubeLiveSettings()

        mockYouTubeAPIService.setupLiveStreamResult = .failure(YouTubeAPIError.quotaExceeded)
        let viewModel = makeCameraViewModel()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(
            viewModel.errorMessage?.contains("YouTube APIの利用制限に達しました") ?? false,
            "Should show quota exceeded message, got: \(viewModel.errorMessage ?? "nil")"
        )
    }

    func testError_tokenRefreshFailed_showsReLoginMessage() async {
        setupYouTubeDestination()
        signInGoogle()
        setupYouTubeLiveSettings()

        // Token refresh fails
        mockGoogleAuthService.getAccessTokenError = GoogleAuthError.tokenRefreshFailed("expired")
        let viewModel = makeCameraViewModel()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(
            viewModel.errorMessage?.contains("再ログインが必要です") ?? false,
            "Should show re-login message, got: \(viewModel.errorMessage ?? "nil")"
        )
    }

    func testError_transitionFailure_keepsRTMPAlive() async {
        setupYouTubeDestination()
        signInGoogle()
        setupYouTubeLiveSettings()

        // Make transition fail (testing -> live fails)
        mockYouTubeAPIService.transitionBroadcastResult = .failure(
            YouTubeAPIError.transitionFailed("Broadcast not ready")
        )
        let viewModel = makeCameraViewModel()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 500_000_000)

        // RTMP should be streaming (connected successfully)
        XCTAssertEqual(viewModel.streamingState, .streaming,
                       "RTMP should still be streaming even if broadcast transition fails")

        // Wait for lifecycle transition attempt
        try? await Task.sleep(nanoseconds: 4_000_000_000)

        // Error message should be shown
        XCTAssertNotNil(viewModel.errorMessage, "Should show transition error message")

        // RTMP should STILL be streaming (connection maintained for retry)
        XCTAssertEqual(viewModel.streamingState, .streaming,
                       "RTMP should remain streaming after transition failure")
    }

    // MARK: - Coexistence with Manual RTMP Tests

    func testManualRTMP_twitchDestination_directConnect() async {
        setupTwitchDestination()
        let viewModel = makeCameraViewModel()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 200_000_000)

        // YouTube API should NOT be called
        XCTAssertEqual(mockYouTubeAPIService.setupLiveStreamCallCount, 0, "Should not call YouTube API for Twitch")

        // Manual RTMP should be used directly
        XCTAssertEqual(mockStreamingService.startStreamingCallCount, 1, "Should start RTMP directly")
        XCTAssertEqual(mockStreamingService.startStreamingURL, "rtmp://live.twitch.tv/app")
        XCTAssertEqual(mockStreamingService.startStreamingStreamKey, "twitch-key-abc123")
        XCTAssertFalse(viewModel.isYouTubeAPISession, "Should NOT be YouTube API session")
    }

    func testManualRTMP_customDestination_directConnect() async {
        setupCustomRTMPDestination()
        let viewModel = makeCameraViewModel()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(mockYouTubeAPIService.setupLiveStreamCallCount, 0, "Should not call YouTube API for custom")
        XCTAssertEqual(mockStreamingService.startStreamingCallCount, 1, "Should start RTMP directly")
        XCTAssertEqual(mockStreamingService.startStreamingURL, "rtmp://custom.example.com/live")
        XCTAssertEqual(mockStreamingService.startStreamingStreamKey, "custom-key-xyz")
    }

    func testSwitchBetween_YouTubeAndTwitch() async {
        // Start with YouTube
        setupYouTubeDestination()
        signInGoogle()
        setupYouTubeLiveSettings()
        let viewModel = makeCameraViewModel()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertTrue(viewModel.isYouTubeAPISession)
        viewModel.stopStreaming()
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Now switch to Twitch destination
        let twitchDest = StreamingDestination(
            name: "Twitch",
            platform: .twitch,
            rtmpURL: "rtmp://live.twitch.tv/app",
            streamKey: "twitch-key"
        )
        mockStreamingSettingsRepo.destinations.append(twitchDest)
        mockStreamingSettingsRepo._selectedDestinationId = twitchDest.id

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertFalse(viewModel.isYouTubeAPISession, "Should NOT be YouTube API session for Twitch")
        XCTAssertEqual(mockStreamingService.startStreamingStreamKey, "twitch-key")
    }

    func testManualRTMP_addEditDeleteDestination_works() {
        // Verify destination management is not broken by Sprint 13 changes
        let repo = MockStreamingSettingsRepository()

        // Add
        let dest = StreamingDestination(
            name: "Test",
            platform: .twitch,
            rtmpURL: "rtmp://live.twitch.tv/app",
            streamKey: "key123"
        )
        repo.saveDestination(dest)
        XCTAssertEqual(repo.destinations.count, 1)
        XCTAssertEqual(repo.destinations.first?.name, "Test")

        // Edit
        let updated = StreamingDestination(
            id: dest.id,
            name: "Updated",
            platform: .twitch,
            rtmpURL: "rtmp://live.twitch.tv/app",
            streamKey: "newkey",
            createdAt: dest.createdAt
        )
        repo.saveDestination(updated)
        XCTAssertEqual(repo.destinations.count, 1)
        XCTAssertEqual(repo.destinations.first?.name, "Updated")

        // Delete
        repo.deleteDestination(id: dest.id)
        XCTAssertEqual(repo.destinations.count, 0)
    }

    func testRecording_blocksYouTubeStreaming() async {
        setupYouTubeDestination()
        signInGoogle()
        setupYouTubeLiveSettings()
        mockPermissionRepo.microphoneStatus = .authorized
        let viewModel = makeCameraViewModel()

        // Start recording
        await viewModel.startRecording()
        XCTAssertTrue(viewModel.isRecording)

        // Try to start YouTube streaming
        viewModel.startStreaming()

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(
            viewModel.errorMessage?.contains("録画中は配信を開始できません") ?? false,
            "Should show mutual exclusion message"
        )
        XCTAssertEqual(mockYouTubeAPIService.setupLiveStreamCallCount, 0)
    }

    // MARK: - Background / Lifecycle Tests

    func testBackground_stopsYouTubeStreaming_completeBroadcast() async {
        setupYouTubeDestination()
        signInGoogle()
        setupYouTubeLiveSettings()
        let viewModel = makeCameraViewModel()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertTrue(viewModel.isYouTubeAPISession)

        // Simulate background transition by calling stopStreaming directly
        // (handleBackgroundTransition calls stopStreaming)
        viewModel.stopStreaming()
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Broadcast should be transitioned to complete
        let completeTransitions = mockYouTubeAPIService.transitionStatuses.filter { $0 == "complete" }
        XCTAssertFalse(completeTransitions.isEmpty, "Background should complete the YouTube broadcast")

        // State should be idle
        XCTAssertEqual(viewModel.streamingState, .idle)
        XCTAssertFalse(viewModel.isYouTubeAPISession)
    }

    func testForeground_resetsStateAfterBackgroundStop() async {
        setupYouTubeDestination()
        signInGoogle()
        setupYouTubeLiveSettings()
        let viewModel = makeCameraViewModel()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Simulate background stop
        viewModel.stopStreaming()
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Verify foreground state is properly reset
        XCTAssertEqual(viewModel.streamingState, .idle, "Should be idle after background stop")
        XCTAssertFalse(viewModel.isYouTubeAPISession, "YouTube session flag should be cleared")
        XCTAssertNil(viewModel.youTubeSetupProgressMessage, "Progress message should be nil")
    }

    // MARK: - Edge Case Tests

    func testYouTubeDestination_emptyTitle_fallsToManualRTMP() async {
        setupYouTubeDestination()
        signInGoogle()
        // Settings with empty title
        mockYouTubeLiveSettingsRepo.savedSettings = YouTubeLiveSettings(
            title: "",
            description: "",
            privacy: .privateBroadcast
        )

        // Update the destination to have valid RTMP details (for fallback)
        let dest = StreamingDestination(
            name: "YouTube Manual",
            platform: .youTube,
            rtmpURL: "rtmp://a.rtmp.youtube.com/live2",
            streamKey: "manual-key-123"
        )
        mockStreamingSettingsRepo.destinations = [dest]
        mockStreamingSettingsRepo._selectedDestinationId = dest.id

        let viewModel = makeCameraViewModel()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Should fall to manual RTMP (not YouTube API)
        XCTAssertEqual(mockYouTubeAPIService.setupLiveStreamCallCount, 0, "Should not use YouTube API with empty title")
        XCTAssertEqual(mockStreamingService.startStreamingCallCount, 1, "Should use manual RTMP")
        XCTAssertEqual(mockStreamingService.startStreamingStreamKey, "manual-key-123")
    }

    func testYouTubeAPIFlow_stopCalledMultipleTimes_noDoubleComplete() async {
        setupYouTubeDestination()
        signInGoogle()
        setupYouTubeLiveSettings()
        let viewModel = makeCameraViewModel()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Stop twice
        viewModel.stopStreaming()
        viewModel.stopStreaming()
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Should only try to complete once (second call should be no-op since isYouTubeAPISession is cleared)
        let completeTransitions = mockYouTubeAPIService.transitionStatuses.filter { $0 == "complete" }
        XCTAssertEqual(completeTransitions.count, 1, "Should only complete broadcast once")
    }

    func testExplicitURLStreaming_withYouTubeAPIFlag() async {
        let viewModel = makeCameraViewModel()

        // Use the explicit URL method with YouTube API flag
        viewModel.startStreaming(url: "rtmp://a.rtmp.youtube.com/live2", streamKey: "explicit-key", isYouTubeAPI: true)
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertTrue(viewModel.isYouTubeAPISession, "Should be YouTube API session")
        XCTAssertEqual(mockStreamingService.startStreamingCallCount, 1)
    }

    func testManualRTMP_legacyFallback_stillWorks() async {
        // No destinations saved, but legacy URL exists
        mockStreamingSettingsRepo.rtmpURL = "rtmp://legacy.server.com/live"
        mockStreamingSettingsRepo.streamKey = "legacy-key"
        let viewModel = makeCameraViewModel()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(mockStreamingService.startStreamingCallCount, 1)
        XCTAssertEqual(mockStreamingService.startStreamingURL, "rtmp://legacy.server.com/live")
        XCTAssertEqual(mockStreamingService.startStreamingStreamKey, "legacy-key")
    }

    func testStreamingDuration_trackedDuringYouTubeSession() async {
        setupYouTubeDestination()
        signInGoogle()
        setupYouTubeLiveSettings()
        let viewModel = makeCameraViewModel()

        viewModel.startStreaming()
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

        // Duration should be tracked
        XCTAssertGreaterThan(viewModel.streamingDuration, 0, "Duration should be tracked during YouTube streaming")

        viewModel.stopStreaming()
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Duration should be reset
        XCTAssertEqual(viewModel.streamingDuration, 0, "Duration should be reset after stop")
    }

    func testFormattedStreamingDuration_format() {
        let viewModel = makeCameraViewModel()

        // Test HH:MM:SS format
        XCTAssertEqual(viewModel.formattedStreamingDuration, "00:00:00")
    }

    func testStartStreamingWithExplicitURL_whileRecording_blocksWithMessage() async {
        mockPermissionRepo.microphoneStatus = .authorized
        let viewModel = makeCameraViewModel()

        await viewModel.startRecording()
        XCTAssertTrue(viewModel.isRecording)

        viewModel.startStreaming(url: "rtmp://test.com/live", streamKey: "key")

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(
            viewModel.errorMessage?.contains("録画中は配信を開始できません") ?? false
        )
        XCTAssertEqual(mockStreamingService.startStreamingCallCount, 0)
    }
}

// MARK: - YouTubeStreamingViewModel Integration Tests for Sprint 13

@MainActor
final class Sprint13YouTubeStreamingVMTests: XCTestCase {

    private var mockAuthService: MockGoogleAuthService!
    private var mockAPIService: MockYouTubeAPIService!
    private var streamingVM: YouTubeStreamingViewModel!

    override func setUp() {
        super.setUp()
        mockAuthService = MockGoogleAuthService()
        mockAPIService = MockYouTubeAPIService()
        streamingVM = YouTubeStreamingViewModel(
            googleAuthService: mockAuthService,
            youTubeAPIService: mockAPIService
        )
    }

    override func tearDown() {
        streamingVM = nil
        mockAuthService = nil
        mockAPIService = nil
        super.tearDown()
    }

    // MARK: - Authentication Error Tests

    func testSetupLiveStream_notSignedIn_showsError() async {
        // Not signed in
        mockAuthService.authState = .signedOut

        let result = await streamingVM.setupLiveStream()

        XCTAssertNil(result, "Should not return RTMP info when not signed in")
        XCTAssertNotNil(streamingVM.errorMessage, "Should show error message")
    }

    func testSetupLiveStream_tokenRefreshFailed_showsReAuthNeeded() async {
        await streamingVM.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Token refresh fails
        mockAuthService.getAccessTokenError = GoogleAuthError.tokenRefreshFailed("Token expired")

        let result = await streamingVM.setupLiveStream()

        XCTAssertNil(result)
        XCTAssertTrue(streamingVM.needsReAuth, "Should set needsReAuth flag")
        XCTAssertNotNil(streamingVM.errorMessage)
    }

    // MARK: - API Error Tests

    func testSetupLiveStream_networkError() async {
        await streamingVM.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)

        mockAPIService.setupLiveStreamResult = .failure(YouTubeAPIError.networkError("Connection refused"))

        let result = await streamingVM.setupLiveStream()

        XCTAssertNil(result)
        XCTAssertNotNil(streamingVM.errorMessage)
        XCTAssertFalse(streamingVM.isReadyToStream)
    }

    func testSetupLiveStream_quotaExceeded() async {
        await streamingVM.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)

        mockAPIService.setupLiveStreamResult = .failure(YouTubeAPIError.quotaExceeded)

        let result = await streamingVM.setupLiveStream()

        XCTAssertNil(result)
        XCTAssertNotNil(streamingVM.errorMessage)
    }

    func testSetupLiveStream_authError_setsNeedsReAuth() async {
        await streamingVM.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)

        mockAPIService.setupLiveStreamResult = .failure(YouTubeAPIError.authenticationError("Invalid token"))

        let result = await streamingVM.setupLiveStream()

        XCTAssertNil(result)
        XCTAssertTrue(streamingVM.needsReAuth, "Auth errors should set needsReAuth")
    }

    // MARK: - Lifecycle Transition Error Tests

    func testTransitionError_doesNotResetReadyState() async {
        await streamingVM.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)

        let rtmpInfo = await streamingVM.setupLiveStream()
        XCTAssertNotNil(rtmpInfo)
        XCTAssertTrue(streamingVM.isReadyToStream)

        // Simulate transition failure
        mockAPIService.transitionBroadcastResult = .failure(
            YouTubeAPIError.transitionFailed("Not ready")
        )

        streamingVM.startBroadcastLifecycle()
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        // Should show error but RTMP info should still be available
        XCTAssertNotNil(streamingVM.errorMessage)
        XCTAssertNotNil(streamingVM.lastRTMPInfo, "RTMP info should remain for retry")
    }

    // MARK: - Complete Broadcast Tests

    func testCompleteBroadcast_resetsState() async {
        await streamingVM.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)
        _ = await streamingVM.setupLiveStream()

        streamingVM.completeBroadcast()
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(streamingVM.broadcastStatus, .complete)
        XCTAssertFalse(streamingVM.isReadyToStream)
    }
}

// MARK: - Error Message Mapping Tests

@MainActor
final class Sprint13ErrorMappingTests: XCTestCase {

    private var mockCameraService: MockCameraService!
    private var mockPhotoRepo: MockPhotoRepository!
    private var mockPermissionRepo: MockPermissionRepository!
    private var mockFaceRepo: MockFaceRepository!
    private var mockVideoFrameProcessor: MockVideoFrameProcessor!
    private var mockVideoRecordingService: MockVideoRecordingService!
    private var mockStreamingService: MockStreamingService!
    private var mockStreamingSettingsRepo: MockStreamingSettingsRepository!
    private var mockGoogleAuthService: MockGoogleAuthService!
    private var mockYouTubeAPIService: MockYouTubeAPIService!
    private var mockYouTubeLiveSettingsRepo: MockYouTubeLiveSettingsRepository!

    override func setUp() {
        super.setUp()
        mockCameraService = MockCameraService()
        mockPhotoRepo = MockPhotoRepository()
        mockPermissionRepo = MockPermissionRepository()
        mockFaceRepo = MockFaceRepository()
        mockVideoFrameProcessor = MockVideoFrameProcessor()
        mockVideoRecordingService = MockVideoRecordingService()
        mockStreamingService = MockStreamingService()
        mockStreamingSettingsRepo = MockStreamingSettingsRepository()
        mockGoogleAuthService = MockGoogleAuthService()
        mockYouTubeAPIService = MockYouTubeAPIService()
        mockYouTubeLiveSettingsRepo = MockYouTubeLiveSettingsRepository()
    }

    override func tearDown() {
        mockCameraService = nil
        mockPhotoRepo = nil
        mockPermissionRepo = nil
        mockFaceRepo = nil
        mockVideoFrameProcessor = nil
        mockVideoRecordingService = nil
        mockStreamingService = nil
        mockStreamingSettingsRepo = nil
        mockGoogleAuthService = nil
        mockYouTubeAPIService = nil
        mockYouTubeLiveSettingsRepo = nil
        super.tearDown()
    }

    private func makeCameraViewModel() -> CameraViewModel {
        CameraViewModel(
            cameraService: mockCameraService,
            photoRepository: mockPhotoRepo,
            permissionRepository: mockPermissionRepo,
            faceRepository: mockFaceRepo,
            videoFrameProcessor: mockVideoFrameProcessor,
            videoRecordingService: mockVideoRecordingService,
            streamingService: mockStreamingService,
            streamingSettingsRepository: mockStreamingSettingsRepo,
            googleAuthService: mockGoogleAuthService,
            youTubeAPIService: mockYouTubeAPIService,
            youTubeLiveSettingsRepository: mockYouTubeLiveSettingsRepo
        )
    }

    private func setupYouTubeAndSignIn() {
        let dest = StreamingDestination(
            name: "YouTube",
            platform: .youTube,
            rtmpURL: "rtmp://a.rtmp.youtube.com/live2",
            streamKey: ""
        )
        mockStreamingSettingsRepo.destinations = [dest]
        mockStreamingSettingsRepo._selectedDestinationId = dest.id
        mockGoogleAuthService.authState = .signedIn(
            GoogleUserInfo(displayName: "Test", email: "t@g.com", profileImageURL: nil)
        )
        mockYouTubeLiveSettingsRepo.savedSettings = YouTubeLiveSettings(title: "Test")
    }

    func testNetworkError_message() async {
        setupYouTubeAndSignIn()
        mockYouTubeAPIService.setupLiveStreamResult = .failure(
            YouTubeAPIError.networkError("connection refused")
        )
        let vm = makeCameraViewModel()

        vm.startStreaming()
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(vm.errorMessage, "ネットワーク接続を確認してください")
    }

    func testQuotaExceeded_message() async {
        setupYouTubeAndSignIn()
        mockYouTubeAPIService.setupLiveStreamResult = .failure(YouTubeAPIError.quotaExceeded)
        let vm = makeCameraViewModel()

        vm.startStreaming()
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(
            vm.errorMessage,
            "YouTube APIの利用制限に達しました。しばらくしてから再度お試しください。"
        )
    }

    func testAuthError_message() async {
        setupYouTubeAndSignIn()
        mockYouTubeAPIService.setupLiveStreamResult = .failure(
            YouTubeAPIError.authenticationError("invalid token")
        )
        let vm = makeCameraViewModel()

        vm.startStreaming()
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertTrue(
            vm.errorMessage?.contains("再ログインが必要です") ?? false,
            "Auth error should mention re-login, got: \(vm.errorMessage ?? "nil")"
        )
    }

    func testTokenRefreshFailed_message() async {
        setupYouTubeAndSignIn()
        mockGoogleAuthService.getAccessTokenError = GoogleAuthError.tokenRefreshFailed("expired")
        let vm = makeCameraViewModel()

        vm.startStreaming()
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertTrue(
            vm.errorMessage?.contains("再ログインが必要です") ?? false,
            "Token refresh failure should mention re-login, got: \(vm.errorMessage ?? "nil")"
        )
    }

    func testNoCurrentUser_message() async {
        setupYouTubeAndSignIn()
        mockGoogleAuthService.getAccessTokenError = GoogleAuthError.noCurrentUser
        let vm = makeCameraViewModel()

        vm.startStreaming()
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertTrue(
            vm.errorMessage?.contains("Googleアカウントにログインしてください") ?? false,
            "No current user should mention login, got: \(vm.errorMessage ?? "nil")"
        )
    }
}
