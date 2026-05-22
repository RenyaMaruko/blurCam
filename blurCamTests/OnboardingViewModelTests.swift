import XCTest
@testable import blurCam

@MainActor
final class OnboardingViewModelTests: XCTestCase {

    private var mockFaceRepo: MockFaceRepository!

    override func setUp() {
        super.setUp()
        mockFaceRepo = MockFaceRepository()
    }

    override func tearDown() {
        mockFaceRepo = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInit_FaceNotRegistered_ShowsWelcome() {
        mockFaceRepo.hasRegisteredFace = false
        let viewModel = OnboardingViewModel(faceRepository: mockFaceRepo)

        XCTAssertFalse(viewModel.isFaceRegistered)
        XCTAssertEqual(viewModel.currentStep, .welcome)
    }

    func testInit_FaceAlreadyRegistered() {
        mockFaceRepo.hasRegisteredFace = true
        let viewModel = OnboardingViewModel(faceRepository: mockFaceRepo)

        XCTAssertTrue(viewModel.isFaceRegistered)
    }

    // MARK: - Welcome -> Face Capture Navigation Tests

    func testNavigateToFaceCapture_UpdatesStep() {
        let viewModel = OnboardingViewModel(faceRepository: mockFaceRepo)

        viewModel.navigateToFaceCapture()

        XCTAssertEqual(viewModel.currentStep, .faceCapture)
        XCTAssertFalse(viewModel.navigationPath.isEmpty)
    }

    // MARK: - Face Capture -> Complete Navigation Tests

    func testOnFaceRegistrationComplete_UpdatesStepAndRegistrationStatus() {
        let viewModel = OnboardingViewModel(faceRepository: mockFaceRepo)

        viewModel.navigateToFaceCapture()
        viewModel.onFaceRegistrationComplete()

        XCTAssertTrue(viewModel.isFaceRegistered)
        XCTAssertEqual(viewModel.currentStep, .complete)
    }

    // MARK: - Back Navigation Tests

    func testNavigateBackToWelcome_FromFaceCapture() {
        let viewModel = OnboardingViewModel(faceRepository: mockFaceRepo)

        viewModel.navigateToFaceCapture()
        XCTAssertEqual(viewModel.currentStep, .faceCapture)

        viewModel.navigateBackToWelcome()

        XCTAssertEqual(viewModel.currentStep, .welcome)
        XCTAssertTrue(viewModel.navigationPath.isEmpty)
    }

    func testNavigateBackToWelcome_EmptyPathDoesNotCrash() {
        let viewModel = OnboardingViewModel(faceRepository: mockFaceRepo)

        // Should not crash even with empty path
        viewModel.navigateBackToWelcome()

        XCTAssertEqual(viewModel.currentStep, .welcome)
    }

    // MARK: - Complete Onboarding Tests

    func testCompleteOnboarding_AfterRegistration() {
        let viewModel = OnboardingViewModel(faceRepository: mockFaceRepo)

        viewModel.navigateToFaceCapture()
        viewModel.onFaceRegistrationComplete()
        viewModel.completeOnboarding()

        XCTAssertTrue(viewModel.isFaceRegistered)
    }

    // MARK: - Check Registration Status Tests

    func testCheckRegistrationStatus_UpdatesState() {
        mockFaceRepo.hasRegisteredFace = false
        let viewModel = OnboardingViewModel(faceRepository: mockFaceRepo)
        XCTAssertFalse(viewModel.isFaceRegistered)

        // Simulate external registration
        mockFaceRepo.hasRegisteredFace = true
        viewModel.checkRegistrationStatus()

        XCTAssertTrue(viewModel.isFaceRegistered)
    }

    // MARK: - Flow Sequence Tests

    func testFullOnboardingFlow_WelcomeToFaceCaptureToComplete() {
        let viewModel = OnboardingViewModel(faceRepository: mockFaceRepo)

        // Step 1: Welcome
        XCTAssertEqual(viewModel.currentStep, .welcome)
        XCTAssertFalse(viewModel.isFaceRegistered)

        // Step 2: Navigate to face capture
        viewModel.navigateToFaceCapture()
        XCTAssertEqual(viewModel.currentStep, .faceCapture)

        // Step 3: Complete registration
        viewModel.onFaceRegistrationComplete()
        XCTAssertEqual(viewModel.currentStep, .complete)
        XCTAssertTrue(viewModel.isFaceRegistered)

        // Step 4: Complete onboarding
        viewModel.completeOnboarding()
        XCTAssertTrue(viewModel.isFaceRegistered)
    }

    // MARK: - Skip Onboarding Tests

    func testRegisteredUser_SkipsOnboarding() {
        mockFaceRepo.hasRegisteredFace = true
        let viewModel = OnboardingViewModel(faceRepository: mockFaceRepo)

        // If face is already registered, onboarding should be skippable
        XCTAssertTrue(viewModel.isFaceRegistered)
    }
}
