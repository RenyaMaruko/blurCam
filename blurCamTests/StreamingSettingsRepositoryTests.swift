import XCTest
@testable import blurCam

final class StreamingSettingsRepositoryTests: XCTestCase {

    private var repository: StreamingSettingsRepository!
    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: "StreamingSettingsRepositoryTests")!
        userDefaults.removePersistentDomain(forName: "StreamingSettingsRepositoryTests")
        repository = StreamingSettingsRepository(userDefaults: userDefaults)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: "StreamingSettingsRepositoryTests")
        userDefaults = nil
        repository = nil
        super.tearDown()
    }

    // MARK: - RTMP URL Tests

    func testLoadRTMPURL_ReturnsNilByDefault() {
        XCTAssertNil(repository.loadRTMPURL())
    }

    func testSaveAndLoadRTMPURL() {
        let url = "rtmp://live.example.com/app"
        repository.saveRTMPURL(url)

        XCTAssertEqual(repository.loadRTMPURL(), url)
    }

    func testSaveRTMPURL_OverwritesPrevious() {
        repository.saveRTMPURL("rtmp://first.com/app")
        repository.saveRTMPURL("rtmp://second.com/app")

        XCTAssertEqual(repository.loadRTMPURL(), "rtmp://second.com/app")
    }

    func testSaveRTMPURL_EmptyString() {
        repository.saveRTMPURL("")

        XCTAssertEqual(repository.loadRTMPURL(), "")
    }

    // MARK: - Stream Key Tests

    func testLoadStreamKey_ReturnsNilByDefault() {
        XCTAssertNil(repository.loadStreamKey())
    }

    func testSaveAndLoadStreamKey() {
        let key = "test-stream-key-12345"
        repository.saveStreamKey(key)

        XCTAssertEqual(repository.loadStreamKey(), key)
    }

    func testSaveStreamKey_OverwritesPrevious() {
        repository.saveStreamKey("key1")
        repository.saveStreamKey("key2")

        XCTAssertEqual(repository.loadStreamKey(), "key2")
    }

    func testSaveStreamKey_EmptyString() {
        repository.saveStreamKey("")

        XCTAssertEqual(repository.loadStreamKey(), "")
    }

    // MARK: - Independent Storage Tests

    func testRTMPURLAndStreamKey_StoredIndependently() {
        repository.saveRTMPURL("rtmp://example.com/live")
        repository.saveStreamKey("my-secret-key")

        XCTAssertEqual(repository.loadRTMPURL(), "rtmp://example.com/live")
        XCTAssertEqual(repository.loadStreamKey(), "my-secret-key")
    }

    func testPersistenceAcrossInstances() {
        repository.saveRTMPURL("rtmp://persist.com/app")
        repository.saveStreamKey("persistent-key")

        // Create a new instance with the same UserDefaults
        let newRepo = StreamingSettingsRepository(userDefaults: userDefaults)

        XCTAssertEqual(newRepo.loadRTMPURL(), "rtmp://persist.com/app")
        XCTAssertEqual(newRepo.loadStreamKey(), "persistent-key")
    }

    // MARK: - Destination Save/Load Tests

    func testLoadDestinations_ReturnsEmptyByDefault() {
        XCTAssertEqual(repository.loadDestinations().count, 0)
    }

    func testSaveAndLoadDestination() {
        let destination = StreamingDestination(
            name: "My YouTube",
            platform: .youTube,
            rtmpURL: "rtmp://a.rtmp.youtube.com/live2",
            streamKey: "test-key"
        )

        repository.saveDestination(destination)
        let loaded = repository.loadDestinations()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "My YouTube")
        XCTAssertEqual(loaded.first?.platform, .youTube)
        XCTAssertEqual(loaded.first?.rtmpURL, "rtmp://a.rtmp.youtube.com/live2")
        XCTAssertEqual(loaded.first?.streamKey, "test-key")
    }

    func testSaveMultipleDestinations() {
        let dest1 = StreamingDestination(
            name: "YouTube",
            platform: .youTube,
            rtmpURL: "rtmp://yt.com",
            streamKey: "k1",
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let dest2 = StreamingDestination(
            name: "Twitch",
            platform: .twitch,
            rtmpURL: "rtmp://tw.com",
            streamKey: "k2",
            createdAt: Date(timeIntervalSince1970: 200)
        )

        repository.saveDestination(dest1)
        repository.saveDestination(dest2)

        let loaded = repository.loadDestinations()
        XCTAssertEqual(loaded.count, 2)
    }

    func testSaveDestination_UpdatesExisting() {
        let id = UUID()
        let original = StreamingDestination(
            id: id,
            name: "Original",
            platform: .youTube,
            rtmpURL: "rtmp://yt.com",
            streamKey: "k1"
        )
        let updated = StreamingDestination(
            id: id,
            name: "Updated",
            platform: .youTube,
            rtmpURL: "rtmp://yt.com/new",
            streamKey: "k2"
        )

        repository.saveDestination(original)
        repository.saveDestination(updated)

        let loaded = repository.loadDestinations()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "Updated")
        XCTAssertEqual(loaded.first?.rtmpURL, "rtmp://yt.com/new")
    }

    // MARK: - Destination Delete Tests

    func testDeleteDestination() {
        let dest1 = StreamingDestination(
            name: "YouTube",
            platform: .youTube,
            rtmpURL: "rtmp://yt.com",
            streamKey: "k1"
        )
        let dest2 = StreamingDestination(
            name: "Twitch",
            platform: .twitch,
            rtmpURL: "rtmp://tw.com",
            streamKey: "k2"
        )

        repository.saveDestination(dest1)
        repository.saveDestination(dest2)
        repository.deleteDestination(id: dest1.id)

        let loaded = repository.loadDestinations()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "Twitch")
    }

    func testDeleteDestination_ClearsSelectionIfSelected() {
        let dest = StreamingDestination(
            name: "YouTube",
            platform: .youTube,
            rtmpURL: "rtmp://yt.com",
            streamKey: "k1"
        )

        repository.saveDestination(dest)
        repository.selectDestination(id: dest.id)
        XCTAssertEqual(repository.selectedDestinationId, dest.id)

        repository.deleteDestination(id: dest.id)
        XCTAssertNil(repository.selectedDestinationId)
    }

    func testDeleteDestination_NonExistent_DoesNotCrash() {
        // Should not crash even if the ID doesn't exist
        repository.deleteDestination(id: UUID())
        XCTAssertEqual(repository.loadDestinations().count, 0)
    }

    // MARK: - Destination Selection Tests

    func testSelectedDestinationId_NilByDefault() {
        XCTAssertNil(repository.selectedDestinationId)
    }

    func testSelectDestination() {
        let dest = StreamingDestination(
            name: "YouTube",
            platform: .youTube,
            rtmpURL: "rtmp://yt.com",
            streamKey: "k1"
        )

        repository.saveDestination(dest)
        repository.selectDestination(id: dest.id)

        XCTAssertEqual(repository.selectedDestinationId, dest.id)
    }

    func testSelectDestination_Nil_ClearsSelection() {
        let dest = StreamingDestination(
            name: "YouTube",
            platform: .youTube,
            rtmpURL: "rtmp://yt.com",
            streamKey: "k1"
        )

        repository.saveDestination(dest)
        repository.selectDestination(id: dest.id)
        repository.selectDestination(id: nil)

        XCTAssertNil(repository.selectedDestinationId)
    }

    func testLoadSelectedDestination_ReturnsCorrectDestination() {
        let dest1 = StreamingDestination(
            name: "YouTube",
            platform: .youTube,
            rtmpURL: "rtmp://yt.com",
            streamKey: "k1"
        )
        let dest2 = StreamingDestination(
            name: "Twitch",
            platform: .twitch,
            rtmpURL: "rtmp://tw.com",
            streamKey: "k2"
        )

        repository.saveDestination(dest1)
        repository.saveDestination(dest2)
        repository.selectDestination(id: dest2.id)

        let selected = repository.loadSelectedDestination()
        XCTAssertEqual(selected?.id, dest2.id)
        XCTAssertEqual(selected?.name, "Twitch")
    }

    func testLoadSelectedDestination_ReturnsNilWhenNoneSelected() {
        XCTAssertNil(repository.loadSelectedDestination())
    }

    func testLoadSelectedDestination_ReturnsNilWhenSelectedDoesNotExist() {
        repository.selectDestination(id: UUID())
        XCTAssertNil(repository.loadSelectedDestination())
    }

    // MARK: - Destination Persistence Tests

    func testDestinationsPersistAcrossInstances() {
        let dest = StreamingDestination(
            name: "Persistent",
            platform: .custom,
            rtmpURL: "rtmp://persist.com",
            streamKey: "persist-key"
        )

        repository.saveDestination(dest)
        repository.selectDestination(id: dest.id)

        // Create a new instance
        let newRepo = StreamingSettingsRepository(userDefaults: userDefaults)

        let loaded = newRepo.loadDestinations()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "Persistent")
        XCTAssertEqual(newRepo.selectedDestinationId, dest.id)
        XCTAssertEqual(newRepo.loadSelectedDestination()?.name, "Persistent")
    }

    // MARK: - Destinations Sorted By CreatedAt

    func testLoadDestinations_SortedByCreatedAt() {
        let dest1 = StreamingDestination(
            name: "Oldest",
            platform: .youTube,
            rtmpURL: "rtmp://a.com",
            streamKey: "k1",
            createdAt: Date(timeIntervalSince1970: 1000)
        )
        let dest2 = StreamingDestination(
            name: "Newest",
            platform: .twitch,
            rtmpURL: "rtmp://b.com",
            streamKey: "k2",
            createdAt: Date(timeIntervalSince1970: 3000)
        )
        let dest3 = StreamingDestination(
            name: "Middle",
            platform: .custom,
            rtmpURL: "rtmp://c.com",
            streamKey: "k3",
            createdAt: Date(timeIntervalSince1970: 2000)
        )

        // Save in non-chronological order
        repository.saveDestination(dest2)
        repository.saveDestination(dest3)
        repository.saveDestination(dest1)

        let loaded = repository.loadDestinations()
        XCTAssertEqual(loaded.count, 3)
        XCTAssertEqual(loaded[0].name, "Oldest")
        XCTAssertEqual(loaded[1].name, "Middle")
        XCTAssertEqual(loaded[2].name, "Newest")
    }
}
