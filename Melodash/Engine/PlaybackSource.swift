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

/// How the shared `AVAudioSession` must be brought up around a source's
/// `prepare()`. Declared by each source so the engine sequences the session
/// without knowing the concrete type (DIP) — the ordering is subtle and
/// source-specific, so it belongs to the source, not a `song.source` switch.
enum SessionActivation {
    /// Configure the session first, THEN `prepare` (which attaches the player
    /// node to the still-stopped engine), THEN start the mic with echo
    /// cancellation. Local PCM sources — prevents the "player started when in a
    /// disconnected state" crash.
    case beforePrepare
    /// `prepare` FIRST — MusicKit must own the media-server connection before we
    /// touch the session — THEN start the mic *without* the voice-processing
    /// (VPIO) unit and *with* `.mixWithOthers`. DRM sources: the VPIO duplex unit
    /// otherwise starves ApplicationMusicPlayer of the route ("ping did not
    /// pong" → silence), and AEC is useless on DRM audio anyway.
    case afterPrepare
}

@MainActor
protocol PlaybackSource: AnyObject {
    /// Master clock: seconds elapsed in the track. Drives lyric sync + scoring.
    var currentTime: TimeInterval { get }

    /// How the engine must order session setup around `prepare` for this source.
    var sessionActivation: SessionActivation { get }

    /// True once playback has run past the end of the track.
    var didFinish: Bool { get }

    /// Non-nil once `prepare` determines the song can't actually be played
    /// (e.g. an Apple Music track with no active subscription). Surfaced to the
    /// user as a warning. Nil means playback is expected to work.
    var unavailableReason: String? { get }

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

/// A playback source that can dim the lead vocal. Only local PCM sources can —
/// DRM sources (Apple Music) never see the samples, so they simply don't
/// conform, and the vocal-suppress toggle is offered only when `playback is
/// VocalSuppressing`. Split out of `PlaybackSource` so the base seam stays lean
/// (Interface Segregation).
@MainActor
protocol VocalSuppressing: AnyObject {
    /// Whether the *currently loaded track* can actually be suppressed (e.g. a
    /// mono file can't), distinct from the source type merely supporting it.
    var canSuppressVocals: Bool { get }

    /// When true (and `canSuppressVocals`), playback uses the suppressed mix.
    var vocalSuppressionEnabled: Bool { get set }
}
