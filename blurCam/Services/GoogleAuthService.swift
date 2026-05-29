import Foundation
import GoogleSignIn

/// Error types for Google authentication operations
enum GoogleAuthError: LocalizedError, Equatable {
    case signInFailed(String)
    case signInCancelled
    case noCurrentUser
    case tokenRefreshFailed(String)
    case missingScopes
    case presentingViewControllerUnavailable

    var errorDescription: String? {
        switch self {
        case .signInFailed(let message):
            return "Googleサインインに失敗しました: \(message)"
        case .signInCancelled:
            return "サインインがキャンセルされました"
        case .noCurrentUser:
            return "Googleアカウントにサインインしていません"
        case .tokenRefreshFailed(let message):
            return "トークンの更新に失敗しました: \(message)"
        case .missingScopes:
            return "YouTube APIに必要な権限が付与されていません"
        case .presentingViewControllerUnavailable:
            return "画面表示エラーが発生しました"
        }
    }
}

/// Represents the current Google authentication state
enum GoogleAuthState: Equatable {
    case signedOut
    case signingIn
    case signedIn(GoogleUserInfo)
    case error(String)

    var isSignedIn: Bool {
        if case .signedIn = self { return true }
        return false
    }
}

/// Information about the signed-in Google user
struct GoogleUserInfo: Equatable {
    let displayName: String
    let email: String
    let profileImageURL: URL?
}

/// Protocol for Google authentication operations
protocol GoogleAuthServiceProtocol: AnyObject {
    /// Current authentication state
    var authState: GoogleAuthState { get }

    /// Callback when auth state changes
    var onAuthStateChanged: ((GoogleAuthState) -> Void)? { get set }

    /// Sign in with Google, requesting YouTube API scopes
    func signIn() async throws

    /// Sign out and discard tokens
    func signOut()

    /// Restore previous sign-in session
    func restorePreviousSignIn() async -> Bool

    /// Get a valid access token, refreshing if necessary
    func getAccessToken() async throws -> String

    /// Whether the user needs to re-authenticate (token refresh failed)
    var needsReAuthentication: Bool { get }
}

/// Service managing Google Sign-In authentication and token lifecycle.
/// Handles OAuth 2.0 flows with YouTube Data API v3 scopes.
final class GoogleAuthService: GoogleAuthServiceProtocol {

    // MARK: - Properties

    private(set) var authState: GoogleAuthState = .signedOut {
        didSet {
            if authState != oldValue {
                onAuthStateChanged?(authState)
            }
        }
    }

    var onAuthStateChanged: ((GoogleAuthState) -> Void)?

    private(set) var needsReAuthentication: Bool = false

    /// YouTube Data API v3 required scopes
    private let youTubeScopes: [String] = [
        "https://www.googleapis.com/auth/youtube",
        "https://www.googleapis.com/auth/youtube.upload",
        "https://www.googleapis.com/auth/youtube.force-ssl"
    ]

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    func signIn() async throws {
        authState = .signingIn

        guard let presentingViewController = await getPresentingViewController() else {
            authState = .error(GoogleAuthError.presentingViewControllerUnavailable.localizedDescription)
            throw GoogleAuthError.presentingViewControllerUnavailable
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: presentingViewController,
                hint: nil,
                additionalScopes: youTubeScopes
            )

            let user = result.user

            // Verify that all required scopes were granted
            let grantedScopes = user.grantedScopes ?? []
            let hasAllScopes = youTubeScopes.allSatisfy { scope in
                grantedScopes.contains(scope)
            }

            if !hasAllScopes {
                // Request additional scopes if not all were granted
                let additionalResult = try await user.addScopes(
                    youTubeScopes,
                    presenting: presentingViewController
                )

                let updatedUser = additionalResult.user
                let userInfo = extractUserInfo(from: updatedUser)
                authState = .signedIn(userInfo)
                needsReAuthentication = false
            } else {
                let userInfo = extractUserInfo(from: user)
                authState = .signedIn(userInfo)
                needsReAuthentication = false
            }
        } catch let error as GIDSignInError {
            if error.code == .canceled {
                authState = .signedOut
                throw GoogleAuthError.signInCancelled
            } else {
                let message = error.localizedDescription
                authState = .error(message)
                throw GoogleAuthError.signInFailed(message)
            }
        } catch let error as GoogleAuthError {
            throw error
        } catch {
            let message = error.localizedDescription
            authState = .error(message)
            throw GoogleAuthError.signInFailed(message)
        }
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        authState = .signedOut
        needsReAuthentication = false
    }

    func restorePreviousSignIn() async -> Bool {
        do {
            let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            let userInfo = extractUserInfo(from: user)
            authState = .signedIn(userInfo)
            needsReAuthentication = false
            return true
        } catch {
            authState = .signedOut
            return false
        }
    }

    func getAccessToken() async throws -> String {
        guard let currentUser = GIDSignIn.sharedInstance.currentUser else {
            needsReAuthentication = true
            throw GoogleAuthError.noCurrentUser
        }

        // Check if the token needs refreshing
        if currentUser.accessToken.tokenString.isEmpty ||
            currentUser.accessToken.expirationDate ?? Date.distantPast < Date() {
            do {
                try await currentUser.refreshTokensIfNeeded()
            } catch {
                needsReAuthentication = true
                authState = .error(GoogleAuthError.tokenRefreshFailed(error.localizedDescription).localizedDescription)
                throw GoogleAuthError.tokenRefreshFailed(error.localizedDescription)
            }
        }

        let token = currentUser.accessToken.tokenString
        if token.isEmpty {
            needsReAuthentication = true
            throw GoogleAuthError.noCurrentUser
        }

        needsReAuthentication = false
        return token
    }

    // MARK: - Private Methods

    private func extractUserInfo(from user: GIDGoogleUser) -> GoogleUserInfo {
        GoogleUserInfo(
            displayName: user.profile?.name ?? "",
            email: user.profile?.email ?? "",
            profileImageURL: user.profile?.imageURL(withDimension: 200)
        )
    }

    @MainActor
    private func getPresentingViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }),
              let rootVC = window.rootViewController else {
            return nil
        }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        return topVC
    }
}
