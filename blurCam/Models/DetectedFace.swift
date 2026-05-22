import CoreGraphics
import Foundation

/// Represents a face detected in a camera frame.
/// Contains the bounding box and whether it matches a registered face.
struct DetectedFace: Equatable, Identifiable {
    /// Unique identifier for this detection instance
    let id: UUID

    /// Normalized bounding box of the face in the image (Vision coordinate system: origin bottom-left)
    let boundingBox: CGRect

    /// Whether this face matches a registered face
    let isRegistered: Bool

    /// Confidence score of the face detection (0.0 - 1.0)
    let confidence: Float

    init(
        id: UUID = UUID(),
        boundingBox: CGRect,
        isRegistered: Bool,
        confidence: Float = 1.0
    ) {
        self.id = id
        self.boundingBox = boundingBox
        self.isRegistered = isRegistered
        self.confidence = confidence
    }
}
