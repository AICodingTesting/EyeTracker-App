import Foundation
import CoreGraphics
import QuartzCore
import simd

public struct GazeSample: Sendable, Hashable, Codable {
    public enum Validity: String, Codable {
        case valid
        case invalid
        case limited
    }

    public let timestamp: TimeInterval
    public let viewPoint: CGPoint
    public let screenPoint: CGPoint?
    public let features: SIMD8<Double>
    public let validity: Validity
    public let eyeOpenness: Double
    public let pupilDiameter: Double?

    public init(
        timestamp: TimeInterval = CACurrentMediaTime(),
        viewPoint: CGPoint,
        screenPoint: CGPoint? = nil,
        features: SIMD8<Double>,
        validity: Validity = .valid,
        eyeOpenness: Double = 1.0,
        pupilDiameter: Double? = nil
    ) {
        self.timestamp = timestamp
        self.viewPoint = viewPoint
        self.screenPoint = screenPoint
        self.features = features
        self.validity = validity
        self.eyeOpenness = eyeOpenness
        self.pupilDiameter = pupilDiameter
    }
}

public struct GazeCalibrationResult: Sendable, Codable {
    public let coefficients: [Double]
    public let regularization: Double
    public let featureDimension: Int
    public let rmsError: Double
    public let medianError: Double
    public let percentile95Error: Double

    public init(
        coefficients: [Double],
        regularization: Double,
        featureDimension: Int,
        rmsError: Double,
        medianError: Double,
        percentile95Error: Double
    ) {
        self.coefficients = coefficients
        self.regularization = regularization
        self.featureDimension = featureDimension
        self.rmsError = rmsError
        self.medianError = medianError
        self.percentile95Error = percentile95Error
    }
}

public struct CalibrationPoint: Identifiable, Hashable, Codable {
    public let id: Int
    public let target: CGPoint
    public let duration: TimeInterval

    public init(id: Int, target: CGPoint, duration: TimeInterval = 0.4) {
        self.id = id
        self.target = target
        self.duration = duration
    }
}

public struct GazeStatistics: Sendable, Codable {
    public let samples: Int
    public let medianError: Double
    public let percentile95Error: Double
    public let rms: Double
    public let angularMedian: Double
    public let angular95: Double

    public init(samples: Int, medianError: Double, percentile95Error: Double, rms: Double, angularMedian: Double, angular95: Double) {
        self.samples = samples
        self.medianError = medianError
        self.percentile95Error = percentile95Error
        self.rms = rms
        self.angularMedian = angularMedian
        self.angular95 = angular95
    }
}

public enum GazeError: Error {
    case insufficientSamples
    case regressionFailure
    case metalUnavailable
    case permissionDenied
}
