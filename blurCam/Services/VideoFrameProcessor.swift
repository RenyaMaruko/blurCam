import AVFoundation
import CoreImage
import CoreVideo
import Foundation
import UIKit
import Vision

/// Error types for video frame processor operations
enum VideoFrameProcessorError: LocalizedError {
    case cannotAddVideoOutput
    case cannotAddAudioOutput
    case processingFailed(String)

    var errorDescription: String? {
        switch self {
        case .cannotAddVideoOutput:
            return "ビデオ出力の追加に失敗しました"
        case .cannotAddAudioOutput:
            return "オーディオ出力の追加に失敗しました"
        case .processingFailed(let message):
            return "フレーム処理に失敗しました: \(message)"
        }
    }
}

/// Concrete implementation of VideoFrameProcessorProtocol.
/// Orchestrates face detection, recognition, and blur processing for each camera frame.
///
/// Architecture:
/// - Receives raw camera frames via AVCaptureVideoDataOutputSampleBufferDelegate
/// - Throttles face detection/recognition to maintain performance
/// - Applies blur processing using BlurProcessingService
/// - Outputs processed frames via callback (CIImage for display, CVPixelBuffer for recording)
final class VideoFrameProcessor: NSObject, VideoFrameProcessorProtocol {

    // MARK: - Properties

    var onFrameProcessed: ((CIImage) -> Void)?
    var onFacesDetected: (([DetectedFace]) -> Void)?
    var onProcessedPixelBuffer: ((CVPixelBuffer, CMTime) -> Void)?
    var onAudioSampleBuffer: ((CMSampleBuffer) -> Void)?

    private(set) var videoWidth: Int = 0
    private(set) var videoHeight: Int = 0

    private let faceRecognitionService: FaceRecognitionServiceProtocol
    let blurProcessingService: BlurProcessingServiceProtocol

    private let videoOutput = AVCaptureVideoDataOutput()
    private var audioOutput: AVCaptureAudioDataOutput?
    private let processingQueue = DispatchQueue(
        label: "com.blurCam.videoFrameProcessingQueue",
        qos: .userInteractive
    )
    private let audioQueue = DispatchQueue(
        label: "com.blurCam.audioProcessingQueue",
        qos: .userInteractive
    )
    private let recognitionQueue = DispatchQueue(
        label: "com.blurCam.faceRecognitionQueue",
        qos: .userInitiated
    )
    private let recognitionLock = NSLock()
    private var _isRecognitionBusy = false
    private var isRecognitionBusy: Bool {
        get { recognitionLock.withLock { _isRecognitionBusy } }
        set { recognitionLock.withLock { _isRecognitionBusy = newValue } }
    }
    private var isProcessingActive = false
    private weak var captureSession: AVCaptureSession?

    /// Throttle face detection to maintain performance.
    /// Detection runs at a lower frequency than frame rendering.
    private var lastDetectionTime: CFTimeInterval = 0
    private let detectionInterval: CFTimeInterval = 0.1 // ~10 detections per second

    /// Per-face 1-Euro filters keyed by stable track ID
    private var rectFilters: [Int: RectOneEuroFilter] = [:]
    /// Consecutive frames with no Vision detection — used to clear stale cachedFaces
    private var noDetectionFrameCount: Int = 0
    private let maxNoDetectionFrames: Int = 15  // ~0.5s at 30fps
    /// Lightweight tracker for per-frame Vision detection (separate from FaceNet's tracker)
    private let displayTracker = FaceTracker()

    /// Cache the last detection results for frames between detections
    private var cachedFaces: [DetectedFace] = []

    /// The current video orientation
    private var videoOrientation: CGImagePropertyOrientation = .right

    /// CIContext for still image processing and pixel buffer rendering
    private let ciContext: CIContext

    /// Reusable pixel buffer pool for rendering processed frames for recording
    private var renderPixelBufferPool: CVPixelBufferPool?
    private var renderPoolWidth: Int = 0
    private var renderPoolHeight: Int = 0

    // MARK: - Initialization

