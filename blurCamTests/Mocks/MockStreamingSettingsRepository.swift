import Foundation
@testable import blurCam

/// Mock implementation of StreamingSettingsRepositoryProtocol for testing
final class MockStreamingSettingsRepository: StreamingSettingsRepositoryProtocol {

    // MARK: - Configurable State

    var rtmpURL: String?
    var streamKey: String?

    // MARK: - Call Tracking

    var loadRTMPURLCallCount = 0
    var saveRTMPURLCallCount = 0
    var savedRTMPURLs: [String] = []
    var loadStreamKeyCallCount = 0
    var saveStreamKeyCallCount = 0
    var savedStreamKeys: [String] = []

    // MARK: - Destination Management State

    var destinations: [StreamingDestination] = []
    var _selectedDestinationId: UUID?

    // MARK: - Destination Call Tracking

    var saveDestinationCallCount = 0
    var loadDestinationsCallCount = 0
    var deleteDestinationCallCount = 0
    var selectDestinationCallCount = 0
    var loadSelectedDestinationCallCount = 0
    var deletedDestinationIds: [UUID] = []

    // MARK: - StreamingSettingsRepositoryProtocol (Legacy)

    func loadRTMPURL() -> String? {
        loadRTMPURLCallCount += 1
        return rtmpURL
    }

    func saveRTMPURL(_ url: String) {
        saveRTMPURLCallCount += 1
        savedRTMPURLs.append(url)
        rtmpURL = url
    }

    func loadStreamKey() -> String? {
        loadStreamKeyCallCount += 1
        return streamKey
    }

    func saveStreamKey(_ key: String) {
        saveStreamKeyCallCount += 1
        savedStreamKeys.append(key)
        streamKey = key
    }

    // MARK: - Destination Management

    func saveDestination(_ destination: StreamingDestination) {
        saveDestinationCallCount += 1
        if let index = destinations.firstIndex(where: { $0.id == destination.id }) {
            destinations[index] = destination
        } else {
            destinations.append(destination)
        }
    }

    func loadDestinations() -> [StreamingDestination] {
        loadDestinationsCallCount += 1
        return destinations.sorted { $0.createdAt < $1.createdAt }
    }

    func deleteDestination(id: UUID) {
        deleteDestinationCallCount += 1
        deletedDestinationIds.append(id)
        destinations.removeAll { $0.id == id }
        if _selectedDestinationId == id {
            _selectedDestinationId = nil
        }
    }

    var selectedDestinationId: UUID? {
        return _selectedDestinationId
    }

    func selectDestination(id: UUID?) {
        selectDestinationCallCount += 1
        _selectedDestinationId = id
    }

    func loadSelectedDestination() -> StreamingDestination? {
        loadSelectedDestinationCallCount += 1
        guard let selectedId = _selectedDestinationId else { return nil }
        return destinations.first { $0.id == selectedId }
    }
}
