import XCTest
@testable import GazeTrackingKit

final class CalibrationTests: XCTestCase {
    func testPolynomialRegressorProducesCoefficients() throws {
        let regressor = PolynomialRegressor(degree: 1, regularization: 1e-6)
        let inputs = (0..<10).map { _ in SIMD8<Double>(repeating: 0.5) }
        let outputs = (0..<10).map { _ in CGPoint(x: 0.3, y: 0.6) }
        let result = try regressor.fit(inputs: inputs, outputs: outputs)
        XCTAssertEqual(result.featureCount, regressor.designVector(from: inputs[0]).count)
    }
}
