import XCTest
@testable import GazeTrackingKit

final class FilterTests: XCTestCase {
    func testOneEuroFilterSmoothsNoise() {
        let filter = OneEuroFilter(minCutoff: 1.0, beta: 0.1, dCutoff: 1.0)
        var output: [Double] = []
        for i in 0..<60 {
            let timestamp = Double(i) / 60.0
            let noisy = sin(timestamp) + Double.random(in: -0.05...0.05)
            output.append(filter.filter(value: noisy, timestamp: timestamp))
        }
        XCTAssertLessThan(output.last ?? 1, 1)
    }

    func testRobustOutlierFilterRejectsSpikes() {
        var filter = RobustOutlierFilter(threshold: 2.5, windowSize: 20)
        for value in stride(from: 0.0, through: 1.0, by: 0.05) {
            XCTAssertTrue(filter.evaluate(value: value))
        }
        XCTAssertFalse(filter.evaluate(value: 100))
    }
}
