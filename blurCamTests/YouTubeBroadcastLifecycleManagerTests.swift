import XCTest
@testable import blurCam

final class YouTubeBroadcastLifecycleManagerTests: XCTestCase {

    private var mockAPIService: MockYouTubeAPIService!
    private var mockAuthService: MockGoogleAuthService!
    private var manager: YouTubeBroadcastLifecycleManager!
    private var delegateSpy: LifecycleDelegateSpy!

    override func setUp() {
        super.setUp()
        mockAPIService = MockYouTubeAPIService()
        mockAuthService = MockGoogleAuthService()
        mockAuthService.authState = .signedIn(GoogleUserInfo(displayName: "Test", email: "test@gmail.com", profileImageURL: nil))
        manager = YouTubeBroadcastLifecycleManager(apiService: mockAPIService, authService: mockAuthService)
        delegateSpy = LifecycleDelegateSpy()
        manager.delegate = delegateSpy
    }

    override func tearDown() {
        manager.stopMonitoring()
        manager = nil
        delegateSpy = nil
        mockAPIService = nil
        mockAuthService = nil
        super.tearDown()
    }

    // MARK: - Configuration Tests

    func testConfigure_setsBroadcastAndStreamIds() {
        manager.configure(broadcastId: "bc-123", streamId: "st-456")

        XCTAssertEqual(manager.broadcastId, "bc-123")
        XCTAssertEqual(manager.streamId, "st-456")
        XCTAssertEqual(manager.broadcastStatus, .created)
        XCTAssertEqual(manager.streamHealth, .noData)
    }

    func testReset_clearsAllState() {
        manager.configure(broadcastId: "bc-123", streamId: "st-456")
        manager.reset()

        XCTAssertNil(manager.broadcastId)
        XCTAssertNil(manager.streamId)
        XCTAssertEqual(manager.broadcastStatus, .created)
        XCTAssertEqual(manager.streamHealth, .noData)
        XCTAssertFalse(manager.isMonitoring)
    }

    // MARK: - Lifecycle Tests

    func testStartLifecycle_transitionsToTestingThenLive() async throws {
        manager.configure(broadcastId: "bc-123", streamId: "st-456")

        try await manager.startLifecycle()

        // Should have called transition twice: testing and live
        XCTAssertEqual(mockAPIService.transitionBroadcastCallCount, 2)
        XCTAssertEqual(mockAPIService.transitionStatuses, ["testing", "live"])
        XCTAssertEqual(mockAPIService.transitionBroadcastIds, ["bc-123", "bc-123"])
        XCTAssertEqual(manager.broadcastStatus, .live)
        XCTAssertTrue(manager.isMonitoring)
    }

    func testStartLifecycle_failsWithoutConfiguration() async {
        do {
            try await manager.startLifecycle()
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertTrue(error is YouTubeAPIError)
        }
    }

