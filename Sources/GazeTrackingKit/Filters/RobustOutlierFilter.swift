import Foundation

public struct RobustOutlierFilter: Sendable {
    public var threshold: Double
    public var windowSize: Int
    private var values: [Double] = []

    public init(threshold: Double = 3.5, windowSize: Int = 120) {
        self.threshold = threshold
        self.windowSize = max(1, windowSize)
    }

    public mutating func evaluate(value: Double) -> Bool {
        values.append(value)
        if values.count > windowSize {
            values.removeFirst(values.count - windowSize)
        }
        guard values.count >= 5 else { return true }
        let median = percentile(values: values, q: 0.5)
        let deviations = values.map { abs($0 - median) }
        let mad = percentile(values: deviations, q: 0.5) * 1.4826
        guard mad > .ulpOfOne else { return true }
        let modifiedZ = abs(value - median) / mad
        return modifiedZ <= threshold
    }

    private func percentile(values: [Double], q: Double) -> Double {
        let sorted = values.sorted()
        let index = min(max(Int(Double(sorted.count - 1) * q), 0), sorted.count - 1)
        return sorted[index]
    }
}
