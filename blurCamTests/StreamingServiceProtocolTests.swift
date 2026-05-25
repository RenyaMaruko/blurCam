import XCTest
@testable import blurCam

final class StreamingServiceProtocolTests: XCTestCase {

    // MARK: - StreamingError Tests

    func testStreamingError_AlreadyStreaming_Description() {
        let error = StreamingError.alreadyStreaming
        XCTAssertEqual(error.localizedDescription, "既に配信中です")
    }

    func testStreamingError_NotStreaming_Description() {
        let error = StreamingError.notStreaming
        XCTAssertEqual(error.localizedDescription, "配信されていません")
    }

    func testStreamingError_ConnectionFailed_Description() {
        let error = StreamingError.connectionFailed("サーバーに到達できません")
        XCTAssertTrue(error.localizedDescription.contains("RTMP接続に失敗しました"))
        XCTAssertTrue(error.localizedDescription.contains("サーバーに到達できません"))
    }

    func testStreamingError_InvalidURL_Description() {
        let error = StreamingError.invalidURL
        XCTAssertEqual(error.localizedDescription, "無効なRTMP URLです")
    }

    func testStreamingError_MissingConfiguration_Description() {
        let error = StreamingError.missingConfiguration
        XCTAssertTrue(error.localizedDescription.contains("配信先が設定されていません"))
    }

    // MARK: - MockStreamingService Tests

    func testMockStreamingService_InitialState() {
        let service = MockStreamingService()
        XCTAssertEqual(service.streamingState, .idle)
        XCTAssertEqual(service.startStreamingCallCount, 0)
        XCTAssertEqual(service.stopStreamingCallCount, 0)
    }

    func testMockStreamingService_StartStreaming() throws {
        let service = MockStreamingService()

        try service.startStreaming(
            url: "rtmp://test.com/live",
            streamKey: "key123",
            width: 1920,
            height: 1080
        )

        XCTAssertEqual(service.startStreamingCallCount, 1)
        XCTAssertEqual(service.startStreamingURL, "rtmp://test.com/live")
        XCTAssertEqual(service.startStreamingStreamKey, "key123")
        XCTAssertEqual(service.startStreamingWidth, 1920)
        XCTAssertEqual(service.startStreamingHeight, 1080)
        XCTAssertEqual(service.streamingState, .streaming)
    }

    func testMockStreamingService_StopStreaming() throws {
        let service = MockStreamingService()

        try service.startStreaming(url: "rtmp://test.com/live", streamKey: "key", width: 1920, height: 1080)
        service.stopStreaming()

        XCTAssertEqual(service.stopStreamingCallCount, 1)
        XCTAssertEqual(service.streamingState, .idle)
    }

    func testMockStreamingService_ThrowsError() {
        let service = MockStreamingService()
        service.startStreamingError = StreamingError.invalidURL

        XCTAssertThrowsError(
            try service.startStreaming(url: "bad", streamKey: "", width: 1920, height: 1080)
        ) { error in
            XCTAssertTrue(error is StreamingError)
        }
    }

    func testMockStreamingService_SimulateDisconnection() throws {
        let service = MockStreamingService()
        var stateChanges: [StreamingState] = []
        service.onStateChanged = { state in
            stateChanges.append(state)
        }

        try service.startStreaming(url: "rtmp://test.com/live", streamKey: "key", width: 1920, height: 1080)
        service.simulateDisconnection()

        XCTAssertTrue(stateChanges.contains(where: {
            if case .error = $0 { return true }
            return false
        }))
    }
}
