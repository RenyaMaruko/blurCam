import AVFoundation
import Foundation
@testable import blurCam

/// Mock implementation of CameraServiceProtocol for testing
final class MockCameraService: CameraServiceProtocol {

    // MARK: - Properties

    let captureSession = AVCaptureSession()
    var isRunning: Bool = false
    var currentPosition: CameraPosition = .back
    var flashMode: FlashMode = .off
    var hasFlash: Bool = true
    var isTorchActive: Bool = false

    // MARK: - Configurable Behavior

    var configureError: Error?
    var capturePhotoResult: Result<Data, Error> = .success(Data())
    var switchCameraError: Error?
    var enableTorchError: Error?

    // MARK: - Call Tracking

    var configureCallCount = 0
    var startCallCount = 0
    var stopCallCount = 0
    var capturePhotoCallCount = 0
    var switchCameraCallCount = 0
    var enableTorchCallCount = 0
    var disableTorchCallCount = 0

    // MARK: - CameraServiceProtocol

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

    @discardableResult
    func switchCamera() throws -> CameraPosition {
        switchCameraCallCount += 1
        if let error = switchCameraError {
            throw error
        }
        currentPosition = currentPosition.toggled
        return currentPosition
    }

    func enableTorch() throws {
        enableTorchCallCount += 1
        if let error = enableTorchError {
            throw error
        }
        isTorchActive = true
    }

    func disableTorch() {
        disableTorchCallCount += 1
        isTorchActive = false
    }

    var zoomFactor: CGFloat = 1.0
    var maxZoomFactor: CGFloat = 10.0

    func setZoomFactor(_ factor: CGFloat) {
        zoomFactor = min(max(factor, 1.0), maxZoomFactor)
    }
}
