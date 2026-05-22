import CoreGraphics
import CoreImage
import CoreML
import CoreVideo
import Foundation
import UIKit
import Vision

/// Face recognition using FaceNet CoreML model.
///
/// Strategy:
/// 1. VNDetectFaceRectanglesRequest detects all faces in a frame
/// 2. Each detected face is cropped and resized to 160x160
/// 3. FaceNet model generates a 128-dimensional embedding vector
/// 4. Embeddings are compared using cosine similarity
/// 5. If similarity exceeds the threshold, the face is "registered"
final class FaceRecognitionService: FaceRecognitionServiceProtocol {

    // MARK: - Properties

    private(set) var hasRegisteredFace: Bool = false

    /// Stored 128-dim embedding vectors for all registered faces
    private var registeredEmbeddings: [[Float]] = []

    /// Cosine similarity threshold. Same person: >0.6, different person: <0.4 typically
    private let similarityThreshold: Float = 0.4

    /// CoreML model for face embedding
    private var faceNetModel: MLModel?

    /// CIContext for image processing
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - Initialization

    init() {
        loadModel()
    }

    private func loadModel() {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndNeuralEngine
            // Xcode auto-generates a class from the .mlpackage
            // The class name matches the file name: FaceNet
            let model = try FaceNet(configuration: config)
            faceNetModel = model.model
            print("[FaceRecognition] FaceNet model loaded successfully")
        } catch {
            print("[FaceRecognition] Failed to load FaceNet model: \(error)")
        }
    }

    // MARK: - FaceRecognitionServiceProtocol

    func loadRegisteredFace(from faceImageData: Data) {
        loadRegisteredFaces(from: [faceImageData])
    }

    func loadRegisteredFaces(from faceImageDataArray: [Data]) {
        registeredEmbeddings = []

        for faceImageData in faceImageDataArray {
            guard let cgImage = createCGImage(from: faceImageData) else { continue }

            // Detect face, crop, and get embedding
            if let embedding = extractEmbedding(fromFaceImage: cgImage) {
                registeredEmbeddings.append(embedding)
            }
        }

        hasRegisteredFace = !registeredEmbeddings.isEmpty
        print("[FaceRecognition] Loaded \(registeredEmbeddings.count) registered embedding(s)")
    }

    func detectAndIdentifyFaces(
        in pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation
    ) -> [DetectedFace] {
        // Step 1: Detect face rectangles
        let faceRequest = VNDetectFaceRectanglesRequest()
        faceRequest.revision = VNDetectFaceRectanglesRequestRevision3
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])

        do {
            try handler.perform([faceRequest])
        } catch {
            return []
        }

        guard let observations = faceRequest.results, !observations.isEmpty else {
            return []
        }

        guard hasRegisteredFace, !registeredEmbeddings.isEmpty, faceNetModel != nil else {
            return observations.map {
                DetectedFace(boundingBox: $0.boundingBox, isRegistered: false, confidence: $0.confidence)
            }
        }

        // Step 2: For each face, crop, embed, compare
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let imageWidth = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let imageHeight = CGFloat(CVPixelBufferGetHeight(pixelBuffer))

        return observations.map { obs in
            let isRegistered = checkMatch(observation: obs, ciImage: ciImage, width: imageWidth, height: imageHeight)
            return DetectedFace(boundingBox: obs.boundingBox, isRegistered: isRegistered, confidence: obs.confidence)
        }
    }

    // MARK: - Embedding Extraction

    /// Extracts a 128-dim embedding from a face image (full image with a face in it).
    private func extractEmbedding(fromFaceImage cgImage: CGImage) -> [Float]? {
        // Detect face in the image first
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let face = request.results?.first else { return nil }

        let ciImage = CIImage(cgImage: cgImage)
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)

        return computeEmbedding(boundingBox: face.boundingBox, ciImage: ciImage, imageWidth: w, imageHeight: h)
    }

    /// Checks if a detected face matches any registered face.
    private func checkMatch(
        observation: VNFaceObservation,
        ciImage: CIImage,
        width: CGFloat,
        height: CGFloat
    ) -> Bool {
        guard let embedding = computeEmbedding(
            boundingBox: observation.boundingBox,
            ciImage: ciImage,
            imageWidth: width,
            imageHeight: height
        ) else {
            return false
        }

        // Compare against all registered embeddings using cosine similarity
        var maxSimilarity: Float = -1
        for regEmb in registeredEmbeddings {
            let sim = cosineSimilarity(embedding, regEmb)
            if sim > maxSimilarity {
                maxSimilarity = sim
            }
        }

        let isMatch = maxSimilarity > similarityThreshold
        print("[FaceRecognition] similarity=\(String(format: "%.3f", maxSimilarity)), threshold=\(similarityThreshold), isMatch=\(isMatch)")
        return isMatch
    }

    /// Crops a face from the image, resizes to 160x160, and runs FaceNet to get embedding.
    private func computeEmbedding(
        boundingBox: CGRect,
        ciImage: CIImage,
        imageWidth: CGFloat,
        imageHeight: CGFloat
    ) -> [Float]? {
        guard let model = faceNetModel else { return nil }

        // Convert Vision normalized rect to pixel coordinates
        let faceRect = VNImageRectForNormalizedRect(boundingBox, Int(imageWidth), Int(imageHeight))

        // Expand slightly for better context
        let expandedRect = faceRect.insetBy(dx: -faceRect.width * 0.2, dy: -faceRect.height * 0.2)
            .intersection(ciImage.extent)
        guard !expandedRect.isEmpty, expandedRect.width > 10, expandedRect.height > 10 else { return nil }

        // Crop face
        let cropped = ciImage.cropped(to: expandedRect)

        // Resize to 160x160
        let scaleX = 160.0 / cropped.extent.width
        let scaleY = 160.0 / cropped.extent.height
        let resized = cropped
            .transformed(by: CGAffineTransform(translationX: -cropped.extent.origin.x, y: -cropped.extent.origin.y))
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        // Render to pixel buffer
        guard let pixelBuffer = createPixelBuffer(width: 160, height: 160) else { return nil }
        ciContext.render(resized, to: pixelBuffer)

        // Convert pixel buffer to MLMultiArray (1, 160, 160, 3) with float32, normalized to [-1, 1]
        guard let multiArray = pixelBufferToMultiArray(pixelBuffer) else { return nil }

        // Run inference
        do {
            let input = try MLDictionaryFeatureProvider(dictionary: ["face_image": multiArray])
            let output = try model.prediction(from: input)

            // Extract embedding from output (auto-generated output name from ONNX conversion)
            guard let embeddingFeature = output.featureValue(for: "var_1980"),
                  let embeddingArray = embeddingFeature.multiArrayValue else {
                return nil
            }

            // Convert MLMultiArray to [Float]
            let count = embeddingArray.count
            var embedding = [Float](repeating: 0, count: count)
            for i in 0..<count {
                embedding[i] = embeddingArray[i].floatValue
            }

            // L2 normalize
            let norm = sqrt(embedding.reduce(0) { $0 + $1 * $1 })
            if norm > 0 {
                embedding = embedding.map { $0 / norm }
            }

            return embedding
        } catch {
            print("[FaceRecognition] Inference error: \(error)")
            return nil
        }
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

    /// Converts a 160x160 BGRA pixel buffer to MLMultiArray (1, 160, 160, 3) normalized to [-1, 1]
    private func pixelBufferToMultiArray(_ pixelBuffer: CVPixelBuffer) -> MLMultiArray? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        guard let multiArray = try? MLMultiArray(shape: [1, 160, 160, 3], dataType: .float32) else {
            return nil
        }

        let pixels = baseAddress.assumingMemoryBound(to: UInt8.self)

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * 4
                // BGRA format
                let b = Float(pixels[offset]) / 127.5 - 1.0
                let g = Float(pixels[offset + 1]) / 127.5 - 1.0
                let r = Float(pixels[offset + 2]) / 127.5 - 1.0

                // NHWC format: (0, y, x, channel)
                let baseIdx = y * width * 3 + x * 3
                multiArray[baseIdx] = NSNumber(value: r)
                multiArray[baseIdx + 1] = NSNumber(value: g)
                multiArray[baseIdx + 2] = NSNumber(value: b)
            }
        }

        return multiArray
    }

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Float = 0
        var normA: Float = 0
        var normB: Float = 0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        let denom = sqrt(normA) * sqrt(normB)
        return denom > 0 ? dot / denom : 0
    }

    private func createCGImage(from data: Data) -> CGImage? {
        guard let uiImage = UIImage(data: data) else { return nil }
        return uiImage.cgImage
    }
}
