import Foundation

/// Protocol for persisting blur settings.
protocol BlurSettingsRepositoryProtocol {
    /// Load the saved blur intensity, or return nil if not set
    func loadBlurIntensity() -> BlurIntensity?

    /// Save the blur intensity setting
    func saveBlurIntensity(_ intensity: BlurIntensity)
}

/// Concrete implementation of BlurSettingsRepositoryProtocol using UserDefaults.
/// Persists blur intensity settings across app restarts.
final class BlurSettingsRepository: BlurSettingsRepositoryProtocol {

    private static let blurIntensityKey = "com.blurCam.blurIntensity"

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadBlurIntensity() -> BlurIntensity? {
        guard userDefaults.object(forKey: Self.blurIntensityKey) != nil else {
            return nil
        }
        let rawValue = userDefaults.integer(forKey: Self.blurIntensityKey)
        return BlurIntensity(rawValue: rawValue)
    }

    func saveBlurIntensity(_ intensity: BlurIntensity) {
        userDefaults.set(intensity.rawValue, forKey: Self.blurIntensityKey)
    }
}
