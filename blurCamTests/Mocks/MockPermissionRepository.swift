import Foundation
@testable import blurCam

/// Mock implementation of PermissionRepositoryProtocol for testing
final class MockPermissionRepository: PermissionRepositoryProtocol, @unchecked Sendable {

    // MARK: - Configurable Return Values

    var cameraStatus: CameraPermissionStatus = .notDetermined
    var photoLibraryStatus: PhotoLibraryPermissionStatus = .notDetermined
    var microphoneStatus: MicrophonePermissionStatus = .notDetermined
    var cameraRequestResult: CameraPermissionStatus = .authorized
    var photoLibraryRequestResult: PhotoLibraryPermissionStatus = .authorized
    var microphoneRequestResult: MicrophonePermissionStatus = .authorized

    // MARK: - Call Tracking

    var cameraPermissionStatusCallCount = 0
    var requestCameraPermissionCallCount = 0
    var photoLibraryPermissionStatusCallCount = 0
    var requestPhotoLibraryPermissionCallCount = 0
    var microphonePermissionStatusCallCount = 0
    var requestMicrophonePermissionCallCount = 0
    var openAppSettingsCallCount = 0

    // MARK: - PermissionRepositoryProtocol

    func cameraPermissionStatus() -> CameraPermissionStatus {
        cameraPermissionStatusCallCount += 1
        return cameraStatus
    }

    func requestCameraPermission() async -> CameraPermissionStatus {
        requestCameraPermissionCallCount += 1
        cameraStatus = cameraRequestResult
        return cameraRequestResult
    }

    func photoLibraryPermissionStatus() -> PhotoLibraryPermissionStatus {
        photoLibraryPermissionStatusCallCount += 1
        return photoLibraryStatus
    }

    func requestPhotoLibraryPermission() async -> PhotoLibraryPermissionStatus {
        requestPhotoLibraryPermissionCallCount += 1
        photoLibraryStatus = photoLibraryRequestResult
        return photoLibraryRequestResult
    }

    func microphonePermissionStatus() -> MicrophonePermissionStatus {
        microphonePermissionStatusCallCount += 1
        return microphoneStatus
    }

    func requestMicrophonePermission() async -> MicrophonePermissionStatus {
        requestMicrophonePermissionCallCount += 1
        microphoneStatus = microphoneRequestResult
        return microphoneRequestResult
    }

    func openAppSettings() {
        openAppSettingsCallCount += 1
    }
}
