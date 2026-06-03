import Foundation

/// Protocol for YouTube live chat polling service
protocol YouTubeLiveChatServiceProtocol: AnyObject {
    /// Whether the service is currently polling for messages
    var isPolling: Bool { get }

    /// Callback invoked on the main thread when new chat messages arrive
    var onNewMessages: (([LiveChatMessage]) -> Void)? { get set }

    /// Callback invoked when a polling error occurs (non-fatal, polling continues)
    var onError: ((Error) -> Void)? { get set }

    /// Start polling for live chat messages for the given broadcast
    func startPolling(broadcastId: String, accessToken: String) async throws

    /// Start polling with a known liveChatId directly
    func startPollingWithChatId(_ liveChatId: String, accessToken: String)

    /// Stop polling and clean up
    func stopPolling()
}

/// Service that polls YouTube Live Chat API and delivers new messages via callback.
/// Respects the API-provided pollingIntervalMillis for efficient polling.
final class YouTubeLiveChatService: YouTubeLiveChatServiceProtocol {

    // MARK: - Properties

    private(set) var isPolling: Bool = false

    var onNewMessages: (([LiveChatMessage]) -> Void)?
    var onError: ((Error) -> Void)?

    // MARK: - Dependencies

    private let apiService: YouTubeAPIServiceProtocol
    private let authService: GoogleAuthServiceProtocol

    // MARK: - Private Properties

    /// Current liveChatId being polled
    private var liveChatId: String?

    /// Page token for pagination (tracks where we left off)
    private var nextPageToken: String?

    /// Set of message IDs we've already delivered (to prevent duplicates)
    private var deliveredMessageIds: Set<String> = []

    /// The polling task
    private var pollingTask: Task<Void, Never>?

    /// Default polling interval if API doesn't provide one (in milliseconds)
    private let defaultPollingIntervalMs: Int = 5000

    /// Minimum polling interval to avoid excessive API calls (in milliseconds)
    private let minimumPollingIntervalMs: Int = 2000

    /// Current polling interval from API response (in milliseconds)
    private var currentPollingIntervalMs: Int

    // MARK: - Initialization

    init(
        apiService: YouTubeAPIServiceProtocol,
        authService: GoogleAuthServiceProtocol
    ) {
        self.apiService = apiService
        self.authService = authService
        self.currentPollingIntervalMs = defaultPollingIntervalMs
    }

    deinit {
        stopPolling()
    }

    // MARK: - Public Methods

    func startPolling(broadcastId: String, accessToken: String) async throws {
        guard !isPolling else { return }

        // First, get the liveChatId for this broadcast
        let chatId = try await apiService.getLiveChatId(
            broadcastId: broadcastId,
            accessToken: accessToken
        )

        startPollingWithChatId(chatId, accessToken: accessToken)
    }

    func startPollingWithChatId(_ liveChatId: String, accessToken: String) {
        guard !isPolling else { return }

        self.liveChatId = liveChatId
        self.nextPageToken = nil
        self.deliveredMessageIds.removeAll()
        self.isPolling = true
        self.currentPollingIntervalMs = defaultPollingIntervalMs

        pollingTask = Task { [weak self] in
            await self?.pollLoop()
        }
    }

    func stopPolling() {
        isPolling = false
        pollingTask?.cancel()
        pollingTask = nil
        liveChatId = nil
        nextPageToken = nil
        deliveredMessageIds.removeAll()
        currentPollingIntervalMs = defaultPollingIntervalMs
    }

    // MARK: - Private Methods

    private func pollLoop() async {
        while isPolling && !Task.isCancelled {
            await pollOnce()

            // Wait for the polling interval
            let intervalMs = max(currentPollingIntervalMs, minimumPollingIntervalMs)
            let intervalNs = UInt64(intervalMs) * 1_000_000
            do {
                try await Task.sleep(nanoseconds: intervalNs)
            } catch {
                // Task was cancelled
                break
            }
        }
    }

    private func pollOnce() async {
        guard let liveChatId = liveChatId, isPolling else { return }

        do {
            let accessToken = try await authService.getAccessToken()
            let response = try await apiService.fetchLiveChatMessages(
                liveChatId: liveChatId,
                pageToken: nextPageToken,
                accessToken: accessToken
            )

            // Update polling interval from API response
            if let pollingInterval = response.pollingIntervalMillis, pollingInterval > 0 {
                currentPollingIntervalMs = pollingInterval
            }

            // Update page token for next request
            if let token = response.nextPageToken {
                nextPageToken = token
            }

            // Filter for new messages only
            let newItems = (response.items ?? []).filter { item in
                !deliveredMessageIds.contains(item.id)
            }

            guard !newItems.isEmpty else { return }

            // Track delivered messages
            for item in newItems {
                deliveredMessageIds.insert(item.id)
            }

            // Convert to display models
            let messages = newItems.map { LiveChatMessage(from: $0) }

            // Deliver on main thread
            await MainActor.run { [weak self] in
                self?.onNewMessages?(messages)
            }
        } catch {
            // Report error but continue polling
            await MainActor.run { [weak self] in
                self?.onError?(error)
            }
        }
    }
}
