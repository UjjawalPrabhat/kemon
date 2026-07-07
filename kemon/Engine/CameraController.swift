//
//  CameraController.swift
//  kemon
//
//  Owns the AVCaptureSession (front camera). Runs Vision face detection on each
//  frame on a background queue, hands the detected face to the EmotionAnalyzing
//  model, and reports an EmotionReading back on the main actor.
//
//  The same session feeds an AVCaptureVideoPreviewLayer (see CameraPreview.swift)
//  so the live camera view and the ML frame stream share one capture pipeline.
//

@preconcurrency import AVFoundation
import Vision
import ImageIO

/// `nonisolated` because frame processing runs on a background capture queue;
/// the project defaults types to the main actor. Results hop back to the main
/// actor via `onReading`.
nonisolated final class CameraController: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {

    /// Exposed so the SwiftUI preview layer can attach to it.
    let session = AVCaptureSession()

    /// Delivered on the MAIN actor with each new reading.
    var onReading: (@MainActor (EmotionReading) -> Void)?

    private let analyzer: EmotionAnalyzing
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "kemon.camera.session")
    private let frameQueue = DispatchQueue(label: "kemon.camera.frames", qos: .userInitiated)
    // Landmarks (not just rectangles) so we can measure a geometric smile,
    // which survives singing better than the static-image emotion model.
    private let faceRequest = VNDetectFaceLandmarksRequest()

    /// Throttle ML work to ~8 fps — plenty for expression scoring, and keeps
    /// the CPU/GPU free for playback and UI. (The preview stays at full fps.)
    private let minFrameInterval: CFTimeInterval = 1.0 / 8.0
    private var lastProcessed: CFTimeInterval = 0

    init(analyzer: EmotionAnalyzing) {
        self.analyzer = analyzer
        super.init()
    }

    // MARK: - Lifecycle

    /// Requests permission if needed, configures the session, and starts it.
    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted { self?.configureAndRun() }
            }
        default:
            break // denied/restricted — camera stays off; app still runs.
        }
    }

    func stop() {
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    private func configureAndRun() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.inputs.isEmpty {
                self.configureSession()
            }
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        // Prefer the front camera (iPhone selfie cam); on a Mac there's usually
        // no explicit `.front` device, so fall back to the default video device
        // (the built-in FaceTime camera).
        let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                             for: .video,
                                             position: .front)
            ?? AVCaptureDevice.default(for: .video)
        if let device,
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }

        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: frameQueue)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        session.commitConfiguration()
    }

    // MARK: - Frame processing (background queue)

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        let now = CACurrentMediaTime()
        guard now - lastProcessed >= minFrameInterval else { return }
        lastProcessed = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // iPhone front camera in portrait → faces are upright when read as
        // .leftMirrored. The Mac's FaceTime camera already delivers upright,
        // landscape frames, so read those as .up.
        #if os(iOS)
        let orientation: CGImagePropertyOrientation = .leftMirrored
        #else
        let orientation: CGImagePropertyOrientation = .up
        #endif

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: orientation,
                                            options: [:])
        do {
            try handler.perform([faceRequest])
        } catch {
            return
        }

        guard let face = (faceRequest.results?
            .max { $0.boundingBox.height < $1.boundingBox.height }) else {
            emit(EmotionReading(dominant: .neutral,
                                confidences: [.neutral: 1.0],
                                faceDetected: false))
            return
        }

        let smile = FaceGeometry.smileScore(from: face.landmarks)
        do {
            var reading = try analyzer.analyze(pixelBuffer: pixelBuffer,
                                               orientation: orientation,
                                               face: face)
            reading.smile = smile
            emit(reading)
        } catch {
            // Model failed (e.g. not configured yet) — report face-present neutral.
            emit(EmotionReading(dominant: .neutral,
                                confidences: [.neutral: 1.0],
                                faceDetected: true,
                                smile: smile))
        }
    }

    private func emit(_ reading: EmotionReading) {
        guard let onReading else { return }
        Task { @MainActor in onReading(reading) }
    }
}