    init(
        faceRecognitionService: FaceRecognitionServiceProtocol = FaceRecognitionService(),
        blurProcessingService: BlurProcessingServiceProtocol = BlurProcessingService()
    ) {
        self.faceRecognitionService = faceRecognitionService
        self.blurProcessingService = blurProcessingService

        // Use Metal for GPU acceleration
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            self.ciContext = CIContext(mtlDevice: metalDevice, options: [
                .cacheIntermediates: false
            ])
        } else {
            self.ciContext = CIContext(options: [
                .useSoftwareRenderer: false,
                .cacheIntermediates: false
            ])
        }

        super.init()
    }

    // MARK: - VideoFrameProcessorProtocol

    func startProcessing(on session: AVCaptureSession) throws {
        guard !isProcessingActive else { return }

        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        // NOTE: Caller is responsible for stopping/starting the session.
        // Do NOT call stopRunning/startRunning here to avoid threading conflicts.
        session.beginConfiguration()
        guard session.canAddOutput(videoOutput) else {
            session.commitConfiguration()
            throw VideoFrameProcessorError.cannotAddVideoOutput
        }
        session.addOutput(videoOutput)

        // Set video orientation and disable mirroring for consistent face recognition
        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false
            }
        }

        session.commitConfiguration()

        captureSession = session
        isProcessingActive = true
    }

    func stopProcessing() {
        guard isProcessingActive, let session = captureSession else { return }

        session.beginConfiguration()
        session.removeOutput(videoOutput)
        session.commitConfiguration()

        isProcessingActive = false
        cachedFaces = []
        captureSession = nil
    }

    func startAudioCapture(on session: AVCaptureSession) throws {
        // Add microphone input if not already present
        let hasAudioInput = session.inputs.contains { input in
            guard let deviceInput = input as? AVCaptureDeviceInput else { return false }
            return deviceInput.device.hasMediaType(.audio)
        }

        session.beginConfiguration()

        if !hasAudioInput {
            guard let microphone = AVCaptureDevice.default(for: .audio) else {
                session.commitConfiguration()
                // No microphone available - not an error, just no audio
                return
            }

            do {
                let audioInput = try AVCaptureDeviceInput(device: microphone)
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                }
            } catch {
                session.commitConfiguration()
                // Failed to add audio input - continue without audio
                return
            }
        }

        // Add audio output
        let output = AVCaptureAudioDataOutput()
        output.setSampleBufferDelegate(self, queue: audioQueue)

        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            throw VideoFrameProcessorError.cannotAddAudioOutput
        }
        session.addOutput(output)
        audioOutput = output

        session.commitConfiguration()
    }

    func stopAudioCapture() {
        guard let session = captureSession, let output = audioOutput else { return }

        session.beginConfiguration()
        session.removeOutput(output)

        // Remove audio input
        let audioInputs = session.inputs.filter { input in
            guard let deviceInput = input as? AVCaptureDeviceInput else { return false }
            return deviceInput.device.hasMediaType(.audio)
        }
        for input in audioInputs {
            session.removeInput(input)
        }

        session.commitConfiguration()
        audioOutput = nil
    }

    /// Load registered face data into the recognition service.
    /// This allows the processor to distinguish registered faces from unknown ones.
    func loadRegisteredFace(from faceImageData: Data) {
        faceRecognitionService.loadRegisteredFace(from: faceImageData)
    }

    /// Load multiple registered face data into the recognition service.
    /// Replaces any previously loaded face data.
    func loadRegisteredFaces(from faceImageDataArray: [Data]) {
        faceRecognitionService.loadRegisteredFaces(from: faceImageDataArray)
    }

    func processStillImage(_ imageData: Data) -> Data? {
        guard let uiImage = UIImage(data: imageData),
              let cgImage = uiImage.cgImage else {
            return nil
        }

        // Detect and identify faces in the still image
        let ciImage = CIImage(cgImage: cgImage)

        // Create a pixel buffer from the CGImage for face detection
        guard let pixelBuffer = createPixelBuffer(from: cgImage) else {
            return nil
        }

        let faces = faceRecognitionService.detectAndIdentifyFaces(
            in: pixelBuffer,
            orientation: .up
        )

        // If no unregistered faces, return original data
        let hasUnregisteredFaces = faces.contains { !$0.isRegistered }
        guard hasUnregisteredFaces else {
            return imageData
        }

        // Apply blur to unregistered faces
        guard let blurredImage = blurProcessingService.applyBlur(
            to: ciImage,
            faces: faces
        ) else {
            return imageData
        }

        // Render the blurred image to JPEG data
        let outputExtent = blurredImage.extent
        guard let outputCGImage = ciContext.createCGImage(blurredImage, from: outputExtent) else {
            return imageData
        }

        let outputUIImage = UIImage(cgImage: outputCGImage, scale: uiImage.scale, orientation: uiImage.imageOrientation)
        return outputUIImage.jpegData(compressionQuality: 0.95)
    }

    // MARK: - Private Methods

    private func createPixelBuffer(from cgImage: CGImage) -> CVPixelBuffer? {
        let width = cgImage.width
        let height = cgImage.height

        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        )

        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        return buffer
    }

    /// Render a CIImage into a CVPixelBuffer for video recording.
    /// Uses a pixel buffer pool for efficient allocation.
    private func renderToPixelBuffer(_ ciImage: CIImage, width: Int, height: Int) -> CVPixelBuffer? {
        // Lazily create or recreate the pool if dimensions change
        if renderPixelBufferPool == nil || renderPoolWidth != width || renderPoolHeight != height {
            let poolAttrs: [String: Any] = [
                kCVPixelBufferPoolMinimumBufferCountKey as String: 3
            ]
            let pixelBufferAttrs: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:]
            ]

            var pool: CVPixelBufferPool?
            CVPixelBufferPoolCreate(
                kCFAllocatorDefault,
                poolAttrs as CFDictionary,
                pixelBufferAttrs as CFDictionary,
                &pool
            )
            renderPixelBufferPool = pool
            renderPoolWidth = width
            renderPoolHeight = height
        }

        guard let pool = renderPixelBufferPool else { return nil }

        var outputBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &outputBuffer)

        guard let buffer = outputBuffer else { return nil }

        ciContext.render(ciImage, to: buffer)
        return buffer
    }

    private static func computeIoU(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let inter = a.intersection(b)
        if inter.isNull { return 0 }
        let interArea = inter.width * inter.height
        let unionArea = a.width * a.height + b.width * b.height - interArea
        return unionArea > 0 ? interArea / unionArea : 0
    }

    /// Smooth a bounding box using 1-Euro filter (per track).
    private func smoothBox(trackIndex: Int, target: CGRect) -> CGRect {
        let filter = rectFilters[trackIndex] ?? {
            let f = RectOneEuroFilter(freq: 30.0, mincutoff: 0.05, beta: 10.0, dcutoff: 1.0)
            rectFilters[trackIndex] = f
            return f
        }()
        return filter.filter(target)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate & AVCaptureAudioDataOutputSampleBufferDelegate

extension VideoFrameProcessor: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Handle audio output
        if output is AVCaptureAudioDataOutput {
            onAudioSampleBuffer?(sampleBuffer)
            return
        }

        // Handle video output
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let currentTime = CACurrentMediaTime()
        let shouldDetect = currentTime - lastDetectionTime >= detectionInterval

        let imageWidth = CVPixelBufferGetWidth(pixelBuffer)
        let imageHeight = CVPixelBufferGetHeight(pixelBuffer)

        // Update video dimensions
        videoWidth = imageWidth
        videoHeight = imageHeight

        // --- Lightweight face detection every frame (Vision only, fast) ---
        // Updates face POSITIONS every frame so blur tracks movement in real-time
        let faceRequest = VNDetectFaceRectanglesRequest()
        faceRequest.revision = VNDetectFaceRectanglesRequestRevision3
        let visionHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        var currentBoxes: [CGRect] = []
        if let _ = try? visionHandler.perform([faceRequest]),
           let results = faceRequest.results, !results.isEmpty {
            currentBoxes = results.map { $0.boundingBox }
            noDetectionFrameCount = 0

            // Assign stable track IDs using IoU tracker
            let assignments = displayTracker.assign(boxes: currentBoxes)

            // Build updated faces with smoothed positions and tracked identity
            var updatedFaces: [DetectedFace] = []
            var activeTrackIDs = Set<Int>()

            for (box, trackedFace) in assignments {
                let trackID = trackedFace.trackID
                activeTrackIDs.insert(trackID)

                // Smooth the bounding box per-track to prevent jitter
                let stableBox = smoothBox(trackIndex: trackID, target: box)

                // Use TrackedFace's own isRegistered state (persists across frames via trackID).
                // This is the single source of truth, updated by displayTracker's hysteresis
                // when FaceNet recognition results arrive.
                updatedFaces.append(DetectedFace(
                    boundingBox: stableBox,
                    isRegistered: trackedFace.isRegistered,
                    confidence: Float(trackedFace.isRegistered ? 0.9 : 0.5),
                    similarity: trackedFace.averageSimilarity
                ))
            }

            cachedFaces = updatedFaces

            // Clean up filters for disappeared faces
            for key in rectFilters.keys where !activeTrackIDs.contains(key) {
                rectFilters.removeValue(forKey: key)
            }

            onFacesDetected?(cachedFaces)
        } else {
            // Vision detected 0 faces — keep cachedFaces for a grace period, then clear
            noDetectionFrameCount += 1
            if noDetectionFrameCount > maxNoDetectionFrames {
                cachedFaces = []
                onFacesDetected?(cachedFaces)
            }
        }

        // --- Heavy ArcFace recognition on separate thread (throttled) ---
        if shouldDetect && !isRecognitionBusy {
            lastDetectionTime = currentTime
            isRecognitionBusy = true

            let recognitionService = faceRecognitionService
            let tracker = displayTracker
            recognitionQueue.async { [weak self] in
                let faces = recognitionService.detectAndIdentifyFaces(
                    in: pixelBuffer,
                    orientation: .up
                )

                // Propagate ACTUAL similarity values to displayTracker's TrackedFaces.
                // Use updateSimilarities instead of assign to avoid:
                //   1. Creating new tracks from the recognition thread
                //   2. Overwriting track positions (which would break per-frame IoU matching)
                //   3. Mismatched track IDs between recognition and display
                let recognitionResults = faces.map { (box: $0.boundingBox, similarity: $0.similarity) }
                tracker.updateSimilarities(recognitionResults: recognitionResults)

                // Do NOT overwrite cachedFaces here.
                // The cachedFaces are always generated from displayTracker state
                // in the per-frame Vision detection block above.
                // This prevents FaceNet's raw (pre-hysteresis) results from
                // leaking into the rendering pipeline.

                self?.isRecognitionBusy = false
            }
        }

        // Apply blur using cached face data (never waits for recognition)
        let faces = cachedFaces
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        if faces.isEmpty || !faces.contains(where: { !$0.isRegistered }) {
            // No faces or no unregistered faces - pass through original image
            let originalImage = CIImage(cvPixelBuffer: pixelBuffer)
            onFrameProcessed?(originalImage)

            // For recording, provide the original pixel buffer
            onProcessedPixelBuffer?(pixelBuffer, presentationTime)
        } else {
            // Apply blur to unregistered faces
            if let processedImage = blurProcessingService.applyBlur(
                to: pixelBuffer,
                faces: faces,
                imageWidth: imageWidth,
                imageHeight: imageHeight
            ) {
                onFrameProcessed?(processedImage)

                // For recording, render the processed CIImage to a pixel buffer
                if onProcessedPixelBuffer != nil {
                    if let outputBuffer = renderToPixelBuffer(processedImage, width: imageWidth, height: imageHeight) {
                        onProcessedPixelBuffer?(outputBuffer, presentationTime)
                    }
                }
            } else {
                let originalImage = CIImage(cvPixelBuffer: pixelBuffer)
                onFrameProcessed?(originalImage)
                onProcessedPixelBuffer?(pixelBuffer, presentationTime)
            }
        }
    }
}
