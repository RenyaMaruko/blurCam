import XCTest
@testable import blurCam

final class FaceRepositoryMultiFaceTests: XCTestCase {

    private var tempDirectory: URL!
    private var sut: FaceRepository!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FaceRepositoryMultiFaceTests-\(UUID().uuidString)", isDirectory: true)
        sut = FaceRepository(fileManager: .default, baseDirectory: tempDirectory)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - loadAllRegistrations Tests

    func testLoadAllRegistrations_EmptyWhenNone() {
        XCTAssertTrue(sut.loadAllRegistrations().isEmpty)
    }

    func testLoadAllRegistrations_ReturnsSingleRegistration() throws {
        let imageData = createTestImageData()
        let saved = try sut.saveFace(imageData)

        let loaded = sut.loadAllRegistrations()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, saved.id)
    }

    func testLoadAllRegistrations_ReturnsMultipleRegistrations() throws {
        let imageData1 = createTestImageData(seed: 1)
        let imageData2 = createTestImageData(seed: 2)
        let imageData3 = createTestImageData(seed: 3)

        let saved1 = try sut.saveFace(imageData1)
        let saved2 = try sut.saveFace(imageData2)
        let saved3 = try sut.saveFace(imageData3)

        let loaded = sut.loadAllRegistrations()

        XCTAssertEqual(loaded.count, 3)
        XCTAssertEqual(loaded[0].id, saved1.id)
        XCTAssertEqual(loaded[1].id, saved2.id)
        XCTAssertEqual(loaded[2].id, saved3.id)
    }

    // MARK: - Multiple saveFace Tests

    func testSaveFace_MultipleTimes_AllAccessible() throws {
        let imageData1 = createTestImageData(seed: 10)
        let imageData2 = createTestImageData(seed: 20)

        let reg1 = try sut.saveFace(imageData1)
        let reg2 = try sut.saveFace(imageData2)

        XCTAssertNotEqual(reg1.id, reg2.id)
        XCTAssertNotEqual(reg1.imageFileName, reg2.imageFileName)

        // Both images should be accessible
        XCTAssertEqual(sut.loadFaceImage(for: reg1), imageData1)
        XCTAssertEqual(sut.loadFaceImage(for: reg2), imageData2)
    }

    func testSaveFace_MultipleTimes_HasFaceRegisteredTrue() throws {
        try sut.saveFace(createTestImageData(seed: 1))
        try sut.saveFace(createTestImageData(seed: 2))

        XCTAssertTrue(sut.hasFaceRegistered())
    }

    // MARK: - deleteFace Tests

    func testDeleteFace_RemovesSpecificFace() throws {
        let reg1 = try sut.saveFace(createTestImageData(seed: 1))
        let reg2 = try sut.saveFace(createTestImageData(seed: 2))

        try sut.deleteFace(id: reg1.id)

        let remaining = sut.loadAllRegistrations()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.id, reg2.id)
    }

    func testDeleteFace_RemovesImageFile() throws {
        let reg = try sut.saveFace(createTestImageData(seed: 1))
        _ = try sut.saveFace(createTestImageData(seed: 2))

        let imageURL = tempDirectory.appendingPathComponent(reg.imageFileName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: imageURL.path))

        try sut.deleteFace(id: reg.id)

        XCTAssertFalse(FileManager.default.fileExists(atPath: imageURL.path))
    }

    func testDeleteFace_LastFace_CleansUpEverything() throws {
        let reg = try sut.saveFace(createTestImageData(seed: 1))

        try sut.deleteFace(id: reg.id)

        XCTAssertFalse(sut.hasFaceRegistered())
        XCTAssertTrue(sut.loadAllRegistrations().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempDirectory.path))
    }

    func testDeleteFace_NonexistentId_Throws() {
        XCTAssertThrowsError(try sut.deleteFace(id: UUID())) { error in
            guard let repoError = error as? FaceRepositoryError else {
                XCTFail("Expected FaceRepositoryError but got \(error)")
                return
            }
            XCTAssertEqual(repoError, .faceNotFound)
        }
    }

    func testDeleteFace_AfterDeleting_CanStillAccessOthers() throws {
        let imageData1 = createTestImageData(seed: 1)
        let imageData2 = createTestImageData(seed: 2)
        let imageData3 = createTestImageData(seed: 3)

        let reg1 = try sut.saveFace(imageData1)
        let reg2 = try sut.saveFace(imageData2)
        let reg3 = try sut.saveFace(imageData3)

        try sut.deleteFace(id: reg2.id)

        XCTAssertEqual(sut.loadFaceImage(for: reg1), imageData1)
        XCTAssertNil(sut.loadFaceImage(for: reg2))
        XCTAssertEqual(sut.loadFaceImage(for: reg3), imageData3)
    }

    // MARK: - deleteAll Tests

    func testDeleteAll_RemovesAllFaces() throws {
        try sut.saveFace(createTestImageData(seed: 1))
        try sut.saveFace(createTestImageData(seed: 2))
        try sut.saveFace(createTestImageData(seed: 3))

        XCTAssertEqual(sut.loadAllRegistrations().count, 3)

        try sut.deleteAll()

        XCTAssertFalse(sut.hasFaceRegistered())
        XCTAssertTrue(sut.loadAllRegistrations().isEmpty)
    }

    // MARK: - loadRegistration (legacy) Tests

    func testLoadRegistration_ReturnsFirstRegistration() throws {
        let reg1 = try sut.saveFace(createTestImageData(seed: 1))
        _ = try sut.saveFace(createTestImageData(seed: 2))

        let loaded = sut.loadRegistration()
        XCTAssertEqual(loaded?.id, reg1.id)
    }

    // MARK: - Persistence Tests

    func testMultipleFaces_PersistAcrossNewInstances() throws {
        let reg1 = try sut.saveFace(createTestImageData(seed: 1))
        let reg2 = try sut.saveFace(createTestImageData(seed: 2))

        let newRepo = FaceRepository(fileManager: .default, baseDirectory: tempDirectory)
        let loaded = newRepo.loadAllRegistrations()

        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].id, reg1.id)
        XCTAssertEqual(loaded[1].id, reg2.id)
    }

    // MARK: - Legacy Compatibility Tests

    func testLegacySingleRegistration_IsLoadedByLoadAllRegistrations() throws {
        // Simulate legacy data: write only registration.json (not registrations.json)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let imageFileName = "legacy-face.jpg"
        let imageData = createTestImageData(seed: 99)
        let imageURL = tempDirectory.appendingPathComponent(imageFileName)
        try imageData.write(to: imageURL)

        let registration = FaceRegistration(imageFileName: imageFileName)
        let registrationURL = tempDirectory.appendingPathComponent("registration.json")
        let data = try JSONEncoder().encode(registration)
        try data.write(to: registrationURL)

        // loadAllRegistrations should pick up the legacy registration
        let loaded = sut.loadAllRegistrations()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, registration.id)
        XCTAssertEqual(loaded.first?.imageFileName, imageFileName)
    }

    // MARK: - Helper Methods

    private func createTestImageData(seed: UInt8 = 0) -> Data {
        return Data([0xFF, 0xD8, 0xFF, 0xE0, seed, 0x10, 0x4A, 0x46, 0x49, 0x46])
    }
}
