//
//  KemonEngine.swift
//  kemon
//
//  The Observable coordinator from the system-design diagram. It wires the
//  audio track, the camera/ML frame stream, and the scoring matrix together,
//  driving all lyric sync and scoring off the audio clock. SwiftUI observes
//  this object directly.
//

import SwiftUI
import Observation

@MainActor
@Observable
final class KemonEngine {

    // Live state observed by the UI.
    private(set) var currentReading: EmotionReading = .empty
    private(set) var score = ScoringMatrix()
    private(set) var isPerforming = false
    private(set) var currentLyricIndex: Int?
    private(set) var elapsed: TimeInterval = 0
    private(set) var finalSummary: String?

    /// Resolved timed lyrics for the active song (from a bundled .lrc if present).
    private(set) var lyrics: [LyricLine] = []

    let camera: CameraController
    #if canImport(ARKit)
    let arFace: ARFaceController?
    #endif
    let audio = AudioController()

    /// Active analysis pipeline (A/B switch). Observed by the UI.
    private(set) var mode: AnalysisMode = .model

    /// Whether the ARKit pipeline can run on this device (TrueDepth required).
    var arKitAvailable: Bool {
        #if canImport(ARKit)
        return arFace != nil
        #else
        return false
        #endif
    }

    private var song: Song?
    private var clock: Timer?

    /// True when the real Core ML model was found and loaded; false while
    /// running on the geometry-based placeholder. Useful for a debug badge.
    let usingTrainedModel: Bool

    /// Uses the trained Core ML model if `EmotionClassifier.mlmodelc` is in the
    /// bundle, otherwise falls back to the placeholder so the app still runs.
    /// Pass an explicit analyzer to override (e.g. in tests).
    init(analyzer: EmotionAnalyzing? = nil) {
        let resolved: EmotionAnalyzing
        if let analyzer {
            resolved = analyzer
            usingTrainedModel = analyzer is CoreMLEmotionAnalyzer
        } else if let coreML = try? CoreMLEmotionAnalyzer() {
            resolved = coreML
            usingTrainedModel = true
        } else {
            resolved = PlaceholderEmotionAnalyzer()
            usingTrainedModel = false
        }
        camera = CameraController(analyzer: resolved)
        #if canImport(ARKit)
        arFace = ARFaceController.isSupported ? ARFaceController() : nil
        #endif

        // self is fully initialised past this point — safe to capture.
        camera.onReading = { [weak self] reading in
            self?.handle(reading)
        }
        #if canImport(ARKit)
        arFace?.onReading = { [weak self] reading in
            self?.handle(reading)
        }
        #endif
    }

    /// The source for the current mode (falls back to the camera).
    private var activeSource: FaceSource {
        #if canImport(ARKit)
        if mode == .arkit, let arFace { return arFace }
        #endif
        return camera
    }

    /// Switches pipeline live. If a performance is in progress the new source is
    /// started immediately; the two sources never run at once (they share the
    /// camera).
    func setMode(_ newMode: AnalysisMode) {
        guard newMode != mode else { return }
        let wasPerforming = isPerforming
        activeSource.stop()      // stop the OLD source (mode not yet changed)
        mode = newMode
        smoothed = [:]
        if wasPerforming { activeSource.start() }
    }

    // MARK: - Session control

    /// Begin a performance for `song`: camera warms up immediately; audio +
    /// scoring start together.
    func start(song: Song) {
        self.song = song
        lyrics = LyricsLoader.lyrics(for: song)
        smoothed = [:]
        score.reset()
        finalSummary = nil
        currentLyricIndex = nil
        elapsed = 0

        activeSource.start()
        audio.load(fileName: song.audioFileName, fileExtension: song.audioFileExtension)
        audio.play()
        isPerforming = true
        startClock()
    }

    func stop() {
        finishPerformance()
        camera.stop()
        #if canImport(ARKit)
        arFace?.stop()
        #endif
    }

    // MARK: - Clock (driven off the audio position)

