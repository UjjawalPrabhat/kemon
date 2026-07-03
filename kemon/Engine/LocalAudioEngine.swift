//
//  LocalAudioEngine.swift
//  kemon
//
//  PlaybackSource for bundled and user-imported songs. It attaches an
//  AVAudioPlayerNode to the SHARED AVAudioEngine owned by MicController, so the
//  backing track and the mic live in one graph and voice-processing echo
//  cancellation can subtract the playback from the captured voice.
//
//  It reads the whole file into a buffer once at `prepare`, precomputes the
//  vocal-suppressed variant, and toggles between them by rescheduling. The
//  master clock comes from the player node's sample time (AVAudioPlayerNode has
//  no `currentTime`), which stays sample-locked to what the user hears.
//

import AVFoundation

@MainActor
final class LocalAudioEngine: PlaybackSource {

    private let engine: AVAudioEngine
    private let player = AVAudioPlayerNode()
    private let separator: VocalSeparating

    /// The decoded track, and its vocal-suppressed twin (nil for mono sources).
    private var originalBuffer: AVAudioPCMBuffer?
    private var suppressedBuffer: AVAudioPCMBuffer?

    /// Sample offset of the segment currently scheduled, so `currentTime`
    /// survives a mid-song reschedule (toggle / future seek).
    private var segmentStartFrame: AVAudioFramePosition = 0

    private var finished = false
    private var attached = false

    /// Bumped on every (re)schedule. A buffer's completion handler only marks
    /// the track finished if its generation still matches — so a mid-song toggle
    /// (which stops the player and fires the OLD buffer's completion) doesn't
    /// end the performance prematurely.
    private var scheduleGeneration = 0

    init(engine: AVAudioEngine, separator: VocalSeparating = CenterChannelSuppressor()) {
        self.engine = engine
        self.separator = separator
    }

    // MARK: - PlaybackSource

    var isPlaying: Bool { player.isPlaying }

    var supportsVocalSuppression: Bool { suppressedBuffer != nil }

    var vocalSuppressionEnabled: Bool = false {
        didSet {
            guard oldValue != vocalSuppressionEnabled, supportsVocalSuppression else { return }
            rescheduleFromCurrentPosition()
        }
    }

    var didFinish: Bool { finished }

    /// Player position in seconds, derived from the node's render sample time.
    /// Returns the last known value between renders (playerTime can be nil).
    var currentTime: TimeInterval {
        guard let buffer = originalBuffer else { return 0 }
        let rate = buffer.format.sampleRate
        guard let nodeTime = player.lastRenderTime,
              let playerTime = player.playerTime(forNodeTime: nodeTime) else {
            return Double(segmentStartFrame) / rate
        }
        return Double(segmentStartFrame + playerTime.sampleTime) / rate
    }

    /// Reads the bundled/imported file into memory and precomputes the
    /// suppressed variant. Returns without throwing if the file is missing, so
    /// the emotion + mic pipeline still runs during development.
    func prepare(for song: Song) async {
        guard let url = Self.resolveURL(for: song),
              let file = try? AVAudioFile(forReading: url) else {
            return
        }
        let format = file.processingFormat
        let length = AVAudioFrameCount(file.length)
        guard length > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: length),
              (try? file.read(into: buffer)) != nil else {
            return
        }
        originalBuffer = buffer
        suppressedBuffer = separator.suppressVocals(in: buffer)

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        attached = true
    }

    func play() {
        guard originalBuffer != nil, attached else { return }
        finished = false
        segmentStartFrame = 0
        scheduleActiveBuffer(fromFrame: 0)
        if !engine.isRunning {
            engine.prepare()
            try? engine.start()
        }
        player.play()
    }

    func pause() { player.pause() }

    func resume() {
        if !engine.isRunning { try? engine.start() }
        player.play()
    }

    func stop() {
        scheduleGeneration += 1   // ignore the flushed buffer's completion
        player.stop()
        if attached {
            engine.detach(player)
            attached = false
        }
        originalBuffer = nil
        suppressedBuffer = nil
        finished = false
        segmentStartFrame = 0
    }

    // MARK: - Scheduling

    private var activeBuffer: AVAudioPCMBuffer? {
        (vocalSuppressionEnabled ? suppressedBuffer : originalBuffer) ?? originalBuffer
    }

    /// Schedules the active buffer starting at `fromFrame`. Sets `finished` when
    /// the scheduled audio has actually played out.
    private func scheduleActiveBuffer(fromFrame: AVAudioFramePosition) {
        guard let buffer = activeBuffer else { return }

        let segment: AVAudioPCMBuffer
        if fromFrame <= 0 {
            segment = buffer
        } else if let tail = Self.slice(of: buffer, fromFrame: fromFrame) {
            segment = tail
        } else {
            finished = true
            return
        }

        scheduleGeneration += 1
        let generation = scheduleGeneration
        player.scheduleBuffer(segment, at: nil, options: [], completionCallbackType: .dataPlayedBack) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                // Ignore the completion of a buffer we've since replaced (toggle).
                if self.scheduleGeneration == generation { self.finished = true }
            }
        }
    }

    /// On a toggle, restart the active buffer at the current position so the
    /// switch is seamless-ish (a sub-100 ms reseek).
    private func rescheduleFromCurrentPosition() {
        guard let buffer = originalBuffer, player.isPlaying else { return }
        let frame = AVAudioFramePosition(currentTime * buffer.format.sampleRate)
        player.stop()
        segmentStartFrame = max(0, min(frame, buffer.frameLength.asFramePosition))
        scheduleActiveBuffer(fromFrame: segmentStartFrame)
        player.play()
    }

    // MARK: - Helpers

    /// A copy of `buffer` from `fromFrame` to the end.
    private static func slice(of buffer: AVAudioPCMBuffer, fromFrame: AVAudioFramePosition) -> AVAudioPCMBuffer? {
        let total = AVAudioFramePosition(buffer.frameLength)
        guard fromFrame < total else { return nil }
        let count = AVAudioFrameCount(total - fromFrame)
        guard let out = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: count),
              let src = buffer.floatChannelData, let dst = out.floatChannelData else { return nil }
        let channels = Int(buffer.format.channelCount)
        for c in 0..<channels {
            memcpy(dst[c], src[c] + Int(fromFrame), Int(count) * MemoryLayout<Float>.stride)
        }
        out.frameLength = count
        return out
    }

    /// Resolves the file: an imported security-scoped URL wins, otherwise the
    /// bundled resource (mirrors AudioController's bundle lookup).
    private static func resolveURL(for song: Song) -> URL? {
        if case .imported = song.source, let url = song.importedURL {
            return url
        }
        return Bundle.main.url(forResource: song.audioFileName, withExtension: song.audioFileExtension)
    }
}

private extension AVAudioFrameCount {
    var asFramePosition: AVAudioFramePosition { AVAudioFramePosition(self) }
}
