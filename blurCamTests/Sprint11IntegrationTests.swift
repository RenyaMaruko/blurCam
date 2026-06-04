import XCTest
@testable import blurCam

/// Integration tests for Sprint 11: YouTube配信設定UI
/// Tests the integration between StreamingSettingsViewModel, YouTubeLiveSettingsViewModel,
/// and the YouTube API streaming flow in CameraViewModel.
@MainActor
final class Sprint11IntegrationTests: XCTestCase {

    // MARK: - StreamingSettingsViewModel YouTube API Mode Tests

    func testStreamingSettingsVM_youTubeAPIMode_skipsStreamKeyValidation() {
        let mockRepo = MockStreamingSettingsRepository()
        let vm = StreamingSettingsViewModel(repository: mockRepo)

        vm.selectedPlatform = .youTube
        vm.formRTMPURL = "rtmp://a.rtmp.youtube.com/live2"
        vm.formStreamKey = "" // empty stream key
        vm.isYouTubeAPIMode = true

        let error = vm.validateForm()
        XCTAssertNil(error, "YouTube API mode should skip stream key validation")
    }

    func testStreamingSettingsVM_youTubeAPIMode_disabled_requiresStreamKey() {
        let mockRepo = MockStreamingSettingsRepository()
        let vm = StreamingSettingsViewModel(repository: mockRepo)

        vm.selectedPlatform = .youTube
        vm.formRTMPURL = "rtmp://a.rtmp.youtube.com/live2"
        vm.formStreamKey = "" // empty stream key
        vm.isYouTubeAPIMode = false

        let error = vm.validateForm()
        XCTAssertEqual(error, .emptyStreamKey)
    }

    func testStreamingSettingsVM_twitchPlatform_apiModeIgnored() {
        let mockRepo = MockStreamingSettingsRepository()
        let vm = StreamingSettingsViewModel(repository: mockRepo)

        vm.selectedPlatform = .twitch
        vm.formRTMPURL = "rtmp://live.twitch.tv/app"
        vm.formStreamKey = ""
        vm.isYouTubeAPIMode = true // should not affect Twitch

        let error = vm.validateForm()
        XCTAssertEqual(error, .emptyStreamKey)
    }

    func testStreamingSettingsVM_customPlatform_apiModeIgnored() {
        let mockRepo = MockStreamingSettingsRepository()
        let vm = StreamingSettingsViewModel(repository: mockRepo)

        vm.selectedPlatform = .custom
        vm.formRTMPURL = "rtmp://custom.example.com/live"
        vm.formStreamKey = ""
        vm.isYouTubeAPIMode = true // should not affect custom

        let error = vm.validateForm()
        XCTAssertEqual(error, .emptyStreamKey)
    }

    func testStreamingSettingsVM_youTubeAPIMode_stillValidatesURL() {
        let mockRepo = MockStreamingSettingsRepository()
        let vm = StreamingSettingsViewModel(repository: mockRepo)

        vm.selectedPlatform = .youTube
        vm.formRTMPURL = ""
        vm.formStreamKey = ""
        vm.isYouTubeAPIMode = true

        let error = vm.validateForm()
        XCTAssertEqual(error, .emptyURL, "URL validation should still be enforced")
    }

    func testStreamingSettingsVM_youTubeAPIMode_savesWithEmptyStreamKey() {
        let mockRepo = MockStreamingSettingsRepository()
        let vm = StreamingSettingsViewModel(repository: mockRepo)

        vm.startAddingDestination()
        vm.selectedPlatform = .youTube
        vm.formRTMPURL = "rtmp://a.rtmp.youtube.com/live2"
        vm.formStreamKey = ""
        vm.isYouTubeAPIMode = true

        let saved = vm.saveDestination()
        XCTAssertTrue(saved, "Should save successfully with empty stream key in YouTube API mode")
        XCTAssertEqual(vm.destinations.count, 1)
    }

    // MARK: - Regression: Twitch/Custom Destination Tests

