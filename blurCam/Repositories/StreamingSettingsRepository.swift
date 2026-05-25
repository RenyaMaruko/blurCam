import Foundation

/// Protocol for persisting streaming configuration settings.
protocol StreamingSettingsRepositoryProtocol {
    /// Load the saved RTMP URL, or return nil if not set
    func loadRTMPURL() -> String?

    /// Save the RTMP URL
    func saveRTMPURL(_ url: String)

    /// Load the saved stream key, or return nil if not set
    func loadStreamKey() -> String?

    /// Save the stream key
    func saveStreamKey(_ key: String)

    // MARK: - Destination Management

    /// Save a streaming destination to the persistent store
    func saveDestination(_ destination: StreamingDestination)

    /// Load all saved streaming destinations
    func loadDestinations() -> [StreamingDestination]

    /// Delete a streaming destination by ID
    func deleteDestination(id: UUID)

    /// Get the ID of the currently selected destination
    var selectedDestinationId: UUID? { get }

    /// Select a destination by ID for use during streaming
    func selectDestination(id: UUID?)

    /// Load the currently selected destination, if any
    func loadSelectedDestination() -> StreamingDestination?
}

/// Concrete implementation of StreamingSettingsRepositoryProtocol using UserDefaults.
/// Persists RTMP URL, stream key, and streaming destination settings across app restarts.
final class StreamingSettingsRepository: StreamingSettingsRepositoryProtocol {

    private static let rtmpURLKey = "com.blurCam.streamingRTMPURL"
    private static let streamKeyKey = "com.blurCam.streamingStreamKey"
    private static let destinationsKey = "com.blurCam.streamingDestinations"
    private static let selectedDestinationIdKey = "com.blurCam.selectedDestinationId"

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - Legacy RTMP URL / Stream Key (kept for backward compatibility)

    func loadRTMPURL() -> String? {
        userDefaults.string(forKey: Self.rtmpURLKey)
    }

    func saveRTMPURL(_ url: String) {
        userDefaults.set(url, forKey: Self.rtmpURLKey)
    }

    func loadStreamKey() -> String? {
        userDefaults.string(forKey: Self.streamKeyKey)
    }

    func saveStreamKey(_ key: String) {
        userDefaults.set(key, forKey: Self.streamKeyKey)
    }

    // MARK: - Destination Management

    func saveDestination(_ destination: StreamingDestination) {
        var destinations = loadDestinations()

        // Replace if exists, otherwise append
        if let index = destinations.firstIndex(where: { $0.id == destination.id }) {
            destinations[index] = destination
        } else {
            destinations.append(destination)
        }

        saveDestinations(destinations)
    }

    func loadDestinations() -> [StreamingDestination] {
        guard let data = userDefaults.data(forKey: Self.destinationsKey) else {
            return []
        }

        do {
            let destinations = try JSONDecoder().decode([StreamingDestination].self, from: data)
            return destinations.sorted { $0.createdAt < $1.createdAt }
        } catch {
            return []
        }
    }

    func deleteDestination(id: UUID) {
        var destinations = loadDestinations()
        destinations.removeAll { $0.id == id }
        saveDestinations(destinations)

        // If the deleted destination was selected, clear the selection
        if selectedDestinationId == id {
            selectDestination(id: nil)
        }
    }

    var selectedDestinationId: UUID? {
        guard let uuidString = userDefaults.string(forKey: Self.selectedDestinationIdKey) else {
            return nil
        }
        return UUID(uuidString: uuidString)
    }

    func selectDestination(id: UUID?) {
        if let id = id {
            userDefaults.set(id.uuidString, forKey: Self.selectedDestinationIdKey)
        } else {
            userDefaults.removeObject(forKey: Self.selectedDestinationIdKey)
        }
    }

    func loadSelectedDestination() -> StreamingDestination? {
        guard let selectedId = selectedDestinationId else { return nil }
        return loadDestinations().first { $0.id == selectedId }
    }

    // MARK: - Private

    private func saveDestinations(_ destinations: [StreamingDestination]) {
        do {
            let data = try JSONEncoder().encode(destinations)
            userDefaults.set(data, forKey: Self.destinationsKey)
        } catch {
            // Encoding should not fail for Codable types, but silently handle
        }
    }
}
