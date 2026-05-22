import XCTest
@testable import blurCam

final class CaptureStateTests: XCTestCase {

    func testCaptureState_Equatable() {
        XCTAssertEqual(CaptureState.idle, CaptureState.idle)
        XCTAssertEqual(CaptureState.capturing, CaptureState.capturing)
        XCTAssertEqual(CaptureState.captured, CaptureState.captured)
        XCTAssertEqual(CaptureState.recording, CaptureState.recording)
        XCTAssertEqual(CaptureState.stoppingRecording, CaptureState.stoppingRecording)
        XCTAssertEqual(CaptureState.failed("error"), CaptureState.failed("error"))
    }

    func testCaptureState_NotEqual() {
        XCTAssertNotEqual(CaptureState.idle, CaptureState.capturing)
        XCTAssertNotEqual(CaptureState.idle, CaptureState.recording)
        XCTAssertNotEqual(CaptureState.recording, CaptureState.stoppingRecording)
        XCTAssertNotEqual(CaptureState.failed("a"), CaptureState.failed("b"))
    }
}
