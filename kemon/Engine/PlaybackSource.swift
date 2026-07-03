//
//  PlaybackSource.swift
//  kemon
//
//  The song-source seam. It abstracts the master clock and the vocal-suppress
//  toggle across the two ways Kemon can play a song:
//
//    • LocalAudioEngine     — bundled / user-imported files (local PCM), which
//                             support vocal suppression and feed the AEC graph.
//    • MusicKitPlaybackSource — Apple Music tracks, played full-mix as-is
//                             (DRM makes suppression impossible).
//
//  KemonEngine drives lyric sync and scoring off `currentTime`, so both sources
//  look identical to the rest of the app. This is the same dependency-injection
//  seam already used for EmotionAnalyzing.
//

import Foundation

@MainActor
protocol PlaybackSource: AnyObject {
    /// Master clock: seconds elapsed in the track. Drives lyric sync + scoring.
    var currentTime: TimeInterval { get }

    var isPlaying: Bool { get }

    /// True once playback has run past the end of the track.
    var didFinish: Bool { get }

    /// Whether this source can dim the lead vocal. False for MusicKit (DRM).
    var supportsVocalSuppression: Bool { get }

    /// When true (and supported), playback uses the vocal-suppressed mix.
    var vocalSuppressionEnabled: Bool { get set }

    /// Loads/queues the song. Async because MusicKit prepares over the network.
    func prepare(for song: Song) async

    func play()
    func stop()

    /// Pause/resume for audio-session interruptions (calls, Siri). Default
    /// no-ops so a source that doesn't need them stays simple.
    func pause()
    func resume()
}

extension PlaybackSource {
    func pause() {}
    func resume() {}
}
