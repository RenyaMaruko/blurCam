import Foundation

/// Represents the current state of photo library permission
enum PhotoLibraryPermissionStatus: Equatable {
    /// Permission has not been determined yet
    case notDetermined
    /// Permission has been granted (full or limited access)
    case authorized
    /// Permission has been denied or restricted
    case denied
}
