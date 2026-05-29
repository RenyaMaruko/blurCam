import XCTest
@testable import blurCam

/// Integration tests for Sprint 12 features:
/// - YouTube broadcast lifecycle management (F22)
/// - Thumbnail upload (F23)
@MainActor
final class Sprint12IntegrationTests: XCTestCase {

    private var mockAuthService: MockGoogleAuthService!
    private var mockAPIService: MockYouTubeAPIService!
    private var mockStreamingService: MockStreamingService!
    private var streamingVM: YouTubeStreamingViewModel!

    override func setUp() {
        super.setUp()
        mockAuthService = MockGoogleAuthService()
        mockAPIService = MockYouTubeAPIService()
        mockStreamingService = MockStreamingService()

        streamingVM = YouTubeStreamingViewModel(
            googleAuthService: mockAuthService,
            youTubeAPIService: mockAPIService
        )
    }

    override func tearDown() {
        streamingVM = nil
        mockAuthService = nil
        mockAPIService = nil
        mockStreamingService = nil
        super.tearDown()
    }

    // MARK: - F22: Broadcast Lifecycle Flow Tests

    func testFullLifecycleFlow_broadcastCreation_toTesting_toLive() async {
        // Setup: sign in and create stream
        await streamingVM.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)

        let rtmpInfo = await streamingVM.setupLiveStream()
        XCTAssertNotNil(rtmpInfo)

        // Verify lifecycle manager is configured
        XCTAssertNotNil(streamingVM.lifecycleManager)
        XCTAssertEqual(streamingVM.lifecycleManager?.broadcastId, "mock-broadcast-id")
        XCTAssertEqual(streamingVM.lifecycleManager?.streamId, "mock-stream-id")

        // Start lifecycle (testing -> live)
        streamingVM.startBroadcastLifecycle()
        try? await Task.sleep(nanoseconds: 4_000_000_000)

