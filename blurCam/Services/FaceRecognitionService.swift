import CoreGraphics
import CoreImage
import CoreVideo
import Foundation
import UIKit
import Vision

/// Concrete implementation of FaceRecognitionServiceProtocol using Vision framework.
///
/// Detection strategy:
/// 1. VNDetectFaceLandmarksRequest detects faces and extracts 2D landmarks
/// 2. Normalizes landmark positions to create a face geometry signature
/// 3. Compares each detected face's geometry against all registered faces' geometries
/// 4. If geometry distance is below the threshold, the face is considered "registered"
final class FaceRecognitionService: FaceRecognitionServiceProtocol {

    // MARK: - Properties

    private(set) var hasRegisteredFace: Bool = false

    /// Stored face geometry signatures for all registered faces
    private var registeredSignatures: [[Float]] = []

    /// Geometry distance threshold for face matching.
    /// Lower = stricter matching. Tuned for normalized landmark comparison.
    private let matchingThreshold: Float = 1.25

    /// CIContext for image processing, reused for performance
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - FaceRecognitionServiceProtocol

    func loadRegisteredFace(from faceImageData: Data) {
        loadRegisteredFaces(from: [faceImageData])
    }

    func loadRegisteredFaces(from faceImageDataArray: [Data]) {
        registeredSignatures = []

        for faceImageData in faceImageDataArray {
            guard let cgImage = createCGImage(from: faceImageData) else {
                continue
            }

            if let signature = extractFaceSignature(from: cgImage) {
                registeredSignatures.append(signature)
            }
        }

        hasRegisteredFace = !registeredSignatures.isEmpty
    }

    func detectAndIdentifyFaces(
        in pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation
    ) -> [DetectedFace] {
        let landmarksRequest = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: orientation,
            options: [:]
        )

        do {
            try handler.perform([landmarksRequest])
        } catch {
            return []
        }

        guard let faceObservations = landmarksRequest.results, !faceObservations.isEmpty else {
            return []
        }

        // If we don't have any registered faces, all detected faces are unregistered
        guard hasRegisteredFace, !registeredSignatures.isEmpty else {
            return faceObservations.map { observation in
                DetectedFace(
                    boundingBox: observation.boundingBox,
                    isRegistered: false,
                    confidence: observation.confidence
                )
            }
        }

