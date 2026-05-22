import CoreGraphics
import CoreImage
import CoreML
import CoreVideo
import Foundation
import UIKit
import Vision

// MARK: - Face Tracker (IoU + Hysteresis)

/// Tracks a single face across frames with similarity history for stable decisions.
final class TrackedFace {
    let trackID: Int
    private var simHistory: [Float] = []
    private(set) var isRegistered = false
    private var missCount = 0

    /// Threshold to transition from unknown → registered (strict)
    let enterThreshold: Float
    /// Threshold to transition from registered → unknown (lenient, prevents flickering)
    let exitThreshold: Float
    let windowSize: Int

    init(trackID: Int, enter: Float = 0.75, exit: Float = 0.60, window: Int = 7) {
        self.trackID = trackID
        self.enterThreshold = enter
        self.exitThreshold = exit
        self.windowSize = window
    }

    /// Feed one frame's similarity. Returns true if face should be blurred.
    func update(similarity: Float?) -> Bool {
        missCount = 0
        let sim = similarity ?? 0  // Fail-safe: unknown → blur
        simHistory.append(sim)
        if simHistory.count > windowSize { simHistory.removeFirst() }
        let avg = simHistory.reduce(0, +) / Float(simHistory.count)

        if isRegistered {
            if avg < exitThreshold { isRegistered = false }
        } else {
            if avg >= enterThreshold { isRegistered = true }
        }
        return !isRegistered
    }

    /// Call when face disappears from frame. Returns true if track should be removed.
    func markMissed() -> Bool {
        missCount += 1
        return missCount > 10
    }
}

/// Assigns persistent track IDs to detected faces using IoU matching.
final class FaceTracker {
    private var tracked: [Int: (face: TrackedFace, lastBox: CGRect)] = [:]
    private var nextID = 0

    func assign(boxes: [CGRect]) -> [(box: CGRect, face: TrackedFace)] {
        let iouThreshold: CGFloat = 0.3
        var result: [(CGRect, TrackedFace)] = []
        var matchedIDs = Set<Int>()

        for box in boxes {
            var bestID: Int?
            var bestIoU: CGFloat = iouThreshold
            for (id, entry) in tracked where !matchedIDs.contains(id) {
                let iou = Self.iou(box, entry.lastBox)
                if iou > bestIoU { bestIoU = iou; bestID = id }
            }
            if let id = bestID {
                matchedIDs.insert(id)
                tracked[id]?.lastBox = box
                result.append((box, tracked[id]!.face))
            } else {
                let face = TrackedFace(trackID: nextID)
                tracked[nextID] = (face, box)
                matchedIDs.insert(nextID)
                result.append((box, face))
                nextID += 1
            }
        }

        // Remove tracks that have been missing too long
        for (id, entry) in tracked where !matchedIDs.contains(id) {
            if entry.face.markMissed() { tracked.removeValue(forKey: id) }
        }
        return result
    }

    func reset() {
        tracked.removeAll()
        nextID = 0
    }

    static func iou(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let inter = a.intersection(b)
        if inter.isNull { return 0 }
        let interArea = inter.width * inter.height
        let unionArea = a.width * a.height + b.width * b.height - interArea
        return unionArea > 0 ? interArea / unionArea : 0
    }
}

// MARK: - Face Recognition Service

/// Face recognition using FaceNet CoreML model with alignment, tracking, and hysteresis.
final class FaceRecognitionService: FaceRecognitionServiceProtocol {

    private(set) var hasRegisteredFace: Bool = false

    /// L2-normalized registered embeddings
    private var registeredEmbeddings: [[Float]] = []

    /// CoreML model
    private var faceNetModel: MLModel?

    /// CIContext for image processing
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    /// Face tracker for temporal smoothing
    let faceTracker = FaceTracker()

    /// Minimum face size (normalized) to attempt embedding
    private let minFaceSize: CGFloat = 0.05

    init() {
        loadModel()
    }

