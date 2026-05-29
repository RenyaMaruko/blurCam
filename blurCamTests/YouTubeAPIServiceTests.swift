import XCTest
@testable import blurCam

/// Tests for YouTubeAPIService using MockYouTubeAPIService for unit testing,
/// and URL protocol stubbing for integration-level tests.
final class YouTubeAPIServiceTests: XCTestCase {

    // MARK: - Mock Service Tests

    private var mockService: MockYouTubeAPIService!

    override func setUp() {
        super.setUp()
        mockService = MockYouTubeAPIService()
    }

    override func tearDown() {
        mockService = nil
        super.tearDown()
    }

    // MARK: - createBroadcast Tests

    func testCreateBroadcast_success() async throws {
        let config = YouTubeBroadcastConfig(title: "Test", description: "desc", privacy: .unlisted)
        let response = try await mockService.createBroadcast(config: config, accessToken: "token123")

        XCTAssertEqual(response.id, "mock-broadcast-id")
        XCTAssertEqual(response.snippet?.title, "Test Broadcast")
        XCTAssertEqual(mockService.createBroadcastCallCount, 1)
        XCTAssertEqual(mockService.createBroadcastAccessTokens.first, "token123")
    }

    func testCreateBroadcast_failure() async {
        mockService.createBroadcastResult = .failure(YouTubeAPIError.broadcastCreationFailed("server error"))

        do {
            _ = try await mockService.createBroadcast(
                config: YouTubeBroadcastConfig(),
                accessToken: "token"
            )
            XCTFail("Expected error")
        } catch let error as YouTubeAPIError {
            XCTAssertEqual(error, .broadcastCreationFailed("server error"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testCreateBroadcast_authError() async {
        mockService.createBroadcastResult = .failure(YouTubeAPIError.authenticationError("invalid token"))

        do {
            _ = try await mockService.createBroadcast(
                config: YouTubeBroadcastConfig(),
                accessToken: "expired-token"
            )
            XCTFail("Expected error")
        } catch let error as YouTubeAPIError {
            XCTAssertEqual(error.category, .authentication)
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    // MARK: - createStream Tests

    func testCreateStream_success() async throws {
        let config = YouTubeStreamConfig()
        let response = try await mockService.createStream(config: config, accessToken: "token")

        XCTAssertEqual(response.id, "mock-stream-id")
        XCTAssertEqual(response.cdn?.ingestionInfo?.ingestionAddress, "rtmp://a.rtmp.youtube.com/live2")
        XCTAssertEqual(response.cdn?.ingestionInfo?.streamName, "mock-stream-key-abc123")
        XCTAssertEqual(mockService.createStreamCallCount, 1)
    }

    func testCreateStream_failure() async {
        mockService.createStreamResult = .failure(YouTubeAPIError.streamCreationFailed("quota"))

        do {
            _ = try await mockService.createStream(
                config: YouTubeStreamConfig(),
                accessToken: "token"
            )
            XCTFail("Expected error")
        } catch let error as YouTubeAPIError {
            XCTAssertEqual(error, .streamCreationFailed("quota"))
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    // MARK: - bindBroadcastToStream Tests

    func testBind_success() async throws {
        let response = try await mockService.bindBroadcastToStream(
            broadcastId: "bc-1",
            streamId: "st-1",
            accessToken: "token"
        )

        XCTAssertEqual(response.contentDetails?.boundStreamId, "mock-stream-id")
        XCTAssertEqual(mockService.bindCallCount, 1)
        XCTAssertEqual(mockService.bindBroadcastIds.first, "bc-1")
        XCTAssertEqual(mockService.bindStreamIds.first, "st-1")
    }

    func testBind_failure() async {
        mockService.bindResult = .failure(YouTubeAPIError.bindFailed("not found"))

        do {
            _ = try await mockService.bindBroadcastToStream(
                broadcastId: "bc-1",
                streamId: "st-1",
                accessToken: "token"
            )
            XCTFail("Expected error")
        } catch let error as YouTubeAPIError {
            XCTAssertEqual(error, .bindFailed("not found"))
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    // MARK: - setupLiveStream Tests

    func testSetupLiveStream_success() async throws {
        let rtmpInfo = try await mockService.setupLiveStream(
            broadcastConfig: YouTubeBroadcastConfig(title: "Test"),
            streamConfig: YouTubeStreamConfig(),
            accessToken: "token"
        )

        XCTAssertEqual(rtmpInfo.rtmpURL, "rtmp://a.rtmp.youtube.com/live2")
        XCTAssertEqual(rtmpInfo.streamKey, "mock-stream-key-abc123")
        XCTAssertEqual(rtmpInfo.broadcastId, "mock-broadcast-id")
        XCTAssertEqual(rtmpInfo.streamId, "mock-stream-id")

        // All three API calls should have been made
        XCTAssertEqual(mockService.createBroadcastCallCount, 1)
        XCTAssertEqual(mockService.createStreamCallCount, 1)
        XCTAssertEqual(mockService.bindCallCount, 1)
        XCTAssertEqual(mockService.setupLiveStreamCallCount, 1)
    }

    func testSetupLiveStream_broadcastFailure_propagatesError() async {
        mockService.createBroadcastResult = .failure(YouTubeAPIError.broadcastCreationFailed("fail"))

        do {
            _ = try await mockService.setupLiveStream(
                broadcastConfig: YouTubeBroadcastConfig(),
                streamConfig: YouTubeStreamConfig(),
                accessToken: "token"
            )
            XCTFail("Expected error")
        } catch let error as YouTubeAPIError {
            XCTAssertEqual(error, .broadcastCreationFailed("fail"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }

        // Stream and bind should not have been called
        XCTAssertEqual(mockService.createStreamCallCount, 0)
        XCTAssertEqual(mockService.bindCallCount, 0)
    }

    func testSetupLiveStream_streamFailure_propagatesError() async {
        mockService.createStreamResult = .failure(YouTubeAPIError.networkError("timeout"))

        do {
            _ = try await mockService.setupLiveStream(
                broadcastConfig: YouTubeBroadcastConfig(),
                streamConfig: YouTubeStreamConfig(),
                accessToken: "token"
            )
            XCTFail("Expected error")
        } catch let error as YouTubeAPIError {
            XCTAssertEqual(error, .networkError("timeout"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }

        // Broadcast should have been created, but bind should not
        XCTAssertEqual(mockService.createBroadcastCallCount, 1)
        XCTAssertEqual(mockService.bindCallCount, 0)
    }

    func testSetupLiveStream_bindFailure_propagatesError() async {
        mockService.bindResult = .failure(YouTubeAPIError.bindFailed("conflict"))

        do {
            _ = try await mockService.setupLiveStream(
                broadcastConfig: YouTubeBroadcastConfig(),
                streamConfig: YouTubeStreamConfig(),
                accessToken: "token"
            )
            XCTFail("Expected error")
        } catch let error as YouTubeAPIError {
            XCTAssertEqual(error, .bindFailed("conflict"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }

        // Both broadcast and stream should have been created
        XCTAssertEqual(mockService.createBroadcastCallCount, 1)
        XCTAssertEqual(mockService.createStreamCallCount, 1)
    }

    func testSetupLiveStream_noIngestionInfo_throwsError() async {
        // Create a stream response with nil ingestion info
        mockService.createStreamResult = .success(
            YouTubeStreamResponse(
                kind: "youtube#liveStream",
                etag: "test",
                id: "stream-id",
                snippet: nil,
                cdn: YouTubeStreamResponse.StreamCDN(
                    ingestionType: "rtmp",
                    ingestionInfo: nil,
                    resolution: "1080p",
                    frameRate: "30fps"
                ),
                status: nil
            )
        )

        do {
            _ = try await mockService.setupLiveStream(
                broadcastConfig: YouTubeBroadcastConfig(),
                streamConfig: YouTubeStreamConfig(),
                accessToken: "token"
            )
            XCTFail("Expected error")
        } catch let error as YouTubeAPIError {
            XCTAssertEqual(error, .noIngestionInfo)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testSetupLiveStream_overrideResult() async throws {
        let customInfo = YouTubeRTMPInfo(
            rtmpURL: "rtmp://custom.com/live",
            streamKey: "custom-key",
            broadcastId: "custom-bc",
            streamId: "custom-st"
        )
        mockService.setupLiveStreamResult = .success(customInfo)

        let result = try await mockService.setupLiveStream(
            broadcastConfig: YouTubeBroadcastConfig(),
            streamConfig: YouTubeStreamConfig(),
            accessToken: "token"
        )

        XCTAssertEqual(result, customInfo)
        // Individual API calls should NOT have been made
        XCTAssertEqual(mockService.createBroadcastCallCount, 0)
        XCTAssertEqual(mockService.createStreamCallCount, 0)
        XCTAssertEqual(mockService.bindCallCount, 0)
    }

    func testSetupLiveStream_quotaExceeded() async {
        mockService.setupLiveStreamResult = .failure(YouTubeAPIError.quotaExceeded)

        do {
            _ = try await mockService.setupLiveStream(
                broadcastConfig: YouTubeBroadcastConfig(),
                streamConfig: YouTubeStreamConfig(),
                accessToken: "token"
            )
            XCTFail("Expected error")
        } catch let error as YouTubeAPIError {
            XCTAssertEqual(error, .quotaExceeded)
            XCTAssertEqual(error.category, .quota)
        } catch {
            XCTFail("Unexpected error type")
        }
    }

    // MARK: - URL Protocol Tests for Real YouTubeAPIService

    func testRealService_createBroadcast_networkError() async {
        // Use a custom session that rejects all requests
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FailingURLProtocol.self]
        let session = URLSession(configuration: config)
        let service = YouTubeAPIService(session: session)

        do {
            _ = try await service.createBroadcast(
                config: YouTubeBroadcastConfig(),
                accessToken: "token"
            )
            XCTFail("Expected error")
        } catch let error as YouTubeAPIError {
            XCTAssertEqual(error.category, .network)
        } catch {
            // Any error is acceptable for network failure
        }
    }

    func testRealService_createBroadcast_http401() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [HTTP401URLProtocol.self]
        let session = URLSession(configuration: config)
        let service = YouTubeAPIService(session: session)

        do {
            _ = try await service.createBroadcast(
                config: YouTubeBroadcastConfig(),
                accessToken: "bad-token"
            )
            XCTFail("Expected error")
        } catch let error as YouTubeAPIError {
            XCTAssertEqual(error.category, .authentication)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testRealService_createBroadcast_http403_quota() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [HTTP403QuotaURLProtocol.self]
        let session = URLSession(configuration: config)
        let service = YouTubeAPIService(session: session)

        do {
            _ = try await service.createBroadcast(
                config: YouTubeBroadcastConfig(),
                accessToken: "token"
            )
            XCTFail("Expected error")
        } catch let error as YouTubeAPIError {
            XCTAssertEqual(error, .quotaExceeded)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testRealService_createBroadcast_success() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [SuccessBroadcastURLProtocol.self]
        let session = URLSession(configuration: config)
        let service = YouTubeAPIService(session: session)

        let response = try await service.createBroadcast(
            config: YouTubeBroadcastConfig(title: "Test"),
            accessToken: "good-token"
        )

        XCTAssertEqual(response.id, "real-broadcast-id")
    }
}

// MARK: - URL Protocol Stubs

/// A URL protocol that always fails with a network error
private class FailingURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        client?.urlProtocol(self, didFailWithError: error)
    }

    override func stopLoading() {}
}

/// A URL protocol that returns HTTP 401
private class HTTP401URLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 401,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        let body = """
        {"error":{"code":401,"message":"Invalid credentials"}}
        """.data(using: .utf8)!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// A URL protocol that returns HTTP 403 with quota exceeded error
private class HTTP403QuotaURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 403,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        let body = """
        {"error":{"code":403,"message":"quota exceeded","errors":[{"domain":"youtube.quota","reason":"quotaExceeded","message":"Quota exceeded"}]}}
        """.data(using: .utf8)!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// A URL protocol that returns a successful broadcast response
private class SuccessBroadcastURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        let body = """
        {"kind":"youtube#liveBroadcast","etag":"etag","id":"real-broadcast-id","snippet":{"title":"Test"},"status":{"lifeCycleStatus":"created","privacyStatus":"unlisted"}}
        """.data(using: .utf8)!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
