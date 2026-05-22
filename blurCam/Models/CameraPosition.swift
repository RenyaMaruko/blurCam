import AVFoundation
import Foundation

/// Represents the physical position of the camera (front or back)
enum CameraPosition: Equatable {
    /// Back-facing camera (default)
    case back
    /// Front-facing camera (selfie)
    case front

    /// The corresponding AVCaptureDevice.Position
    var avPosition: AVCaptureDevice.Position {
        switch self {
        case .back:
            return .back
        case .front:
            return .front
        }
    }

    /// Returns the opposite camera position
    var toggled: CameraPosition {
        switch self {
        case .back:
            return .front
        case .front:
            return .back
        }
    }
}
