import XCTest
@testable import blurCam

final class FaceRepositoryTests: XCTestCase {

    private var tempDirectory: URL!
    private var sut: FaceRepository!

    override func setUp() {
        super.setUp()
        // Create a unique temp directory for each test
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FaceRepositoryTests-\(UUID().uuidString)", isDirectory: true)
        sut = FaceRepository(fileManager: .default, baseDirectory: tempDirectory)
    }

    override func tearDown() {
        // Clean up temp directory
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - hasFaceRegistered Tests

    func testHasFaceRegistered_InitiallyFalse() {
        XCTAssertFalse(sut.hasFaceRegistered())
    }

    func testHasFaceRegistered_TrueAfterSave() throws {
        let imageData = createTestImageData()
        try sut.saveFace(imageData)

        XCTAssertTrue(sut.hasFaceRegistered())
    }

    // MARK: - saveFace Tests

    func testSaveFace_CreatesRegistration() throws {
        let imageData = createTestImageData()
        let registration = try sut.saveFace(imageData)

        XCTAssertFalse(registration.id.uuidString.isEmpty)
        XCTAssertFalse(registration.imageFileName.isEmpty)
        XCTAssertTrue(registration.imageFileName.hasSuffix(".jpg"))
    }

    func testSaveFace_StoresImageFile() throws {
        let imageData = createTestImageData()
        let registration = try sut.saveFace(imageData)

        let storedImage = sut.loadFaceImage(for: registration)
        XCTAssertNotNil(storedImage)
        XCTAssertEqual(storedImage, imageData)
    }

    func testSaveFace_ThrowsOnEmptyData() {
        XCTAssertThrowsError(try sut.saveFace(Data())) { error in
            guard let repoError = error as? FaceRepositoryError else {
                XCTFail("Expected FaceRepositoryError but got \(error)")
                return
            }
            XCTAssertEqual(repoError, .invalidData)
        }
    }

    func testSaveFace_DataStoredLocallyOnly() throws {
        let imageData = createTestImageData()
        let registration = try sut.saveFace(imageData)

        // Verify the file exists at the expected local path
        let imageURL = tempDirectory.appendingPathComponent(registration.imageFileName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: imageURL.path))

        // Verify registration JSON exists
        let regURL = tempDirectory.appendingPathComponent("registration.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: regURL.path))
    }

    // MARK: - loadRegistration Tests

    func testLoadRegistration_NilWhenNoRegistration() {
        XCTAssertNil(sut.loadRegistration())
    }

    func testLoadRegistration_ReturnsRegistrationAfterSave() throws {
        let imageData = createTestImageData()
        let saved = try sut.saveFace(imageData)

        let loaded = sut.loadRegistration()

        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.id, saved.id)
        XCTAssertEqual(loaded?.imageFileName, saved.imageFileName)
    }

    func testLoadRegistration_PersistsAcrossNewInstances() throws {
        let imageData = createTestImageData()
        let saved = try sut.saveFace(imageData)

        // Create a new repository instance pointing to same directory
        let newRepo = FaceRepository(fileManager: .default, baseDirectory: tempDirectory)
        let loaded = newRepo.loadRegistration()

        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.id, saved.id)
    }

    // MARK: - loadFaceImage Tests

    func testLoadFaceImage_NilForNonexistentRegistration() {
        let fakeRegistration = FaceRegistration(imageFileName: "nonexistent.jpg")
        XCTAssertNil(sut.loadFaceImage(for: fakeRegistration))
    }

    func testLoadFaceImage_ReturnsDataAfterSave() throws {
        let imageData = createTestImageData()
        let registration = try sut.saveFace(imageData)

        let loaded = sut.loadFaceImage(for: registration)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded, imageData)
    }

    // MARK: - deleteAll Tests

    func testDeleteAll_RemovesRegistration() throws {
        let imageData = createTestImageData()
        try sut.saveFace(imageData)
        XCTAssertTrue(sut.hasFaceRegistered())

        try sut.deleteAll()

        XCTAssertFalse(sut.hasFaceRegistered())
        XCTAssertNil(sut.loadRegistration())
    }

    func testDeleteAll_DoesNotThrowWhenEmpty() {
        XCTAssertNoThrow(try sut.deleteAll())
    }

    func testDeleteAll_RemovesDirectory() throws {
        let imageData = createTestImageData()
        try sut.saveFace(imageData)

        try sut.deleteAll()

        XCTAssertFalse(FileManager.default.fileExists(atPath: tempDirectory.path))
    }

    // MARK: - Data Privacy Tests

    func testFaceData_NotStoredOutsideBaseDirectory() throws {
        let imageData = createTestImageData()
        try sut.saveFace(imageData)

        // Ensure data only exists within the base directory
        let contents = try FileManager.default.contentsOfDirectory(
            at: tempDirectory,
            includingPropertiesForKeys: nil
        )

        // Should have 3 files: the image, registrations.json, and legacy registration.json
        XCTAssertEqual(contents.count, 3)

        let fileNames = contents.map { $0.lastPathComponent }
        XCTAssertTrue(fileNames.contains("registrations.json"))
        XCTAssertTrue(fileNames.contains("registration.json"))
        XCTAssertTrue(fileNames.contains(where: { $0.hasSuffix(".jpg") }))
    }

    // MARK: - Helper Methods

    private func createTestImageData() -> Data {
        // Create minimal valid data (not a real image but sufficient for storage tests)
        return Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46])
    }
}
