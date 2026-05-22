import AVFoundation
import Foundation
@testable import blurCam

/// Mock implementation of FaceCaptureServiceProtocol for testing
final class MockFaceCaptureService: FaceCaptureServiceProtocol {

    // MARK: - Properties

    let captureSession = AVCaptureSession()
    var isRunning: Bool = false

    // MARK: - Configurable Behavior

    var configureError: Error?
    var capturePhotoResult: Result<Data, Error> = .success(Data([0xFF, 0xD8, 0xFF]))

    // MARK: - Call Tracking

    var configureCallCount = 0
    var startCallCount = 0
    var stopCallCount = 0
    var capturePhotoCallCount = 0

    // MARK: - FaceCaptureServiceProtocol

    func configure() throws {
        configureCallCount += 1
        if let error = configureError {
            throw error
        }
    }

    func start() {
        startCallCount += 1
        isRunning = true
    }

    func stop() {
        stopCallCount += 1
        isRunning = false
    }

    func capturePhoto() async throws -> Data {
        capturePhotoCallCount += 1
        switch capturePhotoResult {
        case .success(let data):
            return data
        case .failure(let error):
            throw error
        }
    }
}
