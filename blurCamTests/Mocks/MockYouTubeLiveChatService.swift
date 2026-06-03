import Foundation
@testable import blurCam

/// Mock implementation of YouTubeLiveChatServiceProtocol for testing
final class MockYouTubeLiveChatService: YouTubeLiveChatServiceProtocol {

    // MARK: - Configurable State

    private(set) var isPolling: Bool = false

    var onNewMessages: (([LiveChatMessage]) -> Void)?
    var onError: ((Error) -> Void)?

    // MARK: - Mock Configuration

    var startPollingError: Error?
    var startPollingChatIdToReturn: String = "mock-live-chat-id"

    // MARK: - Call Tracking

    var startPollingCallCount = 0
    var startPollingBroadcastIds: [String] = []
    var startPollingAccessTokens: [String] = []

    var startPollingWithChatIdCallCount = 0
    var startPollingWithChatIdLiveChatIds: [String] = []
    var startPollingWithChatIdAccessTokens: [String] = []

    var stopPollingCallCount = 0

    // MARK: - YouTubeLiveChatServiceProtocol

    func startPolling(broadcastId: String, accessToken: String) async throws {
        startPollingCallCount += 1
        startPollingBroadcastIds.append(broadcastId)
        startPollingAccessTokens.append(accessToken)

        if let error = startPollingError {
            throw error
        }

        isPolling = true
    }

    func startPollingWithChatId(_ liveChatId: String, accessToken: String) {
        startPollingWithChatIdCallCount += 1
        startPollingWithChatIdLiveChatIds.append(liveChatId)
        startPollingWithChatIdAccessTokens.append(accessToken)

        isPolling = true
    }

    func stopPolling() {
        stopPollingCallCount += 1
        isPolling = false
    }

    // MARK: - Test Helpers

    /// Simulate receiving new chat messages
    func simulateNewMessages(_ messages: [LiveChatMessage]) {
        onNewMessages?(messages)
    }

    /// Simulate a polling error
    func simulateError(_ error: Error) {
        onError?(error)
    }
}
