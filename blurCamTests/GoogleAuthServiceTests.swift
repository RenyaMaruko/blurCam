import XCTest
@testable import blurCam

/// Tests for GoogleAuthService error types, auth state, and user info models.
/// Note: Actual GIDSignIn calls require a real device/simulator with Google Play Services.
/// These tests focus on the model/state layer and mock-based behavior.
final class GoogleAuthServiceTests: XCTestCase {

    // MARK: - GoogleAuthError Tests

    func testGoogleAuthError_signInFailed_hasDescription() {
        let error = GoogleAuthError.signInFailed("test error")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("test error"))
    }

    func testGoogleAuthError_signInCancelled_hasDescription() {
        let error = GoogleAuthError.signInCancelled
        XCTAssertNotNil(error.errorDescription)
    }

    func testGoogleAuthError_noCurrentUser_hasDescription() {
        let error = GoogleAuthError.noCurrentUser
        XCTAssertNotNil(error.errorDescription)
    }

    func testGoogleAuthError_tokenRefreshFailed_hasDescription() {
        let error = GoogleAuthError.tokenRefreshFailed("refresh error")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("refresh error"))
    }

    func testGoogleAuthError_missingScopes_hasDescription() {
        let error = GoogleAuthError.missingScopes
        XCTAssertNotNil(error.errorDescription)
    }

    func testGoogleAuthError_presentingViewControllerUnavailable_hasDescription() {
        let error = GoogleAuthError.presentingViewControllerUnavailable
        XCTAssertNotNil(error.errorDescription)
    }

    func testGoogleAuthError_equatable() {
        XCTAssertEqual(GoogleAuthError.signInCancelled, GoogleAuthError.signInCancelled)
        XCTAssertEqual(GoogleAuthError.signInFailed("a"), GoogleAuthError.signInFailed("a"))
        XCTAssertNotEqual(GoogleAuthError.signInFailed("a"), GoogleAuthError.signInFailed("b"))
        XCTAssertNotEqual(GoogleAuthError.signInCancelled, GoogleAuthError.noCurrentUser)
    }

    // MARK: - GoogleAuthState Tests

    func testGoogleAuthState_signedOut_isNotSignedIn() {
        let state = GoogleAuthState.signedOut
        XCTAssertFalse(state.isSignedIn)
    }

    func testGoogleAuthState_signingIn_isNotSignedIn() {
        let state = GoogleAuthState.signingIn
        XCTAssertFalse(state.isSignedIn)
    }

    func testGoogleAuthState_signedIn_isSignedIn() {
        let userInfo = GoogleUserInfo(displayName: "Test", email: "test@test.com", profileImageURL: nil)
        let state = GoogleAuthState.signedIn(userInfo)
        XCTAssertTrue(state.isSignedIn)
    }

    func testGoogleAuthState_error_isNotSignedIn() {
        let state = GoogleAuthState.error("error")
        XCTAssertFalse(state.isSignedIn)
    }

    func testGoogleAuthState_equatable() {
        let userInfo1 = GoogleUserInfo(displayName: "A", email: "a@a.com", profileImageURL: nil)
        let userInfo2 = GoogleUserInfo(displayName: "A", email: "a@a.com", profileImageURL: nil)

        XCTAssertEqual(GoogleAuthState.signedOut, GoogleAuthState.signedOut)
        XCTAssertEqual(GoogleAuthState.signingIn, GoogleAuthState.signingIn)
        XCTAssertEqual(GoogleAuthState.signedIn(userInfo1), GoogleAuthState.signedIn(userInfo2))
        XCTAssertEqual(GoogleAuthState.error("x"), GoogleAuthState.error("x"))
        XCTAssertNotEqual(GoogleAuthState.signedOut, GoogleAuthState.signingIn)
    }

    // MARK: - GoogleUserInfo Tests

    func testGoogleUserInfo_initialization() {
        let url = URL(string: "https://example.com/photo.jpg")
        let info = GoogleUserInfo(displayName: "John Doe", email: "john@example.com", profileImageURL: url)

        XCTAssertEqual(info.displayName, "John Doe")
        XCTAssertEqual(info.email, "john@example.com")
        XCTAssertEqual(info.profileImageURL, url)
    }

    func testGoogleUserInfo_nilProfileImage() {
        let info = GoogleUserInfo(displayName: "Jane", email: "jane@test.com", profileImageURL: nil)
        XCTAssertNil(info.profileImageURL)
    }

    func testGoogleUserInfo_equatable() {
        let info1 = GoogleUserInfo(displayName: "A", email: "a@a.com", profileImageURL: nil)
        let info2 = GoogleUserInfo(displayName: "A", email: "a@a.com", profileImageURL: nil)
        let info3 = GoogleUserInfo(displayName: "B", email: "b@b.com", profileImageURL: nil)

        XCTAssertEqual(info1, info2)
        XCTAssertNotEqual(info1, info3)
    }

    // MARK: - MockGoogleAuthService Tests

    func testMockGoogleAuthService_signIn_setsSignedInState() async {
        let mock = MockGoogleAuthService()
        try? await mock.signIn()
        XCTAssertTrue(mock.authState.isSignedIn)
        XCTAssertEqual(mock.signInCallCount, 1)
    }

    func testMockGoogleAuthService_signIn_withError_throwsError() async {
        let mock = MockGoogleAuthService()
        mock.signInError = GoogleAuthError.signInFailed("test")

        do {
            try await mock.signIn()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is GoogleAuthError)
        }
        XCTAssertEqual(mock.signInCallCount, 1)
    }

    func testMockGoogleAuthService_signOut_clearsState() async {
        let mock = MockGoogleAuthService()
        try? await mock.signIn()
        XCTAssertTrue(mock.authState.isSignedIn)

        mock.signOut()
        XCTAssertEqual(mock.authState, .signedOut)
        XCTAssertEqual(mock.signOutCallCount, 1)
    }

    func testMockGoogleAuthService_restorePreviousSignIn_returnsConfiguredResult() async {
        let mock = MockGoogleAuthService()
        mock.restorePreviousSignInResult = true

        let result = await mock.restorePreviousSignIn()
        XCTAssertTrue(result)
        XCTAssertTrue(mock.authState.isSignedIn)
        XCTAssertEqual(mock.restorePreviousSignInCallCount, 1)
    }

    func testMockGoogleAuthService_restorePreviousSignIn_failsWhenConfigured() async {
        let mock = MockGoogleAuthService()
        mock.restorePreviousSignInResult = false

        let result = await mock.restorePreviousSignIn()
        XCTAssertFalse(result)
        XCTAssertEqual(mock.authState, .signedOut)
    }

    func testMockGoogleAuthService_getAccessToken_returnsToken() async throws {
        let mock = MockGoogleAuthService()
        mock.accessToken = "custom-token"

        let token = try await mock.getAccessToken()
        XCTAssertEqual(token, "custom-token")
        XCTAssertEqual(mock.getAccessTokenCallCount, 1)
    }

    func testMockGoogleAuthService_getAccessToken_throwsWhenConfigured() async {
        let mock = MockGoogleAuthService()
        mock.getAccessTokenError = GoogleAuthError.tokenRefreshFailed("expired")

        do {
            _ = try await mock.getAccessToken()
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(mock.needsReAuthentication)
        }
    }

    func testMockGoogleAuthService_stateChangeCallback() async {
        let mock = MockGoogleAuthService()
        var callbackStates: [GoogleAuthState] = []

        mock.onAuthStateChanged = { state in
            callbackStates.append(state)
        }

        try? await mock.signIn()

        // Should have received state changes (signingIn then signedIn)
        XCTAssertFalse(callbackStates.isEmpty)
        XCTAssertTrue(callbackStates.contains(where: { $0.isSignedIn }))
    }
}
