import XCTest
@testable import blurCam

@MainActor
final class SettingsViewModelTests: XCTestCase {

    private var mockFaceRepo: MockFaceRepository!
    private var mockBlurSettingsRepo: MockBlurSettingsRepository!

    override func setUp() {
        super.setUp()
        mockFaceRepo = MockFaceRepository()
        mockBlurSettingsRepo = MockBlurSettingsRepository()
    }

    override func tearDown() {
        mockFaceRepo = nil
        mockBlurSettingsRepo = nil
        super.tearDown()
    }

    private func makeViewModel() -> SettingsViewModel {
        SettingsViewModel(
            faceRepository: mockFaceRepo,
            blurSettingsRepository: mockBlurSettingsRepo
        )
    }

    // MARK: - Initial State

    func testInitialBlurIntensity_DefaultsMedium() {
        let viewModel = makeViewModel()
        XCTAssertEqual(viewModel.blurIntensity, .medium)
    }

    func testInitialBlurIntensity_LoadsSavedValue() {
        mockBlurSettingsRepo.savedIntensity = .high
        let viewModel = makeViewModel()
        XCTAssertEqual(viewModel.blurIntensity, .high)
    }

    func testInitialRegisteredFaces_Empty() {
        let viewModel = makeViewModel()
        XCTAssertTrue(viewModel.registeredFaces.isEmpty)
    }

    // MARK: - Face Loading

    func testLoadFaces_LoadsFromRepository() throws {
        let registration = try mockFaceRepo.saveFace(Data([0xFF, 0xD8, 0xFF]))
        let viewModel = makeViewModel()

        XCTAssertEqual(viewModel.registeredFaces.count, 1)
        XCTAssertEqual(viewModel.registeredFaces.first?.id, registration.id)
    }

    func testLoadFaces_MultipleFaces() throws {
        let reg1 = try mockFaceRepo.saveFace(Data([0xFF, 0xD8, 0x01]))
        let reg2 = try mockFaceRepo.saveFace(Data([0xFF, 0xD8, 0x02]))
        let viewModel = makeViewModel()

        XCTAssertEqual(viewModel.registeredFaces.count, 2)
        XCTAssertEqual(viewModel.registeredFaces[0].id, reg1.id)
        XCTAssertEqual(viewModel.registeredFaces[1].id, reg2.id)
    }

    func testLoadFaces_IncludesThumbnailData() throws {
        let imageData = Data([0xFF, 0xD8, 0xFF, 0xE0])
        try mockFaceRepo.saveFace(imageData)
        let viewModel = makeViewModel()

        XCTAssertNotNil(viewModel.registeredFaces.first?.thumbnailData)
        XCTAssertEqual(viewModel.registeredFaces.first?.thumbnailData, imageData)
    }

    // MARK: - Face Deletion

    func testRequestDeleteFace_ShowsConfirmation() throws {
        try mockFaceRepo.saveFace(Data([0xFF, 0xD8, 0xFF]))
        let viewModel = makeViewModel()
        let face = viewModel.registeredFaces.first!

        viewModel.requestDeleteFace(face)

        XCTAssertTrue(viewModel.showDeleteConfirmation)
        XCTAssertEqual(viewModel.faceToDelete?.id, face.id)
    }

    func testConfirmDeleteFace_RemovesFace() throws {
        try mockFaceRepo.saveFace(Data([0xFF, 0xD8, 0x01]))
        try mockFaceRepo.saveFace(Data([0xFF, 0xD8, 0x02]))
        let viewModel = makeViewModel()
        let faceToDelete = viewModel.registeredFaces.first!

        viewModel.requestDeleteFace(faceToDelete)
        viewModel.confirmDeleteFace()

        XCTAssertEqual(viewModel.registeredFaces.count, 1)
        XCTAssertFalse(viewModel.showDeleteConfirmation)
        XCTAssertNil(viewModel.faceToDelete)
    }

    func testConfirmDeleteFace_CallsFacesChangedCallback() throws {
        try mockFaceRepo.saveFace(Data([0xFF, 0xD8, 0x01]))
        try mockFaceRepo.saveFace(Data([0xFF, 0xD8, 0x02]))
        let viewModel = makeViewModel()

        var callbackCalled = false
        viewModel.onFacesChanged = { callbackCalled = true }

        let face = viewModel.registeredFaces.first!
        viewModel.requestDeleteFace(face)
        viewModel.confirmDeleteFace()

        XCTAssertTrue(callbackCalled)
    }

