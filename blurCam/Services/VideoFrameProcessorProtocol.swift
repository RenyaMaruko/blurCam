import AVFoundation
import CoreImage
import CoreVideo
import Foundation

/// Protocol for processing video frames from the camera.
/// Provides a callback-based interface for receiving processed frames.
protocol VideoFrameProcessorProtocol: AnyObject {
    /// Callback invoked on each processed frame with the resulting CIImage.
    /// Called on a background queue - callers must dispatch to main if needed for UI updates.
    var onFrameProcessed: ((CIImage) -> Void)? { get set }

    /// Callback invoked when detected faces change.
    /// Called on a background queue - callers must dispatch to main if needed.
    var onFacesDetected: (([DetectedFace]) -> Void)? { get set }

    /// Callback invoked on each processed frame with the pixel buffer and presentation time.
    /// Used for video recording - provides blur-processed pixel buffers for AVAssetWriter.
    /// Called on a background queue.
    var onProcessedPixelBuffer: ((CVPixelBuffer, CMTime) -> Void)? { get set }

    /// Callback invoked for each audio sample buffer captured.
    /// Used for video recording - provides audio data for AVAssetWriter.
    /// Called on a background queue.
    var onAudioSampleBuffer: ((CMSampleBuffer) -> Void)? { get set }

    /// Load registered face data for recognition (single face, backward compatible).
    /// - Parameter faceImageData: JPEG data of the registered face image
    func loadRegisteredFace(from faceImageData: Data)

    /// Load multiple registered face data for recognition.
    /// Replaces any previously loaded face data.
    /// - Parameter faceImageDataArray: Array of JPEG data for each registered face
    func loadRegisteredFaces(from faceImageDataArray: [Data])

    /// Start processing video frames from the given capture session.
    /// Adds a video data output to the session.
    func startProcessing(on session: AVCaptureSession) throws

    /// Stop processing and remove video data output from the session.
    func stopProcessing()

    /// Process a single image (for photo capture).
    /// Detects faces, identifies them, and applies blur.
    /// - Parameter imageData: The captured photo data
    /// - Returns: Processed image data with blur applied, or nil on failure
    func processStillImage(_ imageData: Data) -> Data?

    /// Add audio capture output to the session for video recording.
    /// - Parameter session: The capture session to add audio output to
    func startAudioCapture(on session: AVCaptureSession) throws

    /// Remove audio capture output from the session.
    func stopAudioCapture()

    /// Re-apply video connection settings after camera input change.
    func refreshVideoConnection()

    /// The dimensions of the current video output frames
    var videoWidth: Int { get }
    var videoHeight: Int { get }

    /// Access the blur processing service for configuring blur radius
    var blurProcessingService: BlurProcessingServiceProtocol { get }
}
