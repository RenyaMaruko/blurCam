import Foundation

/// 1-Euro Filter — speed-adaptive low-pass filter for noisy input.
/// Reference: "1€ Filter" (CHI 2012, https://gery.casiez.net/1euro/)
///
/// Low speed → strong smoothing (removes jitter)
/// High speed → weak smoothing (responsive tracking)
final class OneEuroFilter {
    private let mincutoff: Double
    private let beta: Double
    private let dcutoff: Double
    private let freq: Double

    private var xPrev: Double?
    private var dxPrev: Double = 0

    init(freq: Double = 30.0, mincutoff: Double = 0.5, beta: Double = 0.007, dcutoff: Double = 1.0) {
        self.freq = freq
        self.mincutoff = mincutoff
        self.beta = beta
        self.dcutoff = dcutoff
    }

    func filter(_ x: Double) -> Double {
        let te = 1.0 / freq

        // Estimate derivative
        let dx: Double
        if let prev = xPrev {
            dx = (x - prev) / te
        } else {
            dx = 0
        }

        // Filter derivative
        let alphaD = smoothingFactor(te: te, cutoff: dcutoff)
        let dxSmoothed = alphaD * dx + (1 - alphaD) * dxPrev
        dxPrev = dxSmoothed

        // Adaptive cutoff based on speed
        let cutoff = mincutoff + beta * abs(dxSmoothed)

        // Filter signal
        let alpha = smoothingFactor(te: te, cutoff: cutoff)
        let result: Double
        if let prev = xPrev {
            result = alpha * x + (1 - alpha) * prev
        } else {
            result = x
        }
        xPrev = result
        return result
    }

    func reset() {
        xPrev = nil
        dxPrev = 0
    }

    private func smoothingFactor(te: Double, cutoff: Double) -> Double {
        let tau = 1.0 / (2 * Double.pi * cutoff)
        return 1.0 / (1.0 + tau / te)
    }
}

/// Four 1-Euro filters for smoothing a CGRect (x, y, width, height).
final class RectOneEuroFilter {
    private let xF: OneEuroFilter
    private let yF: OneEuroFilter
    private let wF: OneEuroFilter
    private let hF: OneEuroFilter

    init(freq: Double = 30.0, mincutoff: Double = 0.5, beta: Double = 0.007, dcutoff: Double = 1.0) {
        xF = OneEuroFilter(freq: freq, mincutoff: mincutoff, beta: beta, dcutoff: dcutoff)
        yF = OneEuroFilter(freq: freq, mincutoff: mincutoff, beta: beta, dcutoff: dcutoff)
        wF = OneEuroFilter(freq: freq, mincutoff: mincutoff, beta: beta, dcutoff: dcutoff)
        hF = OneEuroFilter(freq: freq, mincutoff: mincutoff, beta: beta, dcutoff: dcutoff)
    }

    func filter(_ rect: CGRect) -> CGRect {
        CGRect(
            x: xF.filter(Double(rect.origin.x)),
            y: yF.filter(Double(rect.origin.y)),
            width: max(wF.filter(Double(rect.width)), 0),
            height: max(hF.filter(Double(rect.height)), 0)
        )
    }

    func reset() {
        xF.reset(); yF.reset(); wF.reset(); hF.reset()
    }
}
