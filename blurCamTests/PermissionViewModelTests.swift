import XCTest
@testable import blurCam

@MainActor
final class PermissionViewModelTests: XCTestCase {

    private var mockRepo: MockPermissionRepository!

    override func setUp() {
        super.setUp()
        mockRepo = MockPermissionRepository()
    }

    override func tearDown() {
        mockRepo = nil
        super.tearDown()
    }

    // MARK: - Camera Permission Status Tests

    func testInitialCameraPermissionStatus_NotDetermined() {
        mockRepo.cameraStatus = .notDetermined
        let viewModel = PermissionViewModel(permissionRepository: mockRepo)

        XCTAssertEqual(viewModel.cameraPermission, .notDetermined)
    }

    func testInitialCameraPermissionStatus_Authorized() {
        mockRepo.cameraStatus = .authorized
        let viewModel = PermissionViewModel(permissionRepository: mockRepo)

        XCTAssertEqual(viewModel.cameraPermission, .authorized)
    }

    func testInitialCameraPermissionStatus_Denied() {
        mockRepo.cameraStatus = .denied
        let viewModel = PermissionViewModel(permissionRepository: mockRepo)

        XCTAssertEqual(viewModel.cameraPermission, .denied)
    }

    // MARK: - Camera Permission Request Tests

    func testRequestCameraPermission_Granted() async {
        mockRepo.cameraStatus = .notDetermined
        mockRepo.cameraRequestResult = .authorized
        let viewModel = PermissionViewModel(permissionRepository: mockRepo)

        await viewModel.requestCameraPermission()

        XCTAssertEqual(viewModel.cameraPermission, .authorized)
        XCTAssertEqual(mockRepo.requestCameraPermissionCallCount, 1)
    }

    func testRequestCameraPermission_Denied() async {
        mockRepo.cameraStatus = .notDetermined
        mockRepo.cameraRequestResult = .denied
        let viewModel = PermissionViewModel(permissionRepository: mockRepo)

        await viewModel.requestCameraPermission()

        XCTAssertEqual(viewModel.cameraPermission, .denied)
        XCTAssertEqual(mockRepo.requestCameraPermissionCallCount, 1)
    }

    // MARK: - Photo Library Permission Tests

    func testInitialPhotoLibraryPermissionStatus_NotDetermined() {
        mockRepo.photoLibraryStatus = .notDetermined
        let viewModel = PermissionViewModel(permissionRepository: mockRepo)

        XCTAssertEqual(viewModel.photoLibraryPermission, .notDetermined)
    }

    func testRequestPhotoLibraryPermission_Granted() async {
        mockRepo.photoLibraryStatus = .notDetermined
        mockRepo.photoLibraryRequestResult = .authorized
        let viewModel = PermissionViewModel(permissionRepository: mockRepo)

        await viewModel.requestPhotoLibraryPermission()

        XCTAssertEqual(viewModel.photoLibraryPermission, .authorized)
        XCTAssertEqual(mockRepo.requestPhotoLibraryPermissionCallCount, 1)
    }

    func testRequestPhotoLibraryPermission_Denied() async {
        mockRepo.photoLibraryStatus = .notDetermined
        mockRepo.photoLibraryRequestResult = .denied
        let viewModel = PermissionViewModel(permissionRepository: mockRepo)

        await viewModel.requestPhotoLibraryPermission()

        XCTAssertEqual(viewModel.photoLibraryPermission, .denied)
    }

    // MARK: - Open Settings Tests

    func testOpenAppSettings_CallsRepository() {
        let viewModel = PermissionViewModel(permissionRepository: mockRepo)

        viewModel.openAppSettings()

        XCTAssertEqual(mockRepo.openAppSettingsCallCount, 1)
    }

    // MARK: - Refresh Permissions Tests

    func testRefreshPermissions_UpdatesStatuses() {
        mockRepo.cameraStatus = .notDetermined
        mockRepo.photoLibraryStatus = .notDetermined
        let viewModel = PermissionViewModel(permissionRepository: mockRepo)

        // Change mock statuses
        mockRepo.cameraStatus = .authorized
        mockRepo.photoLibraryStatus = .authorized

        viewModel.refreshPermissions()

        XCTAssertEqual(viewModel.cameraPermission, .authorized)
        XCTAssertEqual(viewModel.photoLibraryPermission, .authorized)
    }
}
