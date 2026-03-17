import AVFoundation
import CoreImage
import SwiftUI

final class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()
    @Published private(set) var isAuthorized = false
    @Published var capturedImage: CGImage?

    private let sessionQueue = DispatchQueue(label: "com.ios-test.camera.session")
    private let dataOutputQueue = DispatchQueue(label: "com.ios-test.camera.dataOutput")
    private let lock = NSLock()
    private var latestPixelBuffer: CVPixelBuffer?

    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var videoDeviceInput: AVCaptureDeviceInput?

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
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let authorized: Bool
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                DispatchQueue.main.async { [weak self] in self?.isAuthorized = true }
                authorized = true
            case .notDetermined:
                authorized = await withCheckedContinuation { cont in
                    AVCaptureDevice.requestAccess(for: .video) { granted in
                        DispatchQueue.main.async { [weak self] in
                            self?.isAuthorized = granted
                        }
                        cont.resume(returning: granted)
                    }
                }
            default:
                authorized = false
            }
            guard authorized else { return }
            configureSession()
            session.startRunning()
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

    private func configureSession() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        videoDeviceInput = input
        if session.canAddInput(input) {
            session.addInput(input)
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