    private func loadModel() {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndNeuralEngine
            let model = try FaceNet(configuration: config)
            faceNetModel = model.model
            print("[FaceRecognition] FaceNet model loaded")
        } catch {
            print("[FaceRecognition] Failed to load FaceNet: \(error)")
        }
    }

    // MARK: - Protocol

    func loadRegisteredFace(from faceImageData: Data) {
        loadRegisteredFaces(from: [faceImageData])
    }

    func loadRegisteredFaces(from faceImageDataArray: [Data]) {
        registeredEmbeddings = []

        for data in faceImageDataArray {
            guard let cgImage = createCGImage(from: data) else { continue }
            if let emb = extractEmbeddingFromImage(cgImage) {
                registeredEmbeddings.append(emb)
            }
        }

        hasRegisteredFace = !registeredEmbeddings.isEmpty
        faceTracker.reset()
        print("[FaceRecognition] Loaded \(registeredEmbeddings.count) embeddings")
    }

    func detectAndIdentifyFaces(
        in pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation
    ) -> [DetectedFace] {
        // Step 1: Detect faces WITH landmarks (needed for alignment)
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return []
        }

        guard let observations = request.results, !observations.isEmpty else {
            return []
        }

        guard hasRegisteredFace, !registeredEmbeddings.isEmpty, faceNetModel != nil else {
            return observations.map {
                DetectedFace(boundingBox: $0.boundingBox, isRegistered: false, confidence: $0.confidence)
            }
        }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let imgW = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let imgH = CGFloat(CVPixelBufferGetHeight(pixelBuffer))

        // Step 2: Extract boxes for tracking
        let boxes = observations.map { $0.boundingBox }
        let assignments = faceTracker.assign(boxes: boxes)

        // Step 3: For each tracked face, compute embedding and update tracker
        var results: [DetectedFace] = []
        for (i, obs) in observations.enumerated() {
            guard i < assignments.count else { break }
            let trackedFace = assignments[i].face

            // Safety: skip tiny faces
            var similarity: Float? = nil
            if obs.boundingBox.width >= minFaceSize && obs.boundingBox.height >= minFaceSize {
                similarity = computeSimilarity(observation: obs, ciImage: ciImage, imgW: imgW, imgH: imgH)
            }

            let shouldBlur = trackedFace.update(similarity: similarity)

            results.append(DetectedFace(
                boundingBox: obs.boundingBox,
                isRegistered: !shouldBlur,
                confidence: obs.confidence
            ))

            if let sim = similarity {
                print("[FaceRecognition] track=\(trackedFace.trackID) sim=\(String(format: "%.3f", sim)) reg=\(!shouldBlur)")
            }
        }

        return results
    }

    // MARK: - Embedding

    /// Extract embedding from a full image (registration)
    private func extractEmbeddingFromImage(_ cgImage: CGImage) -> [Float]? {
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do { try handler.perform([request]) } catch { return nil }

        guard let face = request.results?.first else { return nil }

        let ciImage = CIImage(cgImage: cgImage)
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)

        return computeAlignedEmbedding(observation: face, ciImage: ciImage, imgW: w, imgH: h)
    }

    /// Compute best similarity for a detected face against all registered embeddings
    private func computeSimilarity(
        observation: VNFaceObservation,
        ciImage: CIImage,
        imgW: CGFloat,
        imgH: CGFloat
    ) -> Float? {
        guard let embedding = computeAlignedEmbedding(observation: observation, ciImage: ciImage, imgW: imgW, imgH: imgH) else {
            return nil
        }

        var best: Float = -1
        for reg in registeredEmbeddings {
            // Both are L2-normalized, so dot product == cosine similarity
            let sim = zip(embedding, reg).reduce(Float(0)) { $0 + $1.0 * $1.1 }
            best = max(best, sim)
        }
        return best
    }

    // MARK: - Alignment + FaceNet Inference

    /// Aligns face using eye landmarks, then runs FaceNet to get L2-normalized embedding
    private func computeAlignedEmbedding(
        observation: VNFaceObservation,
        ciImage: CIImage,
        imgW: CGFloat,
        imgH: CGFloat
    ) -> [Float]? {
        guard let model = faceNetModel else { return nil }

        // Try alignment with landmarks
        let alignedImage: CIImage
        if let landmarks = observation.landmarks,
           let leftEye = landmarks.leftEye,
           let rightEye = landmarks.rightEye,
           leftEye.pointCount > 0, rightEye.pointCount > 0 {
            // Aligned path
            if let aligned = alignFace(ciImage: ciImage, observation: observation,
                                        leftEye: leftEye, rightEye: rightEye,
                                        imgW: imgW, imgH: imgH) {
                alignedImage = aligned
            } else {
                // Fallback to simple crop
                guard let cropped = simpleCrop(ciImage: ciImage, boundingBox: observation.boundingBox, imgW: imgW, imgH: imgH) else { return nil }
                alignedImage = cropped
            }
        } else {
            // No landmarks, simple crop
            guard let cropped = simpleCrop(ciImage: ciImage, boundingBox: observation.boundingBox, imgW: imgW, imgH: imgH) else { return nil }
            alignedImage = cropped
        }

        // Render to pixel buffer
        guard let pixelBuffer = createPixelBuffer(width: 160, height: 160) else { return nil }
        ciContext.render(alignedImage, to: pixelBuffer)

        // Convert to MLMultiArray and run inference
        guard let multiArray = pixelBufferToMultiArray(pixelBuffer) else { return nil }

        do {
            let input = try MLDictionaryFeatureProvider(dictionary: ["face_image": multiArray])
            let output = try model.prediction(from: input)

            guard let feat = output.featureValue(for: "var_1980"),
                  let arr = feat.multiArrayValue else { return nil }

            var emb = (0..<arr.count).map { arr[$0].floatValue }

            // L2 normalize
            let norm = sqrt(emb.reduce(0) { $0 + $1 * $1 })
            guard norm > 1e-6 else { return nil }
            emb = emb.map { $0 / norm }

            return emb
        } catch {
            return nil
        }
    }

    /// Align face using eye positions: rotate to level eyes, scale to fixed inter-eye distance, crop 160x160
    private func alignFace(
        ciImage: CIImage,
        observation: VNFaceObservation,
        leftEye: VNFaceLandmarkRegion2D,
        rightEye: VNFaceLandmarkRegion2D,
        imgW: CGFloat,
        imgH: CGFloat
    ) -> CIImage? {
        let box = observation.boundingBox
        let outputSize: CGFloat = 160

        // Convert landmark centers from face-normalized to image pixel coordinates
        func eyeCenter(_ pts: VNFaceLandmarkRegion2D) -> CGPoint {
            var sx: CGFloat = 0, sy: CGFloat = 0
            for i in 0..<pts.pointCount {
                let p = pts.normalizedPoints[i]
                sx += p.x; sy += p.y
            }
            let cx = sx / CGFloat(pts.pointCount)
            let cy = sy / CGFloat(pts.pointCount)
            return CGPoint(
                x: (box.origin.x + cx * box.width) * imgW,
                y: (box.origin.y + cy * box.height) * imgH
            )
        }

        let lEye = eyeCenter(leftEye)
        let rEye = eyeCenter(rightEye)

        let dx = rEye.x - lEye.x
        let dy = rEye.y - lEye.y
        let angle = atan2(dy, dx)
        let eyeDist = hypot(dx, dy)
        guard eyeDist > 5 else { return nil }

        let mid = CGPoint(x: (lEye.x + rEye.x) / 2, y: (lEye.y + rEye.y) / 2)

        // Scale so inter-eye distance = outputSize / 2.2
        let desiredEyeDist = outputSize / 2.2
        let scale = desiredEyeDist / eyeDist

        // Place eye center at (outputSize/2, outputSize*0.4) in output
        let outCenter = CGPoint(x: outputSize / 2, y: outputSize * 0.4)

        let transform = CGAffineTransform.identity
            .translatedBy(x: outCenter.x, y: outCenter.y)
            .scaledBy(x: scale, y: scale)
            .rotated(by: -angle)
            .translatedBy(x: -mid.x, y: -mid.y)

        let aligned = ciImage.transformed(by: transform)
        let crop = CGRect(x: 0, y: 0, width: outputSize, height: outputSize)
        return aligned.cropped(to: crop)
    }

    /// Simple crop fallback (no alignment)
    private func simpleCrop(ciImage: CIImage, boundingBox: CGRect, imgW: CGFloat, imgH: CGFloat) -> CIImage? {
        let faceRect = VNImageRectForNormalizedRect(boundingBox, Int(imgW), Int(imgH))
        let expanded = faceRect.insetBy(dx: -faceRect.width * 0.2, dy: -faceRect.height * 0.2)
            .intersection(ciImage.extent)
        guard !expanded.isEmpty, expanded.width > 10, expanded.height > 10 else { return nil }

        let cropped = ciImage.cropped(to: expanded)
        let scaleX = 160.0 / cropped.extent.width
        let scaleY = 160.0 / cropped.extent.height
        return cropped
            .transformed(by: CGAffineTransform(translationX: -cropped.extent.origin.x, y: -cropped.extent.origin.y))
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
    }

    // MARK: - Helpers

    private func createPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                                         kCVPixelFormatType_32BGRA, attrs as CFDictionary, &buffer)
        return status == kCVReturnSuccess ? buffer : nil
    }

    private func pixelBufferToMultiArray(_ pixelBuffer: CVPixelBuffer) -> MLMultiArray? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        guard let multiArray = try? MLMultiArray(shape: [1, 160, 160, 3], dataType: .float32) else { return nil }

        let pixels = baseAddress.assumingMemoryBound(to: UInt8.self)

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * 4
                let b = Float(pixels[offset]) / 127.5 - 1.0
                let g = Float(pixels[offset + 1]) / 127.5 - 1.0
                let r = Float(pixels[offset + 2]) / 127.5 - 1.0

                let baseIdx = y * width * 3 + x * 3
                multiArray[baseIdx] = NSNumber(value: r)
                multiArray[baseIdx + 1] = NSNumber(value: g)
                multiArray[baseIdx + 2] = NSNumber(value: b)
            }
        }

        return multiArray
    }

    private func createCGImage(from data: Data) -> CGImage? {
        guard let uiImage = UIImage(data: data) else { return nil }
        return uiImage.cgImage
    }
}
