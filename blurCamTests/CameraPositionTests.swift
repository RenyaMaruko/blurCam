import AVFoundation
import XCTest
@testable import blurCam

final class CameraPositionTests: XCTestCase {

    // MARK: - AVPosition Mapping Tests

    func testAVPosition_Back() {
        XCTAssertEqual(CameraPosition.back.avPosition, .back)
    }

    func testAVPosition_Front() {
        XCTAssertEqual(CameraPosition.front.avPosition, .front)
    }

    // MARK: - Toggle Tests

    func testToggled_BackToFront() {
        XCTAssertEqual(CameraPosition.back.toggled, .front)
    }

    func testToggled_FrontToBack() {
        XCTAssertEqual(CameraPosition.front.toggled, .back)
    }

    func testToggled_DoubleToggleReturnsSame() {
        XCTAssertEqual(CameraPosition.back.toggled.toggled, .back)
        XCTAssertEqual(CameraPosition.front.toggled.toggled, .front)
    }

    // MARK: - Equatable Tests

    func testEquatable() {
        XCTAssertEqual(CameraPosition.back, CameraPosition.back)
        XCTAssertEqual(CameraPosition.front, CameraPosition.front)
        XCTAssertNotEqual(CameraPosition.back, CameraPosition.front)
    }
}
