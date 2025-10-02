import CoreGraphics
import Foundation

#if canImport(Metal)
import CoreImage
import Metal
import MetalPerformanceShaders

public final class HeatmapRenderer: ObservableObject {
    public struct Configuration: Sendable {
        public var width: Int
        public var height: Int
        public var decay: Double
        public var blurRadius: Double

        public init(width: Int = 96, height: Int = 54, decay: Double = 0.92, blurRadius: Double = 8.0) {
            self.width = width
            self.height = height
            self.decay = decay
            self.blurRadius = blurRadius
        }
    }

    @Published public private(set) var image: CGImage?

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var texture: MTLTexture
    private var configuration: Configuration
    private let colorMap = TurboColorMap()

    public init?(device: MTLDevice? = MTLCreateSystemDefaultDevice(), configuration: Configuration = Configuration()) {
        guard let device, let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        self.device = device
        self.commandQueue = commandQueue
        self.configuration = configuration
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r32Float, width: configuration.width, height: configuration.height, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        self.texture = texture
    }

    public func reset() {
        let region = MTLRegionMake2D(0, 0, configuration.width, configuration.height)
        var zeros = [Float](repeating: 0, count: configuration.width * configuration.height)
        texture.replace(region: region, mipmapLevel: 0, withBytes: &zeros, bytesPerRow: configuration.width * MemoryLayout<Float>.size)
    }

    public func addSample(_ point: CGPoint, weight: Float = 1.0) {
        guard point.x.isFinite, point.y.isFinite else { return }
        let x = Int((point.x.clamped(to: 0...1)) * CGFloat(configuration.width - 1))
        let y = Int((point.y.clamped(to: 0...1)) * CGFloat(configuration.height - 1))
        let region = MTLRegionMake2D(x, y, 1, 1)
        var existing = Float(0)
        texture.getBytes(&existing, bytesPerRow: MemoryLayout<Float>.size, from: region, mipmapLevel: 0)
        var updated = existing * Float(configuration.decay) + weight
        texture.replace(region: region, mipmapLevel: 0, withBytes: &updated, bytesPerRow: MemoryLayout<Float>.size)
    }

    public func updateImage() {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        let gaussian = MPSImageGaussianBlur(device: device, sigma: Float(configuration.blurRadius))
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r32Float, width: configuration.width, height: configuration.height, mipmapped: false)
        descriptor.usage = [.shaderWrite, .shaderRead]
        guard let output = device.makeTexture(descriptor: descriptor) else { return }
        gaussian.encode(commandBuffer: commandBuffer, sourceTexture: texture, destinationTexture: output)
        commandBuffer.addCompletedHandler { [weak self] _ in
            self?.generateImage(from: output)
        }
        commandBuffer.commit()
    }

    public func gridValues() -> [[Float]] {
        let region = MTLRegionMake2D(0, 0, configuration.width, configuration.height)
        var data = [Float](repeating: 0, count: configuration.width * configuration.height)
        texture.getBytes(&data, bytesPerRow: configuration.width * MemoryLayout<Float>.size, from: region, mipmapLevel: 0)
        var grid: [[Float]] = []
        for y in 0..<configuration.height {
            let start = y * configuration.width
            let row = Array(data[start..<(start + configuration.width)])
            grid.append(row)
        }
        return grid
    }

    private func generateImage(from texture: MTLTexture) {
        let width = texture.width
        let height = texture.height
        let count = width * height
        var data = [Float](repeating: 0, count: count)
        let region = MTLRegionMake2D(0, 0, width, height)
        texture.getBytes(&data, bytesPerRow: width * MemoryLayout<Float>.size, from: region, mipmapLevel: 0)
        let maxValue = data.max() ?? 1
        var rgba = [UInt8](repeating: 0, count: count * 4)
        for i in 0..<count {
            let normalized = maxValue > 0 ? min(data[i] / maxValue, 1) : 0
            let color = colorMap.color(for: normalized)
            rgba[i * 4 + 0] = color.red
            rgba[i * 4 + 1] = color.green
            rgba[i * 4 + 2] = color.blue
            rgba[i * 4 + 3] = UInt8(normalized * 255)
        }
        let provider = CGDataProvider(data: Data(rgba) as CFData)!
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}
#else

public final class HeatmapRenderer: ObservableObject {
    public struct Configuration: Sendable {
        public init(width: Int = 96, height: Int = 54, decay: Double = 0.92, blurRadius: Double = 8.0) {}
    }

    @Published public private(set) var image: CGImage?

    public init?(device: Any? = nil, configuration: Configuration = Configuration()) {
        return nil
    }

    public func reset() {}
    public func addSample(_ point: CGPoint, weight: Float = 1.0) {}
    public func updateImage() {}
    public func gridValues() -> [[Float]] { [] }
}
#endif

private struct TurboColorMap {
    struct RGB { let red: UInt8; let green: UInt8; let blue: UInt8 }

    func color(for value: Float) -> RGB {
        let clamped = max(0, min(1, value))
        let r = UInt8(255 * pow(clamped, 0.5))
        let g = UInt8(255 * sin(clamped * .pi * 0.5))
        let b = UInt8(255 * (1 - clamped * 0.8))
        return RGB(red: r, green: g, blue: b)
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
