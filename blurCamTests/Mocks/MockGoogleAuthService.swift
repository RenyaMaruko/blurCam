import Foundation
@testable import blurCam

/// Mock implementation of GoogleAuthServiceProtocol for testing
final class MockGoogleAuthService: GoogleAuthServiceProtocol {

    // MARK: - Configurable State

    var authState: GoogleAuthState = .signedOut {
        didSet {
            onAuthStateChanged?(authState)
        }
    }

    var onAuthStateChanged: ((GoogleAuthState) -> Void)?
    var needsReAuthentication: Bool = false

    // MARK: - Mock Configuration

    var signInError: Error?
    var signInUserInfo: GoogleUserInfo = GoogleUserInfo(
        displayName: "Test User",
        email: "test@gmail.com",
        profileImageURL: nil
    )

    var restorePreviousSignInResult: Bool = false
    var accessToken: String = "mock-access-token-12345"
    var getAccessTokenError: Error?

    // MARK: - Call Tracking

    var signInCallCount = 0
    var signOutCallCount = 0
    var restorePreviousSignInCallCount = 0
    var getAccessTokenCallCount = 0

    // MARK: - GoogleAuthServiceProtocol

    func signIn() async throws {
        signInCallCount += 1

        if let error = signInError {
            authState = .error(error.localizedDescription)
            throw error
        }

        authState = .signingIn
        // Simulate brief delay
        authState = .signedIn(signInUserInfo)
    }

    func signOut() {
        signOutCallCount += 1
        authState = .signedOut
        needsReAuthentication = false
    }

    func restorePreviousSignIn() async -> Bool {
        restorePreviousSignInCallCount += 1

        if restorePreviousSignInResult {
            authState = .signedIn(signInUserInfo)
        } else {
            authState = .signedOut
        }

        return restorePreviousSignInResult
    }

    func getAccessToken() async throws -> String {
        getAccessTokenCallCount += 1

        if let error = getAccessTokenError {
            needsReAuthentication = true
            throw error
        }

        return accessToken
    }

    // MARK: - Test Helpers

    func simulateTokenExpiry() {
        needsReAuthentication = true
        authState = .error("トークンの有効期限が切れました")
    }
}
