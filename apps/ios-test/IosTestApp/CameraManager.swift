import AVFoundation
import CoreImage
import SwiftUI

final class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()
    @Published private(set) var isAuthorized = false
    @Published var capturedImage: CGImage?
    @Published private(set) var zoomFactor: CGFloat = 1.0
    @Published private(set) var minZoomFactor: CGFloat = 1.0
    @Published private(set) var maxZoomFactor: CGFloat = 1.0

    private let sessionQueue = DispatchQueue(label: "com.ios-test.camera.session")
    private let dataOutputQueue = DispatchQueue(label: "com.ios-test.camera.dataOutput")
    private let lock = NSLock()
    private var latestPixelBuffer: CVPixelBuffer?

    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var videoDeviceInput: AVCaptureDeviceInput?
    private weak var captureDevice: AVCaptureDevice?

    override init() {
        super.init()
    }

    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                }
            }
        default:
            isAuthorized = false
        }
    }

    func startSession() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            sessionQueue.async { [weak self] in
                guard let self else { return }
                configureSession()
                session.startRunning()
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async { [weak self] in
                    self?.isAuthorized = granted
                }
                guard granted, let self else { return }
                sessionQueue.async { [weak self] in
                    guard let self else { return }
                    configureSession()
                    session.startRunning()
                }
            }
        default:
            isAuthorized = false
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    func captureCurrentFrame() -> CGImage? {
        lock.lock()
        let buffer = latestPixelBuffer
        lock.unlock()
        guard let buffer else { return nil }
        return createCGImage(from: buffer)
    }

    func zoomIn() {
        let next = min(zoomFactor * 1.25, maxZoomFactor)
        setZoomFactor(next)
    }

    func zoomOut() {
        let next = max(zoomFactor / 1.25, minZoomFactor)
        setZoomFactor(next)
    }

    /// Apply a relative scale to current zoom (e.g. from pinch onEnded).
    func applyZoom(scale: CGFloat) {
        let target = zoomFactor * scale
        setZoomFactor(target)
    }

    /// Set zoom to an absolute factor (e.g. from pinch onChanged: baseZoom * gestureScale).
    func applyZoomToTarget(_ factor: CGFloat) {
        setZoomFactor(factor)
    }

    private func setZoomFactor(_ factor: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self, let device = self.captureDevice else { return }
            let minZ = device.minAvailableVideoZoomFactor
            let maxZ = device.maxAvailableVideoZoomFactor
            let clamped = min(max(factor, minZ), maxZ)
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clamped
                device.unlockForConfiguration()
                DispatchQueue.main.async {
                    self.zoomFactor = clamped
                    self.minZoomFactor = device.minAvailableVideoZoomFactor
                    self.maxZoomFactor = device.maxAvailableVideoZoomFactor
                }
            } catch { }
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        captureDevice = device
        videoDeviceInput = input
        if session.canAddInput(input) {
            session.addInput(input)
        }
        DispatchQueue.main.async { [weak self] in
            self?.minZoomFactor = device.minAvailableVideoZoomFactor
            self?.maxZoomFactor = device.maxAvailableVideoZoomFactor
            self?.zoomFactor = device.videoZoomFactor
        }

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: dataOutputQueue)
        output.alwaysDiscardsLateVideoFrames = true
        videoDataOutput = output
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
    }

    private func createCGImage(from pixelBuffer: CVPixelBuffer) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            .oriented(.right) // Camera delivers landscape-right; orient upright for portrait display
        let context = CIContext(options: nil)
        return context.createCGImage(ciImage, from: ciImage.extent)
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        var copy: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            CVPixelBufferGetWidth(pixelBuffer),
            CVPixelBufferGetHeight(pixelBuffer),
            CVPixelBufferGetPixelFormatType(pixelBuffer),
            nil,
            &copy
        )
        guard status == kCVReturnSuccess, let copy else { return }
        CVPixelBufferLockBaseAddress(copy, [])
        defer { CVPixelBufferUnlockBaseAddress(copy, []) }
        if let src = CVPixelBufferGetBaseAddress(pixelBuffer),
           let dst = CVPixelBufferGetBaseAddress(copy) {
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            memcpy(dst, src, bytesPerRow * height)
        }

        lock.lock()
        latestPixelBuffer = copy
        lock.unlock()
    }
}
