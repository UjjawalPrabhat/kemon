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
import AVFoundation

@MainActor
@Observable
final class KemonEngine {

    // Live state observed by the UI.
    private(set) var currentReading: EmotionReading = .empty
    private(set) var currentVoice: VoiceReading = .empty
    private(set) var score = ScoringMatrix()
    private(set) var voiceScore = VoiceScoringMatrix()
    private(set) var isPerforming = false
    private(set) var currentLyricIndex: Int?
    private(set) var elapsed: TimeInterval = 0
    private(set) var finalSummary: String?

    /// Resolved timed lyrics for the active song (from a bundled .lrc if present).
    private(set) var lyrics: [LyricLine] = []

    let camera: CameraController

    /// Captures + analyses the singer's voice. Owns the shared AVAudioEngine
    /// that LocalAudioEngine attaches its backing-track player to.
    let mic = MicController()

    /// Active playback (local file engine or MusicKit), chosen per song.
    private(set) var playback: PlaybackSource

    /// Combined voice + emotion score for the live overall readout.
    var overallScore: Int { voiceScore.overall(emotionScore: score.normalizedScore) }

    /// Whether the active source can dim the lead vocal. Observed by the UI;
    /// resolved after the (async) playback prepare completes.
    private(set) var canSuppressVocals = false

    /// UI-bound vocal-suppression toggle. Applies to the active source.
    var vocalSuppressed = false {
        didSet {
            guard oldValue != vocalSuppressed else { return }
            setVocalSuppress(vocalSuppressed)
        }
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

        // Local playback attaches its player node to the mic's shared engine so
        // echo cancellation has the backing track as its reference signal.
        playback = LocalAudioEngine(engine: mic.engine)

        // self is fully initialised past this point — safe to capture.
        camera.onReading = { [weak self] reading in
            self?.handle(reading)
        }
        mic.onReading = { [weak self] reading in
            self?.handle(voice: reading)
        }
        #if os(iOS)
        observeInterruptions()
        #endif
    }

    /// The face-analysis source (Core ML + Vision camera pipeline).
    private var activeSource: FaceSource { camera }

    // MARK: - Session control

    /// Begin a performance for `song`: camera + mic warm up, then audio and
    /// scoring start together. Async because MusicKit prepares over the network.
    func start(song: Song) {
        self.song = song
        lyrics = LyricsLoader.lyrics(for: song)
        // No bundled/stored lyrics (typically an Apple Music track, whose lyrics
        // MusicKit never exposes) — fetch them from an open lyrics provider and
        // fold them in when they arrive. Best-effort; playback never waits on it.
        if lyrics.isEmpty {
            fetchRemoteLyrics(for: song)
        }
        smoothed = [:]
        score.reset()
        voiceScore.reset()
        voiceScore.setLyricLines(lyrics)
        currentVoice = .empty
        finalSummary = nil
        currentLyricIndex = nil
        elapsed = 0
        canSuppressVocals = false
        vocalSuppressed = false

        playback = makePlaybackSource(for: song)
        let isAppleMusic = song.source == .appleMusic
        activeSource.start()

        Task { @MainActor in
            if isAppleMusic {
                // Apple Music: MusicKit must prepare BEFORE we touch the
                // AVAudioSession. Setting .playAndRecord early disrupts
                // ApplicationMusicPlayer's mediaserverd connection
                // ("ping did not pong" → prepareToPlay fails → silence).
                await playback.prepare(for: song)
                canSuppressVocals = playback.supportsVocalSuppression
                // Now start the mic — this sets .playAndRecord + starts the
                // engine. MusicKit's player is already prepared and tolerates
                // the session change at this point. Crucially, run WITHOUT the
                // voice-processing (VPIO) unit and WITH .mixWithOthers: the VPIO
                // duplex unit otherwise starves ApplicationMusicPlayer of the
                // audio route ("ping did not pong" → silence). AEC is useless on
                // DRM audio anyway, so nothing is lost.
                mic.start(voiceProcessing: false, mixWithOthers: true)
            } else {
                // Local songs: configure the session first, THEN prepare
                // (which attaches the AVAudioPlayerNode to the still-stopped
                // engine), THEN start the mic (which starts the engine with
                // all nodes connected). This prevents the "player started
                // when in a disconnected state" crash.
                mic.configureSession()
                await playback.prepare(for: song)
                canSuppressVocals = playback.supportsVocalSuppression
                mic.start()
            }

            playback.play()
            isPerforming = true
            startClock()
        }
    }