        // Verify transitions happened
        XCTAssertEqual(mockAPIService.transitionBroadcastCallCount, 2)
        XCTAssertEqual(mockAPIService.transitionStatuses, ["testing", "live"])
    }

    func testFullLifecycleFlow_broadcastCompletion() async {
        // Setup and start lifecycle
        await streamingVM.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)
        _ = await streamingVM.setupLiveStream()

        // Complete broadcast
        streamingVM.completeBroadcast()
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Verify complete transition
        XCTAssertEqual(mockAPIService.transitionStatuses.last, "complete")
        XCTAssertEqual(streamingVM.broadcastStatus, .complete)
    }

    func testLifecycleTransitionError_showsErrorMessage() async {
        await streamingVM.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)
        _ = await streamingVM.setupLiveStream()

        // Configure transition to fail
        mockAPIService.transitionBroadcastResult = .failure(YouTubeAPIError.transitionFailed("API error"))

        streamingVM.startBroadcastLifecycle()
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        // Error should be displayed
        XCTAssertNotNil(streamingVM.errorMessage)
    }

    // MARK: - F22: Stream Health Monitoring Tests

    func testStreamHealth_goodStatus_showsNormalUI() async {
        await streamingVM.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)
        _ = await streamingVM.setupLiveStream()

        // Simulate good health via delegate
        let manager = streamingVM.lifecycleManager!
        streamingVM.lifecycleManager(manager, didUpdateStreamHealth: .good)
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(streamingVM.streamHealth, .good)
        XCTAssertTrue(streamingVM.streamHealth.isHealthy)
    }

    func testStreamHealth_okStatus_showsNormalUI() async {
        await streamingVM.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)
        _ = await streamingVM.setupLiveStream()

        let manager = streamingVM.lifecycleManager!
        streamingVM.lifecycleManager(manager, didUpdateStreamHealth: .ok)
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(streamingVM.streamHealth, .ok)
        XCTAssertTrue(streamingVM.streamHealth.isHealthy)
    }

    func testStreamHealth_badStatus_showsWarning() async {
        await streamingVM.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)
        _ = await streamingVM.setupLiveStream()

        let manager = streamingVM.lifecycleManager!
        streamingVM.lifecycleManager(manager, didUpdateStreamHealth: .bad)
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(streamingVM.streamHealth, .bad)
        XCTAssertFalse(streamingVM.streamHealth.isHealthy)
    }

    func testStreamHealth_noDataTimeout_showsWarning() async {
        await streamingVM.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)
        _ = await streamingVM.setupLiveStream()

        let manager = streamingVM.lifecycleManager!
        streamingVM.lifecycleManagerDidDetectNoDataTimeout(manager)
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertTrue(streamingVM.showNoDataWarning)
    }

    func testStreamHealth_pollingStopsWhenStreamingStops() async {
        await streamingVM.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)
        _ = await streamingVM.setupLiveStream()

        streamingVM.stopLifecycleMonitoring()

        XCTAssertFalse(streamingVM.lifecycleManager?.isMonitoring ?? true)
        XCTAssertEqual(streamingVM.streamHealth, .noData)
        XCTAssertFalse(streamingVM.showNoDataWarning)
    }

    // MARK: - F22: Metadata Update Tests

    func testMetadataUpdate_titleDuringStreaming() async {
        await streamingVM.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)
        _ = await streamingVM.setupLiveStream()

        await streamingVM.updateMetadata(title: "Updated Title", description: streamingVM.broadcastDescription)

        XCTAssertEqual(mockAPIService.updateBroadcastMetadataCallCount, 1)
        XCTAssertEqual(mockAPIService.updateBroadcastMetadataConfigs.first?.title, "Updated Title")
        XCTAssertEqual(streamingVM.broadcastTitle, "Updated Title")
        XCTAssertTrue(streamingVM.metadataUpdateSuccess)
    }

    func testMetadataUpdate_descriptionDuringStreaming() async {
        await streamingVM.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)
        _ = await streamingVM.setupLiveStream()

        await streamingVM.updateMetadata(title: streamingVM.broadcastTitle, description: "Updated Description")

        XCTAssertEqual(mockAPIService.updateBroadcastMetadataCallCount, 1)
        XCTAssertEqual(mockAPIService.updateBroadcastMetadataConfigs.first?.description, "Updated Description")
        XCTAssertEqual(streamingVM.broadcastDescription, "Updated Description")
    }

    func testMetadataUpdate_failure_showsErrorButContinues() async {
        await streamingVM.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)
        _ = await streamingVM.setupLiveStream()

        mockAPIService.updateBroadcastMetadataResult = .failure(YouTubeAPIError.networkError("timeout"))

        await streamingVM.updateMetadata(title: "New", description: "New Desc")

        XCTAssertNotNil(streamingVM.errorMessage)
        XCTAssertFalse(streamingVM.metadataUpdateSuccess)
        // Lifecycle manager should still be intact
        XCTAssertNotNil(streamingVM.lifecycleManager)
    }

    // MARK: - F23: Thumbnail Tests

    func testThumbnailSelection_setsData() {
        let imageData = Data([0xFF, 0xD8, 0xFF, 0xE0]) // JPEG header
        streamingVM.selectedThumbnailData = imageData
        streamingVM.selectedThumbnailMimeType = "image/jpeg"

        XCTAssertNotNil(streamingVM.selectedThumbnailData)
        XCTAssertEqual(streamingVM.selectedThumbnailMimeType, "image/jpeg")
    }

    func testThumbnailUpload_duringBroadcastCreation() async {
        await streamingVM.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)

        let thumbnailData = Data([0x01, 0x02, 0x03, 0x04])
        streamingVM.selectedThumbnailData = thumbnailData
        streamingVM.selectedThumbnailMimeType = "image/jpeg"

        _ = await streamingVM.setupLiveStream()
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(mockAPIService.uploadThumbnailCallCount, 1)
        XCTAssertEqual(mockAPIService.uploadThumbnailBroadcastIds.first, "mock-broadcast-id")
    }

    func testNoThumbnail_streamStartsWithoutError() async {
        await streamingVM.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)

        streamingVM.selectedThumbnailData = nil

        let rtmpInfo = await streamingVM.setupLiveStream()

        XCTAssertNotNil(rtmpInfo)
        XCTAssertTrue(streamingVM.isReadyToStream)
        XCTAssertEqual(mockAPIService.uploadThumbnailCallCount, 0)
    }

    func testThumbnailUploadFail_streamContinues() async {
        await streamingVM.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)

        streamingVM.selectedThumbnailData = Data([0x01])
        mockAPIService.uploadThumbnailError = YouTubeAPIError.thumbnailUploadFailed("quota")

        let rtmpInfo = await streamingVM.setupLiveStream()
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Stream should still be ready
        XCTAssertNotNil(rtmpInfo)
        XCTAssertTrue(streamingVM.isReadyToStream)
        // But error should be shown
        XCTAssertNotNil(streamingVM.errorMessage)
    }

    // MARK: - Existing RTMP Functionality Preservation Tests

    func testManualRTMPFlow_notAffected() {
        // Manual streaming platforms should still work
        XCTAssertEqual(StreamingPlatform.youTube.presetURL, "rtmp://a.rtmp.youtube.com/live2")
        XCTAssertEqual(StreamingPlatform.twitch.presetURL, "rtmp://live.twitch.tv/app")

        let destination = StreamingDestination(
            name: "Test Twitch",
            platform: .twitch,
            rtmpURL: "rtmp://live.twitch.tv/app",
            streamKey: "twitch-key-123"
        )
        XCTAssertEqual(destination.platform, .twitch)
        XCTAssertEqual(destination.rtmpURL, "rtmp://live.twitch.tv/app")
    }

    func testYouTubeStreamingFlowType_manual_stillWorks() {
        XCTAssertEqual(YouTubeStreamingFlowType.manual, .manual)
        XCTAssertNotEqual(YouTubeStreamingFlowType.manual, .youTubeAPI)
    }
}
