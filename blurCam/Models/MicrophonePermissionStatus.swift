import Foundation

/// Represents the current microphone permission authorization state
enum MicrophonePermissionStatus: Equatable {
    /// Permission has not yet been requested
    case notDetermined
    /// Permission has been granted
    case authorized
    /// Permission has been denied or restricted
    case denied
}
