import Combine
import SwiftUI
import GazeTrackingKit

public struct GazeDashboard: View {
    @StateObject private var viewModel: GazeViewModel
    private let samplePublisher: AnyPublisher<GazeSample, Never>

    public init(viewModel: GazeViewModel = GazeViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
        samplePublisher = viewModel.session.samplePublisher
    }

    public var body: some View {
        TabView {
            LiveGazeView(viewModel: viewModel)
                .tabItem { Label("Live", systemImage: "dot.radiowaves.left.and.right") }
            MiniMapView(viewModel: viewModel)
                .tabItem { Label("Mini Map", systemImage: "map") }
            CalibrationFlowView(manager: viewModel.session.calibration, publisher: samplePublisher)
                .tabItem { Label("Calibrate", systemImage: "target") }
            MetricsView(manager: viewModel.session.calibration)
                .tabItem { Label("Metrics", systemImage: "chart.bar.xaxis") }
        }
    }
}