    func testStartLifecycle_transitionToTestingFails_throwsError() async {
        manager.configure(broadcastId: "bc-123", streamId: "st-456")
        mockAPIService.transitionBroadcastResult = .failure(YouTubeAPIError.transitionFailed("test error"))

        do {
            try await manager.startLifecycle()
            XCTFail("Should have thrown an error")
        } catch let error as YouTubeAPIError {
            if case .transitionFailed = error {
                // Expected
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(mockAPIService.transitionBroadcastCallCount, 1)
    }

    func testStartLifecycle_delegateReceivesStatusUpdates() async throws {
        manager.configure(broadcastId: "bc-123", streamId: "st-456")

        try await manager.startLifecycle()

        // Delegate should have received testing and live status updates
        XCTAssertTrue(delegateSpy.receivedStatuses.contains(.testing))
        XCTAssertTrue(delegateSpy.receivedStatuses.contains(.live))
    }

    // MARK: - Complete Broadcast Tests

    func testCompleteBroadcast_transitionsToComplete() async {
        manager.configure(broadcastId: "bc-123", streamId: "st-456")

        await manager.completeBroadcast()

        XCTAssertEqual(mockAPIService.transitionBroadcastCallCount, 1)
        XCTAssertEqual(mockAPIService.transitionStatuses, ["complete"])
        XCTAssertEqual(manager.broadcastStatus, .complete)
        XCTAssertFalse(manager.isMonitoring)
    }

    func testCompleteBroadcast_withoutConfiguration_doesNothing() async {
        await manager.completeBroadcast()

        XCTAssertEqual(mockAPIService.transitionBroadcastCallCount, 0)
    }

    func testCompleteBroadcast_apiError_reportsToDelegate() async {
        manager.configure(broadcastId: "bc-123", streamId: "st-456")
        mockAPIService.transitionBroadcastResult = .failure(YouTubeAPIError.transitionFailed("fail"))

        await manager.completeBroadcast()

        XCTAssertTrue(delegateSpy.receivedErrors.count > 0)
    }

    // MARK: - Metadata Update Tests

    func testUpdateMetadata_callsAPIService() async throws {
        manager.configure(broadcastId: "bc-123", streamId: "st-456")

        try await manager.updateMetadata(title: "New Title", description: "New Desc")

        XCTAssertEqual(mockAPIService.updateBroadcastMetadataCallCount, 1)
        XCTAssertEqual(mockAPIService.updateBroadcastMetadataConfigs.first?.broadcastId, "bc-123")
        XCTAssertEqual(mockAPIService.updateBroadcastMetadataConfigs.first?.title, "New Title")
        XCTAssertEqual(mockAPIService.updateBroadcastMetadataConfigs.first?.description, "New Desc")
    }

    func testUpdateMetadata_failsWithoutConfiguration() async {
        do {
            try await manager.updateMetadata(title: "Title", description: "Desc")
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertTrue(error is YouTubeAPIError)
        }
    }

    func testUpdateMetadata_apiError_throws() async {
        manager.configure(broadcastId: "bc-123", streamId: "st-456")
        mockAPIService.updateBroadcastMetadataResult = .failure(YouTubeAPIError.networkError("fail"))

        do {
            try await manager.updateMetadata(title: "Title", description: "Desc")
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertTrue(error is YouTubeAPIError)
        }
    }

    // MARK: - Thumbnail Upload Tests

    func testUploadThumbnail_callsAPIService() async throws {
        manager.configure(broadcastId: "bc-123", streamId: "st-456")
        let imageData = Data([0x01, 0x02, 0x03])

        try await manager.uploadThumbnail(imageData: imageData, mimeType: "image/jpeg")

        XCTAssertEqual(mockAPIService.uploadThumbnailCallCount, 1)
        XCTAssertEqual(mockAPIService.uploadThumbnailBroadcastIds.first, "bc-123")
        XCTAssertEqual(mockAPIService.uploadThumbnailImageData.first, imageData)
        XCTAssertEqual(mockAPIService.uploadThumbnailMimeTypes.first, "image/jpeg")
    }

    func testUploadThumbnail_failsWithoutConfiguration() async {
        do {
            try await manager.uploadThumbnail(imageData: Data(), mimeType: "image/jpeg")
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertTrue(error is YouTubeAPIError)
        }
    }

    func testUploadThumbnail_apiError_throws() async {
        manager.configure(broadcastId: "bc-123", streamId: "st-456")
        mockAPIService.uploadThumbnailError = YouTubeAPIError.thumbnailUploadFailed("fail")

        do {
            try await manager.uploadThumbnail(imageData: Data([0x01]), mimeType: "image/jpeg")
            XCTFail("Should have thrown an error")
        } catch let error as YouTubeAPIError {
            if case .thumbnailUploadFailed = error {
                // Expected
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Health Monitoring Tests

    func testStopMonitoring_stopsPolling() {
        manager.configure(broadcastId: "bc-123", streamId: "st-456")
        manager.stopMonitoring()

        XCTAssertFalse(manager.isMonitoring)
    }

    // MARK: - Stream Health Model Tests

    func testStreamHealthStatus_displayNames() {
        XCTAssertEqual(YouTubeStreamHealthStatus.good.displayName, "良好")
        XCTAssertEqual(YouTubeStreamHealthStatus.ok.displayName, "正常")
        XCTAssertEqual(YouTubeStreamHealthStatus.bad.displayName, "低下")
        XCTAssertEqual(YouTubeStreamHealthStatus.noData.displayName, "データなし")
    }

    func testStreamHealthStatus_isHealthy() {
        XCTAssertTrue(YouTubeStreamHealthStatus.good.isHealthy)
        XCTAssertTrue(YouTubeStreamHealthStatus.ok.isHealthy)
        XCTAssertFalse(YouTubeStreamHealthStatus.bad.isHealthy)
        XCTAssertFalse(YouTubeStreamHealthStatus.noData.isHealthy)
    }

    func testStreamHealthStatus_rawValues() {
        XCTAssertEqual(YouTubeStreamHealthStatus(rawValue: "good"), .good)
        XCTAssertEqual(YouTubeStreamHealthStatus(rawValue: "ok"), .ok)
        XCTAssertEqual(YouTubeStreamHealthStatus(rawValue: "bad"), .bad)
        XCTAssertEqual(YouTubeStreamHealthStatus(rawValue: "noData"), .noData)
        XCTAssertNil(YouTubeStreamHealthStatus(rawValue: "unknown"))
    }

    // MARK: - Broadcast Lifecycle Status Model Tests

    func testBroadcastLifecycleStatus_displayNames() {
        XCTAssertEqual(YouTubeBroadcastLifecycleStatus.created.displayName, "作成済み")
        XCTAssertEqual(YouTubeBroadcastLifecycleStatus.ready.displayName, "準備完了")
        XCTAssertEqual(YouTubeBroadcastLifecycleStatus.testing.displayName, "テスト中")
        XCTAssertEqual(YouTubeBroadcastLifecycleStatus.live.displayName, "配信中")
        XCTAssertEqual(YouTubeBroadcastLifecycleStatus.complete.displayName, "完了")
        XCTAssertEqual(YouTubeBroadcastLifecycleStatus.revoked.displayName, "取消済み")
    }

    func testBroadcastLifecycleStatus_rawValues() {
        XCTAssertEqual(YouTubeBroadcastLifecycleStatus(rawValue: "created"), .created)
        XCTAssertEqual(YouTubeBroadcastLifecycleStatus(rawValue: "ready"), .ready)
        XCTAssertEqual(YouTubeBroadcastLifecycleStatus(rawValue: "testing"), .testing)
        XCTAssertEqual(YouTubeBroadcastLifecycleStatus(rawValue: "live"), .live)
        XCTAssertEqual(YouTubeBroadcastLifecycleStatus(rawValue: "complete"), .complete)
        XCTAssertEqual(YouTubeBroadcastLifecycleStatus(rawValue: "revoked"), .revoked)
    }

    // MARK: - Broadcast Update Config Tests

    func testBroadcastUpdateConfig_initialization() {
        let config = YouTubeBroadcastUpdateConfig(
            broadcastId: "bc-123",
            title: "Test",
            description: "Desc"
        )
        XCTAssertEqual(config.broadcastId, "bc-123")
        XCTAssertEqual(config.title, "Test")
        XCTAssertEqual(config.description, "Desc")
    }

    // MARK: - No Data Timeout Tests

    func testNoDataTimeoutThreshold_isAtLeast30Seconds() {
        XCTAssertGreaterThanOrEqual(manager.noDataTimeoutThreshold, 30.0)
    }
}

// MARK: - Lifecycle Delegate Spy

final class LifecycleDelegateSpy: YouTubeBroadcastLifecycleDelegate {
    var receivedHealthStatuses: [YouTubeStreamHealthStatus] = []
    var receivedStatuses: [YouTubeBroadcastLifecycleStatus] = []
    var receivedErrors: [Error] = []
    var noDataTimeoutCount = 0

    func lifecycleManager(_ manager: YouTubeBroadcastLifecycleManager, didUpdateStreamHealth health: YouTubeStreamHealthStatus) {
        receivedHealthStatuses.append(health)
    }

    func lifecycleManager(_ manager: YouTubeBroadcastLifecycleManager, didUpdateBroadcastStatus status: YouTubeBroadcastLifecycleStatus) {
        receivedStatuses.append(status)
    }

    func lifecycleManager(_ manager: YouTubeBroadcastLifecycleManager, didEncounterError error: Error) {
        receivedErrors.append(error)
    }

    func lifecycleManagerDidDetectNoDataTimeout(_ manager: YouTubeBroadcastLifecycleManager) {
        noDataTimeoutCount += 1
    }
}
