import Combine
import SwiftUI
import GazeTrackingKit

public struct CalibrationFlowView: View {
    @ObservedObject private var manager: CalibrationManager
    private let publisher: AnyPublisher<GazeSample, Never>

    @State private var currentIndex: Int = 0
    @State private var isRunning: Bool = false

    public init(manager: CalibrationManager, publisher: AnyPublisher<GazeSample, Never>) {
        self.manager = manager
        self.publisher = publisher
    }

    public var body: some View {
        VStack(spacing: 24) {
            Text("Calibration")
                .font(.largeTitle)
                .bold()
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.1))
                GeometryReader { proxy in
                    if isRunning, currentIndex < manager.points.count {
                        let point = manager.points[currentIndex].target
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 24, height: 24)
                            .position(x: proxy.size.width * point.x, y: proxy.size.height * point.y)
                            .transition(.scale)
                    }
                }
            }
            .aspectRatio(16/9, contentMode: .fit)
            ProgressView(value: manager.progress)
            HStack {
                Button("Start") {
                    isRunning = true
                    currentIndex = 0
                    manager.beginCalibration(using: publisher)
                    advance()
                }
                .disabled(isRunning)
                Button("Finish") {
                    isRunning = false
                    manager.finishCalibration()
                }
                .disabled(!isRunning)
            }
        }
        .padding()
        .onReceive(manager.$progress) { progress in
            guard isRunning else { return }
            let total = Double(manager.points.count)
            currentIndex = min(Int(progress * total), manager.points.count - 1)
        }
    }

    private func advance() {
        Task { @MainActor in
            for idx in 0..<manager.points.count {
                currentIndex = idx
                try? await Task.sleep(nanoseconds: UInt64(manager.points[idx].duration * 1_000_000_000))
            }
            manager.finishCalibration()
            isRunning = false
        }
    }
}
