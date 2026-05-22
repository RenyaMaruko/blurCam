import CoreGraphics
import CoreVideo
import Foundation
import ImageIO
@testable import blurCam

/// Mock implementation of FaceRecognitionServiceProtocol for testing
final class MockFaceRecognitionService: FaceRecognitionServiceProtocol {

    // MARK: - Configurable State

    var hasRegisteredFace: Bool = false
    var detectAndIdentifyResult: [DetectedFace] = []

    // MARK: - Call Tracking

    var loadRegisteredFaceCallCount = 0
    var loadRegisteredFaceData: [Data] = []
    var loadRegisteredFacesCallCount = 0
    var loadRegisteredFacesDataArrays: [[Data]] = []
    var detectAndIdentifyCallCount = 0

    // MARK: - FaceRecognitionServiceProtocol

    func loadRegisteredFace(from faceImageData: Data) {
        loadRegisteredFaceCallCount += 1
        loadRegisteredFaceData.append(faceImageData)
        hasRegisteredFace = true
    }

    func loadRegisteredFaces(from faceImageDataArray: [Data]) {
        loadRegisteredFacesCallCount += 1
        loadRegisteredFacesDataArrays.append(faceImageDataArray)
        hasRegisteredFace = !faceImageDataArray.isEmpty
    }

    func detectAndIdentifyFaces(
        in pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation
    ) -> [DetectedFace] {
        detectAndIdentifyCallCount += 1
        return detectAndIdentifyResult
    }
}
