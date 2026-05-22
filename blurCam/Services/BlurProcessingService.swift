import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreVideo
import Foundation

/// Concrete implementation of BlurProcessingServiceProtocol using Core Image.
/// Applies CIGaussianBlur to face regions of unregistered faces.
///
/// Strategy:
/// 1. Create a fully blurred version of the entire image
/// 2. For each unregistered face, create an elliptical mask over the face region
/// 3. Composite: use the blurred image where the mask is white (face regions),
///    and the original image everywhere else
final class BlurProcessingService: BlurProcessingServiceProtocol {

    // MARK: - Properties

    var blurRadius: CGFloat = 30.0

    /// CIContext backed by Metal for GPU-accelerated rendering
    private let ciContext: CIContext

    init() {
        // Use Metal for GPU acceleration when available
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
    }

    /// Initializer for testing that accepts a custom CIContext
    init(ciContext: CIContext) {
        self.ciContext = ciContext
    }

    // MARK: - BlurProcessingServiceProtocol

    func applyBlur(
        to pixelBuffer: CVPixelBuffer,
        faces: [DetectedFace],
        imageWidth: Int,
        imageHeight: Int
    ) -> CIImage? {
        let originalImage = CIImage(cvPixelBuffer: pixelBuffer)
        return applyBlurToImage(originalImage, faces: faces, imageWidth: imageWidth, imageHeight: imageHeight)
    }

    func applyBlur(
        to ciImage: CIImage,
        faces: [DetectedFace]
    ) -> CIImage? {
        let imageWidth = Int(ciImage.extent.width)
        let imageHeight = Int(ciImage.extent.height)
        return applyBlurToImage(ciImage, faces: faces, imageWidth: imageWidth, imageHeight: imageHeight)
    }

    // MARK: - Private Methods

    private func applyBlurToImage(
        _ originalImage: CIImage,
        faces: [DetectedFace],
        imageWidth: Int,
        imageHeight: Int
    ) -> CIImage? {
        // Filter to only unregistered faces
        let unregisteredFaces = faces.filter { !$0.isRegistered }

        // If no unregistered faces, return the original image
        guard !unregisteredFaces.isEmpty else {
            return originalImage
        }

        // Step 1: Create a fully blurred version of the image
        guard let blurredImage = createBlurredImage(from: originalImage) else {
            return originalImage
        }

        // Step 2: Create a combined mask for all unregistered face regions
        guard let combinedMask = createCombinedFaceMask(
            faces: unregisteredFaces,
            imageWidth: imageWidth,
            imageHeight: imageHeight
        ) else {
            return originalImage
        }

        // Step 3: Composite: blurred where mask is white, original where mask is black
        let blendFilter = CIFilter.blendWithMask()
        blendFilter.inputImage = blurredImage
        blendFilter.backgroundImage = originalImage
        blendFilter.maskImage = combinedMask

        return blendFilter.outputImage?.cropped(to: originalImage.extent)
    }

    private func createBlurredImage(from image: CIImage) -> CIImage? {
        let blurFilter = CIFilter.gaussianBlur()
        blurFilter.inputImage = image
        blurFilter.radius = Float(blurRadius)

        // Clamp the image before blur to prevent edge artifacts
        let clampFilter = CIFilter.affineClamp()
        clampFilter.inputImage = image
        clampFilter.transform = CGAffineTransform.identity

        guard let clampedImage = clampFilter.outputImage else {
            return nil
        }

        blurFilter.inputImage = clampedImage

        // Crop back to original extent after blur
        return blurFilter.outputImage?.cropped(to: image.extent)
    }

    private func createCombinedFaceMask(
        faces: [DetectedFace],
        imageWidth: Int,
        imageHeight: Int
    ) -> CIImage? {
        var combinedMask: CIImage?

        for face in faces {
            // Convert Vision normalized coordinates to pixel coordinates
            let faceRect = VNImageRectForNormalizedRect(
                face.boundingBox,
                imageWidth,
                imageHeight
            )

            // Create an elliptical mask for this face with soft edges
            guard let faceMask = createEllipticalMask(for: faceRect) else {
                continue
            }

            if let existingMask = combinedMask {
                // Combine masks using maximum (additive compositing)
                let addFilter = CIFilter.maximumCompositing()
                addFilter.inputImage = faceMask
                addFilter.backgroundImage = existingMask
                combinedMask = addFilter.outputImage
            } else {
                combinedMask = faceMask
            }
        }

        return combinedMask
    }

    private func createEllipticalMask(for rect: CGRect) -> CIImage? {
        // Add a small padding to cover the full face area
        let paddedRect = rect.insetBy(
            dx: -rect.width * 0.15,
            dy: -rect.height * 0.15
        )

        // Create a radial gradient that forms an ellipse
        let center = CGPoint(x: paddedRect.midX, y: paddedRect.midY)
        let radius0 = min(paddedRect.width, paddedRect.height) * 0.35
        let radius1 = max(paddedRect.width, paddedRect.height) * 0.55

        let radialGradient = CIFilter.radialGradient()
        radialGradient.center = center
        radialGradient.radius0 = Float(radius0)
        radialGradient.radius1 = Float(radius1)
        radialGradient.color0 = CIColor.white
        radialGradient.color1 = CIColor.clear

        return radialGradient.outputImage
    }
}

// Import Vision for VNImageRectForNormalizedRect
import Vision
