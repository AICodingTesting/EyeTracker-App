import CoreGraphics
import XCTest
@testable import GazeTrackingKit

final class TrailRendererTests: XCTestCase {
    func testTrailRendererMaintainsDuration() {
        let renderer = TrailRenderer(duration: 0.5, maximumSamples: 10)
        let start = Date().timeIntervalSinceReferenceDate
        renderer.append(point: CGPoint(x: 0.5, y: 0.5), timestamp: start)
        renderer.append(point: CGPoint(x: 0.6, y: 0.6), timestamp: start + 0.1)
        let expectation = XCTestExpectation(description: "segments updated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            XCTAssertFalse(renderer.segments.isEmpty)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
}
