import XCTest
@testable import blurCam

final class StreamingDestinationTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInit_DefaultValues() {
        let destination = StreamingDestination(
            name: "Test",
            platform: .youTube,
            rtmpURL: "rtmp://test.com/live",
            streamKey: "key123"
        )

        XCTAssertFalse(destination.id.uuidString.isEmpty)
        XCTAssertEqual(destination.name, "Test")
        XCTAssertEqual(destination.platform, .youTube)
        XCTAssertEqual(destination.rtmpURL, "rtmp://test.com/live")
        XCTAssertEqual(destination.streamKey, "key123")
        XCTAssertNotNil(destination.createdAt)
    }

    func testInit_CustomId() {
        let customId = UUID()
        let destination = StreamingDestination(
            id: customId,
            name: "Custom",
            platform: .twitch,
            rtmpURL: "rtmp://live.twitch.tv/app",
            streamKey: "live_key"
        )

        XCTAssertEqual(destination.id, customId)
    }

    func testEquatable() {
        let id = UUID()
        let date = Date()
        let dest1 = StreamingDestination(id: id, name: "A", platform: .youTube, rtmpURL: "rtmp://a.com", streamKey: "k1", createdAt: date)
        let dest2 = StreamingDestination(id: id, name: "A", platform: .youTube, rtmpURL: "rtmp://a.com", streamKey: "k1", createdAt: date)

        XCTAssertEqual(dest1, dest2)
    }

    func testNotEqual_DifferentIds() {
        let dest1 = StreamingDestination(name: "A", platform: .youTube, rtmpURL: "rtmp://a.com", streamKey: "k1")
        let dest2 = StreamingDestination(name: "A", platform: .youTube, rtmpURL: "rtmp://a.com", streamKey: "k1")

        XCTAssertNotEqual(dest1, dest2) // Different UUIDs
    }

    // MARK: - Codable Tests

    func testCodable_RoundTrip() throws {
        let original = StreamingDestination(
            name: "My YouTube",
            platform: .youTube,
            rtmpURL: "rtmp://a.rtmp.youtube.com/live2",
            streamKey: "secret-key-123"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StreamingDestination.self, from: encoded)

        XCTAssertEqual(original, decoded)
        XCTAssertEqual(decoded.name, "My YouTube")
        XCTAssertEqual(decoded.platform, .youTube)
        XCTAssertEqual(decoded.rtmpURL, "rtmp://a.rtmp.youtube.com/live2")
        XCTAssertEqual(decoded.streamKey, "secret-key-123")
    }

    func testCodable_Array() throws {
        let destinations = [
            StreamingDestination(name: "YT", platform: .youTube, rtmpURL: "rtmp://yt.com", streamKey: "k1"),
            StreamingDestination(name: "Twitch", platform: .twitch, rtmpURL: "rtmp://tw.com", streamKey: "k2"),
            StreamingDestination(name: "Custom", platform: .custom, rtmpURL: "rtmp://custom.com", streamKey: "k3"),
        ]

        let encoded = try JSONEncoder().encode(destinations)
        let decoded = try JSONDecoder().decode([StreamingDestination].self, from: encoded)

        XCTAssertEqual(decoded.count, 3)
        XCTAssertEqual(decoded[0].name, "YT")
        XCTAssertEqual(decoded[1].name, "Twitch")
        XCTAssertEqual(decoded[2].name, "Custom")
    }
}
