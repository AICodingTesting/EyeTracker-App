import Combine
import Foundation
#if canImport(ARKit)
import ARKit
#endif
#if canImport(Vision)
import Vision
#endif

public protocol GazeProvider: AnyObject {
    var samples: AnyPublisher<GazeSample, Never> { get }
    func start()
    func stop()
}

public enum GazeProviderConfiguration: Sendable {
    case arFaceTracking
    case visionLandmarks
}

public final class GazeProviderFactory {
    public static func makeProvider(configuration: GazeProviderConfiguration) -> GazeProvider {
        switch configuration {
        case .arFaceTracking:
            #if canImport(ARKit)
            return ARFaceTrackingProvider()
            #else
            return VisionGazeProvider()
            #endif
        case .visionLandmarks:
            return VisionGazeProvider()
        }
    }
}
