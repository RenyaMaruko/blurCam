import CoreImage
import CoreVideo
import Foundation

/// Protocol abstracting blur processing capabilities.
/// Applies Gaussian blur to specific face regions in camera frames.
protocol BlurProcessingServiceProtocol: AnyObject {
    /// Apply Gaussian blur to unregistered face regions in a pixel buffer.
    /// - Parameters:
    ///   - pixelBuffer: The original camera frame
    ///   - faces: Array of detected faces with identification status
    ///   - imageWidth: Width of the image in pixels
    ///   - imageHeight: Height of the image in pixels
    /// - Returns: A CIImage with blur applied to unregistered face regions
    func applyBlur(
        to pixelBuffer: CVPixelBuffer,
        faces: [DetectedFace],
        imageWidth: Int,
        imageHeight: Int
    ) -> CIImage?

    /// Apply Gaussian blur to unregistered face regions in a CIImage.
    /// Used for still photo processing.
    /// - Parameters:
    ///   - ciImage: The original image
    ///   - faces: Array of detected faces with identification status
    /// - Returns: A CIImage with blur applied to unregistered face regions
    func applyBlur(
        to ciImage: CIImage,
        faces: [DetectedFace]
    ) -> CIImage?

    /// The blur radius to apply. Higher values = more blur.
    var blurRadius: CGFloat { get set }
}
