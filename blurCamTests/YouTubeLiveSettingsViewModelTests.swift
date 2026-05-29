import XCTest
@testable import blurCam

@MainActor
final class YouTubeLiveSettingsViewModelTests: XCTestCase {

    private var mockAuthService: MockGoogleAuthService!
    private var mockRepository: MockYouTubeLiveSettingsRepository!
    private var viewModel: YouTubeLiveSettingsViewModel!

    override func setUp() {
        super.setUp()
        mockAuthService = MockGoogleAuthService()
        mockRepository = MockYouTubeLiveSettingsRepository()
        viewModel = YouTubeLiveSettingsViewModel(
            googleAuthService: mockAuthService,
            repository: mockRepository
        )
    }

    override func tearDown() {
        mockAuthService = nil
        mockRepository = nil
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState_defaultValues() {
        XCTAssertEqual(viewModel.authState, .signedOut)
        XCTAssertEqual(viewModel.title, "blurCam Live")
        XCTAssertEqual(viewModel.broadcastDescription, "")
        XCTAssertEqual(viewModel.privacy, .privateBroadcast)
        XCTAssertEqual(viewModel.category, .entertainment)
        XCTAssertEqual(viewModel.latencyPreference, .normal)
        XCTAssertTrue(viewModel.enableChat)
        XCTAssertTrue(viewModel.enableDVR)
        XCTAssertNil(viewModel.validationError)
        XCTAssertFalse(viewModel.didSaveSuccessfully)
    }

    func testInitialState_loadsFromRepository() {
        let settings = YouTubeLiveSettings(
            title: "Stored Title",
            description: "Stored Desc",
            privacy: .publicBroadcast,
            category: .gaming,
            latencyPreference: .ultraLow,
            enableChat: false,
            enableDVR: false
        )
        mockRepository.savedSettings = settings

        let vm = YouTubeLiveSettingsViewModel(
            googleAuthService: mockAuthService,
            repository: mockRepository
        )

        XCTAssertEqual(vm.title, "Stored Title")
        XCTAssertEqual(vm.broadcastDescription, "Stored Desc")
        XCTAssertEqual(vm.privacy, .publicBroadcast)
        XCTAssertEqual(vm.category, .gaming)
        XCTAssertEqual(vm.latencyPreference, .ultraLow)
        XCTAssertFalse(vm.enableChat)
        XCTAssertFalse(vm.enableDVR)
    }

    // MARK: - Authentication Tests

    func testSignIn_success() async {
        await viewModel.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(mockAuthService.signInCallCount, 1)
        XCTAssertTrue(viewModel.authState.isSignedIn)
    }

    func testSignIn_cancelled() async {
        mockAuthService.signInError = GoogleAuthError.signInCancelled
        await viewModel.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Auth state should not remain signed in
        XCTAssertFalse(viewModel.authState.isSignedIn)
    }

    func testSignOut_clearsState() async {
        await viewModel.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(viewModel.authState.isSignedIn)

        viewModel.signOut()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(mockAuthService.signOutCallCount, 1)
        XCTAssertEqual(viewModel.authState, .signedOut)
    }

    func testRestorePreviousSignIn_success() async {
        mockAuthService.restorePreviousSignInResult = true
        await viewModel.restorePreviousSignIn()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(viewModel.authState.isSignedIn)
    }

    func testRestorePreviousSignIn_failure() async {
        mockAuthService.restorePreviousSignInResult = false
        await viewModel.restorePreviousSignIn()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.authState, .signedOut)
    }

    // MARK: - Google Account Display Tests

    func testSignedInUser_displaysProfileInfo() async {
        let userInfo = GoogleUserInfo(
            displayName: "Test User",
            email: "test@gmail.com",
            profileImageURL: URL(string: "https://example.com/photo.jpg")
        )
        mockAuthService.signInUserInfo = userInfo
        await viewModel.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)

