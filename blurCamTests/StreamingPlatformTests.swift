import XCTest
@testable import blurCam

final class StreamingPlatformTests: XCTestCase {

    // MARK: - Display Name Tests

    func testDisplayName_YouTube() {
        XCTAssertEqual(StreamingPlatform.youTube.displayName, "YouTube Live")
    }

    func testDisplayName_Twitch() {
        XCTAssertEqual(StreamingPlatform.twitch.displayName, "Twitch")
    }

    func testDisplayName_Custom() {
        XCTAssertEqual(StreamingPlatform.custom.displayName, "カスタムRTMP")
    }

    // MARK: - Preset URL Tests

    func testPresetURL_YouTube() {
        XCTAssertEqual(StreamingPlatform.youTube.presetURL, "rtmp://a.rtmp.youtube.com/live2")
        XCTAssertTrue(StreamingPlatform.youTube.presetURL.hasPrefix("rtmp://"))
    }

    func testPresetURL_Twitch() {
        XCTAssertEqual(StreamingPlatform.twitch.presetURL, "rtmp://live.twitch.tv/app")
        XCTAssertTrue(StreamingPlatform.twitch.presetURL.hasPrefix("rtmp://"))
    }

    func testPresetURL_Custom() {
        XCTAssertEqual(StreamingPlatform.custom.presetURL, "")
    }

    // MARK: - All Cases Tests

    func testAllCases_ContainsThreePlatforms() {
        XCTAssertEqual(StreamingPlatform.allCases.count, 3)
        XCTAssertTrue(StreamingPlatform.allCases.contains(.youTube))
        XCTAssertTrue(StreamingPlatform.allCases.contains(.twitch))
        XCTAssertTrue(StreamingPlatform.allCases.contains(.custom))
    }

    // MARK: - Codable Tests

    func testCodable_RoundTrip() throws {
        for platform in StreamingPlatform.allCases {
            let encoded = try JSONEncoder().encode(platform)
            let decoded = try JSONDecoder().decode(StreamingPlatform.self, from: encoded)
            XCTAssertEqual(platform, decoded)
        }
    }

    // MARK: - Icon Name Tests

    func testIconName_NotEmpty() {
        for platform in StreamingPlatform.allCases {
            XCTAssertFalse(platform.iconName.isEmpty, "\(platform) should have an icon name")
        }
    }

    // MARK: - Identifiable Tests

    func testId_MatchesRawValue() {
        for platform in StreamingPlatform.allCases {
            XCTAssertEqual(platform.id, platform.rawValue)
        }
    }
}
