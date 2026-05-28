import AVFoundation
import CoreImage
import CoreVideo
import Foundation
@testable import blurCam

/// Mock implementation of VideoFrameProcessorProtocol for testing
final class MockVideoFrameProcessor: VideoFrameProcessorProtocol {

    // MARK: - Configurable State

    var onFrameProcessed: ((CIImage) -> Void)?
    var onFacesDetected: (([DetectedFace]) -> Void)?
    var onProcessedPixelBuffer: ((CVPixelBuffer, CMTime) -> Void)?
    var onAudioSampleBuffer: ((CMSampleBuffer) -> Void)?
    var processStillImageResult: Data?
    var startProcessingError: Error?
    var startAudioCaptureError: Error?

    var videoWidth: Int = 1920
    var videoHeight: Int = 1080

    var blurProcessingService: BlurProcessingServiceProtocol = MockBlurProcessingService()

    // MARK: - Call Tracking

    var loadRegisteredFaceCallCount = 0
    var loadRegisteredFaceData: [Data] = []
    var loadRegisteredFacesCallCount = 0
    var loadRegisteredFacesDataArrays: [[Data]] = []
    var startProcessingCallCount = 0
    var stopProcessingCallCount = 0
    var processStillImageCallCount = 0
    var processStillImageInputData: [Data] = []
    var startAudioCaptureCallCount = 0
    var stopAudioCaptureCallCount = 0

    // MARK: - VideoFrameProcessorProtocol

    func loadRegisteredFace(from faceImageData: Data) {
        loadRegisteredFaceCallCount += 1
        loadRegisteredFaceData.append(faceImageData)
    }

    func loadRegisteredFaces(from faceImageDataArray: [Data]) {
        loadRegisteredFacesCallCount += 1
        loadRegisteredFacesDataArrays.append(faceImageDataArray)
    }

    func startProcessing(on session: AVCaptureSession) throws {
        startProcessingCallCount += 1
        if let error = startProcessingError {
            throw error
        }
    }

    func stopProcessing() {
        stopProcessingCallCount += 1
    }

    func processStillImage(_ imageData: Data) -> Data? {
        processStillImageCallCount += 1
        processStillImageInputData.append(imageData)
        return processStillImageResult ?? imageData
    }

    func startAudioCapture(on session: AVCaptureSession) throws {
        startAudioCaptureCallCount += 1
        if let error = startAudioCaptureError {
            throw error
        }
    }

    func stopAudioCapture() {
        stopAudioCaptureCallCount += 1
    }

    func refreshVideoConnection() {}
}
