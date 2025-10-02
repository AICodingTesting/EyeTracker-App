import Combine
import CoreGraphics
import Foundation

public final class CalibrationManager: ObservableObject {
    @Published public private(set) var points: [CalibrationPoint]
    @Published public private(set) var isCalibrating: Bool = false
    @Published public private(set) var progress: Double = 0
    @Published public private(set) var lastResult: GazeCalibrationResult?

    private var cancellables = Set<AnyCancellable>()
    private var capturedSamples: [SIMD8<Double>] = []
    private var capturedTargets: [CGPoint] = []
    private let regressor = PolynomialRegressor()
    private let samplingQueue = DispatchQueue(label: "com.eyetracker.calibration")

    public init(points: [CalibrationPoint] = CalibrationManager.defaultPoints()) {
        self.points = points
    }

    public func updatePoints(count: Int) {
        points = CalibrationManager.generatePoints(count: count)
    }

    public func beginCalibration(using publisher: AnyPublisher<GazeSample, Never>) {
        guard !isCalibrating else { return }
        isCalibrating = true
        progress = 0
        capturedSamples = []
        capturedTargets = []
        let total = Double(points.count)
        var currentIndex = 0
        publisher
            .receive(on: samplingQueue)
            .prefix(points.count * 300)
            .sink { [weak self] sample in
                guard let self else { return }
                guard currentIndex < self.points.count else { return }
                let target = self.points[currentIndex]
                self.capturedSamples.append(sample.features)
                self.capturedTargets.append(target.target)
                let fraction = Double(self.capturedSamples.count) / (total * 300.0)
                DispatchQueue.main.async {
                    self.progress = min(fraction, 1.0)
                }
                if self.capturedSamples.count % 300 == 0 {
                    currentIndex += 1
                }
            }
            .store(in: &cancellables)
    }

    public func finishCalibration() {
        samplingQueue.async { [weak self] in
            guard let self else { return }
            do {
                let (wx, wy, featureCount) = try self.regressor.fit(inputs: self.capturedSamples, outputs: self.capturedTargets)
                let predictions = zip(self.capturedSamples, self.capturedTargets).map { features, target -> (CGPoint, CGPoint) in
                    let predicted = self.predict(features: features, weightsX: wx, weightsY: wy)
                    return (predicted, target)
                }
                let errors = predictions.map { hypot(Double($0.0.x - $0.1.x), Double($0.0.y - $0.1.y)) }
                let median = CalibrationManager.percentile(values: errors, q: 0.5)
                let percentile95 = CalibrationManager.percentile(values: errors, q: 0.95)
                let rms = sqrt(errors.reduce(0) { $0 + $1 * $1 } / Double(max(errors.count, 1)))
                let result = GazeCalibrationResult(
                    coefficients: wx + wy,
                    regularization: regressor.regularization,
                    featureDimension: featureCount,
                    rmsError: rms,
                    medianError: median,
                    percentile95Error: percentile95
                )
                DispatchQueue.main.async {
                    self.lastResult = result
                    self.isCalibrating = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isCalibrating = false
                }
            }
        }
    }

    public func predictPoint(for sample: GazeSample) -> CGPoint? {
        guard let result = lastResult else { return nil }
        let count = result.featureDimension
        let weightsX = Array(result.coefficients.prefix(count))
        let weightsY = Array(result.coefficients.suffix(count))
        return predict(features: sample.features, weightsX: weightsX, weightsY: weightsY)
    }

    private func predict(features: SIMD8<Double>, weightsX: [Double], weightsY: [Double]) -> CGPoint {
        let vector = regressor.designVector(from: features)
        let x = zip(vector, weightsX).reduce(0) { $0 + $1.0 * $1.1 }
        let y = zip(vector, weightsY).reduce(0) { $0 + $1.0 * $1.1 }
        return CGPoint(x: x, y: y)
    }

    public func computeStatistics(samples: [GazeSample], targets: [CGPoint]) -> GazeStatistics {
        let paired = zip(samples, targets)
        let predictions = paired.compactMap { sample, target -> (CGPoint, CGPoint)? in
            guard let predicted = predictPoint(for: sample) else { return nil }
            return (predicted, target)
        }
        let errors = predictions.map { hypot(Double($0.0.x - $0.1.x), Double($0.0.y - $0.1.y)) }
        let angularErrors = predictions.map { error -> Double in
            let distance = hypot(Double(error.1.x - 0.5), Double(error.1.y - 0.5))
            return atan2(distance, 0.6) * (180.0 / .pi)
        }
        return GazeStatistics(
            samples: predictions.count,
            medianError: CalibrationManager.percentile(values: errors, q: 0.5),
            percentile95Error: CalibrationManager.percentile(values: errors, q: 0.95),
            rms: sqrt(errors.reduce(0) { $0 + $1 * $1 } / Double(max(errors.count, 1))),
            angularMedian: CalibrationManager.percentile(values: angularErrors, q: 0.5),
            angular95: CalibrationManager.percentile(values: angularErrors, q: 0.95)
        )
    }

    public static func defaultPoints() -> [CalibrationPoint] {
        return generatePoints(count: 9)
    }

    public static func generatePoints(count: Int) -> [CalibrationPoint] {
        let templates: [[CGPoint]] = [
            [
                CGPoint(x: 0.5, y: 0.5),
                CGPoint(x: 0.1, y: 0.1),
                CGPoint(x: 0.9, y: 0.1),
                CGPoint(x: 0.1, y: 0.9),
                CGPoint(x: 0.9, y: 0.9)
            ],
            [
                CGPoint(x: 0.1, y: 0.1), CGPoint(x: 0.5, y: 0.1), CGPoint(x: 0.9, y: 0.1),
                CGPoint(x: 0.1, y: 0.5), CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.9, y: 0.5),
                CGPoint(x: 0.1, y: 0.9), CGPoint(x: 0.5, y: 0.9), CGPoint(x: 0.9, y: 0.9)
            ]
        ]
        let chosen: [CGPoint]
        switch count {
        case ..<5:
            chosen = Array(templates[0].prefix(max(count, 1)))
        case 5:
            chosen = templates[0]
        default:
            chosen = templates[1]
        }
        return chosen.enumerated().map { CalibrationPoint(id: $0.offset, target: $0.element) }
    }

    private static func percentile(values: [Double], q: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let index = min(max(Int(Double(sorted.count - 1) * q), 0), sorted.count - 1)
        return sorted[index]
    }
}