    func testDeleteAllFaces_SetsAllFacesDeleted() throws {
        try mockFaceRepo.saveFace(Data([0xFF, 0xD8, 0xFF]))
        let viewModel = makeViewModel()

        XCTAssertEqual(viewModel.registeredFaces.count, 1)

        let face = viewModel.registeredFaces.first!
        viewModel.requestDeleteFace(face)
        viewModel.confirmDeleteFace()

        XCTAssertTrue(viewModel.allFacesDeleted)
        XCTAssertTrue(viewModel.registeredFaces.isEmpty)
    }

    func testCancelDeleteFace_DoesNotDelete() throws {
        try mockFaceRepo.saveFace(Data([0xFF, 0xD8, 0xFF]))
        let viewModel = makeViewModel()
        let face = viewModel.registeredFaces.first!

        viewModel.requestDeleteFace(face)
        viewModel.cancelDeleteFace()

        XCTAssertEqual(viewModel.registeredFaces.count, 1)
        XCTAssertFalse(viewModel.showDeleteConfirmation)
        XCTAssertNil(viewModel.faceToDelete)
    }

    // MARK: - Face Addition

    func testStartAddingFace_SetsIsAddingFace() {
        let viewModel = makeViewModel()

        viewModel.startAddingFace()

        XCTAssertTrue(viewModel.isAddingFace)
    }

    func testOnFaceAdded_ResetsAddingState() {
        let viewModel = makeViewModel()
        viewModel.startAddingFace()

        viewModel.onFaceAdded()

        XCTAssertFalse(viewModel.isAddingFace)
    }

    func testOnFaceAdded_ReloadsAndCallsCallback() throws {
        let viewModel = makeViewModel()

        var callbackCalled = false
        viewModel.onFacesChanged = { callbackCalled = true }

        // Simulate adding a face externally (as the capture flow would do)
        try mockFaceRepo.saveFace(Data([0xFF, 0xD8, 0xFF]))
        viewModel.onFaceAdded()

        XCTAssertEqual(viewModel.registeredFaces.count, 1)
        XCTAssertTrue(callbackCalled)
    }

    // MARK: - Blur Intensity

    func testBlurIntensity_SavesWhenChanged() {
        let viewModel = makeViewModel()

        viewModel.blurIntensity = .high

        XCTAssertEqual(mockBlurSettingsRepo.savedIntensity, .high)
        XCTAssertEqual(mockBlurSettingsRepo.saveBlurIntensityCallCount, 1)
    }

    func testBlurIntensity_CallsCallback() {
        let viewModel = makeViewModel()

        var receivedIntensity: BlurIntensity?
        viewModel.onBlurIntensityChanged = { intensity in
            receivedIntensity = intensity
        }

        viewModel.blurIntensity = .low

        XCTAssertEqual(receivedIntensity, .low)
    }

    func testBlurSliderValue_MapsCorrectly() {
        let viewModel = makeViewModel()

        // Default is medium (rawValue 1)
        XCTAssertEqual(viewModel.blurSliderValue, 0.5, accuracy: 0.01)

        viewModel.blurSliderValue = 0.0
        XCTAssertEqual(viewModel.blurIntensity, .low)

        viewModel.blurSliderValue = 0.5
        XCTAssertEqual(viewModel.blurIntensity, .medium)

        viewModel.blurSliderValue = 1.0
        XCTAssertEqual(viewModel.blurIntensity, .high)
    }

    // MARK: - Error Handling

    func testDeleteFace_HandlesError() throws {
        try mockFaceRepo.saveFace(Data([0xFF, 0xD8, 0xFF]))
        let viewModel = makeViewModel()
        let face = viewModel.registeredFaces.first!

        mockFaceRepo.deleteFaceError = FaceRepositoryError.deleteFailed("テストエラー")

        viewModel.requestDeleteFace(face)
        viewModel.confirmDeleteFace()

        XCTAssertNotNil(viewModel.errorMessage)
    }
}
