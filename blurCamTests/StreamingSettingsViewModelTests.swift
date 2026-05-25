import XCTest
@testable import blurCam

@MainActor
final class StreamingSettingsViewModelTests: XCTestCase {

    private var mockRepo: MockStreamingSettingsRepository!
    private var viewModel: StreamingSettingsViewModel!

    override func setUp() {
        super.setUp()
        mockRepo = MockStreamingSettingsRepository()
        viewModel = StreamingSettingsViewModel(repository: mockRepo)
    }

    override func tearDown() {
        mockRepo = nil
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState_EmptyDestinations() {
        XCTAssertEqual(viewModel.destinations.count, 0)
        XCTAssertNil(viewModel.selectedDestinationId)
        XCTAssertFalse(viewModel.isAddingDestination)
        XCTAssertFalse(viewModel.showDeleteConfirmation)
    }

    func testInitialState_LoadsExistingDestinations() {
        let dest = StreamingDestination(
            name: "YouTube",
            platform: .youTube,
            rtmpURL: "rtmp://yt.com",
            streamKey: "k1"
        )
        mockRepo.destinations = [dest]
        mockRepo._selectedDestinationId = dest.id

        let vm = StreamingSettingsViewModel(repository: mockRepo)

        XCTAssertEqual(vm.destinations.count, 1)
        XCTAssertEqual(vm.selectedDestinationId, dest.id)
    }

    // MARK: - Start Adding Destination Tests

    func testStartAddingDestination_ResetsFormState() {
        viewModel.formName = "Old Name"
        viewModel.formRTMPURL = "rtmp://old.com"
        viewModel.formStreamKey = "old-key"
        viewModel.formValidationError = .emptyURL

        viewModel.startAddingDestination()

        XCTAssertTrue(viewModel.isAddingDestination)
        XCTAssertEqual(viewModel.selectedPlatform, .youTube)
        XCTAssertEqual(viewModel.formName, "")
        XCTAssertEqual(viewModel.formRTMPURL, StreamingPlatform.youTube.presetURL)
        XCTAssertEqual(viewModel.formStreamKey, "")
        XCTAssertNil(viewModel.formValidationError)
    }

    func testStartAddingDestination_SetsYouTubePresetURL() {
        viewModel.startAddingDestination()

        XCTAssertEqual(viewModel.formRTMPURL, "rtmp://a.rtmp.youtube.com/live2")
    }

    // MARK: - Platform Selection Tests

    func testSelectedPlatform_YouTube_SetsPresetURL() {
        viewModel.selectedPlatform = .youTube

        XCTAssertEqual(viewModel.formRTMPURL, "rtmp://a.rtmp.youtube.com/live2")
    }

    func testSelectedPlatform_Twitch_SetsPresetURL() {
        viewModel.selectedPlatform = .twitch

        XCTAssertEqual(viewModel.formRTMPURL, "rtmp://live.twitch.tv/app")
    }

    func testSelectedPlatform_Custom_ClearsURL() {
        viewModel.formRTMPURL = "rtmp://some.com"
        viewModel.selectedPlatform = .custom

        XCTAssertEqual(viewModel.formRTMPURL, "")
    }

    func testSelectedPlatform_Change_ClearsValidationError() {
        viewModel.formValidationError = .emptyURL

        viewModel.selectedPlatform = .twitch

        XCTAssertNil(viewModel.formValidationError)
    }

    // MARK: - Validation Tests

    func testValidateForm_EmptyURL_ReturnsError() {
        viewModel.formRTMPURL = ""
        viewModel.formStreamKey = "key"

        let error = viewModel.validateForm()
        XCTAssertEqual(error, .emptyURL)
    }

    func testValidateForm_WhitespaceOnlyURL_ReturnsError() {
        viewModel.formRTMPURL = "   "
        viewModel.formStreamKey = "key"

        let error = viewModel.validateForm()
        XCTAssertEqual(error, .emptyURL)
    }

    func testValidateForm_InvalidURLFormat_ReturnsError() {
        viewModel.formRTMPURL = "http://not-rtmp.com"
        viewModel.formStreamKey = "key"

        let error = viewModel.validateForm()
        XCTAssertEqual(error, .invalidURLFormat)
    }

    func testValidateForm_EmptyStreamKey_ReturnsError() {
        viewModel.formRTMPURL = "rtmp://valid.com/app"
        viewModel.formStreamKey = ""

        let error = viewModel.validateForm()
        XCTAssertEqual(error, .emptyStreamKey)
    }

    func testValidateForm_WhitespaceOnlyStreamKey_ReturnsError() {
        viewModel.formRTMPURL = "rtmp://valid.com/app"
        viewModel.formStreamKey = "  "

        let error = viewModel.validateForm()
        XCTAssertEqual(error, .emptyStreamKey)
    }

    func testValidateForm_ValidInput_ReturnsNil() {
        viewModel.formRTMPURL = "rtmp://valid.com/app"
        viewModel.formStreamKey = "valid-key"

        let error = viewModel.validateForm()
        XCTAssertNil(error)
    }

    func testValidateForm_RtmpsURL_IsValid() {
        viewModel.formRTMPURL = "rtmps://secure.com/app"
        viewModel.formStreamKey = "key"

        let error = viewModel.validateForm()
        XCTAssertNil(error)
    }

    // MARK: - Save Destination Tests

    func testSaveDestination_Valid_SavesAndDismisses() {
        viewModel.startAddingDestination()
        viewModel.formName = "My YouTube"
        viewModel.formRTMPURL = "rtmp://a.rtmp.youtube.com/live2"
        viewModel.formStreamKey = "test-key-123"

        let result = viewModel.saveDestination()

        XCTAssertTrue(result)
        XCTAssertFalse(viewModel.isAddingDestination)
        XCTAssertEqual(viewModel.destinations.count, 1)
        XCTAssertEqual(viewModel.destinations.first?.name, "My YouTube")
        XCTAssertEqual(viewModel.destinations.first?.platform, .youTube)
        XCTAssertEqual(viewModel.destinations.first?.rtmpURL, "rtmp://a.rtmp.youtube.com/live2")
        XCTAssertEqual(viewModel.destinations.first?.streamKey, "test-key-123")
    }

    func testSaveDestination_EmptyName_UsesPlatformName() {
        viewModel.startAddingDestination()
        viewModel.selectedPlatform = .twitch
        viewModel.formName = ""
        viewModel.formStreamKey = "key"

        viewModel.saveDestination()

        XCTAssertEqual(viewModel.destinations.first?.name, "Twitch")
    }

    func testSaveDestination_Invalid_ShowsErrorAndDoesNotDismiss() {
        viewModel.startAddingDestination()
        viewModel.formRTMPURL = ""
        viewModel.formStreamKey = ""

        let result = viewModel.saveDestination()

        XCTAssertFalse(result)
        XCTAssertTrue(viewModel.isAddingDestination)
        XCTAssertNotNil(viewModel.formValidationError)
        XCTAssertEqual(viewModel.destinations.count, 0)
    }

    func testSaveDestination_TrimsWhitespace() {
        viewModel.startAddingDestination()
        viewModel.formName = "  My Channel  "
        viewModel.formRTMPURL = "  rtmp://test.com/app  "
        viewModel.formStreamKey = "  key123  "

        viewModel.saveDestination()

        XCTAssertEqual(viewModel.destinations.first?.name, "My Channel")
        XCTAssertEqual(viewModel.destinations.first?.rtmpURL, "rtmp://test.com/app")
        XCTAssertEqual(viewModel.destinations.first?.streamKey, "key123")
    }

    func testSaveDestination_AutoSelectsFirst() {
        XCTAssertNil(viewModel.selectedDestinationId)

        viewModel.startAddingDestination()
        viewModel.formRTMPURL = "rtmp://test.com/app"
        viewModel.formStreamKey = "key"

        viewModel.saveDestination()

        XCTAssertNotNil(viewModel.selectedDestinationId)
        XCTAssertEqual(viewModel.selectedDestinationId, viewModel.destinations.first?.id)
    }

    func testSaveDestination_DoesNotAutoSelectSubsequent() {
        // Save first destination (auto-selected)
        let firstDest = StreamingDestination(
            name: "First",
            platform: .youTube,
            rtmpURL: "rtmp://first.com",
            streamKey: "k1"
        )
        mockRepo.destinations = [firstDest]
        mockRepo._selectedDestinationId = firstDest.id
        viewModel.loadDestinations()

        // Save second destination
        viewModel.startAddingDestination()
        viewModel.formName = "Second"
        viewModel.selectedPlatform = .twitch
        viewModel.formStreamKey = "k2"

        viewModel.saveDestination()

        // The first should still be selected
        XCTAssertEqual(viewModel.selectedDestinationId, firstDest.id)
    }

    // MARK: - Delete Destination Tests

    func testRequestDeleteDestination_ShowsConfirmation() {
        let dest = StreamingDestination(
            name: "YouTube",
            platform: .youTube,
            rtmpURL: "rtmp://yt.com",
            streamKey: "k1"
        )

        viewModel.requestDeleteDestination(dest)

        XCTAssertTrue(viewModel.showDeleteConfirmation)
        XCTAssertEqual(viewModel.destinationToDelete?.id, dest.id)
    }

    func testConfirmDeleteDestination_RemovesDestination() {
        let dest = StreamingDestination(
            name: "YouTube",
            platform: .youTube,
            rtmpURL: "rtmp://yt.com",
            streamKey: "k1"
        )
        mockRepo.destinations = [dest]
        viewModel.loadDestinations()

        viewModel.requestDeleteDestination(dest)
        viewModel.confirmDeleteDestination()

        XCTAssertEqual(viewModel.destinations.count, 0)
        XCTAssertFalse(viewModel.showDeleteConfirmation)
        XCTAssertNil(viewModel.destinationToDelete)
    }

    func testCancelDeleteDestination_DoesNotRemove() {
        let dest = StreamingDestination(
            name: "YouTube",
            platform: .youTube,
            rtmpURL: "rtmp://yt.com",
            streamKey: "k1"
        )
        mockRepo.destinations = [dest]
        viewModel.loadDestinations()

        viewModel.requestDeleteDestination(dest)
        viewModel.cancelDeleteDestination()

        XCTAssertEqual(viewModel.destinations.count, 1)
        XCTAssertFalse(viewModel.showDeleteConfirmation)
        XCTAssertNil(viewModel.destinationToDelete)
    }

    // MARK: - Select Destination Tests

    func testSelectDestination() {
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
        mockRepo.destinations = [dest1, dest2]
        viewModel.loadDestinations()

        viewModel.selectDestination(dest2)

        XCTAssertEqual(viewModel.selectedDestinationId, dest2.id)
        XCTAssertTrue(viewModel.isSelected(dest2))
        XCTAssertFalse(viewModel.isSelected(dest1))
    }

    func testGetSelectedDestination_ReturnsCorrect() {
        let dest = StreamingDestination(
            name: "YouTube",
            platform: .youTube,
            rtmpURL: "rtmp://yt.com",
            streamKey: "k1"
        )
        mockRepo.destinations = [dest]
        mockRepo._selectedDestinationId = dest.id
        viewModel.loadDestinations()

        let selected = viewModel.getSelectedDestination()
        XCTAssertEqual(selected?.id, dest.id)
    }

    func testGetSelectedDestination_ReturnsNilWhenNoneSelected() {
        XCTAssertNil(viewModel.getSelectedDestination())
    }

    // MARK: - Validation Error Description Tests

    func testValidationError_EmptyURL_HasDescription() {
        XCTAssertNotNil(StreamingDestinationValidationError.emptyURL.errorDescription)
    }

    func testValidationError_EmptyStreamKey_HasDescription() {
        XCTAssertNotNil(StreamingDestinationValidationError.emptyStreamKey.errorDescription)
    }

    func testValidationError_InvalidURLFormat_HasDescription() {
        XCTAssertNotNil(StreamingDestinationValidationError.invalidURLFormat.errorDescription)
    }
}