    func stop() {
        finishPerformance()
        camera.stop()
        mic.stop()
    }

    /// Toggles vocal suppression on the backing track (local sources only).
    func setVocalSuppress(_ enabled: Bool) {
        guard playback.supportsVocalSuppression else { return }
        playback.vocalSuppressionEnabled = enabled
    }

    /// Resolves lyrics for a song with none locally (Apple Music tracks), then
    /// folds them into the live session and caches them onto the model. The
    /// lyric layer decides source and eligibility; the engine just applies the
    /// result. No-ops on failure (shows no lyrics).
    private func fetchRemoteLyrics(for song: Song) {
        Task { @MainActor in
            let fetched = await LyricsLoader.remoteLyrics(for: song)
            // Bail if nothing came back or the user moved to another song.
            guard !fetched.isEmpty, self.song === song else { return }
            lyrics = fetched
            voiceScore.setLyricLines(fetched)
            song.lyrics = fetched   // persisted by SwiftData's autosave
        }
    }

    /// Chooses the playback source for the song. Apple Music songs play through
    /// MusicKit; everything else plays locally (and supports suppression).
    private func makePlaybackSource(for song: Song) -> PlaybackSource {
        #if canImport(MusicKit)
        if song.source == .appleMusic {
            return MusicKitPlaybackSource()
        }
        #endif
        return LocalAudioEngine(engine: mic.engine)
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
        elapsed = playback.currentTime
        currentLyricIndex = lyricIndex(at: elapsed, in: lyrics)

        // End the performance when the track completes.
        if playback.didFinish {
            finishPerformance()
        }
    }

    private func finishPerformance() {
        guard isPerforming else { return }
        isPerforming = false
        stopClock()
        playback.stop()
        mic.stop()
        voiceScore.finalize()
        if let song {
            finalSummary = voiceScore.summary(for: song, emotionScore: score.normalizedScore)
        }
    }

    // MARK: - Audio-session interruptions

    // AVAudioSession — and therefore interruption notifications — only exist on
    // iOS. On macOS the audio graph isn't interrupted this way, so these are
    // no-ops there.
    #if os(iOS)
    private func observeInterruptions() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            MainActor.assumeIsolated { self?.handleInterruption(note) }
        }
    }

    private func handleInterruption(_ note: Notification) {
        guard isPerforming,
              let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        switch type {
        case .began:
            stopClock()
            playback.pause()
            mic.pause()
        case .ended:
            let options = (note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt)
                .map(AVAudioSession.InterruptionOptions.init(rawValue:)) ?? []
            if options.contains(.shouldResume) {
                mic.resume()
                playback.resume()
                startClock()
            }
        @unknown default:
            break
        }
    }
    #endif

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

        // Sensitivity-scale the classifier, then fuse the gated Vision smile
        // into `happy` (which the static-image model reads weakly while singing).
        var calibrated: [Emotion: Double] = [:]
        for e in Emotion.allCases {
            calibrated[e] = reading.confidence(of: e) * (sensitivity[e] ?? 1)
        }
        let gatedSmile = reading.smile < smileGate ? 0 : reading.smile
        calibrated[.happy] = calibrated[.happy]! * happyModelWeight
                           + gatedSmile * happyVisionWeight

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

    /// Ingests one microphone reading: stamps it with the audio clock, exposes
    /// it for the live pitch/energy UI, and feeds it to the voice score.
    private func handle(voice reading: VoiceReading) {
        var stamped = reading
        stamped.mediaTime = elapsed
        currentVoice = stamped
        guard isPerforming else { return }
        voiceScore.ingest(stamped)
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
