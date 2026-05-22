import XCTest
@testable import blurCam

final class MicrophonePermissionStatusTests: XCTestCase {

    func testMicrophonePermissionStatus_Equatable() {
        XCTAssertEqual(MicrophonePermissionStatus.notDetermined, MicrophonePermissionStatus.notDetermined)
        XCTAssertEqual(MicrophonePermissionStatus.authorized, MicrophonePermissionStatus.authorized)
        XCTAssertEqual(MicrophonePermissionStatus.denied, MicrophonePermissionStatus.denied)
        XCTAssertNotEqual(MicrophonePermissionStatus.notDetermined, MicrophonePermissionStatus.authorized)
        XCTAssertNotEqual(MicrophonePermissionStatus.authorized, MicrophonePermissionStatus.denied)
    }
}
