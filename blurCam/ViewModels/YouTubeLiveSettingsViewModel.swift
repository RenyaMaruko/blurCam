import Foundation
import SwiftUI

/// Validation error types for YouTube live settings form
enum YouTubeLiveSettingsValidationError: LocalizedError, Equatable {
    case emptyTitle

    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "配信タイトルを入力してください"
        }
    }
}

/// ViewModel responsible for managing YouTube live broadcast detailed settings.
/// Handles Google Sign-In state display, broadcast configuration (title, description,
/// privacy, category, latency, chat, DVR), form validation, and settings persistence.
@MainActor
final class YouTubeLiveSettingsViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Current Google authentication state (read from GoogleAuthService)
    @Published private(set) var authState: GoogleAuthState = .signedOut

    /// Broadcast title (required)
    @Published var title: String = "blurCam Live"

    /// Broadcast description (optional)
    @Published var broadcastDescription: String = ""

    /// Privacy setting
    @Published var privacy: YouTubeBroadcastPrivacy = .privateBroadcast

    /// Video category
    @Published var category: YouTubeCategory = .entertainment

    /// Latency preference
    @Published var latencyPreference: YouTubeLatencyPreference = .normal

    /// Whether live chat is enabled
    @Published var enableChat: Bool = true

    /// Whether DVR is enabled
    @Published var enableDVR: Bool = true

    /// Validation error for the form
    @Published var validationError: YouTubeLiveSettingsValidationError?

    /// Whether settings have been successfully saved (for dismissal feedback)
    @Published var didSaveSuccessfully: Bool = false

    // MARK: - Dependencies

    private let googleAuthService: GoogleAuthServiceProtocol
    private let repository: YouTubeLiveSettingsRepositoryProtocol

    // MARK: - Initialization

    init(
        googleAuthService: GoogleAuthServiceProtocol? = nil,
        repository: YouTubeLiveSettingsRepositoryProtocol? = nil
    ) {
        self.googleAuthService = googleAuthService ?? GoogleAuthService()
        self.repository = repository ?? YouTubeLiveSettingsRepository()

        loadSettings()
        setupAuthStateCallback()
    }

    // MARK: - Authentication

    /// Sign in with Google
    func signIn() async {
        do {
            try await googleAuthService.signIn()
        } catch {
            // Error handling is done via auth state callback
        }
    }

    /// Sign out from Google
    func signOut() {
        googleAuthService.signOut()
        authState = .signedOut
    }

    /// Restore previous sign-in session
    func restorePreviousSignIn() async {
        _ = await googleAuthService.restorePreviousSignIn()
    }

    // MARK: - Settings Management

    /// Loads saved settings from the repository
    func loadSettings() {
        let settings = repository.loadSettings()
        title = settings.title
        broadcastDescription = settings.description
        privacy = settings.privacy
        category = settings.category
        latencyPreference = settings.latencyPreference
        enableChat = settings.enableChat
        enableDVR = settings.enableDVR
    }

    /// Validates and saves the settings
    /// - Returns: true if saved successfully, false if validation failed
    @discardableResult
    func saveSettings() -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedTitle.isEmpty {
            validationError = .emptyTitle
            return false
        }

        validationError = nil

        let settings = YouTubeLiveSettings(
            title: trimmedTitle,
            description: broadcastDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            privacy: privacy,
            category: category,
            latencyPreference: latencyPreference,
            enableChat: enableChat,
            enableDVR: enableDVR
        )

        repository.saveSettings(settings)
        didSaveSuccessfully = true
        return true
    }

    /// Returns the current settings as a YouTubeLiveSettings struct
    func currentSettings() -> YouTubeLiveSettings {
        YouTubeLiveSettings(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: broadcastDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            privacy: privacy,
            category: category,
            latencyPreference: latencyPreference,
            enableChat: enableChat,
            enableDVR: enableDVR
        )
    }

    /// Whether the settings are complete enough for API-based streaming
    /// (requires sign-in and non-empty title)
    var isConfiguredForAPIStreaming: Bool {
        authState.isSignedIn &&
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Private Methods

    private func setupAuthStateCallback() {
        googleAuthService.onAuthStateChanged = { [weak self] newState in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.authState = newState
            }
        }
        // Set initial state
        authState = googleAuthService.authState
    }
}
