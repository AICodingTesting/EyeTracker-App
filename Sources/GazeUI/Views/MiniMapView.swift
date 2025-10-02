import SwiftUI
import GazeTrackingKit

public struct MiniMapView: View {
    @ObservedObject private var viewModel: GazeViewModel

    public init(viewModel: GazeViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 16) {
            Text("Mini Map")
                .font(.title2)
                .bold()
            if let image = viewModel.heatmapImage {
                Image(decorative: image, scale: 1.0)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.4), lineWidth: 1))
                    .shadow(radius: 4)
            } else {
                Text("Heatmap will appear once tracking starts.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
    }
}
