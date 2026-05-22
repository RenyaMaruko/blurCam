import XCTest
@testable import blurCam

final class ModelTests: XCTestCase {

    // MARK: - CameraPermissionStatus Tests

    func testCameraPermissionStatus_Equatable() {
        XCTAssertEqual(CameraPermissionStatus.notDetermined, CameraPermissionStatus.notDetermined)
        XCTAssertEqual(CameraPermissionStatus.authorized, CameraPermissionStatus.authorized)
        XCTAssertEqual(CameraPermissionStatus.denied, CameraPermissionStatus.denied)
        XCTAssertNotEqual(CameraPermissionStatus.notDetermined, CameraPermissionStatus.authorized)
        XCTAssertNotEqual(CameraPermissionStatus.authorized, CameraPermissionStatus.denied)
    }

    // MARK: - PhotoLibraryPermissionStatus Tests

    func testPhotoLibraryPermissionStatus_Equatable() {
        XCTAssertEqual(PhotoLibraryPermissionStatus.notDetermined, PhotoLibraryPermissionStatus.notDetermined)
        XCTAssertEqual(PhotoLibraryPermissionStatus.authorized, PhotoLibraryPermissionStatus.authorized)
        XCTAssertEqual(PhotoLibraryPermissionStatus.denied, PhotoLibraryPermissionStatus.denied)
        XCTAssertNotEqual(PhotoLibraryPermissionStatus.notDetermined, PhotoLibraryPermissionStatus.authorized)
    }

    // MARK: - CaptureState Tests

    func testCaptureState_Equatable() {
        XCTAssertEqual(CaptureState.idle, CaptureState.idle)
        XCTAssertEqual(CaptureState.capturing, CaptureState.capturing)
        XCTAssertEqual(CaptureState.captured, CaptureState.captured)
        XCTAssertEqual(CaptureState.recording, CaptureState.recording)
        XCTAssertEqual(CaptureState.stoppingRecording, CaptureState.stoppingRecording)
        XCTAssertEqual(CaptureState.failed("error"), CaptureState.failed("error"))
        XCTAssertNotEqual(CaptureState.idle, CaptureState.capturing)
        XCTAssertNotEqual(CaptureState.idle, CaptureState.recording)
        XCTAssertNotEqual(CaptureState.recording, CaptureState.stoppingRecording)
        XCTAssertNotEqual(CaptureState.failed("a"), CaptureState.failed("b"))
    }

    // MARK: - PhotoRepositoryError Tests

    func testPhotoRepositoryError_Descriptions() {
        let saveError = PhotoRepositoryError.saveFailed("test")
        XCTAssertNotNil(saveError.errorDescription)
        XCTAssertTrue(saveError.errorDescription!.contains("test"))

        let invalidError = PhotoRepositoryError.invalidImageData
        XCTAssertNotNil(invalidError.errorDescription)

        let videoSaveError = PhotoRepositoryError.videoSaveFailed("test")
        XCTAssertNotNil(videoSaveError.errorDescription)
        XCTAssertTrue(videoSaveError.errorDescription!.contains("test"))
    }

    // MARK: - CameraServiceError Tests

    func testCameraServiceError_Descriptions() {
        let errors: [CameraServiceError] = [
            .cameraUnavailable,
            .cannotAddInput,
            .cannotAddOutput,
            .captureInProgress,
            .captureFailed("test"),
            .switchFailed("test"),
            .torchUnavailable
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error \(error) should have a description")
        }
    }
}
