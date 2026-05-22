import XCTest
@testable import blurCam

final class BlurSettingsRepositoryTests: XCTestCase {

    private var userDefaults: UserDefaults!
    private var sut: BlurSettingsRepository!

    override func setUp() {
        super.setUp()
        // Use a separate UserDefaults suite for testing
        let suiteName = "BlurSettingsRepositoryTests-\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)!
        sut = BlurSettingsRepository(userDefaults: userDefaults)
    }

    override func tearDown() {
        // Clean up the test suite
        if let suiteName = userDefaults.volatileDomainNames.first {
            userDefaults.removeSuite(named: suiteName)
        }
        userDefaults = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - Load Tests

    func testLoadBlurIntensity_NilWhenNotSet() {
        XCTAssertNil(sut.loadBlurIntensity())
    }

    func testLoadBlurIntensity_ReturnsAfterSave() {
        sut.saveBlurIntensity(.high)
        XCTAssertEqual(sut.loadBlurIntensity(), .high)
    }

    // MARK: - Save Tests

    func testSaveBlurIntensity_Low() {
        sut.saveBlurIntensity(.low)
        XCTAssertEqual(sut.loadBlurIntensity(), .low)
    }

    func testSaveBlurIntensity_Medium() {
        sut.saveBlurIntensity(.medium)
        XCTAssertEqual(sut.loadBlurIntensity(), .medium)
    }

    func testSaveBlurIntensity_High() {
        sut.saveBlurIntensity(.high)
        XCTAssertEqual(sut.loadBlurIntensity(), .high)
    }

    // MARK: - Persistence Tests

    func testSaveBlurIntensity_PersistsAcrossInstances() {
        sut.saveBlurIntensity(.low)

        // Create a new instance with the same UserDefaults
        let newRepo = BlurSettingsRepository(userDefaults: userDefaults)
        XCTAssertEqual(newRepo.loadBlurIntensity(), .low)
    }

    func testSaveBlurIntensity_Overwrite() {
        sut.saveBlurIntensity(.low)
        sut.saveBlurIntensity(.high)
        XCTAssertEqual(sut.loadBlurIntensity(), .high)
    }
}
