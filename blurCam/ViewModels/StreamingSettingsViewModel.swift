import Foundation
import SwiftUI

/// Validation error types for streaming destination form
enum StreamingDestinationValidationError: LocalizedError, Equatable {
    case emptyURL
    case emptyStreamKey
    case invalidURLFormat

    var errorDescription: String? {
        switch self {
        case .emptyURL:
            return "RTMP URLを入力してください"
        case .emptyStreamKey:
            return "ストリームキーを入力してください"
        case .invalidURLFormat:
            return "RTMP URLは rtmp:// で始まる必要があります"
        }
    }
}

/// ViewModel responsible for managing streaming destinations.
/// Handles adding, deleting, selecting destinations, and form validation.
@MainActor
final class StreamingSettingsViewModel: ObservableObject {

    // MARK: - Published Properties

    /// All saved streaming destinations
    @Published private(set) var destinations: [StreamingDestination] = []

    /// The ID of the currently selected destination
    @Published private(set) var selectedDestinationId: UUID?

    /// Whether the add destination sheet is presented
    @Published var isAddingDestination: Bool = false

    /// Whether a delete confirmation alert is shown
    @Published var showDeleteConfirmation: Bool = false

    /// The destination pending deletion
    @Published var destinationToDelete: StreamingDestination?

    /// Error message to display in the destination list
    @Published private(set) var errorMessage: String?

    // MARK: - Add Form State

    /// The selected platform in the add form
    @Published var selectedPlatform: StreamingPlatform = .youTube {
        didSet {
            // Auto-fill URL when platform changes
            if selectedPlatform != .custom {
                formRTMPURL = selectedPlatform.presetURL
            } else {
                formRTMPURL = ""
            }
            formValidationError = nil
        }
    }

    /// Name input in the add form
    @Published var formName: String = ""

    /// RTMP URL input in the add form
    @Published var formRTMPURL: String = ""

    /// Stream key input in the add form
    @Published var formStreamKey: String = ""

    /// Validation error for the add form
    @Published var formValidationError: StreamingDestinationValidationError?

    /// Whether the stream key is visible in the add form
    @Published var isStreamKeyVisible: Bool = false

    // MARK: - Dependencies

    private let repository: StreamingSettingsRepositoryProtocol

    // MARK: - Initialization

    init(repository: StreamingSettingsRepositoryProtocol = StreamingSettingsRepository()) {
        self.repository = repository
        loadDestinations()
    }

    // MARK: - Public Methods

    /// Loads all saved destinations from the repository
    func loadDestinations() {
        destinations = repository.loadDestinations()
        selectedDestinationId = repository.selectedDestinationId
    }

    /// Starts the add destination flow
    func startAddingDestination() {
        // Reset form state
        selectedPlatform = .youTube
        formName = ""
        formRTMPURL = StreamingPlatform.youTube.presetURL
        formStreamKey = ""
        formValidationError = nil
        isStreamKeyVisible = false
        isAddingDestination = true
    }

    /// Validates and saves a new streaming destination
    /// - Returns: true if saved successfully, false if validation failed
    @discardableResult
    func saveDestination() -> Bool {
        // Validate
        if let error = validateForm() {
            formValidationError = error
            return false
        }

        // Generate name if empty
        let name = formName.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = name.isEmpty ? selectedPlatform.displayName : name

        let destination = StreamingDestination(
            name: displayName,
            platform: selectedPlatform,
            rtmpURL: formRTMPURL.trimmingCharacters(in: .whitespacesAndNewlines),
            streamKey: formStreamKey.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        repository.saveDestination(destination)

        // Auto-select the first destination if none is selected
        if selectedDestinationId == nil {
            repository.selectDestination(id: destination.id)
        }

        loadDestinations()
        isAddingDestination = false
        return true
    }

    /// Requests deletion of a destination (shows confirmation dialog)
    func requestDeleteDestination(_ destination: StreamingDestination) {
        destinationToDelete = destination
        showDeleteConfirmation = true
    }

    /// Confirms deletion of the pending destination
    func confirmDeleteDestination() {
        guard let destination = destinationToDelete else { return }

        repository.deleteDestination(id: destination.id)
        loadDestinations()

        destinationToDelete = nil
        showDeleteConfirmation = false
    }

    /// Cancels the pending deletion
    func cancelDeleteDestination() {
        destinationToDelete = nil
        showDeleteConfirmation = false
    }

    /// Selects a destination for streaming
    func selectDestination(_ destination: StreamingDestination) {
        repository.selectDestination(id: destination.id)
        selectedDestinationId = destination.id
    }

    /// Returns the currently selected destination
    func getSelectedDestination() -> StreamingDestination? {
        return repository.loadSelectedDestination()
    }

    /// Whether the destination is currently selected
    func isSelected(_ destination: StreamingDestination) -> Bool {
        return destination.id == selectedDestinationId
    }

    // MARK: - Validation

    /// Validates the add form and returns the first error, or nil if valid
    func validateForm() -> StreamingDestinationValidationError? {
        let url = formRTMPURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = formStreamKey.trimmingCharacters(in: .whitespacesAndNewlines)

        if url.isEmpty {
            return .emptyURL
        }

        if !url.hasPrefix("rtmp://") && !url.hasPrefix("rtmps://") {
            return .invalidURLFormat
        }

        if key.isEmpty {
            return .emptyStreamKey
        }

        return nil
    }
}
