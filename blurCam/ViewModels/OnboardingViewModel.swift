import Foundation
import SwiftUI

/// Represents the current step in the onboarding flow
enum OnboardingStep: Hashable {
    /// Welcome screen - explain app purpose
    case welcome
    /// Face capture screen - capture user's face
    case faceCapture
    /// Registration complete screen
    case complete
}

/// ViewModel responsible for managing the onboarding flow state.
/// Tracks whether the user has completed face registration and
/// which step of the onboarding they are currently on.
@MainActor
final class OnboardingViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Whether the user has completed face registration
    @Published private(set) var isFaceRegistered: Bool = false

    /// The current step in the onboarding flow
    @Published var currentStep: OnboardingStep = .welcome

    /// Navigation path for the onboarding flow
    @Published var navigationPath = NavigationPath()

    // MARK: - Dependencies

    private let faceRepository: FaceRepositoryProtocol

    // MARK: - Initialization

    init(faceRepository: FaceRepositoryProtocol = FaceRepository()) {
        self.faceRepository = faceRepository
        self.isFaceRegistered = faceRepository.hasFaceRegistered()
    }

    // MARK: - Public Methods

    /// Checks whether face registration exists and updates state
    func checkRegistrationStatus() {
        isFaceRegistered = faceRepository.hasFaceRegistered()
    }

    /// Navigates to the face capture screen
    func navigateToFaceCapture() {
        currentStep = .faceCapture
        navigationPath.append(OnboardingStep.faceCapture)
    }

    /// Called when face registration is complete
    func onFaceRegistrationComplete() {
        isFaceRegistered = true
        currentStep = .complete
        navigationPath.append(OnboardingStep.complete)
    }

    /// Navigates back to the welcome screen from face capture
    func navigateBackToWelcome() {
        currentStep = .welcome
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }

    /// Resets the navigation path (used when completing onboarding)
    func completeOnboarding() {
        // isFaceRegistered is already true at this point
        // The root view will detect this and show the camera screen
    }
}
