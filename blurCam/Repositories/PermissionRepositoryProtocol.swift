import Foundation

/// Protocol abstracting permission-related data access.
/// Allows swapping implementations for testing or future changes.
protocol PermissionRepositoryProtocol: Sendable {
    /// Returns the current camera permission status
    func cameraPermissionStatus() -> CameraPermissionStatus

    /// Requests camera permission and returns the resulting status
    func requestCameraPermission() async -> CameraPermissionStatus

    /// Returns the current photo library permission status
    func photoLibraryPermissionStatus() -> PhotoLibraryPermissionStatus

    /// Requests photo library add-only permission and returns the resulting status
    func requestPhotoLibraryPermission() async -> PhotoLibraryPermissionStatus

    /// Returns the current microphone permission status
    func microphonePermissionStatus() -> MicrophonePermissionStatus

    /// Requests microphone permission and returns the resulting status
    func requestMicrophonePermission() async -> MicrophonePermissionStatus

    /// Opens the iOS Settings app for this application
    func openAppSettings()
}
