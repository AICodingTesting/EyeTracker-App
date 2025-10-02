import Combine
import CoreGraphics
import CoreImage
import CoreMedia
import CoreVideo
import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(Vision)
import Vision
#endif

final class VisionGazeProvider: NSObject, GazeProvider {
    private let subject = PassthroughSubject<GazeSample, Never>()
    private let sessionQueue = DispatchQueue(label: "com.eyetracker.visionprovider")
    #if canImport(AVFoundation)
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    #endif

    override init() {
        super.init()
        #if canImport(AVFoundation)
        configureSession()
        #endif
    }

    var samples: AnyPublisher<GazeSample, Never> {
        subject.eraseToAnyPublisher()
    }

    func start() {
        #if canImport(AVFoundation)
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
        #endif
    }

    func stop() {
        #if canImport(AVFoundation)
        captureSession.stopRunning()
        #endif
    }

    #if canImport(AVFoundation)
    private func configureSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .vga640x480
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
           let input = try? AVCaptureDeviceInput(device: device),
           captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        captureSession.commitConfiguration()
    }
    #endif
}

#if canImport(AVFoundation) && canImport(Vision)
extension VisionGazeProvider: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let request = VNDetectFaceLandmarksRequest { [weak self] request, error in
            guard error == nil else { return }
            guard let results = request.results as? [VNFaceObservation] else { return }
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
            for observation in results {
                self?.process(observation: observation, timestamp: timestamp)
            }
        }
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .leftMirrored)
        try? handler.perform([request])
    }

    private func process(observation: VNFaceObservation, timestamp: TimeInterval) {
        guard let landmarks = observation.landmarks,
              let leftPupil = landmarks.leftPupil,
              let rightPupil = landmarks.rightPupil else { return }
        let left = centroid(of: leftPupil)
        let right = centroid(of: rightPupil)
        let features = SIMD8<Double>(
            Double(left.x),
            Double(left.y),
            Double(right.x),
            Double(right.y),
            Double(observation.boundingBox.midX),
            Double(observation.boundingBox.midY),
            Double(observation.roll?.doubleValue ?? 0),
            Double(observation.yaw?.doubleValue ?? 0)
        )
        let viewPoint = CGPoint(x: CGFloat((left.x + right.x) * 0.5), y: CGFloat((left.y + right.y) * 0.5))
        let sample = GazeSample(
            timestamp: timestamp,
            viewPoint: viewPoint,
            screenPoint: nil,
            features: features,
            validity: .limited,
            eyeOpenness: 1.0
        )
        subject.send(sample)
    }

    private func centroid(of region: VNFaceLandmarkRegion2D) -> CGPoint {
        var x: CGFloat = 0
        var y: CGFloat = 0
        for i in 0..<region.pointCount {
            let point = region.normalizedPoints[i]
            x += CGFloat(point.x)
            y += CGFloat(point.y)
        }
        let count = CGFloat(region.pointCount)
        return CGPoint(x: x / count, y: y / count)
    }
}
#endif
