import XCTest
@testable import blurCam

@MainActor
final class YouTubeStreamingViewModelTests: XCTestCase {

    private var mockAuthService: MockGoogleAuthService!
    private var mockAPIService: MockYouTubeAPIService!
    private var viewModel: YouTubeStreamingViewModel!

    override func setUp() {
        super.setUp()
        mockAuthService = MockGoogleAuthService()
        mockAPIService = MockYouTubeAPIService()
        viewModel = YouTubeStreamingViewModel(
            googleAuthService: mockAuthService,
            youTubeAPIService: mockAPIService
        )
    }

    override func tearDown() {
        mockAuthService = nil
        mockAPIService = nil
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertEqual(viewModel.authState, .signedOut)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.needsReAuth)
        XCTAssertEqual(viewModel.broadcastTitle, "blurCam Live")
        XCTAssertEqual(viewModel.broadcastDescription, "")
        XCTAssertEqual(viewModel.broadcastPrivacy, .unlisted)
        XCTAssertNil(viewModel.lastRTMPInfo)
        XCTAssertFalse(viewModel.isReadyToStream)
        XCTAssertEqual(viewModel.broadcastStatus, .created)
        XCTAssertEqual(viewModel.streamHealth, .noData)
        XCTAssertFalse(viewModel.showNoDataWarning)
        XCTAssertFalse(viewModel.isTransitioning)
        XCTAssertFalse(viewModel.isUpdatingMetadata)
        XCTAssertFalse(viewModel.metadataUpdateSuccess)
        XCTAssertNil(viewModel.selectedThumbnailData)
        XCTAssertFalse(viewModel.isUploadingThumbnail)
        XCTAssertFalse(viewModel.thumbnailUploadSuccess)
    }

    // MARK: - Sign In Tests

    func testSignIn_success() async {
        await viewModel.signIn()

        // Wait for auth state callback
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(mockAuthService.signInCallCount, 1)
        XCTAssertTrue(viewModel.authState.isSignedIn)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testSignIn_failure_showsError() async {
        mockAuthService.signInError = GoogleAuthError.signInFailed("network error")

        await viewModel.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(mockAuthService.signInCallCount, 1)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testSignIn_cancelled_noError() async {
        mockAuthService.signInError = GoogleAuthError.signInCancelled

        await viewModel.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertNil(viewModel.errorMessage)
    }

    // MARK: - Sign Out Tests

    func testSignOut_clearsState() async {
        // Sign in first
        await viewModel.signIn()
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertTrue(viewModel.authState.isSignedIn)

        viewModel.signOut()
        // Wait for async state callback to settle
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(mockAuthService.signOutCallCount, 1)
        XCTAssertEqual(viewModel.authState, .signedOut)
        XCTAssertNil(viewModel.lastRTMPInfo)
        XCTAssertFalse(viewModel.isReadyToStream)
        XCTAssertFalse(viewModel.needsReAuth)
    }

    // MARK: - Restore Previous Sign In Tests

    func testRestorePreviousSignIn_success() async {
        mockAuthService.restorePreviousSignInResult = true

        await viewModel.restorePreviousSignIn()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(mockAuthService.restorePreviousSignInCallCount, 1)
        XCTAssertTrue(viewModel.authState.isSignedIn)
    }

    func testRestorePreviousSignIn_failure() async {
        mockAuthService.restorePreviousSignInResult = false

        await viewModel.restorePreviousSignIn()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.authState, .signedOut)
    }

    // MARK: - Setup Live Stream Tests

    func testSetupLiveStream_success() async {
        // Sign in first
        await viewModel.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)

        viewModel.broadcastTitle = "My Live Stream"
        viewModel.broadcastDescription = "Test description"
        viewModel.broadcastPrivacy = .publicBroadcast

        let rtmpInfo = await viewModel.setupLiveStream()

        XCTAssertNotNil(rtmpInfo)
        XCTAssertEqual(rtmpInfo?.rtmpURL, "rtmp://a.rtmp.youtube.com/live2")
        XCTAssertEqual(rtmpInfo?.streamKey, "mock-stream-key-abc123")
        XCTAssertEqual(rtmpInfo?.broadcastId, "mock-broadcast-id")
        XCTAssertEqual(rtmpInfo?.streamId, "mock-stream-id")

        XCTAssertNotNil(viewModel.lastRTMPInfo)
        XCTAssertTrue(viewModel.isReadyToStream)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)

        // Lifecycle manager should be created
        XCTAssertNotNil(viewModel.lifecycleManager)
        XCTAssertEqual(viewModel.lifecycleManager?.broadcastId, "mock-broadcast-id")
        XCTAssertEqual(viewModel.lifecycleManager?.streamId, "mock-stream-id")
    }

    func testSetupLiveStream_notSignedIn_showsError() async {
        let rtmpInfo = await viewModel.setupLiveStream()

        XCTAssertNil(rtmpInfo)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isReadyToStream)
    }

    func testSetupLiveStream_tokenError_setsNeedsReAuth() async {
        await viewModel.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)

        mockAuthService.getAccessTokenError = GoogleAuthError.tokenRefreshFailed("expired")

        let rtmpInfo = await viewModel.setupLiveStream()

        XCTAssertNil(rtmpInfo)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.needsReAuth)
    }

    func testSetupLiveStream_apiError_showsError() async {
        await viewModel.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)

        mockAPIService.setupLiveStreamResult = .failure(YouTubeAPIError.quotaExceeded)

        let rtmpInfo = await viewModel.setupLiveStream()

        XCTAssertNil(rtmpInfo)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isReadyToStream)
    }

    func testSetupLiveStream_networkError_showsError() async {
        await viewModel.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)

        mockAPIService.setupLiveStreamResult = .failure(YouTubeAPIError.networkError("no internet"))

        let rtmpInfo = await viewModel.setupLiveStream()

        XCTAssertNil(rtmpInfo)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage!.contains("ネットワークエラー"))
    }

    func testSetupLiveStream_authError_setsNeedsReAuth() async {
        await viewModel.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)

        mockAPIService.setupLiveStreamResult = .failure(YouTubeAPIError.authenticationError("unauthorized"))

        let rtmpInfo = await viewModel.setupLiveStream()

        XCTAssertNil(rtmpInfo)
        XCTAssertTrue(viewModel.needsReAuth)
    }

    func testSetupLiveStream_clearsOldState() async {
        await viewModel.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)

        // First successful setup
        let info1 = await viewModel.setupLiveStream()
        XCTAssertNotNil(info1)
        XCTAssertTrue(viewModel.isReadyToStream)

        // Second setup should clear old state
        mockAPIService.setupLiveStreamResult = .failure(YouTubeAPIError.networkError("fail"))
        let info2 = await viewModel.setupLiveStream()
        XCTAssertNil(info2)
        XCTAssertNil(viewModel.lastRTMPInfo)
        XCTAssertFalse(viewModel.isReadyToStream)
    }

    func testSetupLiveStream_emptyTitle_usesDefault() async {
        await viewModel.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)

        viewModel.broadcastTitle = ""
        let rtmpInfo = await viewModel.setupLiveStream()

        XCTAssertNotNil(rtmpInfo)
        // The broadcast config should have used "blurCam Live" as default
        XCTAssertEqual(mockAPIService.createBroadcastCallCount, 1)
    }

    // MARK: - Lifecycle Management Tests

    func testCompleteBroadcast_setsStatusToComplete() async {
        // Setup stream first
        await viewModel.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)
        _ = await viewModel.setupLiveStream()

        viewModel.completeBroadcast()
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(viewModel.broadcastStatus, .complete)
    }

    func testStopLifecycleMonitoring_clearsHealthState() async {
        await viewModel.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)
        _ = await viewModel.setupLiveStream()

        viewModel.stopLifecycleMonitoring()

        XCTAssertEqual(viewModel.streamHealth, .noData)
        XCTAssertFalse(viewModel.showNoDataWarning)
    }

    // MARK: - Metadata Update Tests

    func testUpdateMetadata_success() async {
        await viewModel.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)
        _ = await viewModel.setupLiveStream()

        await viewModel.updateMetadata(title: "New Title", description: "New Description")

        XCTAssertEqual(mockAPIService.updateBroadcastMetadataCallCount, 1)
        XCTAssertEqual(viewModel.broadcastTitle, "New Title")
        XCTAssertEqual(viewModel.broadcastDescription, "New Description")
        XCTAssertTrue(viewModel.metadataUpdateSuccess)
        XCTAssertFalse(viewModel.isUpdatingMetadata)
    }

    func testUpdateMetadata_failure_showsErrorButContinuesStream() async {
        await viewModel.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)
        _ = await viewModel.setupLiveStream()

        mockAPIService.updateBroadcastMetadataResult = .failure(YouTubeAPIError.networkError("fail"))

        await viewModel.updateMetadata(title: "New Title", description: "New Description")

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.metadataUpdateSuccess)
        XCTAssertFalse(viewModel.isUpdatingMetadata)
        // The lifecycle manager should still be intact (streaming continues)
        XCTAssertNotNil(viewModel.lifecycleManager)
    }

    func testUpdateMetadata_withoutLifecycleManager_showsError() async {
        await viewModel.updateMetadata(title: "Title", description: "Desc")

        XCTAssertNotNil(viewModel.errorMessage)
    }

    // MARK: - Thumbnail Tests

    func testSetupLiveStream_withThumbnail_uploadsThumbnail() async {
        await viewModel.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)

        viewModel.selectedThumbnailData = Data([0x01, 0x02, 0x03])
        viewModel.selectedThumbnailMimeType = "image/jpeg"

        _ = await viewModel.setupLiveStream()
        // Wait for async thumbnail upload
        try? await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(mockAPIService.uploadThumbnailCallCount, 1)
        XCTAssertEqual(mockAPIService.uploadThumbnailBroadcastIds.first, "mock-broadcast-id")
        XCTAssertEqual(mockAPIService.uploadThumbnailMimeTypes.first, "image/jpeg")
    }

    func testSetupLiveStream_withoutThumbnail_doesNotUpload() async {
        await viewModel.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)

        viewModel.selectedThumbnailData = nil

        _ = await viewModel.setupLiveStream()
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(mockAPIService.uploadThumbnailCallCount, 0)
    }

    func testSetupLiveStream_thumbnailUploadFails_showsErrorButContinuesStream() async {
        await viewModel.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)

        viewModel.selectedThumbnailData = Data([0x01, 0x02])
        mockAPIService.uploadThumbnailError = YouTubeAPIError.thumbnailUploadFailed("fail")

        let rtmpInfo = await viewModel.setupLiveStream()
        try? await Task.sleep(nanoseconds: 300_000_000)

        // Stream should still be created successfully
        XCTAssertNotNil(rtmpInfo)
        XCTAssertTrue(viewModel.isReadyToStream)
        // But thumbnail error should be reported
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.thumbnailUploadSuccess)
    }

    // MARK: - Auth State Callback Tests

    func testAuthStateCallback_updatesViewModel() async {
        XCTAssertEqual(viewModel.authState, .signedOut)

        await viewModel.signIn()
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertTrue(viewModel.authState.isSignedIn)

        viewModel.signOut()
        // Wait for async state callback to settle
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(viewModel.authState, .signedOut)
    }

    // MARK: - RTMP Auto-Connect Integration Tests

    func testSetupLiveStream_returnsRTMPInfoForStreamingService() async {
        await viewModel.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)

        let rtmpInfo = await viewModel.setupLiveStream()

        // Verify the RTMP info can be used with StreamingService
        XCTAssertNotNil(rtmpInfo)
        XCTAssertTrue(rtmpInfo!.rtmpURL.hasPrefix("rtmp://"))
        XCTAssertFalse(rtmpInfo!.streamKey.isEmpty)
    }

    // MARK: - Existing Functionality Preservation Tests

    func testManualStreamingFlowType_stillExists() {
        XCTAssertEqual(YouTubeStreamingFlowType.manual, YouTubeStreamingFlowType.manual)
        XCTAssertEqual(YouTubeStreamingFlowType.youTubeAPI, YouTubeStreamingFlowType.youTubeAPI)
    }

    func testStreamingPlatform_manualDestinationCases_allPresent() {
        let cases = StreamingPlatform.manualDestinationCases
        XCTAssertTrue(cases.contains(.youTube))
        XCTAssertTrue(cases.contains(.twitch))
        XCTAssertTrue(cases.contains(.custom))
    }

    func testStreamingPlatform_existingPresetURLs_unchanged() {
        XCTAssertEqual(StreamingPlatform.youTube.presetURL, "rtmp://a.rtmp.youtube.com/live2")
        XCTAssertEqual(StreamingPlatform.twitch.presetURL, "rtmp://live.twitch.tv/app")
        XCTAssertEqual(StreamingPlatform.custom.presetURL, "")
    }

    // MARK: - Lifecycle Delegate Tests

    func testLifecycleDelegate_streamHealthUpdate() async {
        await viewModel.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)
        _ = await viewModel.setupLiveStream()

        // Simulate health update via delegate
        let manager = viewModel.lifecycleManager!
        viewModel.lifecycleManager(manager, didUpdateStreamHealth: .good)
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(viewModel.streamHealth, .good)
    }

    func testLifecycleDelegate_broadcastStatusUpdate() async {
        await viewModel.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)
        _ = await viewModel.setupLiveStream()

        let manager = viewModel.lifecycleManager!
        viewModel.lifecycleManager(manager, didUpdateBroadcastStatus: .live)
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(viewModel.broadcastStatus, .live)
    }

    func testLifecycleDelegate_noDataTimeout() async {
        await viewModel.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)
        _ = await viewModel.setupLiveStream()

        let manager = viewModel.lifecycleManager!
        viewModel.lifecycleManagerDidDetectNoDataTimeout(manager)
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertTrue(viewModel.showNoDataWarning)
    }

    func testLifecycleDelegate_healthUpdateClearsNoDataWarning() async {
        await viewModel.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)
        _ = await viewModel.setupLiveStream()

        let manager = viewModel.lifecycleManager!
        viewModel.lifecycleManagerDidDetectNoDataTimeout(manager)
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertTrue(viewModel.showNoDataWarning)

        viewModel.lifecycleManager(manager, didUpdateStreamHealth: .good)
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertFalse(viewModel.showNoDataWarning)
    }

    // MARK: - YouTubeAPIError New Cases Tests

    func testTransitionFailedError() {
        let error = YouTubeAPIError.transitionFailed("status error")
        XCTAssertEqual(error.errorDescription, "配信ステータスの遷移に失敗しました: status error")
        XCTAssertEqual(error.category, .other)
    }

    func testThumbnailUploadFailedError() {
        let error = YouTubeAPIError.thumbnailUploadFailed("upload error")
        XCTAssertEqual(error.errorDescription, "サムネイルのアップロードに失敗しました: upload error")
        XCTAssertEqual(error.category, .other)
    }
}
