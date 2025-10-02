import Foundation

public final class OneEuroFilter: @unchecked Sendable {
    public var minCutoff: Double
    public var beta: Double
    public var dCutoff: Double
    private var lastTime: TimeInterval?
    private var xPrev: Double?
    private var dxPrev: Double?

    public init(minCutoff: Double = 1.0, beta: Double = 0.007, dCutoff: Double = 1.0) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.dCutoff = dCutoff
    }

    public func reset() {
        lastTime = nil
        xPrev = nil
        dxPrev = nil
    }

    public func filter(value: Double, timestamp: TimeInterval) -> Double {
        guard let lastTime else {
            lastTime = timestamp
            xPrev = value
            dxPrev = 0
            return value
        }
        let dt = max(timestamp - lastTime, 1.0 / 120.0)
        let dx = (xPrev.map { (value - $0) / dt } ?? 0)
        let alphaD = smoothingFactor(dt: dt, cutoff: dCutoff)
        let dxHat = exponentialSmoothing(alpha: alphaD, value: dx, previous: dxPrev)
        let cutoff = minCutoff + beta * abs(dxHat)
        let alpha = smoothingFactor(dt: dt, cutoff: cutoff)
        let xHat = exponentialSmoothing(alpha: alpha, value: value, previous: xPrev)
        self.lastTime = timestamp
        self.xPrev = xHat
        self.dxPrev = dxHat
        return xHat
    }

    private func smoothingFactor(dt: Double, cutoff: Double) -> Double {
        let r = 2 * Double.pi * cutoff * dt
        return r / (r + 1)
    }

    private func exponentialSmoothing(alpha: Double, value: Double, previous: Double?) -> Double {
        guard let previous else { return value }
        return alpha * value + (1 - alpha) * previous
    }
}
