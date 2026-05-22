import CoreGraphics
import CoreVideo
import Foundation
import ImageIO

/// Protocol abstracting face recognition (identification) capabilities.
/// Compares detected faces against registered face data to determine
/// if a face is registered or unknown.
protocol FaceRecognitionServiceProtocol: AnyObject {
    /// Load registered face embeddings from stored face image data.
    /// Should be called once at startup or when face registrations change.
    /// - Parameter faceImageData: JPEG data of the registered face image
    func loadRegisteredFace(from faceImageData: Data)

    /// Load multiple registered face embeddings from stored face image data.
    /// Replaces any previously loaded face data.
    /// - Parameter faceImageDataArray: Array of JPEG data for each registered face
    func loadRegisteredFaces(from faceImageDataArray: [Data])

    /// Whether registered face data has been loaded
    var hasRegisteredFace: Bool { get }

    /// Detect and identify all faces in a pixel buffer.
    /// Returns an array of DetectedFace with isRegistered set appropriately.
    /// - Parameters:
    ///   - pixelBuffer: The camera frame pixel buffer
    ///   - orientation: The image orientation for proper detection
    /// - Returns: Array of detected faces with identification results
    func detectAndIdentifyFaces(in pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) -> [DetectedFace]
}
