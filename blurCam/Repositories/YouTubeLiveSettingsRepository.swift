import Foundation

/// Protocol for persisting YouTube live broadcast settings.
protocol YouTubeLiveSettingsRepositoryProtocol {
    /// Load the saved YouTube live settings, or return default settings if not saved
    func loadSettings() -> YouTubeLiveSettings

    /// Save the YouTube live settings
    func saveSettings(_ settings: YouTubeLiveSettings)

    /// Clear all saved settings and revert to defaults
    func clearSettings()
}

/// Concrete implementation of YouTubeLiveSettingsRepositoryProtocol using UserDefaults.
/// Persists YouTube live broadcast configuration (title, description, privacy, category,
/// latency, chat, DVR) across app restarts.
final class YouTubeLiveSettingsRepository: YouTubeLiveSettingsRepositoryProtocol {

    private static let settingsKey = "com.blurCam.youTubeLiveSettings"

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadSettings() -> YouTubeLiveSettings {
        guard let data = userDefaults.data(forKey: Self.settingsKey) else {
            return YouTubeLiveSettings()
        }

        do {
            let settings = try JSONDecoder().decode(YouTubeLiveSettings.self, from: data)
            return settings
        } catch {
            return YouTubeLiveSettings()
        }
    }

    func saveSettings(_ settings: YouTubeLiveSettings) {
        do {
            let data = try JSONEncoder().encode(settings)
            userDefaults.set(data, forKey: Self.settingsKey)
        } catch {
            // Encoding should not fail for Codable types, but silently handle
        }
    }

    func clearSettings() {
        userDefaults.removeObject(forKey: Self.settingsKey)
    }
}
