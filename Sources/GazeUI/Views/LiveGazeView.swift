import SwiftUI
import GazeTrackingKit

public struct LiveGazeView: View {
    @StateObject private var viewModel: GazeViewModel

    public init(viewModel: GazeViewModel = GazeViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.gray, lineWidth: 2)
                    .background(Color.black.opacity(0.1))
                    .overlay(alignment: .topLeading) {
                        GeometryReader { proxy in
                            if let image = viewModel.heatmapImage, viewModel.displayHeatmap {
                                Image(decorative: image, scale: 1.0, orientation: .upMirrored)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: proxy.size.width, height: proxy.size.height)
                                    .clipped()
                            }
                            if viewModel.displayTrails {
                                TrailOverlay(trails: viewModel.session.trails)
                            }
                            Circle()
                                .fill(Color.red)
                                .frame(width: 12, height: 12)
                                .position(x: proxy.size.width * viewModel.latestPoint.x, y: proxy.size.height * viewModel.latestPoint.y)
                                .animation(.easeOut(duration: 0.1), value: viewModel.latestPoint)
                        }
                    }
                    .aspectRatio(16/9, contentMode: .fit)
            }
            Toggle("Heatmap", isOn: $viewModel.displayHeatmap)
            Toggle("Trails", isOn: $viewModel.displayTrails)
            Button(action: viewModel.toggleTracking) {
                Label(viewModel.isTracking ? "Stop" : "Start", systemImage: viewModel.isTracking ? "stop.fill" : "play.fill")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(viewModel.isTracking ? Color.red : Color.accentColor)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
}

struct TrailOverlay: View {
    @ObservedObject var trails: TrailRenderer

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                for segment in trails.segments {
                    var path = Path()
                    let points = segment.points
                    guard let first = points.first else { continue }
                    path.move(to: CGPoint(x: first.x * size.width, y: first.y * size.height))
                    for point in points.dropFirst() {
                        path.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height))
                    }
                    let age = timeline.date.timeIntervalSinceReferenceDate - segment.createdAt
                    let alpha = max(0, 1 - age / 3.5)
                    context.stroke(path, with: .color(Color.blue.opacity(alpha)), lineWidth: 3)
                }
            }
        }
    }
}
