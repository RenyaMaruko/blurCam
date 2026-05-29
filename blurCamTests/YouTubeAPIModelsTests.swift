import XCTest
@testable import blurCam

/// Tests for YouTube API model types including errors, request configs, and response parsing
final class YouTubeAPIModelsTests: XCTestCase {

    // MARK: - YouTubeAPIError Tests

    func testYouTubeAPIError_networkError_hasDescription() {
        let error = YouTubeAPIError.networkError("timeout")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("timeout"))
        XCTAssertEqual(error.category, .network)
    }

    func testYouTubeAPIError_authenticationError_hasDescription() {
        let error = YouTubeAPIError.authenticationError("invalid token")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertEqual(error.category, .authentication)
    }

    func testYouTubeAPIError_quotaExceeded_hasDescription() {
        let error = YouTubeAPIError.quotaExceeded
        XCTAssertNotNil(error.errorDescription)
        XCTAssertEqual(error.category, .quota)
    }

    func testYouTubeAPIError_invalidResponse_hasDescription() {
        let error = YouTubeAPIError.invalidResponse("bad JSON")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertEqual(error.category, .other)
    }

    func testYouTubeAPIError_broadcastCreationFailed_hasDescription() {
        let error = YouTubeAPIError.broadcastCreationFailed("permission denied")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("permission denied"))
    }

    func testYouTubeAPIError_streamCreationFailed_hasDescription() {
        let error = YouTubeAPIError.streamCreationFailed("server error")
        XCTAssertNotNil(error.errorDescription)
    }

    func testYouTubeAPIError_bindFailed_hasDescription() {
        let error = YouTubeAPIError.bindFailed("not found")
        XCTAssertNotNil(error.errorDescription)
    }

    func testYouTubeAPIError_noIngestionInfo_hasDescription() {
        let error = YouTubeAPIError.noIngestionInfo
        XCTAssertNotNil(error.errorDescription)
    }

    func testYouTubeAPIError_unknown_hasDescription() {
        let error = YouTubeAPIError.unknown("something went wrong")
        XCTAssertNotNil(error.errorDescription)
    }

    func testYouTubeAPIError_equatable() {
        XCTAssertEqual(YouTubeAPIError.quotaExceeded, YouTubeAPIError.quotaExceeded)
        XCTAssertEqual(YouTubeAPIError.noIngestionInfo, YouTubeAPIError.noIngestionInfo)
        XCTAssertEqual(YouTubeAPIError.networkError("a"), YouTubeAPIError.networkError("a"))
        XCTAssertNotEqual(YouTubeAPIError.networkError("a"), YouTubeAPIError.networkError("b"))
        XCTAssertNotEqual(YouTubeAPIError.quotaExceeded, YouTubeAPIError.noIngestionInfo)
    }

    // MARK: - YouTubeBroadcastPrivacy Tests

    func testBroadcastPrivacy_rawValues() {
        XCTAssertEqual(YouTubeBroadcastPrivacy.publicBroadcast.rawValue, "public")
        XCTAssertEqual(YouTubeBroadcastPrivacy.unlisted.rawValue, "unlisted")
        XCTAssertEqual(YouTubeBroadcastPrivacy.privateBroadcast.rawValue, "private")
    }

    func testBroadcastPrivacy_displayNames() {
        XCTAssertEqual(YouTubeBroadcastPrivacy.publicBroadcast.displayName, "公開")
        XCTAssertEqual(YouTubeBroadcastPrivacy.unlisted.displayName, "限定公開")
        XCTAssertEqual(YouTubeBroadcastPrivacy.privateBroadcast.displayName, "非公開")
    }

    func testBroadcastPrivacy_allCases() {
        XCTAssertEqual(YouTubeBroadcastPrivacy.allCases.count, 3)
    }

    // MARK: - YouTubeBroadcastConfig Tests

    func testBroadcastConfig_defaults() {
        let config = YouTubeBroadcastConfig()
        XCTAssertEqual(config.title, "blurCam Live")
        XCTAssertEqual(config.description, "")
        XCTAssertEqual(config.privacy, .unlisted)
    }

    func testBroadcastConfig_customValues() {
        let config = YouTubeBroadcastConfig(
            title: "My Stream",
            description: "Test desc",
            privacy: .publicBroadcast
        )
        XCTAssertEqual(config.title, "My Stream")
        XCTAssertEqual(config.description, "Test desc")
        XCTAssertEqual(config.privacy, .publicBroadcast)
    }

    // MARK: - YouTubeStreamConfig Tests

    func testStreamConfig_defaults() {
        let config = YouTubeStreamConfig()
        XCTAssertEqual(config.title, "blurCam Stream")
        XCTAssertEqual(config.resolution, "1080p")
        XCTAssertEqual(config.frameRate, "30fps")
        XCTAssertEqual(config.ingestionType, "rtmp")
    }

    func testStreamConfig_customValues() {
        let config = YouTubeStreamConfig(
            title: "Custom",
            resolution: "720p",
            frameRate: "60fps",
            ingestionType: "dash"
        )
        XCTAssertEqual(config.title, "Custom")
        XCTAssertEqual(config.resolution, "720p")
        XCTAssertEqual(config.frameRate, "60fps")
        XCTAssertEqual(config.ingestionType, "dash")
    }

    // MARK: - YouTubeRTMPInfo Tests

    func testRTMPInfo_creation() {
        let info = YouTubeRTMPInfo(
            rtmpURL: "rtmp://a.rtmp.youtube.com/live2",
            streamKey: "stream-key-abc",
            broadcastId: "broadcast-123",
            streamId: "stream-456"
        )
        XCTAssertEqual(info.rtmpURL, "rtmp://a.rtmp.youtube.com/live2")
        XCTAssertEqual(info.streamKey, "stream-key-abc")
        XCTAssertEqual(info.broadcastId, "broadcast-123")
        XCTAssertEqual(info.streamId, "stream-456")
    }

    func testRTMPInfo_equatable() {
        let info1 = YouTubeRTMPInfo(rtmpURL: "rtmp://a.com", streamKey: "k1", broadcastId: "b1", streamId: "s1")
        let info2 = YouTubeRTMPInfo(rtmpURL: "rtmp://a.com", streamKey: "k1", broadcastId: "b1", streamId: "s1")
        let info3 = YouTubeRTMPInfo(rtmpURL: "rtmp://b.com", streamKey: "k2", broadcastId: "b2", streamId: "s2")

        XCTAssertEqual(info1, info2)
        XCTAssertNotEqual(info1, info3)
    }

    // MARK: - Response Decoding Tests

    func testBroadcastResponse_decoding() throws {
        let json = """
        {
            "kind": "youtube#liveBroadcast",
            "etag": "test-etag",
            "id": "test-broadcast-id",
            "snippet": {
                "publishedAt": "2026-01-01T00:00:00Z",
                "channelId": "channel-123",
                "title": "Test Broadcast",
                "description": "A test",
                "scheduledStartTime": "2026-01-01T00:00:00Z"
            },
            "status": {
                "lifeCycleStatus": "created",
                "privacyStatus": "unlisted"
            },
            "contentDetails": {
                "enableDvr": true,
                "enableAutoStart": true,
                "enableAutoStop": true
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(YouTubeBroadcastResponse.self, from: json)
        XCTAssertEqual(response.id, "test-broadcast-id")
        XCTAssertEqual(response.kind, "youtube#liveBroadcast")
        XCTAssertEqual(response.snippet?.title, "Test Broadcast")
        XCTAssertEqual(response.status?.privacyStatus, "unlisted")
        XCTAssertEqual(response.contentDetails?.enableDvr, true)
    }

    func testStreamResponse_decoding() throws {
        let json = """
        {
            "kind": "youtube#liveStream",
            "etag": "test-etag",
            "id": "test-stream-id",
            "snippet": {
                "channelId": "channel-123",
                "title": "Test Stream"
            },
            "cdn": {
                "ingestionType": "rtmp",
                "ingestionInfo": {
                    "streamName": "test-stream-key",
                    "ingestionAddress": "rtmp://a.rtmp.youtube.com/live2",
                    "backupIngestionAddress": "rtmp://b.rtmp.youtube.com/live2?backup=1"
                },
                "resolution": "1080p",
                "frameRate": "30fps"
            },
            "status": {
                "streamStatus": "ready",
                "healthStatus": {
                    "status": "good"
                }
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(YouTubeStreamResponse.self, from: json)
        XCTAssertEqual(response.id, "test-stream-id")
        XCTAssertEqual(response.cdn?.ingestionInfo?.streamName, "test-stream-key")
        XCTAssertEqual(response.cdn?.ingestionInfo?.ingestionAddress, "rtmp://a.rtmp.youtube.com/live2")
        XCTAssertEqual(response.cdn?.resolution, "1080p")
        XCTAssertEqual(response.status?.healthStatus?.status, "good")
    }

    func testBindResponse_decoding() throws {
        let json = """
        {
            "kind": "youtube#liveBroadcast",
            "etag": "test-etag",
            "id": "test-broadcast-id",
            "contentDetails": {
                "boundStreamId": "test-stream-id"
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(YouTubeBindResponse.self, from: json)
        XCTAssertEqual(response.id, "test-broadcast-id")
        XCTAssertEqual(response.contentDetails?.boundStreamId, "test-stream-id")
    }

    func testErrorResponse_decoding() throws {
        let json = """
        {
            "error": {
                "code": 403,
                "message": "The request cannot be completed because you have exceeded your quota.",
                "errors": [
                    {
                        "domain": "youtube.quota",
                        "reason": "quotaExceeded",
                        "message": "Quota exceeded"
                    }
                ]
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(YouTubeAPIErrorResponse.self, from: json)
        XCTAssertEqual(response.error?.code, 403)
        XCTAssertEqual(response.error?.errors?.first?.reason, "quotaExceeded")
    }

    // MARK: - YouTubeAPIErrorCategory Tests

    func testErrorCategory_network() {
        XCTAssertEqual(YouTubeAPIError.networkError("").category, .network)
    }

    func testErrorCategory_authentication() {
        XCTAssertEqual(YouTubeAPIError.authenticationError("").category, .authentication)
    }

    func testErrorCategory_quota() {
        XCTAssertEqual(YouTubeAPIError.quotaExceeded.category, .quota)
    }

    func testErrorCategory_other() {
        XCTAssertEqual(YouTubeAPIError.broadcastCreationFailed("").category, .other)
        XCTAssertEqual(YouTubeAPIError.streamCreationFailed("").category, .other)
        XCTAssertEqual(YouTubeAPIError.bindFailed("").category, .other)
        XCTAssertEqual(YouTubeAPIError.noIngestionInfo.category, .other)
        XCTAssertEqual(YouTubeAPIError.invalidResponse("").category, .other)
        XCTAssertEqual(YouTubeAPIError.unknown("").category, .other)
    }

    // MARK: - YouTubeStreamingFlowType Tests

    func testStreamingFlowType_equatable() {
        XCTAssertEqual(YouTubeStreamingFlowType.manual, YouTubeStreamingFlowType.manual)
        XCTAssertEqual(YouTubeStreamingFlowType.youTubeAPI, YouTubeStreamingFlowType.youTubeAPI)
        XCTAssertNotEqual(YouTubeStreamingFlowType.manual, YouTubeStreamingFlowType.youTubeAPI)
    }
}