        if case .signedIn(let info) = viewModel.authState {
            XCTAssertEqual(info.displayName, "Test User")
            XCTAssertEqual(info.email, "test@gmail.com")
            XCTAssertNotNil(info.profileImageURL)
        } else {
            XCTFail("Expected signed in state")
        }
    }

    // MARK: - Save Settings Tests

    func testSaveSettings_validTitle_succeeds() {
        viewModel.title = "My Stream"
        viewModel.broadcastDescription = "Description"
        viewModel.privacy = .unlisted
        viewModel.category = .education
        viewModel.latencyPreference = .low
        viewModel.enableChat = false
        viewModel.enableDVR = true

        let result = viewModel.saveSettings()

        XCTAssertTrue(result)
        XCTAssertTrue(viewModel.didSaveSuccessfully)
        XCTAssertNil(viewModel.validationError)
        XCTAssertEqual(mockRepository.saveSettingsCallCount, 1)
        XCTAssertEqual(mockRepository.savedSettings?.title, "My Stream")
        XCTAssertEqual(mockRepository.savedSettings?.description, "Description")
        XCTAssertEqual(mockRepository.savedSettings?.privacy, .unlisted)
        XCTAssertEqual(mockRepository.savedSettings?.category, .education)
        XCTAssertEqual(mockRepository.savedSettings?.latencyPreference, .low)
        XCTAssertEqual(mockRepository.savedSettings?.enableChat, false)
        XCTAssertEqual(mockRepository.savedSettings?.enableDVR, true)
    }

    func testSaveSettings_emptyTitle_fails() {
        viewModel.title = ""

        let result = viewModel.saveSettings()

        XCTAssertFalse(result)
        XCTAssertFalse(viewModel.didSaveSuccessfully)
        XCTAssertEqual(viewModel.validationError, .emptyTitle)
        XCTAssertEqual(mockRepository.saveSettingsCallCount, 0)
    }

    func testSaveSettings_whitespaceOnlyTitle_fails() {
        viewModel.title = "   "

        let result = viewModel.saveSettings()

        XCTAssertFalse(result)
        XCTAssertEqual(viewModel.validationError, .emptyTitle)
    }

    func testSaveSettings_trimsWhitespace() {
        viewModel.title = "  Trimmed Title  "
        viewModel.broadcastDescription = "  Trimmed Desc  "

        viewModel.saveSettings()

        XCTAssertEqual(mockRepository.savedSettings?.title, "Trimmed Title")
        XCTAssertEqual(mockRepository.savedSettings?.description, "Trimmed Desc")
    }

    func testSaveSettings_emptyDescription_succeeds() {
        viewModel.title = "Title"
        viewModel.broadcastDescription = ""

        let result = viewModel.saveSettings()

        XCTAssertTrue(result)
        XCTAssertEqual(mockRepository.savedSettings?.description, "")
    }

    // MARK: - Load Settings Tests

    func testLoadSettings_restoresFromRepository() {
        let settings = YouTubeLiveSettings(
            title: "Loaded Title",
            description: "Loaded Desc",
            privacy: .unlisted,
            category: .music,
            latencyPreference: .low,
            enableChat: false,
            enableDVR: false
        )
        mockRepository.savedSettings = settings

        viewModel.loadSettings()

        XCTAssertEqual(viewModel.title, "Loaded Title")
        XCTAssertEqual(viewModel.broadcastDescription, "Loaded Desc")
        XCTAssertEqual(viewModel.privacy, .unlisted)
        XCTAssertEqual(viewModel.category, .music)
        XCTAssertEqual(viewModel.latencyPreference, .low)
        XCTAssertFalse(viewModel.enableChat)
        XCTAssertFalse(viewModel.enableDVR)
    }

    // MARK: - currentSettings Tests

    func testCurrentSettings_reflectsCurrentState() {
        viewModel.title = "Current"
        viewModel.broadcastDescription = "Current Desc"
        viewModel.privacy = .publicBroadcast
        viewModel.category = .gaming
        viewModel.latencyPreference = .ultraLow
        viewModel.enableChat = false
        viewModel.enableDVR = true

        let settings = viewModel.currentSettings()

        XCTAssertEqual(settings.title, "Current")
        XCTAssertEqual(settings.description, "Current Desc")
        XCTAssertEqual(settings.privacy, .publicBroadcast)
        XCTAssertEqual(settings.category, .gaming)
        XCTAssertEqual(settings.latencyPreference, .ultraLow)
        XCTAssertFalse(settings.enableChat)
        XCTAssertTrue(settings.enableDVR)
    }

    // MARK: - isConfiguredForAPIStreaming Tests

    func testIsConfiguredForAPIStreaming_notSignedIn_returnsFalse() {
        viewModel.title = "Valid Title"
        XCTAssertFalse(viewModel.isConfiguredForAPIStreaming)
    }

    func testIsConfiguredForAPIStreaming_signedInWithTitle_returnsTrue() async {
        await viewModel.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)

        viewModel.title = "Valid Title"
        XCTAssertTrue(viewModel.isConfiguredForAPIStreaming)
    }

    func testIsConfiguredForAPIStreaming_signedInEmptyTitle_returnsFalse() async {
        await viewModel.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)

        viewModel.title = ""
        XCTAssertFalse(viewModel.isConfiguredForAPIStreaming)
    }

    func testIsConfiguredForAPIStreaming_signedInWhitespaceTitle_returnsFalse() async {
        await viewModel.signIn()
        try? await Task.sleep(nanoseconds: 100_000_000)

        viewModel.title = "   "
        XCTAssertFalse(viewModel.isConfiguredForAPIStreaming)
    }

    // MARK: - Privacy Default Test

    func testPrivacyDefaultIsPrivate() {
        // Sprint contract specifies default should be "非公開" (private)
        XCTAssertEqual(viewModel.privacy, .privateBroadcast)
    }

    // MARK: - Validation Error Tests

    func testValidationError_emptyTitle_displayMessage() {
        let error = YouTubeLiveSettingsValidationError.emptyTitle
        XCTAssertEqual(error.errorDescription, "配信タイトルを入力してください")
    }

    func testValidationError_equatable() {
        XCTAssertEqual(
            YouTubeLiveSettingsValidationError.emptyTitle,
            YouTubeLiveSettingsValidationError.emptyTitle
        )
    }

    // MARK: - Auth State Callback Tests

    func testAuthStateCallback_updatesViewModel() async {
        XCTAssertEqual(viewModel.authState, .signedOut)

        await viewModel.signIn()
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertTrue(viewModel.authState.isSignedIn)

        viewModel.signOut()
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(viewModel.authState, .signedOut)
    }
}