        return faceObservations.map { observation in
            let isRegistered = checkFaceMatch(observation: observation)

            return DetectedFace(
                boundingBox: observation.boundingBox,
                isRegistered: isRegistered,
                confidence: observation.confidence
            )
        }
    }

    // MARK: - Face Signature Extraction

    /// Extracts a normalized face geometry signature from a CGImage.
    private func extractFaceSignature(from cgImage: CGImage) -> [Float]? {
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let face = request.results?.first,
              let landmarks = face.landmarks else {
            return nil
        }

        return computeSignature(from: landmarks, boundingBox: face.boundingBox)
    }

    /// Checks if a detected face matches any registered face by comparing landmark geometry.
    private func checkFaceMatch(observation: VNFaceObservation) -> Bool {
        guard let landmarks = observation.landmarks else {
            return false
        }

        let candidateSignature = computeSignature(from: landmarks, boundingBox: observation.boundingBox)

        var minDistance: Float = Float.greatestFiniteMagnitude
        for registeredSig in registeredSignatures {
            let distance = euclideanDistance(candidateSignature, registeredSig)
            if distance < minDistance {
                minDistance = distance
            }
        }

        let isMatch = minDistance < matchingThreshold
        print("[FaceRecognition] distance=\(String(format: "%.4f", minDistance)), threshold=\(matchingThreshold), isMatch=\(isMatch)")
        return isMatch
    }

    /// Computes a normalized face geometry signature from 2D landmarks.
    /// The signature captures facial proportions (ratios) that are unique to each person
    /// and invariant to scale, position, and (somewhat) rotation.
    private func computeSignature(from landmarks: VNFaceLandmarks2D, boundingBox: CGRect) -> [Float] {
        var signature: [Float] = []

        // Get key landmark regions (normalized 0-1 coordinates within the face bounding box)
        var leftEye = centerPoint(of: landmarks.leftEye)
        var rightEye = centerPoint(of: landmarks.rightEye)
        let nose = centerPoint(of: landmarks.nose)
        let noseCrest = centerPoint(of: landmarks.noseCrest)
        let outerLips = centerPoint(of: landmarks.outerLips)
        let innerLips = centerPoint(of: landmarks.innerLips)
        var leftEyebrow = centerPoint(of: landmarks.leftEyebrow)
        var rightEyebrow = centerPoint(of: landmarks.rightEyebrow)
        let faceContour = landmarks.faceContour

        guard let le = leftEye, let re = rightEye, let n = nose else {
            return signature
        }

        // === Mirror-invariant normalization ===
        // Always ensure "eye1" has smaller x than "eye2" to handle front/back camera mirroring
        let eye1: CGPoint
        let eye2: CGPoint
        let eyebrow1: CGPoint?
        let eyebrow2: CGPoint?
        if le.x <= re.x {
            eye1 = le; eye2 = re
            eyebrow1 = leftEyebrow; eyebrow2 = rightEyebrow
        } else {
            eye1 = re; eye2 = le
            eyebrow1 = rightEyebrow; eyebrow2 = leftEyebrow
        }

        // Inter-eye distance as the normalization base
        let eyeDist = distance(eye1, eye2)
        guard eyeDist > 0.001 else { return signature }

        // Midpoint between eyes
        let eyeCenter = CGPoint(x: (eye1.x + eye2.x) / 2, y: (eye1.y + eye2.y) / 2)

        // === Facial Proportions (mirror-invariant, normalized by inter-eye distance) ===

        // 1. Nose position relative to eye center (use abs(x) for mirror invariance)
        signature.append(Float(abs(n.x - eyeCenter.x) / eyeDist))
        signature.append(Float((n.y - eyeCenter.y) / eyeDist))

        // 2. Mouth position relative to eye center
        if let ol = outerLips {
            signature.append(Float(abs(ol.x - eyeCenter.x) / eyeDist))
            signature.append(Float((ol.y - eyeCenter.y) / eyeDist))
        }

        // 3. Inner lips position (mouth shape)
        if let il = innerLips {
            signature.append(Float(abs(il.x - eyeCenter.x) / eyeDist))
            signature.append(Float((il.y - eyeCenter.y) / eyeDist))
        }

        // 4. Nose crest position
        if let nc = noseCrest {
            signature.append(Float(abs(nc.x - eyeCenter.x) / eyeDist))
            signature.append(Float((nc.y - eyeCenter.y) / eyeDist))
        }

        // 5. Eyebrow heights relative to eyes (sorted consistently)
        if let eb1 = eyebrow1 {
            signature.append(Float((eb1.y - eye1.y) / eyeDist))
        }
        if let eb2 = eyebrow2 {
            signature.append(Float((eb2.y - eye2.y) / eyeDist))
        }

        // 6. Eye aspect ratios (use sorted order: smaller x eye first)
        let eyeRegions: [VNFaceLandmarkRegion2D?]
        if (leftEye?.x ?? 0) <= (rightEye?.x ?? 0) {
            eyeRegions = [landmarks.leftEye, landmarks.rightEye]
        } else {
            eyeRegions = [landmarks.rightEye, landmarks.leftEye]
        }
        for eyeRegion in eyeRegions {
            if let region = eyeRegion {
                let (w, h) = regionSpan(region)
                signature.append(Float(h / max(w, 0.001)))
            }
        }

        // 7. Mouth aspect ratio (symmetric, no mirror issue)
        if let outerLipsRegion = landmarks.outerLips {
            let (w, h) = regionSpan(outerLipsRegion)
            signature.append(Float(h / max(w, 0.001)))
        }

        // 8. Nose width relative to eye distance (symmetric)
        if let noseRegion = landmarks.nose {
            let (w, _) = regionSpan(noseRegion)
            signature.append(Float(w / eyeDist))
        }

        // 9. Face contour shape ratios (symmetric measurements only)
        if let contour = faceContour, contour.pointCount >= 10 {
            let faceWidth = regionSpan(contour).0
            let faceHeight = regionSpan(contour).1
            guard faceWidth > 0.001 else { return signature }

            // Face height-to-width ratio (symmetric)
            signature.append(Float(faceHeight / faceWidth))

            // Jaw width at bottom third (symmetric)
            let quarterIdx = contour.pointCount / 4
            let threeQuarterIdx = (contour.pointCount * 3) / 4
            let jawWidth = abs(contour.normalizedPoints[quarterIdx].x - contour.normalizedPoints[threeQuarterIdx].x)
            signature.append(Float(jawWidth / faceWidth))
        }

        return signature
    }

    // MARK: - Geometry Helpers

    private func centerPoint(of region: VNFaceLandmarkRegion2D?) -> CGPoint? {
        guard let region = region, region.pointCount > 0 else { return nil }
        var sumX: CGFloat = 0
        var sumY: CGFloat = 0
        for i in 0..<region.pointCount {
            let p = region.normalizedPoints[i]
            sumX += p.x
            sumY += p.y
        }
        return CGPoint(x: sumX / CGFloat(region.pointCount), y: sumY / CGFloat(region.pointCount))
    }

    private func regionSpan(_ region: VNFaceLandmarkRegion2D) -> (width: CGFloat, height: CGFloat) {
        guard region.pointCount > 0 else { return (0, 0) }
        var minX: CGFloat = .greatestFiniteMagnitude
        var maxX: CGFloat = -.greatestFiniteMagnitude
        var minY: CGFloat = .greatestFiniteMagnitude
        var maxY: CGFloat = -.greatestFiniteMagnitude
        for i in 0..<region.pointCount {
            let p = region.normalizedPoints[i]
            minX = min(minX, p.x)
            maxX = max(maxX, p.x)
            minY = min(minY, p.y)
            maxY = max(maxY, p.y)
        }
        return (maxX - minX, maxY - minY)
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y))
    }

    private func euclideanDistance(_ a: [Float], _ b: [Float]) -> Float {
        let count = min(a.count, b.count)
        guard count > 0 else { return Float.greatestFiniteMagnitude }
        var sum: Float = 0
        for i in 0..<count {
            let diff = a[i] - b[i]
            sum += diff * diff
        }
        return sqrt(sum / Float(count))
    }

    private func createCGImage(from data: Data) -> CGImage? {
        guard let uiImage = UIImage(data: data) else {
            return nil
        }
        return uiImage.cgImage
    }
}
