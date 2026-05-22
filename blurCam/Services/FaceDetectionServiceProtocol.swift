import AVFoundation
import Foundation
import Vision

/// Protocol abstracting face detection capabilities.
/// Allows swapping implementations for testing or future changes.
protocol FaceDetectionServiceProtocol: AnyObject {
    /// Whether at least one face is currently detected in the camera feed
    var isFaceDetected: Bool { get }

    /// Callback invoked when face detection state changes
    var onFaceDetectionChanged: ((Bool) -> Void)? { get set }

    /// Starts face detection on the given AVCaptureSession
    func startDetection(on session: AVCaptureSession) throws

    /// Stops face detection and removes the video output
    func stopDetection()

    /// Performs a one-time face detection on the given image data
    /// - Parameter imageData: JPEG or other image data to analyze
    /// - Returns: true if at least one face is detected
    func detectFace(in imageData: Data) -> Bool
}
