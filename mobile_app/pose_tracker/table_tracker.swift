import AVFoundation
import Vision
import CoreGraphics
import simd
import os

final class TableTracker: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: String(describing: TableTracker.self))

    var onDisplacement: ((SIMD2<Float>) -> Void)?

    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "tabletracker.session")
    private let processingQueue = DispatchQueue(label: "tabletracker.processing")

    private var isConfigured = false
    private var previousFrame: CVPixelBuffer?
    private var horizontalFieldOfViewDegrees: Float = 60

    private static let referenceHeightMeters: Float = 0.06
    private static let minContrastStddev: Float = 2.0
    private static let maxDisplacementPerFrameMeters: Float = 0.02
    private static let glitchOffsetImageFraction: Float = 0.4
    private static let axisSignX: Float = 1
    private static let axisSignY: Float = 1

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            sessionQueue.async { self.configureAndStart() }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.sessionQueue.async { self.configureAndStart() }
                }
            }
        default:
            Self.logger.error("Camera access denied")
        }
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
            self.processingQueue.sync {
                self.previousFrame = nil
            }
        }
    }

    private func configureAndStart() {
        configureIfNeeded()
        if !session.isRunning {
            session.startRunning()
        }
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            Self.logger.error("No back camera available")
            return
        }

        session.beginConfiguration()
        session.sessionPreset = .vga640x480

        guard session.canAddInput(input) else {
            session.commitConfiguration()
            Self.logger.error("Cannot add camera input")
            return
        }
        session.addInput(input)

        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)

        guard session.canAddOutput(videoOutput) else {
            session.commitConfiguration()
            Self.logger.error("Cannot add video output")
            return
        }
        session.addOutput(videoOutput)
        session.commitConfiguration()

        do {
            try device.lockForConfiguration()
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
            device.unlockForConfiguration()
        } catch {
            Self.logger.debug("Could not lock device configuration")
        }

        if let connection = videoOutput.connection(with: .video) {
            if #available(iOS 17.0, *) {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
            } else if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        }

        horizontalFieldOfViewDegrees = Float(device.activeFormat.videoFieldOfView)
        isConfigured = true
        Self.logger.info("Table tracker configured")
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let currentFrame = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        guard surfaceContrast(currentFrame) >= Self.minContrastStddev else {
            previousFrame = currentFrame
            return
        }

        guard let previous = previousFrame else {
            previousFrame = currentFrame
            return
        }
        previousFrame = currentFrame

        let request = VNTranslationalImageRegistrationRequest(targetedCVPixelBuffer: previous)
        let handler = VNImageRequestHandler(cvPixelBuffer: currentFrame, options: [:])
        do {
            try handler.perform([request])
            guard let observation = request.results?.first else { return }
            emitDisplacement(
                pixelOffsetX: Float(observation.alignmentTransform.tx),
                pixelOffsetY: Float(observation.alignmentTransform.ty),
                frame: currentFrame
            )
        } catch {
            Self.logger.debug("Image registration failed: \(error.localizedDescription)")
        }
    }

    private func emitDisplacement(pixelOffsetX: Float, pixelOffsetY: Float, frame: CVPixelBuffer) {
        let width = Float(CVPixelBufferGetWidth(frame))
        let height = Float(CVPixelBufferGetHeight(frame))
        let longestDimension = max(width, height)
        let glitchLimit = Self.glitchOffsetImageFraction * longestDimension
        guard abs(pixelOffsetX) <= glitchLimit, abs(pixelOffsetY) <= glitchLimit else { return }

        let radians = Self.horizontalFieldOfViewDegrees * Float.pi / 180 / 2
        let focalPixels = longestDimension / (2 * tan(radians))
        let metersPerPixel = Self.referenceHeightMeters / focalPixels

        let dx = min(max(pixelOffsetX * metersPerPixel * Self.axisSignX, -Self.maxDisplacementPerFrameMeters), Self.maxDisplacementPerFrameMeters)
        let dy = min(max(pixelOffsetY * metersPerPixel * Self.axisSignY, -Self.maxDisplacementPerFrameMeters), Self.maxDisplacementPerFrameMeters)

        onDisplacement?(SIMD2(dx, dy))
    }

    private func surfaceContrast(_ frame: CVPixelBuffer) -> Float {
        CVPixelBufferLockBaseAddress(frame, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(frame, .readOnly) }

        guard CVPixelBufferGetPlaneCount(frame) > 0,
              let baseAddress = CVPixelBufferGetBaseAddressOfPlane(frame, 0) else { return 0 }

        let width = CVPixelBufferGetWidthOfPlane(frame, 0)
        let height = CVPixelBufferGetHeightOfPlane(frame, 0)
        let stride = CVPixelBufferGetBytesPerRowOfPlane(frame, 0)
        let plane = baseAddress.assumingMemoryBound(to: UInt8.self)

        var total = 0
        var totalSquared = 0
        var samples = 0

        for row in stride(from: 0, to: height, by: 2) {
            let rowStart = plane + row * stride
            for column in stride(from: 0, to: width, by: 2) {
                let value = Int(rowStart[column])
                total += value
                totalSquared += value * value
                samples += 1
            }
        }

        guard samples > 0 else { return 0 }
        let mean = Float(total) / Float(samples)
        let variance = Float(totalSquared) / Float(samples) - mean * mean
        return variance > 0 ? variance.squareRoot() : 0
    }
}
