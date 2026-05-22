import AVFoundation
import Foundation
@testable import blurCam

/// Mock implementation of FaceDetectionServiceProtocol for testing
final class MockFaceDetectionService: FaceDetectionServiceProtocol {

    // MARK: - Configurable State

    var isFaceDetected: Bool = false {
        didSet {
            if oldValue != isFaceDetected {
                onFaceDetectionChanged?(isFaceDetected)
            }
        }
    }

    var onFaceDetectionChanged: ((Bool) -> Void)?

    var detectFaceResult: Bool = true
    var startDetectionError: Error?

    // MARK: - Call Tracking

    var startDetectionCallCount = 0
    var stopDetectionCallCount = 0
    var detectFaceCallCount = 0

    // MARK: - FaceDetectionServiceProtocol

    func startDetection(on session: AVCaptureSession) throws {
        startDetectionCallCount += 1
        if let error = startDetectionError {
            throw error
        }
    }

    func stopDetection() {
        stopDetectionCallCount += 1
        isFaceDetected = false
    }

    func detectFace(in imageData: Data) -> Bool {
        detectFaceCallCount += 1
        return detectFaceResult
    }
}
