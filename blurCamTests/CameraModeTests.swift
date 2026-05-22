import XCTest
@testable import blurCam

final class CameraModeTests: XCTestCase {

    func testCameraMode_PhotoRawValue() {
        XCTAssertEqual(CameraMode.photo.rawValue, "写真")
    }

    func testCameraMode_VideoRawValue() {
        XCTAssertEqual(CameraMode.video.rawValue, "動画")
    }

    func testCameraMode_AllCases() {
        let allCases = CameraMode.allCases
        XCTAssertEqual(allCases.count, 2)
        XCTAssertTrue(allCases.contains(.photo))
        XCTAssertTrue(allCases.contains(.video))
    }

    func testCameraMode_Equatable() {
        XCTAssertEqual(CameraMode.photo, CameraMode.photo)
        XCTAssertEqual(CameraMode.video, CameraMode.video)
        XCTAssertNotEqual(CameraMode.photo, CameraMode.video)
    }
}
