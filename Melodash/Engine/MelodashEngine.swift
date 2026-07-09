//
//  MelodashEngine.swift
//  Melodash
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
final class MelodashEngine {

    // Live state observed by the UI.
    private(set) var currentReading: EmotionReading = .empty
    private(set) var currentVoice: VoiceReading = .empty
    private(set) var score = ScoringMatrix()
    private(set) var voiceScore = VoiceScoringMatrix()
    private(set) var isPerforming = false
    /// True while the singer has paused the track mid-performance. `isPerforming`
    /// stays true — the turn isn't over, the clock and audio are just halted.
    private(set) var isPaused = false
    private(set) var currentLyricIndex: Int?
    private(set) var elapsed: TimeInterval = 0
    /// Flips to true once the turn ends (track finished or stopped), so the UI
    /// can leave the loading state and hand off to the results screen.
    private(set) var didFinish = false

    /// Non-nil when the active track can't play — e.g. an Apple Music song with
    /// no active subscription. The UI shows this as a dismissible warning.
    private(set) var playbackWarning: String?

    /// Resolved timed lyrics for the active song (from a bundled .lrc if present).
    private(set) var lyrics: [LyricLine] = []

    /// Estimated track length: last lyric timestamp + buffer, or a fallback when
    /// there are no lyrics. Neither playback source exposes an exact duration
    /// synchronously, so the progress bar maps its fraction against this.
    var estimatedDuration: TimeInterval {
        if let lastLine = lyrics.last {
            return lastLine.time + 15   // ~15s buffer after the last lyric
        }
        return max(180, elapsed + 30)   // fallback: 3 min, or current + 30s
    }

    /// True when the lyrics contain non-Latin script, so the UI can offer a
    /// romanize toggle.
    var hasNonLatinLyrics: Bool {
        lyrics.contains { $0.text.containsNonLatinScript }
    }

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
    #if os(iOS)
    /// Token for the audio-session interruption observer, removed on deinit so a
    /// fresh engine per turn doesn't leave a registration behind. `nonisolated`
    /// so `deinit` can read it: written once on the main actor in `init`, read
    /// once in `deinit`, never concurrently.
    private nonisolated(unsafe) var interruptionObserver: NSObjectProtocol?
    #endif

    /// Uses the trained Core ML model if `MelodashEmotionClassifier.mlmodelc` is in
    /// the bundle, otherwise falls back to the placeholder so the app still runs.
    /// Pass an explicit analyzer to override (e.g. in tests).
    init(analyzer: EmotionAnalyzing? = nil) {
        let resolved = analyzer ?? (try? CoreMLEmotionAnalyzer()) ?? PlaceholderEmotionAnalyzer()
        camera = CameraController(analyzer: resolved)

        // Local playback attaches its player node to the mic's shared engine so
        // echo cancellation has the backing track as its reference signal.
        playback = LocalAudioEngine(engine: mic.engine)

        // self is fully initialised past this point — safe to capture.
        camera.onReading = { [weak self] reading in
            self?.ingest(emotion: reading)
        }
        mic.onReading = { [weak self] reading in
            self?.ingest(voice: reading)
        }
        #if os(iOS)
        observeInterruptions()
        #endif
    }

    deinit {
        #if os(iOS)
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        #endif
    }

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
        fusion.reset()
        score.reset()
        voiceScore.reset()
        voiceScore.setLyricLines(lyrics)
        currentVoice = .empty
        didFinish = false
        currentLyricIndex = nil
        elapsed = 0
        canSuppressVocals = false
        vocalSuppressed = false
        isPaused = false
        playbackWarning = nil

        playback = makePlaybackSource(for: song)
        let isAppleMusic = song.source == .appleMusic
        camera.start()

        Task { @MainActor in
            if isAppleMusic {
                // Apple Music: MusicKit must prepare BEFORE we touch the
                // AVAudioSession. Setting .playAndRecord early disrupts
                // ApplicationMusicPlayer's mediaserverd connection
                // ("ping did not pong" → prepareToPlay fails → silence).
                await playback.prepare(for: song)
                canSuppressVocals = (playback as? VocalSuppressing)?.canSuppressVocals ?? false
                playbackWarning = playback.unavailableReason
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
                canSuppressVocals = (playback as? VocalSuppressing)?.canSuppressVocals ?? false
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

    /// Play/pause toggle for the singer. Halts (or resumes) the audio, mic
    /// capture, and lyric/scoring clock together so nothing advances while
    /// paused. No-op once the turn has ended.
    func togglePause() {
        guard isPerforming else { return }
        if isPaused {
            isPaused = false
            mic.resume()
            playback.resume()
            startClock()
        } else {
            isPaused = true
            stopClock()
            playback.pause()
            mic.pause()
        }
    }

    /// Scrub to `time` seconds into the track and immediately resync the lyric
    /// highlight so the display doesn't lag a clock tick behind the jump.
    func seek(to time: TimeInterval) {
        guard isPerforming else { return }
        playback.seek(to: max(0, time))
        elapsed = playback.currentTime
        currentLyricIndex = lyricIndex(at: elapsed, in: lyrics)
    }

    /// Toggles vocal suppression on the backing track (local sources only).
    private func setVocalSuppress(_ enabled: Bool) {
        guard let suppressor = playback as? VocalSuppressing, suppressor.canSuppressVocals else { return }
        suppressor.vocalSuppressionEnabled = enabled
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
        isPaused = false
        stopClock()
        playback.stop()
        mic.stop()
        voiceScore.finalize()
        didFinish = true
    }

    // MARK: - Audio-session interruptions

    // AVAudioSession — and therefore interruption notifications — only exist on
    // iOS. On macOS the audio graph isn't interrupted this way, so these are
    // no-ops there.
    #if os(iOS)
    private func observeInterruptions() {
        interruptionObserver = NotificationCenter.default.addObserver(
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

    /// Fuses raw camera readings into the smoothed emotion used for scoring.
    private var fusion = EmotionFusion()

    /// Debug: raw model confidences + smile from the latest frame (pre-fusion).
    private(set) var debugConfidences: [Emotion: Double] = [:]
    private(set) var debugSmile: Double = 0

    private func ingest(emotion reading: EmotionReading) {
        guard reading.faceDetected else {
            currentReading = reading            // "No face" — don't score
            return
        }
        debugConfidences = reading.confidences
        debugSmile = reading.smile

        let adjusted = fusion.fuse(reading)
        currentReading = adjusted
        guard isPerforming, let song else { return }
        score.ingest(adjusted, genre: song.genre)
    }

    /// Ingests one microphone reading: stamps it with the audio clock, exposes
    /// it for the live pitch/energy UI, and feeds it to the voice score.
    private func ingest(voice reading: VoiceReading) {
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
