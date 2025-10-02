#if canImport(ARKit)
import ARKit
import Combine
import CoreGraphics
import Foundation

final class ARFaceTrackingProvider: NSObject, GazeProvider, ARSessionDelegate {
    private let session = ARSession()
    private let subject = PassthroughSubject<GazeSample, Never>()
    private let queue = DispatchQueue(label: "com.eyetracker.arprovider")

    override init() {
        super.init()
        session.delegate = self
    }

    var samples: AnyPublisher<GazeSample, Never> {
        subject.eraseToAnyPublisher()
    }

    func start() {
        guard ARFaceTrackingConfiguration.isSupported else {
            return
        }
        let configuration = ARFaceTrackingConfiguration()
        configuration.isWorldTrackingEnabled = false
        configuration.maximumNumberOfTrackedFaces = 1
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    func stop() {
        session.pause()
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        queue.async { [weak self] in
            anchors.compactMap { $0 as? ARFaceAnchor }.forEach { anchor in
                self?.emitSample(from: anchor)
            }
        }
    }

    private func emitSample(from anchor: ARFaceAnchor) {
        let transform = anchor.transform
        let origin = simd_make_float3(transform.columns.3)
        let lookAt = anchor.lookAtPoint
        let direction = simd_normalize(lookAt - origin)
        let projected = CGPoint(x: CGFloat(direction.x), y: CGFloat(direction.y))
        let features = SIMD8<Double>(
            Double(direction.x),
            Double(direction.y),
            Double(direction.z),
            Double(anchor.blendShapes[.eyeBlinkLeft]?.doubleValue ?? 0),
            Double(anchor.blendShapes[.eyeBlinkRight]?.doubleValue ?? 0),
            Double(anchor.leftEyeTransform.columns.3.x),
            Double(anchor.rightEyeTransform.columns.3.x),
            Double(anchor.lookAtPoint.z)
        )
        let sample = GazeSample(
            timestamp: anchor.timestamp,
            viewPoint: projected,
            screenPoint: nil,
            features: features,
            validity: .valid,
            eyeOpenness: 1.0 - Double(anchor.blendShapes[.eyeBlinkLeft]?.doubleValue ?? 0)
        )
        subject.send(sample)
    }
}
#endif
