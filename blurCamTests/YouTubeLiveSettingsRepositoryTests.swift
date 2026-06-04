import XCTest
@testable import blurCam

final class YouTubeLiveSettingsRepositoryTests: XCTestCase {

    private var userDefaults: UserDefaults!
    private var repository: YouTubeLiveSettingsRepository!

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: "YouTubeLiveSettingsRepositoryTests")!
        userDefaults.removePersistentDomain(forName: "YouTubeLiveSettingsRepositoryTests")
        repository = YouTubeLiveSettingsRepository(userDefaults: userDefaults)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: "YouTubeLiveSettingsRepositoryTests")
        userDefaults = nil
        repository = nil
        super.tearDown()
    }

    // MARK: - Load Tests

    func testLoadSettings_noSavedData_returnsDefaults() {
        let settings = repository.loadSettings()

        XCTAssertEqual(settings.title, "blurCam Live")
        XCTAssertEqual(settings.description, "")
        XCTAssertEqual(settings.privacy, .privateBroadcast)
        XCTAssertEqual(settings.category, .entertainment)
        XCTAssertEqual(settings.latencyPreference, .normal)
        XCTAssertTrue(settings.enableChat)
        XCTAssertTrue(settings.enableDVR)
    }

    func testLoadSettings_withSavedData_returnsStoredValues() {
        let settings = YouTubeLiveSettings(
            title: "Saved Stream",
            description: "Saved description",
            privacy: .publicBroadcast,
            category: .gaming,
            latencyPreference: .ultraLow,
            enableChat: false,
            enableDVR: false
        )

        repository.saveSettings(settings)
        let loaded = repository.loadSettings()

        XCTAssertEqual(loaded, settings)
    }

    func testLoadSettings_corruptData_returnsDefaults() {
        userDefaults.set(Data("corrupt".utf8), forKey: "com.blurCam.youTubeLiveSettings")

        let settings = repository.loadSettings()
        XCTAssertEqual(settings, YouTubeLiveSettings())
    }

    // MARK: - Save Tests

    func testSaveSettings_persistsAllFields() {
        let settings = YouTubeLiveSettings(
            title: "Test Title",
            description: "Test Description",
            privacy: .unlisted,
            category: .education,
            latencyPreference: .low,
            enableChat: true,
            enableDVR: false
        )

        repository.saveSettings(settings)

        // Create a new repository to verify persistence
        let repo2 = YouTubeLiveSettingsRepository(userDefaults: userDefaults)
        let loaded = repo2.loadSettings()

        XCTAssertEqual(loaded.title, "Test Title")
        XCTAssertEqual(loaded.description, "Test Description")
        XCTAssertEqual(loaded.privacy, .unlisted)
        XCTAssertEqual(loaded.category, .education)
        XCTAssertEqual(loaded.latencyPreference, .low)
        XCTAssertTrue(loaded.enableChat)
        XCTAssertFalse(loaded.enableDVR)
    }

    func testSaveSettings_overwritesPrevious() {
        let settings1 = YouTubeLiveSettings(title: "First")
        repository.saveSettings(settings1)

        let settings2 = YouTubeLiveSettings(title: "Second")
        repository.saveSettings(settings2)

        let loaded = repository.loadSettings()
        XCTAssertEqual(loaded.title, "Second")
    }

    // MARK: - Clear Tests

    func testClearSettings_removesData() {
        let settings = YouTubeLiveSettings(title: "To Be Cleared")
        repository.saveSettings(settings)

        repository.clearSettings()
        let loaded = repository.loadSettings()

        // Should return defaults after clearing
        XCTAssertEqual(loaded, YouTubeLiveSettings())
    }

    // MARK: - Round-Trip Tests

    func testRoundTrip_allCategories() {
        for category in YouTubeCategory.allCases {
            let settings = YouTubeLiveSettings(category: category)
            repository.saveSettings(settings)
            let loaded = repository.loadSettings()
            XCTAssertEqual(loaded.category, category, "Failed round-trip for category: \(category)")
        }
    }

    func testRoundTrip_allLatencyPreferences() {
        for latency in YouTubeLatencyPreference.allCases {
            let settings = YouTubeLiveSettings(latencyPreference: latency)
            repository.saveSettings(settings)
            let loaded = repository.loadSettings()
            XCTAssertEqual(loaded.latencyPreference, latency, "Failed round-trip for latency: \(latency)")
        }
    }

    func testRoundTrip_allPrivacyOptions() {
        for privacy in YouTubeBroadcastPrivacy.allCases {
            let settings = YouTubeLiveSettings(privacy: privacy)
            repository.saveSettings(settings)
            let loaded = repository.loadSettings()
            XCTAssertEqual(loaded.privacy, privacy, "Failed round-trip for privacy: \(privacy)")
        }
    }
}