    func testTwitchDestination_canBeCreatedAndEdited() {
        let mockRepo = MockStreamingSettingsRepository()
        let vm = StreamingSettingsViewModel(repository: mockRepo)

        // Add a Twitch destination
        vm.startAddingDestination()
        vm.selectedPlatform = .twitch
        vm.formName = "My Twitch"
        vm.formRTMPURL = "rtmp://live.twitch.tv/app"
        vm.formStreamKey = "live_12345"
        let saved = vm.saveDestination()
        XCTAssertTrue(saved)
        XCTAssertEqual(vm.destinations.count, 1)
        XCTAssertEqual(vm.destinations.first?.platform, .twitch)

        // Edit the destination
        vm.startEditingDestination(vm.destinations.first!)
        XCTAssertEqual(vm.formName, "My Twitch")
        XCTAssertEqual(vm.formStreamKey, "live_12345")
    }

    func testCustomRTMPDestination_canBeCreatedAndDeleted() {
        let mockRepo = MockStreamingSettingsRepository()
        let vm = StreamingSettingsViewModel(repository: mockRepo)

        // Add a custom destination
        vm.startAddingDestination()
        vm.selectedPlatform = .custom
        vm.formName = "My Server"
        vm.formRTMPURL = "rtmp://my-server.com/live"
        vm.formStreamKey = "secret123"
        let saved = vm.saveDestination()
        XCTAssertTrue(saved)
        XCTAssertEqual(vm.destinations.count, 1)

        // Delete it
        let dest = vm.destinations.first!
        vm.requestDeleteDestination(dest)
        vm.confirmDeleteDestination()
        XCTAssertEqual(vm.destinations.count, 0)
    }

    // MARK: - Settings Persistence Round-Trip

    func testYouTubeLiveSettings_persistsAndRestores() {
        let userDefaults = UserDefaults(suiteName: "Sprint11IntegrationTests")!
        userDefaults.removePersistentDomain(forName: "Sprint11IntegrationTests")
        let repo = YouTubeLiveSettingsRepository(userDefaults: userDefaults)

        let original = YouTubeLiveSettings(
            title: "Integration Test",
            description: "Test description",
            privacy: .unlisted,
            category: .gaming,
            latencyPreference: .low,
            enableChat: false,
            enableDVR: true
        )

        repo.saveSettings(original)

        // Create new repo to simulate app restart
        let repo2 = YouTubeLiveSettingsRepository(userDefaults: userDefaults)
        let loaded = repo2.loadSettings()

        XCTAssertEqual(loaded.title, "Integration Test")
        XCTAssertEqual(loaded.description, "Test description")
        XCTAssertEqual(loaded.privacy, .unlisted)
        XCTAssertEqual(loaded.category, .gaming)
        XCTAssertEqual(loaded.latencyPreference, .low)
        XCTAssertFalse(loaded.enableChat)
        XCTAssertTrue(loaded.enableDVR)

        userDefaults.removePersistentDomain(forName: "Sprint11IntegrationTests")
    }

    // MARK: - Platform Selection Regression

    func testPlatformSelectionChoices_unchanged() {
        let platforms = StreamingPlatform.allCases
        XCTAssertEqual(platforms.count, 3)
        XCTAssertTrue(platforms.contains(.youTube))
        XCTAssertTrue(platforms.contains(.twitch))
        XCTAssertTrue(platforms.contains(.custom))
    }

    func testPlatformDisplayNames_unchanged() {
        XCTAssertEqual(StreamingPlatform.youTube.displayName, "YouTube Live")
        XCTAssertEqual(StreamingPlatform.twitch.displayName, "Twitch")
        XCTAssertEqual(StreamingPlatform.custom.displayName, "カスタムRTMP")
    }

    func testPlatformPresetURLs_unchanged() {
        XCTAssertEqual(StreamingPlatform.youTube.presetURL, "rtmp://a.rtmp.youtube.com/live2")
        XCTAssertEqual(StreamingPlatform.twitch.presetURL, "rtmp://live.twitch.tv/app")
        XCTAssertEqual(StreamingPlatform.custom.presetURL, "")
    }
}
