import Foundation

/// Represents the current state of a live streaming session
enum StreamingState: Equatable, Hashable {
    /// No streaming active
    case idle
    /// Attempting to connect to the RTMP server
    case connecting
    /// Connected and actively streaming
    case streaming
    /// An error occurred during streaming
    case error(String)

    /// Whether streaming is actively sending data
    var isStreaming: Bool {
        self == .streaming
    }

    /// Whether a connection attempt or active stream is in progress
    var isActive: Bool {
        switch self {
        case .connecting, .streaming:
            return true
        default:
            return false
        }
    }
}
