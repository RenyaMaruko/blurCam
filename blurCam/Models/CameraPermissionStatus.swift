import Foundation

/// Represents the current state of camera permission
enum CameraPermissionStatus: Equatable {
    /// Permission has not been determined yet (first launch)
    case notDetermined
    /// Permission has been granted
    case authorized
    /// Permission has been denied or restricted
    case denied
}
