import XCTest
@testable import blurCam

final class BlurIntensityTests: XCTestCase {

    // MARK: - Display Name Tests

    func testDisplayName_Low() {
        XCTAssertEqual(BlurIntensity.low.displayName, "弱")
    }

    func testDisplayName_Medium() {
        XCTAssertEqual(BlurIntensity.medium.displayName, "中")
    }

    func testDisplayName_High() {
        XCTAssertEqual(BlurIntensity.high.displayName, "強")
    }

    // MARK: - Blur Radius Tests

    func testBlurRadius_Low() {
        XCTAssertEqual(BlurIntensity.low.blurRadius, 15.0)
    }

    func testBlurRadius_Medium() {
        XCTAssertEqual(BlurIntensity.medium.blurRadius, 30.0)
    }

    func testBlurRadius_High() {
        XCTAssertEqual(BlurIntensity.high.blurRadius, 50.0)
    }

    // MARK: - Default Intensity

    func testDefaultIntensity_IsMedium() {
        XCTAssertEqual(BlurIntensity.defaultIntensity, .medium)
    }

    // MARK: - Raw Value Tests

    func testRawValues() {
        XCTAssertEqual(BlurIntensity.low.rawValue, 0)
        XCTAssertEqual(BlurIntensity.medium.rawValue, 1)
        XCTAssertEqual(BlurIntensity.high.rawValue, 2)
    }

    // MARK: - CaseIterable Tests

    func testAllCases() {
        XCTAssertEqual(BlurIntensity.allCases, [.low, .medium, .high])
    }

    // MARK: - Codable Tests

    func testEncodeDecode() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for intensity in BlurIntensity.allCases {
            let data = try encoder.encode(intensity)
            let decoded = try decoder.decode(BlurIntensity.self, from: data)
            XCTAssertEqual(decoded, intensity)
        }
    }

    // MARK: - Blur Radius Ordering

    func testBlurRadius_IncreasesWithIntensity() {
        XCTAssertLessThan(BlurIntensity.low.blurRadius, BlurIntensity.medium.blurRadius)
        XCTAssertLessThan(BlurIntensity.medium.blurRadius, BlurIntensity.high.blurRadius)
    }
}
