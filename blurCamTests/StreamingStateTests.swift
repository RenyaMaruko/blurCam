import XCTest
@testable import blurCam

final class StreamingStateTests: XCTestCase {

    // MARK: - Equatable Tests

    func testIdle_IsEqual() {
        XCTAssertEqual(StreamingState.idle, StreamingState.idle)
    }

    func testConnecting_IsEqual() {
        XCTAssertEqual(StreamingState.connecting, StreamingState.connecting)
    }

    func testStreaming_IsEqual() {
        XCTAssertEqual(StreamingState.streaming, StreamingState.streaming)
    }

    func testError_IsEqual_WithSameMessage() {
        XCTAssertEqual(StreamingState.error("test"), StreamingState.error("test"))
    }

    func testError_IsNotEqual_WithDifferentMessage() {
        XCTAssertNotEqual(StreamingState.error("test1"), StreamingState.error("test2"))
    }

    func testDifferentStates_AreNotEqual() {
        XCTAssertNotEqual(StreamingState.idle, StreamingState.connecting)
        XCTAssertNotEqual(StreamingState.idle, StreamingState.streaming)
        XCTAssertNotEqual(StreamingState.connecting, StreamingState.streaming)
    }

    // MARK: - isStreaming Tests

    func testIsStreaming_TrueWhenStreaming() {
        XCTAssertTrue(StreamingState.streaming.isStreaming)
    }

    func testIsStreaming_FalseWhenIdle() {
        XCTAssertFalse(StreamingState.idle.isStreaming)
    }

    func testIsStreaming_FalseWhenConnecting() {
        XCTAssertFalse(StreamingState.connecting.isStreaming)
    }

    func testIsStreaming_FalseWhenError() {
        XCTAssertFalse(StreamingState.error("test").isStreaming)
    }

    // MARK: - isActive Tests

    func testIsActive_TrueWhenConnecting() {
        XCTAssertTrue(StreamingState.connecting.isActive)
    }

    func testIsActive_TrueWhenStreaming() {
        XCTAssertTrue(StreamingState.streaming.isActive)
    }

    func testIsActive_FalseWhenIdle() {
        XCTAssertFalse(StreamingState.idle.isActive)
    }

    func testIsActive_FalseWhenError() {
        XCTAssertFalse(StreamingState.error("test").isActive)
    }

    // MARK: - Hashable Tests

    func testHashable_SameStatesHaveSameHash() {
        XCTAssertEqual(StreamingState.idle.hashValue, StreamingState.idle.hashValue)
        XCTAssertEqual(StreamingState.streaming.hashValue, StreamingState.streaming.hashValue)
    }
}
