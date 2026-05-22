import Foundation
import SwiftUI

/// ViewModel responsible for managing camera and photo library permissions.
/// Uses PermissionRepositoryProtocol for data access abstraction.
@MainActor
final class PermissionViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var cameraPermission: CameraPermissionStatus = .notDetermined
    @Published private(set) var photoLibraryPermission: PhotoLibraryPermissionStatus = .notDetermined

    // MARK: - Dependencies

    private let permissionRepository: PermissionRepositoryProtocol

    // MARK: - Initialization

    init(permissionRepository: PermissionRepositoryProtocol = PermissionRepository()) {
        self.permissionRepository = permissionRepository
        refreshPermissions()
    }

    // MARK: - Public Methods

    /// Refreshes all permission statuses from the system
    func refreshPermissions() {
        cameraPermission = permissionRepository.cameraPermissionStatus()
        photoLibraryPermission = permissionRepository.photoLibraryPermissionStatus()
    }

    /// Requests camera permission from the user
    func requestCameraPermission() async {
        let status = await permissionRepository.requestCameraPermission()
        cameraPermission = status
    }

    /// Requests photo library permission from the user
    func requestPhotoLibraryPermission() async {
        let status = await permissionRepository.requestPhotoLibraryPermission()
        photoLibraryPermission = status
    }

    /// Opens the iOS Settings app for this application
    func openAppSettings() {
        permissionRepository.openAppSettings()
    }
}
