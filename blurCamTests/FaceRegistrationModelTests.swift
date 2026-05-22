import XCTest
@testable import blurCam

final class FaceRegistrationModelTests: XCTestCase {

    // MARK: - FaceRegistration Tests

    func testFaceRegistration_Init_DefaultValues() {
        let registration = FaceRegistration(imageFileName: "test.jpg")

        XCTAssertFalse(registration.id.uuidString.isEmpty)
        XCTAssertEqual(registration.imageFileName, "test.jpg")
        XCTAssertNotNil(registration.registeredAt)
    }

    func testFaceRegistration_Init_CustomValues() {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1000)
        let registration = FaceRegistration(id: id, registeredAt: date, imageFileName: "custom.jpg")

        XCTAssertEqual(registration.id, id)
        XCTAssertEqual(registration.registeredAt, date)
        XCTAssertEqual(registration.imageFileName, "custom.jpg")
    }

    func testFaceRegistration_Equatable() {
        let id = UUID()
        let date = Date()
        let reg1 = FaceRegistration(id: id, registeredAt: date, imageFileName: "face.jpg")
        let reg2 = FaceRegistration(id: id, registeredAt: date, imageFileName: "face.jpg")

        XCTAssertEqual(reg1, reg2)
    }

    func testFaceRegistration_NotEqual_DifferentId() {
        let date = Date()
        let reg1 = FaceRegistration(id: UUID(), registeredAt: date, imageFileName: "face.jpg")
        let reg2 = FaceRegistration(id: UUID(), registeredAt: date, imageFileName: "face.jpg")

        XCTAssertNotEqual(reg1, reg2)
    }

    func testFaceRegistration_Codable_RoundTrip() throws {
        let original = FaceRegistration(imageFileName: "roundtrip.jpg")

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(FaceRegistration.self, from: data)

        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.imageFileName, decoded.imageFileName)
        // Date comparison with tolerance for encoding precision
        XCTAssertEqual(
            original.registeredAt.timeIntervalSince1970,
            decoded.registeredAt.timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    // MARK: - FaceRepositoryError Tests

    func testFaceRepositoryError_Descriptions() {
        let errors: [(FaceRepositoryError, String)] = [
            (.directoryCreationFailed("test"), "test"),
            (.imageSaveFailed("test"), "test"),
            (.registrationSaveFailed("test"), "test"),
            (.deleteFailed("test"), "test"),
            (.invalidData, "無効な顔データです"),
        ]

        for (error, expectedContains) in errors {
            XCTAssertNotNil(error.errorDescription, "Error should have a description")
            XCTAssertTrue(
                error.errorDescription!.contains(expectedContains),
                "Error '\(error)' description should contain '\(expectedContains)'"
            )
        }
    }

    func testFaceRepositoryError_Equatable() {
        XCTAssertEqual(FaceRepositoryError.invalidData, FaceRepositoryError.invalidData)
        XCTAssertEqual(
            FaceRepositoryError.imageSaveFailed("a"),
            FaceRepositoryError.imageSaveFailed("a")
        )
        XCTAssertNotEqual(
            FaceRepositoryError.imageSaveFailed("a"),
            FaceRepositoryError.imageSaveFailed("b")
        )
        XCTAssertNotEqual(
            FaceRepositoryError.invalidData,
            FaceRepositoryError.deleteFailed("test")
        )
    }

    // MARK: - OnboardingStep Tests

    func testOnboardingStep_Hashable() {
        let steps: Set<OnboardingStep> = [.welcome, .faceCapture, .complete]
        XCTAssertEqual(steps.count, 3)
    }

    func testOnboardingStep_Equatable() {
        XCTAssertEqual(OnboardingStep.welcome, OnboardingStep.welcome)
        XCTAssertEqual(OnboardingStep.faceCapture, OnboardingStep.faceCapture)
        XCTAssertEqual(OnboardingStep.complete, OnboardingStep.complete)
        XCTAssertNotEqual(OnboardingStep.welcome, OnboardingStep.faceCapture)
        XCTAssertNotEqual(OnboardingStep.faceCapture, OnboardingStep.complete)
    }
}
