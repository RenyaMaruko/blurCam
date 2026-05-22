import SwiftUI

/// Root view of the application that handles navigation based on:
/// 1. Camera permission state
/// 2. Face registration state (onboarding)
///
/// Flow:
/// - If camera permission is not determined -> show permission request
/// - If camera permission is denied -> show denied screen
/// - If camera permission is authorized:
///   - If face is not registered -> show onboarding flow
///   - If face is registered -> show camera preview
///
/// Edge cases:
/// - Camera permission revoked after granting -> shows permission denied screen on next launch/foreground
/// - Face data lost/corrupted -> returns to onboarding flow
struct RootView: View {
    @StateObject private var permissionViewModel = PermissionViewModel()
    @State private var isFaceRegistered: Bool = false
    private let faceRepository: FaceRepositoryProtocol

    init(faceRepository: FaceRepositoryProtocol = FaceRepository()) {
        self.faceRepository = faceRepository
    }

    var body: some View {
        Group {
            switch permissionViewModel.cameraPermission {
            case .notDetermined:
                CameraPermissionRequestView(viewModel: permissionViewModel)
                    .transition(.opacity)
            case .authorized:
                if isFaceRegistered {
                    CameraPreviewScreen(
                        permissionViewModel: permissionViewModel,
                        onAllFacesDeleted: {
                            withAnimation(.easeInOut(duration: DesignTokens.Motion.normal)) {
                                isFaceRegistered = false
                            }
                        }
                    )
                    .transition(.opacity)
                } else {
                    OnboardingFlowView {
                        withAnimation(.easeInOut(duration: DesignTokens.Motion.normal)) {
                            isFaceRegistered = true
                        }
                    }
                    .transition(.opacity)
                }
            case .denied:
                CameraPermissionDeniedView(viewModel: permissionViewModel)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: DesignTokens.Motion.normal), value: permissionViewModel.cameraPermission)
        .animation(.easeInOut(duration: DesignTokens.Motion.normal), value: isFaceRegistered)
        .onAppear {
            checkFaceRegistrationStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            permissionViewModel.refreshPermissions()
            checkFaceRegistrationStatus()
        }
    }

    /// Checks if face data is still valid. If data is corrupted or missing,
    /// resets to unregistered state which triggers the onboarding flow.
    private func checkFaceRegistrationStatus() {
        let hasRegistered = faceRepository.hasFaceRegistered()

        // Additional validation: make sure face data files are actually accessible
        if hasRegistered {
            let registrations = faceRepository.loadAllRegistrations()
            if registrations.isEmpty {
                // Data file is corrupted or inaccessible
                isFaceRegistered = false
                return
            }

            // Check that at least one face has valid image data
            let hasValidImage = registrations.contains { registration in
                faceRepository.loadFaceImage(for: registration) != nil
            }

            if !hasValidImage {
                // Image files are missing; clean up and force re-registration
                try? faceRepository.deleteAll()
                isFaceRegistered = false
                return
            }
        }

        isFaceRegistered = hasRegistered
    }
}
