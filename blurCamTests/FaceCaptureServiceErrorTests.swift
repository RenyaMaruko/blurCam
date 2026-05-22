import XCTest
@testable import blurCam

final class FaceCaptureServiceErrorTests: XCTestCase {

    func testFaceCaptureServiceError_Descriptions() {
        let errors: [FaceCaptureServiceError] = [
            .frontCameraUnavailable,
            .cannotAddInput,
            .cannotAddOutput,
            .captureInProgress,
            .captureFailed("test")
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error \(error) should have a description")
        }
    }

    func testFaceDetectionServiceError_Descriptions() {
        let errors: [FaceDetectionServiceError] = [
            .cannotAddVideoOutput,
            .detectionFailed("test")
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error \(error) should have a description")
        }
    }
}
