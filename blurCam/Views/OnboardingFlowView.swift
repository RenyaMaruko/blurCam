import SwiftUI

/// Container view that manages the onboarding navigation flow.
/// Uses NavigationStack to handle transitions between:
/// Welcome -> Face Capture -> Registration Complete
struct OnboardingFlowView: View {

    @StateObject private var onboardingViewModel = OnboardingViewModel()

    /// Called when the entire onboarding flow is complete
    let onOnboardingComplete: () -> Void

    var body: some View {
        NavigationStack(path: $onboardingViewModel.navigationPath) {
            // Root: Welcome screen
            WelcomeView {
                onboardingViewModel.navigateToFaceCapture()
            }
            .navigationBarHidden(true)
            .navigationDestination(for: OnboardingStep.self) { step in
                switch step {
                case .welcome:
                    EmptyView()
                case .faceCapture:
                    FaceCaptureView(
                        onFaceCaptured: {
                            onboardingViewModel.onFaceRegistrationComplete()
                        },
                        onBack: {
                            onboardingViewModel.navigateBackToWelcome()
                        }
                    )
                    .navigationBarHidden(true)
                case .complete:
                    RegistrationCompleteView {
                        onboardingViewModel.completeOnboarding()
                        onOnboardingComplete()
                    }
                    .navigationBarHidden(true)
                }
            }
        }
    }
}
