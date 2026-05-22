import AVFoundation
import CoreImage
import MetalKit
import SwiftUI
import UIKit
import Vision

/// A UIViewRepresentable that displays processed camera frames (with blur applied).
/// Uses MTKView for efficient GPU-accelerated rendering of CIImage frames.
struct ProcessedCameraPreviewView: UIViewRepresentable {
    /// Binding to the current processed frame
    let framePublisher: FramePublisher

    /// Detected faces for overlay rendering
    let detectedFaces: [DetectedFace]

    func makeUIView(context: Context) -> ProcessedPreviewUIView {
        let view = ProcessedPreviewUIView()
        view.backgroundColor = .black
        view.framePublisher = framePublisher
        return view
    }

    func updateUIView(_ uiView: ProcessedPreviewUIView, context: Context) {
        uiView.detectedFaces = detectedFaces
    }
}

/// Observable class that publishes processed CIImage frames.
/// Acts as a bridge between the video processing pipeline and the SwiftUI view.
@MainActor
final class FramePublisher: ObservableObject {
    @Published var currentFrame: CIImage?
    @Published var detectedFaces: [DetectedFace] = []

    /// Non-isolated setter for use from background queues
    nonisolated func updateFrame(_ frame: CIImage) {
        DispatchQueue.main.async {
            self.currentFrame = frame
        }
    }

    nonisolated func updateFaces(_ faces: [DetectedFace]) {
        DispatchQueue.main.async {
            self.detectedFaces = faces
        }
    }
}

// MARK: - DisplayLink Proxy

/// Weak proxy to avoid retain cycles with CADisplayLink.
/// CADisplayLink strongly retains its target, so this proxy
/// prevents the view from being retained forever.
private final class DisplayLinkProxy {
    weak var target: ProcessedPreviewUIView?

    init(target: ProcessedPreviewUIView) {
        self.target = target
    }

    @objc func displayLinkFired(_ displayLink: CADisplayLink) {
        guard let target else {
            displayLink.invalidate()
            return
        }
        target.handleDisplayLink()
    }
}

/// Custom UIView that uses MTKView to render processed camera frames.
/// Provides efficient GPU-accelerated display of CIImage content.
final class ProcessedPreviewUIView: UIView {

    // MARK: - Properties

    var framePublisher: FramePublisher? {
        didSet {
            setupDisplayLink()
        }
    }

    var detectedFaces: [DetectedFace] = [] {
        didSet {
            updateFaceOverlays()
        }
    }

    private var metalView: MTKView?
    private var metalDevice: MTLDevice?
    private var metalCommandQueue: MTLCommandQueue?
    private var ciContext: CIContext?
    private var currentImage: CIImage?
    private var displayLink: CADisplayLink?

    /// Overlay layer for face indicators
    private let overlayLayer = CALayer()

