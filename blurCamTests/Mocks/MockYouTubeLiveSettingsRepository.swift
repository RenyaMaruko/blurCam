import Foundation
@testable import blurCam

/// Mock implementation of YouTubeLiveSettingsRepositoryProtocol for testing
final class MockYouTubeLiveSettingsRepository: YouTubeLiveSettingsRepositoryProtocol {

    // MARK: - Configurable State

    var savedSettings: YouTubeLiveSettings?

    // MARK: - Call Tracking

    var loadSettingsCallCount = 0
    var saveSettingsCallCount = 0
    var clearSettingsCallCount = 0

    // MARK: - YouTubeLiveSettingsRepositoryProtocol

    func loadSettings() -> YouTubeLiveSettings {
        loadSettingsCallCount += 1
        return savedSettings ?? YouTubeLiveSettings()
    }

    func saveSettings(_ settings: YouTubeLiveSettings) {
        saveSettingsCallCount += 1
        savedSettings = settings
    }

    func clearSettings() {
        clearSettingsCallCount += 1
        savedSettings = nil
    }
}
