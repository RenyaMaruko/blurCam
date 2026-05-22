import Foundation

/// Represents the flash mode for camera capture.
/// Cycles through: off -> auto -> on
enum FlashMode: String, CaseIterable, Equatable {
    /// Flash is always off
    case off = "off"
    /// Flash fires automatically based on ambient light
    case auto = "auto"
    /// Flash always fires
    case on = "on"

    /// The SF Symbol name for the flash mode icon
    var iconName: String {
        switch self {
        case .off:
            return "bolt.slash.fill"
        case .auto:
            return "bolt.badge.automatic.fill"
        case .on:
            return "bolt.fill"
        }
    }

    /// Accessibility label for the flash mode
    var accessibilityLabel: String {
        switch self {
        case .off:
            return "フラッシュオフ"
        case .auto:
            return "フラッシュ自動"
        case .on:
            return "フラッシュオン"
        }
    }

    /// Returns the next flash mode in the cycle: off -> auto -> on -> off
    var next: FlashMode {
        switch self {
        case .off:
            return .auto
        case .auto:
            return .on
        case .on:
            return .off
        }
    }
}
