import Foundation

/// Represents the camera capture mode
enum CameraMode: String, CaseIterable, Equatable {
    /// Photo capture mode
    case photo = "写真"
    /// Video recording mode
    case video = "動画"
}