    private func startClock() {
        stopClock()
        // 20 Hz is smooth for lyric highlighting and cheap; the audio position
        // remains the source of truth so there is no drift.
        clock = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func stopClock() {
        clock?.invalidate()
        clock = nil
    }

    private func tick() {
        guard isPerforming else { return }
        elapsed = audio.currentTime
        currentLyricIndex = lyricIndex(at: elapsed, in: lyrics)

        // End the performance when the track completes.
        if audio.didFinish {
            finishPerformance()
        }
    }

    private func finishPerformance() {
        guard isPerforming else { return }
        isPerforming = false
        stopClock()
        audio.stop()
        if let song { finalSummary = score.summary(for: song) }
    }

    // MARK: - Frame ingestion

    /// Per-emotion sensitivity applied to the raw model output before picking a
    /// winner. `happy` is now carried mostly by Vision geometry (below), so this
    /// is a gentle nudge, not a crutch.
    private let sensitivity: [Emotion: Double] = [
        .happy:     1.2,
        .energetic: 1.3,
        .sad:       1.1,
        .neutral:   1.0,
    ]

    /// How much the geometric smile (Vision landmarks) vs the model contributes
    /// to `happy` in MODEL mode. Vision leads, but not so hard it swamps the
    /// other emotions. Smiles below `smileGate` are ignored so a relaxed mouth
    /// doesn't drift into "happy".
    private let happyModelWeight  = 0.4
    private let happyVisionWeight = 0.6
    private let smileGate         = 0.35

    /// EMA weight for the newest frame (0–1). Lower = smoother/steadier badge,
    /// higher = snappier. Smoothing stops the label flickering frame-to-frame.
    private let smoothingFactor = 0.45
    private var smoothed: [Emotion: Double] = [:]

    /// Debug: raw model confidences + smile from the latest frame (pre-fusion).
    private(set) var debugConfidences: [Emotion: Double] = [:]
    private(set) var debugSmile: Double = 0

    private func handle(_ reading: EmotionReading) {
        guard reading.faceDetected else {
            currentReading = reading            // "No face" — don't score
            return
        }
        debugConfidences = reading.confidences
        debugSmile = reading.smile

        var calibrated: [Emotion: Double] = [:]
        switch mode {
        case .model:
            // Model mode: sensitivity-scale the classifier, then fuse the
            // gated Vision smile into `happy`.
            for e in Emotion.allCases {
                calibrated[e] = reading.confidence(of: e) * (sensitivity[e] ?? 1)
            }
            let gatedSmile = reading.smile < smileGate ? 0 : reading.smile
            calibrated[.happy] = calibrated[.happy]! * happyModelWeight
                               + gatedSmile * happyVisionWeight

        case .arkit:
            // ARKit mode: blendshapes already give a clean 4-way vector — use it
            // raw (no model fusion) so the A/B comparison is fair.
            for e in Emotion.allCases { calibrated[e] = reading.confidence(of: e) }
        }

        // Renormalise to a probability vector.
        let total = calibrated.values.reduce(0, +)
        if total > 0 { for e in Emotion.allCases { calibrated[e]! /= total } }

        // 4) Exponential moving average over recent frames.
        for e in Emotion.allCases {
            let prev = smoothed[e] ?? calibrated[e]!
            smoothed[e] = prev * (1 - smoothingFactor) + calibrated[e]! * smoothingFactor
        }

        let dominant = smoothed.max { $0.value < $1.value }?.key ?? .neutral
        let adjusted = EmotionReading(
            dominant: dominant,
            confidences: smoothed,
            faceDetected: true,
            mediaTime: elapsed,
            smile: reading.smile
        )
        currentReading = adjusted
        guard isPerforming, let song else { return }
        score.ingest(adjusted, genre: song.genre)
    }

    // MARK: - Lyric lookup

    /// Index of the last lyric whose start time has passed, or nil before the
    /// first line.
    private func lyricIndex(at time: TimeInterval, in lyrics: [LyricLine]) -> Int? {
        guard !lyrics.isEmpty else { return nil }
        var result: Int?
        for (i, line) in lyrics.enumerated() {
            if line.time <= time { result = i } else { break }
        }
        return result
    }
}
