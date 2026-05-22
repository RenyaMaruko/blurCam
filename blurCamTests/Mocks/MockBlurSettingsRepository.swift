import Foundation
@testable import blurCam

/// Mock implementation of BlurSettingsRepositoryProtocol for testing
final class MockBlurSettingsRepository: BlurSettingsRepositoryProtocol {

    // MARK: - Configurable State

    var savedIntensity: BlurIntensity?

    // MARK: - Call Tracking

    var loadBlurIntensityCallCount = 0
    var saveBlurIntensityCallCount = 0

    // MARK: - BlurSettingsRepositoryProtocol

    func loadBlurIntensity() -> BlurIntensity? {
        loadBlurIntensityCallCount += 1
        return savedIntensity
    }

    func saveBlurIntensity(_ intensity: BlurIntensity) {
        saveBlurIntensityCallCount += 1
        savedIntensity = intensity
    }
}