    /// Reusable layers for face indicators to avoid allocation per frame
    private var registeredFaceLayers: [CAShapeLayer] = []

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupMetal()
        setupOverlay()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupMetal()
        setupOverlay()
    }

    deinit {
        displayLink?.invalidate()
        displayLink = nil
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        metalView?.frame = bounds
        overlayLayer.frame = bounds
    }

    // MARK: - Setup

    private func setupMetal() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return
        }

        metalDevice = device
        metalCommandQueue = device.makeCommandQueue()
        ciContext = CIContext(mtlDevice: device, options: [
            .cacheIntermediates: false
        ])

        let mtkView = MTKView(frame: bounds, device: device)
        mtkView.delegate = self
        mtkView.framebufferOnly = false
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.preferredFramesPerSecond = 30
        mtkView.contentMode = .scaleAspectFill
        mtkView.backgroundColor = .black
        mtkView.autoResizeDrawable = true

        addSubview(mtkView)
        metalView = mtkView
    }

    private func setupOverlay() {
        overlayLayer.frame = bounds
        layer.addSublayer(overlayLayer)
    }

    private func setupDisplayLink() {
        // Invalidate any existing display link
        displayLink?.invalidate()
        displayLink = nil

        guard framePublisher != nil else { return }

        // Use a proxy to avoid retain cycle
        let proxy = DisplayLinkProxy(target: self)
        let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.displayLinkFired(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 20, maximum: 30, preferred: 30)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    /// Called by the display link proxy to update the current frame
    fileprivate func handleDisplayLink() {
        guard let publisher = framePublisher else { return }
        // Access on main thread since FramePublisher is @MainActor
        if let frame = publisher.currentFrame {
            self.currentImage = frame
        }
    }

    // MARK: - Face Overlay Constants

    /// Design token values for face indicator styling.
    /// Matches /docs/design-tokens.md: Registered Face = light white border, no excessive styling.
    private enum FaceIndicatorStyle {
        /// Border opacity: subtle enough to not distract, visible enough to confirm recognition.
        /// Between borderStrong (0.16) and a functional visibility threshold on camera feed.
        static let borderOpacity: CGFloat = 0.28
        /// Line width for the corner bracket strokes
        static let lineWidth: CGFloat = 1.5
        /// Corner radius matching DesignTokens.Radius.small (8pt)
        static let cornerRadius: CGFloat = 8
        /// Length of each corner bracket arm as a fraction of the shorter side
        static let bracketLengthRatio: CGFloat = 0.22
        /// Minimum bracket arm length in points
        static let bracketMinLength: CGFloat = 10
        /// Implicit animation duration matching DesignTokens.Motion.fast (0.12s)
        static let animationDuration: CFTimeInterval = 0.12
    }

    // MARK: - Face Overlay

    private func updateFaceOverlays() {
        CATransaction.begin()
        // Use a short implicit animation for smooth position tracking
        CATransaction.setAnimationDuration(FaceIndicatorStyle.animationDuration)

        // Remove old layers
        for faceLayer in registeredFaceLayers {
            faceLayer.removeFromSuperlayer()
        }
        registeredFaceLayers.removeAll()

        guard let metalView, let currentImage else {
            CATransaction.commit()
            return
        }

        let viewSize = metalView.bounds.size
        guard viewSize.width > 0, viewSize.height > 0 else {
            CATransaction.commit()
            return
        }

        let imageExtent = currentImage.extent
        guard imageExtent.width > 0, imageExtent.height > 0 else {
            CATransaction.commit()
            return
        }

        // Calculate the aspect-fill transform from image coordinates to view coordinates
        let imageAspect = imageExtent.width / imageExtent.height
        let viewAspect = viewSize.width / viewSize.height

        let scale: CGFloat
        let offsetX: CGFloat
        let offsetY: CGFloat

        if imageAspect > viewAspect {
            // Image is wider - fit height, crop width
            scale = viewSize.height / imageExtent.height
            offsetX = (viewSize.width - imageExtent.width * scale) / 2
            offsetY = 0
        } else {
            // Image is taller - fit width, crop height
            scale = viewSize.width / imageExtent.width
            offsetX = 0
            offsetY = (viewSize.height - imageExtent.height * scale) / 2
        }

        // Draw indicators for registered faces only
        let registeredFaces = detectedFaces.filter { $0.isRegistered }

        for face in registeredFaces {
            // Convert Vision normalized coordinates to image pixel coordinates
            let faceRect = VNImageRectForNormalizedRect(
                face.boundingBox,
                Int(imageExtent.width),
                Int(imageExtent.height)
            )

            // Convert to view coordinates (flip Y axis from Vision to UIKit)
            let viewRect = CGRect(
                x: faceRect.origin.x * scale + offsetX,
                y: viewSize.height - (faceRect.origin.y + faceRect.height) * scale - offsetY,
                width: faceRect.width * scale,
                height: faceRect.height * scale
            )

            // Create corner-bracket style indicator (like iOS camera autofocus)
            let bracketLayer = createCornerBracketLayer(for: viewRect)
            overlayLayer.addSublayer(bracketLayer)
            registeredFaceLayers.append(bracketLayer)
        }

        CATransaction.commit()
    }

    /// Creates a corner-bracket style face indicator layer.
    /// This mimics the subtle autofocus bracket UI found in Apple's Camera app,
    /// providing recognition feedback without overwhelming the camera feed.
    private func createCornerBracketLayer(for rect: CGRect) -> CAShapeLayer {
        let cr = min(FaceIndicatorStyle.cornerRadius, min(rect.width, rect.height) * 0.15)
        let armLength = max(
            FaceIndicatorStyle.bracketMinLength,
            min(rect.width, rect.height) * FaceIndicatorStyle.bracketLengthRatio
        )

        let path = UIBezierPath()

        // Top-left corner
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + armLength))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cr))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + cr, y: rect.minY),
            controlPoint: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX + armLength, y: rect.minY))

        // Top-right corner
        path.move(to: CGPoint(x: rect.maxX - armLength, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cr, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + cr),
            controlPoint: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + armLength))

        // Bottom-right corner
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - armLength))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cr))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - cr, y: rect.maxY),
            controlPoint: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - armLength, y: rect.maxY))

        // Bottom-left corner
        path.move(to: CGPoint(x: rect.minX + armLength, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + cr, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - cr),
            controlPoint: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - armLength))

        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = UIColor.white.withAlphaComponent(FaceIndicatorStyle.borderOpacity).cgColor
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineWidth = FaceIndicatorStyle.lineWidth
        shapeLayer.lineCap = .round

        return shapeLayer
    }
}

// MARK: - MTKViewDelegate

extension ProcessedPreviewUIView: MTKViewDelegate {

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // No-op
    }

    func draw(in view: MTKView) {
        guard let image = currentImage,
              let drawable = view.currentDrawable,
              let commandBuffer = metalCommandQueue?.makeCommandBuffer(),
              let ciContext else {
            return
        }

        let drawableSize = view.drawableSize
        let imageExtent = image.extent

        // Calculate aspect-fill scaling
        let scaleX = drawableSize.width / imageExtent.width
        let scaleY = drawableSize.height / imageExtent.height
        let scale = max(scaleX, scaleY)

        let scaledWidth = imageExtent.width * scale
        let scaledHeight = imageExtent.height * scale

        let offsetX = (drawableSize.width - scaledWidth) / 2
        let offsetY = (drawableSize.height - scaledHeight) / 2

        // Transform the image to fill the drawable
        let transform = CGAffineTransform(translationX: offsetX, y: offsetY)
            .scaledBy(x: scale, y: scale)

        let transformedImage = image.transformed(by: transform)

        let renderDestination = CIRenderDestination(
            width: Int(drawableSize.width),
            height: Int(drawableSize.height),
            pixelFormat: view.colorPixelFormat,
            commandBuffer: commandBuffer,
            mtlTextureProvider: { () -> MTLTexture in
                return drawable.texture
            }
        )

        do {
            try ciContext.startTask(toRender: transformedImage, to: renderDestination)
        } catch {
            // Silently fail - next frame will try again
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
