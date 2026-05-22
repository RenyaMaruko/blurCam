import XCTest
@testable import blurCam

final class DetectedFaceModelTests: XCTestCase {

    func testDetectedFace_DefaultValues() {
        let face = DetectedFace(
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
            isRegistered: false
        )

        XCTAssertEqual(face.boundingBox, CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4))
        XCTAssertFalse(face.isRegistered)
        XCTAssertEqual(face.confidence, 1.0)
        XCTAssertNotNil(face.id)
    }

    func testDetectedFace_RegisteredFace() {
        let face = DetectedFace(
            boundingBox: CGRect(x: 0.5, y: 0.5, width: 0.2, height: 0.2),
            isRegistered: true,
            confidence: 0.95
        )

        XCTAssertTrue(face.isRegistered)
        XCTAssertEqual(face.confidence, 0.95)
    }

    func testDetectedFace_Equatable() {
        let id = UUID()
        let face1 = DetectedFace(
            id: id,
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
            isRegistered: true,
            confidence: 0.9
        )
        let face2 = DetectedFace(
            id: id,
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
            isRegistered: true,
            confidence: 0.9
        )

        XCTAssertEqual(face1, face2)
    }

    func testDetectedFace_NotEqual_DifferentRegistered() {
        let id = UUID()
        let face1 = DetectedFace(
            id: id,
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
            isRegistered: true
        )
        let face2 = DetectedFace(
            id: id,
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
            isRegistered: false
        )

        XCTAssertNotEqual(face1, face2)
    }

    func testDetectedFace_Identifiable() {
        let face1 = DetectedFace(
            boundingBox: .zero,
            isRegistered: false
        )
        let face2 = DetectedFace(
            boundingBox: .zero,
            isRegistered: false
        )

        // Each face should have a unique ID
        XCTAssertNotEqual(face1.id, face2.id)
    }
}
