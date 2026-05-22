import Foundation

/// Represents the state of a photo capture or video recording operation
enum CaptureState: Equatable {
    /// No capture in progress
    case idle
    /// Currently capturing a photo
    case capturing
    /// Capture completed successfully
    case captured
    /// Capture failed with an error
    case failed(String)
    /// Currently recording video
    case recording
    /// Stopping the recording (finalizing)
    case stoppingRecording
}
