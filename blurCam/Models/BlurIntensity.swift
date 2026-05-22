import Foundation

/// Represents the blur intensity level that the user can configure.
/// Mapped to specific CGFloat blur radius values for BlurProcessingService.
enum BlurIntensity: Int, Codable, CaseIterable {
    /// Low blur intensity
    case low = 0
    /// Medium blur intensity (default)
    case medium = 1
    /// High blur intensity
    case high = 2

    /// Display name for the intensity level
    var displayName: String {
        switch self {
        case .low:
            return "弱"
        case .medium:
            return "中"
        case .high:
            return "強"
        }
    }

    /// The blur radius value used by BlurProcessingService
    var blurRadius: CGFloat {
        switch self {
        case .low:
            return 15.0
        case .medium:
            return 30.0
        case .high:
            return 50.0
        }
    }

    /// The default blur intensity
    static let defaultIntensity: BlurIntensity = .medium
}
