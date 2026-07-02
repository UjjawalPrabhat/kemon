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
nonisolated final class MicController: NSObject, VoiceSource, @unchecked Sendable {

    /// The shared engine. LocalAudioEngine attaches its player node here.
    let engine = AVAudioEngine()

    var onReading: (@MainActor (VoiceReading) -> Void)?

    private let detector = PitchDetector()

    /// Analysis window/hop in samples. 2048 (~46 ms @44.1k) resolves the lowest
    /// notes we search; hop 1024 gives ~50% overlap.
    private let windowSize = 2048
    private let hopSize = 1024

    /// Sliding buffer of mono samples awaiting analysis (tap-thread only).
    private var accumulator: [Float] = []

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

    // MARK: - Lifecycle

    /// Requests mic permission if needed, configures the session for play-and-
    /// record with echo cancellation, installs the tap, and starts the engine.
    /// No-ops gracefully on denial so the rest of the app still runs.
    func start() {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            configureAndRun()
        case .undetermined:
            AVAudioApplication.requestRecordPermission { [weak self] granted in
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
    func resume() {
        guard isRunning else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        try? engine.start()
    }

    private func configureAndRun() {
        do {
            let session = AVAudioSession.sharedInstance()
            // Play-and-record so we can hear the backing track AND capture the
            // voice. .defaultToSpeaker keeps playback on the speaker (not the
            // receiver); voice-processing cancels the resulting echo.
            try session.setCategory(.playAndRecord,
                                    mode: .default,
                                    options: [.defaultToSpeaker, .allowBluetoothHFP, .allowBluetoothA2DP])
            try session.setActive(true)

            let input = engine.inputNode
            // Apple's on-device acoustic echo cancellation + noise suppression,
            // so speaker playback doesn't pollute the captured voice. Must be
            // set before the engine starts.
            try? input.setVoiceProcessingEnabled(true)

            // Tap the real input format — never assume 44.1k (Bluetooth forces
            // 16/24 kHz). Analysis uses this rate for the lag→Hz conversion.
            let format = input.inputFormat(forBus: 0)
            accumulator.removeAll(keepingCapacity: true)
            recentF0.removeAll(keepingCapacity: true)

            input.installTap(onBus: 0, bufferSize: UInt32(windowSize), format: format) { [weak self] buffer, _ in
                self?.process(buffer, sampleRate: format.sampleRate)
            }

            engine.prepare()
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
        guard frames > 0 else { return }

        accumulator.append(contentsOf: UnsafeBufferPointer(start: channel, count: frames))

        // Analyse in fixed windows, sliding by hop, so pitch stays stable
        // regardless of the tap's actual buffer size.
        while accumulator.count >= windowSize {
            let reading = analyzeWindow(sampleRate: sampleRate)
            accumulator.removeFirst(hopSize)

            let now = CACurrentMediaTime()
            guard now - lastEmit >= minEmitInterval else { continue }
            lastEmit = now
            if let onReading {
                Task { @MainActor in onReading(reading) }
            }
        }

        // Bound memory if analysis somehow falls behind.
        if accumulator.count > windowSize * 4 {
            accumulator.removeFirst(accumulator.count - windowSize)
        }
    }

    /// Runs pitch + RMS on the oldest `windowSize` samples and applies the
    /// silence/confidence gates and median smoothing.
    private func analyzeWindow(sampleRate: Double) -> VoiceReading {
        var reading = VoiceReading.empty

        accumulator.withUnsafeBufferPointer { buf in
            let ptr = buf.baseAddress!
            let rms = detector.rms(ptr, count: windowSize)
            reading.rms = rms
            reading.db = rms > 0 ? max(-80, 20 * log10(rms)) : -80

            guard rms >= rmsFloor else { return } // silence → unvoiced

            let est = detector.detect(ptr, count: windowSize, sampleRate: sampleRate)
            reading.confidence = est.confidence
            guard let f0 = est.f0, est.confidence >= confidenceFloor else { return }

            let smoothed = medianFiltered(f0)
            let midi = PitchMath.midi(fromHz: smoothed)
            let (note, cents) = PitchMath.nearestNoteAndCents(fromMIDI: midi)
            reading.f0 = smoothed
            reading.midiNote = midi
            reading.nearestNote = note
            reading.centsOff = cents
            reading.isVoiced = true
        }
        return reading
    }

    /// Median of the last few voiced f0 values — kills single-frame octave
    /// jumps and glitches without over-smoothing genuine pitch movement.
    private func medianFiltered(_ f0: Double) -> Double {
        recentF0.append(f0)
        if recentF0.count > medianWindow { recentF0.removeFirst() }
        return recentF0.sorted()[recentF0.count / 2]
    }
}
