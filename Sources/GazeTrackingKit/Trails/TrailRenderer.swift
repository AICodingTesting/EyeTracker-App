import Combine
import CoreGraphics
import Foundation

public final class TrailRenderer: ObservableObject {
    public struct Segment: Identifiable, Sendable {
        public let id = UUID()
        public let points: [CGPoint]
        public let createdAt: TimeInterval
    }

    @Published public private(set) var segments: [Segment] = []

    public var duration: TimeInterval
    public var maximumSamples: Int

    private let queue = DispatchQueue(label: "com.eyetracker.trailrenderer")

    public init(duration: TimeInterval = 3.5, maximumSamples: Int = 120) {
        self.duration = duration
        self.maximumSamples = maximumSamples
    }

    public func append(point: CGPoint, timestamp: TimeInterval) {
        queue.async { [weak self] in
            guard let self else { return }
            var segments = self.segments
            if segments.isEmpty || (timestamp - (segments.last?.createdAt ?? 0) > 0.15) {
                segments.append(Segment(points: [point], createdAt: timestamp))
            } else {
                var last = segments.removeLast()
                var points = last.points
                points.append(point)
                if points.count > self.maximumSamples {
                    points.removeFirst(points.count - self.maximumSamples)
                }
                segments.append(Segment(points: points, createdAt: last.createdAt))
            }
            let cutoff = timestamp - self.duration
            segments.removeAll { $0.createdAt < cutoff }
            DispatchQueue.main.async {
                self.segments = segments
            }
        }
    }

    public func reset() {
        DispatchQueue.main.async {
            self.segments = []
        }
    }
}
