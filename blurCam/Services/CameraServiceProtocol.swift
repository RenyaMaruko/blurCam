import AVFoundation
import Foundation

/// Protocol abstracting camera session management.
/// Allows swapping implementations for testing or future changes.
protocol CameraServiceProtocol: AnyObject {
    /// The underlying AVCaptureSession for preview display
    var captureSession: AVCaptureSession { get }

    /// Whether the camera session is currently running
    var isRunning: Bool { get }

    /// The current camera position (front or back)
    var currentPosition: CameraPosition { get }

    /// The current flash mode
    var flashMode: FlashMode { get set }

    /// Whether the current device has a flash/torch
    var hasFlash: Bool { get }

    /// Whether the torch (continuous light) is currently active
    var isTorchActive: Bool { get }

    /// Configures the camera session with the back camera
    func configure() throws

    /// Starts the camera capture session
    func start()

    /// Stops the camera capture session
    func stop()

    /// Captures a photo and returns the image data
    func capturePhoto() async throws -> Data

    /// Switches between front and back camera.
    /// The caller is responsible for stopping/restarting frame processing around this call.
    /// - Returns: The new camera position after switching
    @discardableResult
    func switchCamera() throws -> CameraPosition

    /// Enables the torch (continuous light) for video recording.
    /// Only effective when the device has a torch (back camera).
    func enableTorch() throws

    /// Disables the torch.
    func disableTorch()

    /// Sets the camera zoom factor.
    /// - Parameter factor: Zoom factor (1.0 = no zoom)
    func setZoomFactor(_ factor: CGFloat)

    /// The current zoom factor
    var zoomFactor: CGFloat { get }

    /// The maximum zoom factor for the current device
    var maxZoomFactor: CGFloat { get }
}
