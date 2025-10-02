import Combine
import CoreGraphics
import Foundation

public final class GazeSession: ObservableObject {
    @Published public private(set) var latestSample: GazeSample?

    public let heatmap: HeatmapRenderer?
    public let trails: TrailRenderer
    public let calibration: CalibrationManager
    public var samplePublisher: AnyPublisher<GazeSample, Never> {
        sampleSubject.eraseToAnyPublisher()
    }

    private let provider: GazeProvider
    private var cancellables = Set<AnyCancellable>()
    private var outlierFilterX = RobustOutlierFilter()
    private var outlierFilterY = RobustOutlierFilter()
    private var filterX = OneEuroFilter()
    private var filterY = OneEuroFilter()
    private let sampleSubject = PassthroughSubject<GazeSample, Never>()

    public init(provider: GazeProvider = GazeProviderFactory.makeProvider(configuration: .visionLandmarks),
                heatmap: HeatmapRenderer? = HeatmapRenderer(),
                trails: TrailRenderer = TrailRenderer(),
                calibration: CalibrationManager = CalibrationManager()) {
        self.provider = provider
        self.heatmap = heatmap
        self.trails = trails
        self.calibration = calibration
        bind()
    }

    private func bind() {
        provider.samples
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            .filter { [weak self] sample in
                guard let self else { return false }
                let okX = self.outlierFilterX.evaluate(value: Double(sample.viewPoint.x))
                let okY = self.outlierFilterY.evaluate(value: Double(sample.viewPoint.y))
                return okX && okY
            }
            .map { [weak self] sample -> GazeSample in
                guard let self else { return sample }
                let filteredX = self.filterX.filter(value: Double(sample.viewPoint.x), timestamp: sample.timestamp)
                let filteredY = self.filterY.filter(value: Double(sample.viewPoint.y), timestamp: sample.timestamp)
                let point = CGPoint(x: filteredX, y: filteredY)
                return GazeSample(timestamp: sample.timestamp, viewPoint: point, screenPoint: sample.screenPoint, features: sample.features, validity: sample.validity, eyeOpenness: sample.eyeOpenness, pupilDiameter: sample.pupilDiameter)
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sample in
                guard let self else { return }
                self.latestSample = sample
                self.heatmap?.addSample(sample.viewPoint)
                self.trails.append(point: sample.viewPoint, timestamp: sample.timestamp)
                self.sampleSubject.send(sample)
            }
            .store(in: &cancellables)
    }

    public func start() {
        provider.start()
    }

    public func stop() {
        provider.stop()
        heatmap?.reset()
        trails.reset()
    }
}
