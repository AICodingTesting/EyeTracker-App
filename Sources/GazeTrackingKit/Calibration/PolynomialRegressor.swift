import Accelerate
import Foundation

struct PolynomialRegressor {
    let degree: Int
    let regularization: Double

    init(degree: Int = 2, regularization: Double = 1e-4) {
        self.degree = degree
        self.regularization = regularization
    }

    func designVector(from features: SIMD8<Double>) -> [Double] {
        var vector: [Double] = [1.0]
        for i in 0..<features.scalarCount {
            vector.append(features[i])
        }
        if degree >= 2 {
            for i in 0..<features.scalarCount {
                for j in i..<features.scalarCount {
                    vector.append(features[i] * features[j])
                }
            }
        }
        return vector
    }

    func fit(inputs: [SIMD8<Double>], outputs: [CGPoint]) throws -> (weightsX: [Double], weightsY: [Double], featureCount: Int) {
        let design = inputs.map(designVector)
        guard let first = design.first else {
            throw GazeError.insufficientSamples
        }
        let rows = design.count
        let cols = first.count
        var matrix = Matrix(rows: rows, columns: cols)
        for r in 0..<rows {
            for c in 0..<cols {
                matrix[r, c] = design[r][c]
            }
        }
        var targetX = outputs.map { Double($0.x) }
        var targetY = outputs.map { Double($0.y) }
        var weightsX = [Double](repeating: 0, count: cols)
        var weightsY = [Double](repeating: 0, count: cols)
        try solveRidge(matrix: matrix, target: &targetX, weights: &weightsX)
        try solveRidge(matrix: matrix, target: &targetY, weights: &weightsY)
        return (weightsX, weightsY, cols)
    }

    private func solveRidge(matrix: Matrix, target: inout [Double], weights: inout [Double]) throws {
        var ata = matrix.transpose.multiply(by: matrix)
        for i in 0..<ata.rows {
            ata[i, i] += regularization
        }
        var atb = matrix.transpose.multiply(vector: target)
        var pivot = [__CLPK_integer](repeating: 0, count: ata.rows)
        var n = __CLPK_integer(ata.rows)
        var nrhs = __CLPK_integer(1)
        var lda = n
        var ldb = n
        var info: __CLPK_integer = 0
        dgesv_(&n, &nrhs, &ata.elements, &lda, &pivot, &atb, &ldb, &info)
        guard info == 0 else {
            throw GazeError.regressionFailure
        }
        weights = atb
    }
}

struct Matrix {
    let rows: Int
    let columns: Int
    var elements: [Double]

    init(rows: Int, columns: Int) {
        self.rows = rows
        self.columns = columns
        self.elements = [Double](repeating: 0, count: rows * columns)
    }

    subscript(row: Int, column: Int) -> Double {
        get { elements[row * columns + column] }
        set { elements[row * columns + column] = newValue }
    }

    var transpose: Matrix {
        var result = Matrix(rows: columns, columns: rows)
        for r in 0..<rows {
            for c in 0..<columns {
                result[c, r] = self[r, c]
            }
        }
        return result
    }

    func multiply(by other: Matrix) -> Matrix {
        precondition(columns == other.rows)
        var result = Matrix(rows: rows, columns: other.columns)
        vDSP_mmulD(elements, 1, other.elements, 1, &result.elements, 1, vDSP_Length(rows), vDSP_Length(other.columns), vDSP_Length(columns))
        return result
    }

    func multiply(vector: [Double]) -> [Double] {
        precondition(columns == vector.count)
        var result = [Double](repeating: 0, count: rows)
        vDSP_mmulD(elements, 1, vector, 1, &result, 1, vDSP_Length(rows), 1, vDSP_Length(columns))
        return result
    }
}
