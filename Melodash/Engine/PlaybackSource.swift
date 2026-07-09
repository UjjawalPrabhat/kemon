//
//  PlaybackSource.swift
//  Melodash
//
//  The song-source seam. It abstracts the master clock and the vocal-suppress
//  toggle across the two ways Melodash can play a song:
//
//    • LocalAudioEngine     — bundled / user-imported files (local PCM), which
//                             support vocal suppression and feed the AEC graph.
//    • MusicKitPlaybackSource — Apple Music tracks, played full-mix as-is
//                             (DRM makes suppression impossible).
//
//  MelodashEngine drives lyric sync and scoring off `currentTime`, so both sources
//  look identical to the rest of the app. This is the same dependency-injection
//  seam already used for EmotionAnalyzing.
//

import Foundation

@MainActor
protocol PlaybackSource: AnyObject {
    /// Master clock: seconds elapsed in the track. Drives lyric sync + scoring.
    var currentTime: TimeInterval { get }

    /// True once playback has run past the end of the track.
    var didFinish: Bool { get }

    /// Non-nil once `prepare` determines the song can't actually be played
    /// (e.g. an Apple Music track with no active subscription). Surfaced to the
    /// user as a warning. Nil means playback is expected to work.
    var unavailableReason: String? { get }

    /// Whether this source can dim the lead vocal. False for MusicKit (DRM).
    var supportsVocalSuppression: Bool { get }

    /// When true (and supported), playback uses the vocal-suppressed mix.
    var vocalSuppressionEnabled: Bool { get set }

    /// Loads/queues the song. Async because MusicKit prepares over the network.
    func prepare(for song: Song) async

    func play()
    func stop()

    /// Jump to `time` seconds into the track (user scrubbing the progress bar).
    /// Default no-ops for sources that can't seek.
    func seek(to time: TimeInterval)

    /// Pause/resume for audio-session interruptions (calls, Siri). Default
    /// no-ops so a source that doesn't need them stays simple.
    func pause()
    func resume()
}

extension PlaybackSource {
    func pause() {}
    func resume() {}
    func seek(to time: TimeInterval) {}
    /// Local sources always play; only Apple Music can be unavailable.
    var unavailableReason: String? { nil }
}
