import XCTest
@testable import blurCam

final class YouTubeLiveSettingsTests: XCTestCase {

    // MARK: - YouTubeLiveSettings Default Values

    func testDefaultValues() {
        let settings = YouTubeLiveSettings()

        XCTAssertEqual(settings.title, "blurCam Live")
        XCTAssertEqual(settings.description, "")
        XCTAssertEqual(settings.privacy, .privateBroadcast)
        XCTAssertEqual(settings.category, .entertainment)
        XCTAssertEqual(settings.latencyPreference, .normal)
        XCTAssertTrue(settings.enableChat)
        XCTAssertTrue(settings.enableDVR)
    }

    func testCustomValues() {
        let settings = YouTubeLiveSettings(
            title: "My Stream",
            description: "Test description",
            privacy: .publicBroadcast,
            category: .gaming,
            latencyPreference: .low,
            enableChat: false,
            enableDVR: false
        )

        XCTAssertEqual(settings.title, "My Stream")
        XCTAssertEqual(settings.description, "Test description")
        XCTAssertEqual(settings.privacy, .publicBroadcast)
        XCTAssertEqual(settings.category, .gaming)
        XCTAssertEqual(settings.latencyPreference, .low)
        XCTAssertFalse(settings.enableChat)
        XCTAssertFalse(settings.enableDVR)
    }

    func testEquatable() {
        let s1 = YouTubeLiveSettings()
        let s2 = YouTubeLiveSettings()
        XCTAssertEqual(s1, s2)

        let s3 = YouTubeLiveSettings(title: "Different")
        XCTAssertNotEqual(s1, s3)
    }

    func testCodable() throws {
        let original = YouTubeLiveSettings(
            title: "Encoded Stream",
            description: "Encoded description",
            privacy: .unlisted,
            category: .scienceTechnology,
            latencyPreference: .ultraLow,
            enableChat: false,
            enableDVR: true
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(YouTubeLiveSettings.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    // MARK: - YouTubeCategory Tests

    func testYouTubeCategoryDisplayNames() {
        XCTAssertEqual(YouTubeCategory.gaming.displayName, "ゲーム")
        XCTAssertEqual(YouTubeCategory.entertainment.displayName, "エンタメ")
        XCTAssertEqual(YouTubeCategory.education.displayName, "教育")
        XCTAssertEqual(YouTubeCategory.scienceTechnology.displayName, "科学と技術")
        XCTAssertEqual(YouTubeCategory.peopleBlogs.displayName, "ブログ")
        XCTAssertEqual(YouTubeCategory.music.displayName, "音楽")
        XCTAssertEqual(YouTubeCategory.sports.displayName, "スポーツ")
        XCTAssertEqual(YouTubeCategory.news.displayName, "ニュース")
        XCTAssertEqual(YouTubeCategory.howtoStyle.displayName, "ハウツーとスタイル")
        XCTAssertEqual(YouTubeCategory.comedy.displayName, "コメディ")
    }

    func testYouTubeCategoryRawValues() {
        XCTAssertEqual(YouTubeCategory.gaming.rawValue, "20")
        XCTAssertEqual(YouTubeCategory.entertainment.rawValue, "24")
        XCTAssertEqual(YouTubeCategory.education.rawValue, "27")
    }

    func testYouTubeCategoryCodable() throws {
        let original = YouTubeCategory.gaming
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(YouTubeCategory.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testYouTubeCategoryAllCases() {
        XCTAssertEqual(YouTubeCategory.allCases.count, 10)
    }

    // MARK: - YouTubeLatencyPreference Tests

    func testYouTubeLatencyDisplayNames() {
        XCTAssertEqual(YouTubeLatencyPreference.normal.displayName, "通常遅延")
        XCTAssertEqual(YouTubeLatencyPreference.low.displayName, "低遅延")
        XCTAssertEqual(YouTubeLatencyPreference.ultraLow.displayName, "超低遅延")
    }

    func testYouTubeLatencyRawValues() {
        XCTAssertEqual(YouTubeLatencyPreference.normal.rawValue, "normal")
        XCTAssertEqual(YouTubeLatencyPreference.low.rawValue, "low")
        XCTAssertEqual(YouTubeLatencyPreference.ultraLow.rawValue, "ultraLow")
    }

    func testYouTubeLatencyCodable() throws {
        let original = YouTubeLatencyPreference.ultraLow
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(YouTubeLatencyPreference.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testYouTubeLatencyAllCases() {
        XCTAssertEqual(YouTubeLatencyPreference.allCases.count, 3)
    }

    // MARK: - YouTubeBroadcastConfig Extension Tests

    func testBroadcastConfigFromLiveSettings() {
        let settings = YouTubeLiveSettings(
            title: "API Stream",
            description: "API desc",
            privacy: .publicBroadcast,
            category: .gaming,
            latencyPreference: .low,
            enableChat: false,
            enableDVR: false
        )

        let config = YouTubeBroadcastConfig(from: settings)

        XCTAssertEqual(config.title, "API Stream")
        XCTAssertEqual(config.description, "API desc")
        XCTAssertEqual(config.privacy, .publicBroadcast)
        XCTAssertEqual(config.categoryId, "20")
        XCTAssertEqual(config.latencyPreference, "low")
        XCTAssertEqual(config.enableChat, false)
        XCTAssertEqual(config.enableDVR, false)
    }

    func testBroadcastConfigFromLiveSettings_emptyTitle_usesDefault() {
        let settings = YouTubeLiveSettings(title: "")
        let config = YouTubeBroadcastConfig(from: settings)
        XCTAssertEqual(config.title, "blurCam Live")
    }

    func testBroadcastConfigDefaultValues() {
        let config = YouTubeBroadcastConfig()
        XCTAssertEqual(config.title, "blurCam Live")
        XCTAssertEqual(config.description, "")
        XCTAssertEqual(config.privacy, .unlisted)
        XCTAssertNil(config.categoryId)
        XCTAssertNil(config.latencyPreference)
        XCTAssertTrue(config.enableChat)
        XCTAssertTrue(config.enableDVR)
    }

    func testBroadcastConfigCustomValues() {
        let config = YouTubeBroadcastConfig(
            title: "Custom",
            description: "Desc",
            privacy: .privateBroadcast,
            categoryId: "27",
            latencyPreference: "ultraLow",
            enableChat: false,
            enableDVR: false
        )

        XCTAssertEqual(config.title, "Custom")
        XCTAssertEqual(config.description, "Desc")
        XCTAssertEqual(config.privacy, .privateBroadcast)
        XCTAssertEqual(config.categoryId, "27")
        XCTAssertEqual(config.latencyPreference, "ultraLow")
        XCTAssertFalse(config.enableChat)
        XCTAssertFalse(config.enableDVR)
    }
}
