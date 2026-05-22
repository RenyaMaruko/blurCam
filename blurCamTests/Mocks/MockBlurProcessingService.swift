import CoreImage
import CoreVideo
import Foundation
@testable import blurCam

/// Mock implementation of BlurProcessingServiceProtocol for testing
final class MockBlurProcessingService: BlurProcessingServiceProtocol {

    // MARK: - Configurable State

    var blurRadius: CGFloat = 30.0
    var applyBlurPixelBufferResult: CIImage?
    var applyBlurCIImageResult: CIImage?

    // MARK: - Call Tracking

    var applyBlurPixelBufferCallCount = 0
    var applyBlurCIImageCallCount = 0
    var lastFacesReceived: [DetectedFace] = []

    // MARK: - BlurProcessingServiceProtocol

    func applyBlur(
        to pixelBuffer: CVPixelBuffer,
        faces: [DetectedFace],
        imageWidth: Int,
        imageHeight: Int
    ) -> CIImage? {
        applyBlurPixelBufferCallCount += 1
        lastFacesReceived = faces
        return applyBlurPixelBufferResult ?? CIImage(cvPixelBuffer: pixelBuffer)
    }

    func applyBlur(
        to ciImage: CIImage,
        faces: [DetectedFace]
    ) -> CIImage? {
        applyBlurCIImageCallCount += 1
        lastFacesReceived = faces
        return applyBlurCIImageResult ?? ciImage
    }
}
