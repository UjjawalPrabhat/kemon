//
//  MicController.swift
//  kemon
//
//  Owns the app's AVAudioEngine and captures the singer's voice. Runs the
//  PitchDetector on each frame on the realtime audio thread and reports a
//  VoiceReading back on the main actor — the audio mirror of CameraController.
//
//  It owns the engine (not just the input tap) because the microphone graph is
//  the one audio graph that exists for EVERY song source, and local playback
//  must attach its player node to this SAME engine so voice-processing echo
//  cancellation has a reference to cancel (see LocalAudioEngine). For MusicKit
//  songs the engine simply runs input-only.
//

@preconcurrency import AVFoundation

/// `nonisolated`/`@unchecked Sendable` because the tap closure runs on a
/// realtime audio thread; readings hop back to the main actor via `onReading`,
/// exactly like CameraController.
nonisolated final class MicController: NSObject, @unchecked Sendable {

    /// The shared engine. LocalAudioEngine attaches its player node here.
    let engine = AVAudioEngine()

    var onReading: (@MainActor (VoiceReading) -> Void)?

    private let detector = PitchDetector()

    /// Analysis window/hop in samples. 2048 (~46 ms @44.1k) resolves the lowest
    /// notes we search; hop 1024 gives ~50% overlap.
    private let windowSize = 2048
    private let hopSize = 1024

    /// Preallocated analysis window and how many samples currently fill it.
    /// Realtime-safe: the tap only memcpy/memmoves into this fixed buffer —
    /// never allocates or shifts a growing array. Sized in `configureAndRun`.
    private var window: [Float] = []
    private var fill = 0

    /// Recent voiced f0 values for median filtering (tap-thread only).
    private var recentF0: [Double] = []
    private let medianWindow = 5

    /// Gates: below these a frame is treated as unvoiced.
    private let rmsFloor: Double = 0.0055        // ≈ −45 dBFS
    private let confidenceFloor: Double = 0.7

    /// Emission throttle so the UI/scoring see ~30 Hz, not every hop.
    private let minEmitInterval: CFTimeInterval = 1.0 / 30.0
    private var lastEmit: CFTimeInterval = 0

    private var isRunning = false

    private var sessionConfigured = false

    /// Whether to enable the voice-processing (AEC) I/O unit. Useful for local
    /// songs (it subtracts the backing track from the captured voice), but its
    /// VPIO duplex unit monopolizes audio I/O and makes ApplicationMusicPlayer's
    /// connection time out ("ping did not pong"). Disabled for Apple Music, where
    /// AEC has no reference signal to cancel anyway.
    private var useVoiceProcessing = true

    /// Adds `.mixWithOthers` so an active play-and-record session doesn't
    /// interrupt ApplicationMusicPlayer's own rendering.
    private var mixWithOthers = false

    // MARK: - Lifecycle

    /// Configures the AVAudioSession for play-and-record WITHOUT starting the
    /// engine. Call this early so MusicKit sees the session before it prepares,
    /// and so LocalAudioEngine can attach its player node before the engine runs.
    ///
    /// macOS has no AVAudioSession — the audio graph runs without one — so this
    /// is a no-op there.
    func configureSession() {
        #if os(iOS)
        guard !sessionConfigured else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            var options: AVAudioSession.CategoryOptions =
                [.defaultToSpeaker, .allowBluetoothHFP, .allowBluetoothA2DP]
            if mixWithOthers { options.insert(.mixWithOthers) }
            try session.setCategory(.playAndRecord, mode: .default, options: options)
            try session.setActive(true)
            sessionConfigured = true
        } catch {
            // Session config failed — mic will no-op.
        }
        #endif
    }

    /// `VoiceSource` entry point: local-song defaults (AEC on, no mixing).
    func start() { start(voiceProcessing: true, mixWithOthers: false) }

    /// Requests mic permission if needed, configures the session (if not yet),
    /// installs the tap, and starts the engine.
    ///
    /// - Parameters:
    ///   - voiceProcessing: enable AEC (local songs). Pass `false` for Apple
    ///     Music so the VPIO unit doesn't break ApplicationMusicPlayer.
    ///   - mixWithOthers: add `.mixWithOthers` to the session (Apple Music).
    func start(voiceProcessing: Bool, mixWithOthers: Bool) {
        self.useVoiceProcessing = voiceProcessing
        self.mixWithOthers = mixWithOthers
        // AVCaptureDevice authorization for `.audio` is the one permission API
        // that exists on BOTH iOS and macOS (AVAudioApplication.recordPermission
        // is iOS-only). It gates the same microphone TCC entitlement.
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                if granted { self?.configureAndRun() }
            }
        default:
            break // denied/restricted — mic stays off; app still runs.
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    /// Pauses the shared engine for an audio-session interruption.
    func pause() {
        guard isRunning else { return }
        engine.pause()
    }

    /// Reactivates the session and restarts the engine after an interruption.
    /// (Interruptions are an iOS concept; on macOS this just restarts the engine.)
    func resume() {
        guard isRunning else { return }
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        try? engine.start()
    }

    private func configureAndRun() {
        guard !isRunning else { return }
        do {
            // Ensure the session is configured (no-ops if already done).
            configureSession()

            let input = engine.inputNode

            if window.count != windowSize { window = [Float](repeating: 0, count: windowSize) }
            fill = 0
            recentF0.removeAll(keepingCapacity: true)

            // Step 1: Prepare first so AVAudioEngine finalises the hardware
            // format BEFORE we touch voice-processing.
            engine.prepare()

            // Step 2: Enable (or disable) voice processing AFTER prepare().
            // For Apple Music the VPIO unit must stay OFF or it starves
            // ApplicationMusicPlayer of the audio route ("ping did not pong").
            if input.isVoiceProcessingEnabled != useVoiceProcessing {
                try? input.setVoiceProcessingEnabled(useVoiceProcessing)
            }

            // Step 3: Re-read the format — voice processing or Bluetooth HFP
            // may have changed the sample rate from what prepare() saw.
            let format = input.inputFormat(forBus: 0)
            guard format.sampleRate > 0 else {
                throw NSError(domain: "MicController",
                              code: -1,
                              userInfo: [NSLocalizedDescriptionKey:
                                "Invalid input format (sampleRate = 0). Check AVAudioSession category/options."])
            }

            // Step 4: Install tap and start.
            input.installTap(onBus: 0, bufferSize: UInt32(windowSize), format: format) { [weak self] buffer, _ in
                self?.process(buffer, sampleRate: format.sampleRate)
            }

            try engine.start()
            isRunning = true
        } catch {
            isRunning = false
        }
    }

    // MARK: - Frame processing (realtime audio thread)

    private func process(_ buffer: AVAudioPCMBuffer, sampleRate: Double) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let frames = Int(buffer.frameLength)
        guard frames > 0, window.count == windowSize else { return }

        let keep = windowSize - hopSize
        let stride = MemoryLayout<Float>.stride

        window.withUnsafeMutableBufferPointer { buf in
            let dst = buf.baseAddress!
            var consumed = 0
            while consumed < frames {
                let take = min(windowSize - fill, frames - consumed)
                memcpy(dst + fill, channel + consumed, take * stride)
                fill += take
                consumed += take
                guard fill == windowSize else { continue }

                let reading = analyze(dst, sampleRate: sampleRate)
                memmove(dst, dst + hopSize, keep * stride)  // slide by hop, keep overlap
                fill = keep
                emitThrottled(reading)
            }
        }
    }

    /// Runs pitch + RMS on a full window and applies the silence/confidence
    /// gates and median smoothing.
    private func analyze(_ ptr: UnsafePointer<Float>, sampleRate: Double) -> VoiceReading {
        var reading = VoiceReading.empty
        let rms = detector.rms(ptr, count: windowSize)
        reading.db = rms > 0 ? max(-80, 20 * log10(rms)) : -80

        guard rms >= rmsFloor else { return reading }

        let est = detector.detect(ptr, count: windowSize, sampleRate: sampleRate)
        reading.confidence = est.confidence
        guard let f0 = est.f0, est.confidence >= confidenceFloor else { return reading }

        let smoothed = medianFiltered(f0)
        let (note, cents) = PitchMath.nearestNoteAndCents(fromMIDI: PitchMath.midi(fromHz: smoothed))
        reading.f0 = smoothed
        reading.nearestNote = note
        reading.centsOff = cents
        reading.isVoiced = true
        return reading
    }

    /// Emits at most `minEmitInterval` apart so the UI/scoring see ~30 Hz.
    private func emitThrottled(_ reading: VoiceReading) {
        let now = CACurrentMediaTime()
        guard now - lastEmit >= minEmitInterval else { return }
        lastEmit = now
        if let onReading { Task { @MainActor in onReading(reading) } }
    }

    /// Median of the last few voiced f0 values — kills single-frame octave
    /// jumps and glitches without over-smoothing genuine pitch movement.
    private func medianFiltered(_ f0: Double) -> Double {
        recentF0.append(f0)
        if recentF0.count > medianWindow { recentF0.removeFirst() }
        return recentF0.sorted()[recentF0.count / 2]
    }
}
