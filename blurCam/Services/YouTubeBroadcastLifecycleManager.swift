import Foundation

/// Delegate protocol for receiving lifecycle events from the broadcast manager
protocol YouTubeBroadcastLifecycleDelegate: AnyObject {
    /// Called when the stream health status changes
    func lifecycleManager(_ manager: YouTubeBroadcastLifecycleManager, didUpdateStreamHealth health: YouTubeStreamHealthStatus)

    /// Called when the broadcast lifecycle status changes
    func lifecycleManager(_ manager: YouTubeBroadcastLifecycleManager, didUpdateBroadcastStatus status: YouTubeBroadcastLifecycleStatus)

    /// Called when a lifecycle error occurs
    func lifecycleManager(_ manager: YouTubeBroadcastLifecycleManager, didEncounterError error: Error)

    /// Called when noData persists beyond the threshold
    func lifecycleManagerDidDetectNoDataTimeout(_ manager: YouTubeBroadcastLifecycleManager)
}

/// Manages the YouTube broadcast lifecycle:
/// created -> testing -> live -> complete
/// Also monitors stream health via polling.
final class YouTubeBroadcastLifecycleManager {

    // MARK: - Properties

    weak var delegate: YouTubeBroadcastLifecycleDelegate?

    /// Current broadcast lifecycle status
    private(set) var broadcastStatus: YouTubeBroadcastLifecycleStatus = .created

    /// Current stream health status
    private(set) var streamHealth: YouTubeStreamHealthStatus = .noData

    /// Broadcast ID for API calls
    private(set) var broadcastId: String?

    /// Stream ID for health monitoring
    private(set) var streamId: String?

    /// Whether the lifecycle manager is actively monitoring
    private(set) var isMonitoring: Bool = false

    // MARK: - Dependencies

    private let apiService: YouTubeAPIServiceProtocol
    private let authService: GoogleAuthServiceProtocol

    // MARK: - Private Properties

    private var healthPollingTimer: Timer?
    private var noDataStartTime: Date?

    /// Polling interval for stream health checks (in seconds)
    private let healthPollingInterval: TimeInterval = 5.0

    /// Duration after which noData triggers a warning (in seconds)
    let noDataTimeoutThreshold: TimeInterval = 30.0

    // MARK: - Initialization

    init(
        apiService: YouTubeAPIServiceProtocol,
        authService: GoogleAuthServiceProtocol
    ) {
        self.apiService = apiService
        self.authService = authService
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Lifecycle Management

    /// Configure the manager with broadcast and stream IDs after setup
    func configure(broadcastId: String, streamId: String) {
        self.broadcastId = broadcastId
        self.streamId = streamId
        self.broadcastStatus = .created
        self.streamHealth = .noData
        self.noDataStartTime = nil
    }

    /// Start the full lifecycle: monitor stream health, then transition to testing and live
    func startLifecycle() async throws {
        guard let broadcastId = broadcastId, let _ = streamId else {
            throw YouTubeAPIError.transitionFailed("Broadcast or stream ID not configured")
        }

        isMonitoring = true
        startHealthPolling()

        // Wait for stream to become healthy before transitioning
        let accessToken = try await authService.getAccessToken()

        // Transition to testing
        do {
            let response = try await apiService.transitionBroadcast(
                broadcastId: broadcastId,
                toStatus: "testing",
                accessToken: accessToken
            )
            broadcastStatus = .testing
            delegate?.lifecycleManager(self, didUpdateBroadcastStatus: .testing)
            _ = response
        } catch {
            delegate?.lifecycleManager(self, didEncounterError: error)
            throw error
        }

        // Wait a brief moment before transitioning to live
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds

        // Transition to live
        do {
            let refreshedToken = try await authService.getAccessToken()
            let response = try await apiService.transitionBroadcast(
                broadcastId: broadcastId,
                toStatus: "live",
                accessToken: refreshedToken
            )
            broadcastStatus = .live
            delegate?.lifecycleManager(self, didUpdateBroadcastStatus: .live)
            _ = response
        } catch {
            delegate?.lifecycleManager(self, didEncounterError: error)
            throw error
        }
    }

    /// Complete the broadcast lifecycle (called when stopping streaming)
    func completeBroadcast() async {
        guard let broadcastId = broadcastId else { return }

        stopMonitoring()

        do {
            let accessToken = try await authService.getAccessToken()
            let response = try await apiService.transitionBroadcast(
                broadcastId: broadcastId,
                toStatus: "complete",
                accessToken: accessToken
            )
            broadcastStatus = .complete
            delegate?.lifecycleManager(self, didUpdateBroadcastStatus: .complete)
            _ = response
        } catch {
            delegate?.lifecycleManager(self, didEncounterError: error)
        }
    }

    /// Update the broadcast metadata (title and description)
    func updateMetadata(title: String, description: String) async throws {
        guard let broadcastId = broadcastId else {
            throw YouTubeAPIError.transitionFailed("Broadcast ID not configured")
        }

        let accessToken = try await authService.getAccessToken()
        let config = YouTubeBroadcastUpdateConfig(
            broadcastId: broadcastId,
            title: title,
            description: description
        )

        _ = try await apiService.updateBroadcastMetadata(config: config, accessToken: accessToken)
    }

    /// Upload a thumbnail for the broadcast
    func uploadThumbnail(imageData: Data, mimeType: String) async throws {
        guard let broadcastId = broadcastId else {
            throw YouTubeAPIError.thumbnailUploadFailed("Broadcast ID not configured")
        }

        let accessToken = try await authService.getAccessToken()
        try await apiService.uploadThumbnail(
            broadcastId: broadcastId,
            imageData: imageData,
            mimeType: mimeType,
            accessToken: accessToken
        )
    }

    /// Stop monitoring and clean up
    func stopMonitoring() {
        isMonitoring = false
        healthPollingTimer?.invalidate()
        healthPollingTimer = nil
        noDataStartTime = nil
    }

    /// Reset the manager for a new broadcast
    func reset() {
        stopMonitoring()
        broadcastId = nil
        streamId = nil
        broadcastStatus = .created
        streamHealth = .noData
    }

    // MARK: - Health Polling

    private func startHealthPolling() {
        healthPollingTimer?.invalidate()
        noDataStartTime = nil

        healthPollingTimer = Timer.scheduledTimer(
            withTimeInterval: healthPollingInterval,
            repeats: true
        ) { [weak self] _ in
            guard let self, self.isMonitoring else { return }
            Task { [weak self] in
                await self?.pollStreamHealth()
            }
        }
    }

    private func pollStreamHealth() async {
        guard let streamId = streamId, isMonitoring else { return }

        do {
            let accessToken = try await authService.getAccessToken()
            let health = try await apiService.getStreamHealth(streamId: streamId, accessToken: accessToken)
            let previousHealth = streamHealth
            streamHealth = health

            if health != previousHealth {
                delegate?.lifecycleManager(self, didUpdateStreamHealth: health)
            }

            // Track noData timeout
            if health == .noData {
                if noDataStartTime == nil {
                    noDataStartTime = Date()
                } else if let startTime = noDataStartTime,
                          Date().timeIntervalSince(startTime) >= noDataTimeoutThreshold {
                    delegate?.lifecycleManagerDidDetectNoDataTimeout(self)
                }
            } else {
                noDataStartTime = nil
            }
        } catch {
            // Polling errors are non-fatal; just report them
            delegate?.lifecycleManager(self, didEncounterError: error)
        }
    }
}
