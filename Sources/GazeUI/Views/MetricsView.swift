import SwiftUI
import GazeTrackingKit

public struct MetricsView: View {
    @ObservedObject private var manager: CalibrationManager

    public init(manager: CalibrationManager) {
        self.manager = manager
    }

    public var body: some View {
        VStack(spacing: 16) {
            Text("Accuracy Metrics")
                .font(.title)
                .bold()
            if let result = manager.lastResult {
                MetricRow(title: "Median px", value: result.medianError)
                MetricRow(title: "95th px", value: result.percentile95Error)
                MetricRow(title: "RMS", value: result.rmsError)
            } else {
                Text("Run calibration to view metrics.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
    }
}

private struct MetricRow: View {
    let title: String
    let value: Double

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(String(format: "%.2f", value))
                .bold()
        }
        .padding(.vertical, 4)
    }
}
