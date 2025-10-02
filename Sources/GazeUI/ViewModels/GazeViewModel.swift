import Combine
import CoreGraphics
import Foundation
import GazeTrackingKit

@MainActor
public final class GazeViewModel: ObservableObject {
    @Published public var isTracking: Bool = false
    @Published public var displayHeatmap: Bool = true
    @Published public var displayTrails: Bool = true
    @Published public var heatmapImage: CGImage?
    @Published public var latestPoint: CGPoint = .zero
    @Published public var calibrationProgress: Double = 0
    @Published public var calibrationResult: GazeCalibrationResult?

    public let session: GazeSession
    private var cancellables = Set<AnyCancellable>()
    private var heatmapTimer: AnyCancellable?

    public init(session: GazeSession = GazeSession()) {
        self.session = session
        bind()
    }

    private func bind() {
        session.$latestSample
            .compactMap { $0 }
            .sink { [weak self] sample in
                self?.latestPoint = sample.viewPoint
            }
            .store(in: &cancellables)

        if let heatmap = session.heatmap {
            heatmap.$image
                .receive(on: DispatchQueue.main)
                .sink { [weak self] image in
                    self?.heatmapImage = image
                }
                .store(in: &cancellables)
        }

        session.calibration.$progress
            .assign(to: &$calibrationProgress)

        session.calibration.$lastResult
            .assign(to: &$calibrationResult)
    }

    public func toggleTracking() {
        isTracking.toggle()
        if isTracking {
            session.start()
            heatmapTimer = Timer.publish(every: 0.2, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    self?.session.heatmap?.updateImage()
                }
        } else {
            session.stop()
            heatmapTimer?.cancel()
            heatmapTimer = nil
        }
    }

    public func beginCalibration(with publisher: AnyPublisher<GazeSample, Never>) {
        session.calibration.beginCalibration(using: publisher)
    }

    public func finishCalibration() {
        session.calibration.finishCalibration()
    }

    public func exportSamples(_ samples: [GazeSample], url: URL) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(samples)
        try data.write(to: url)
    }

    public func exportHeatmapGrid(to url: URL) throws {
        guard let heatmap = session.heatmap else {
            throw GazeError.metalUnavailable
        }
        let grid = heatmap.gridValues()
        guard !grid.isEmpty else { return }
        let csv = grid.map { row in
            row.map { String(format: "%.5f", $0) }.joined(separator: ",")
        }.joined(separator: "\n")
        try csv.data(using: .utf8)?.write(to: url)
    }
}
