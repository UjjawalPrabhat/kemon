//
//  MusicKitPlaybackSource.swift
//  kemon
//
//  PlaybackSource for Apple Music songs. Apple Music playback is DRM-sealed:
//  we never receive the audio samples, so vocal suppression is IMPOSSIBLE here
//  (supportsVocalSuppression is always false — do not attempt it). The karaoke
//  session still runs and scores the singer's own voice.
//
//  Caveat: MusicKit renders outside our AVAudioEngine, so voice-processing echo
//  cancellation has no reference to cancel it. On the built-in speaker the mic
//  will pick up the backing track and pollute scoring — headphones are
//  strongly recommended for Apple Music songs. Local songs are unaffected.
//

import Foundation

#if canImport(MusicKit)
import MusicKit

@MainActor
final class MusicKitPlaybackSource: PlaybackSource {

    private let player = ApplicationMusicPlayer.shared
    private var prepared = false

    /// Set once playback has actually reached `.playing`. Without this, the
    /// window between `prepareToPlay()` (status `.stopped`) and the async
    /// `play()` taking effect would look identical to a finished track, so the
    /// first clock tick would end the performance before a note is heard.
    private var started = false

    var currentTime: TimeInterval { player.playbackTime }
    var isPlaying: Bool { player.state.playbackStatus == .playing }

    // No sample access → suppression can never be offered.
    let supportsVocalSuppression = false
    var vocalSuppressionEnabled = false

    /// MusicKit doesn't expose track duration on the player synchronously; treat
    /// a stopped state that follows actual playback as finished.
    var didFinish: Bool {
        started && player.state.playbackStatus == .stopped
    }

    func prepare(for song: Song) async {
        guard let id = song.appleMusicID else { return }
        do {
            let request = MusicCatalogResourceRequest<MusicKit.Song>(
                matching: \.id, equalTo: MusicItemID(id)
            )
            let response = try await request.response()
            guard let item = response.items.first else { return }
            player.queue = [item]
            try await player.prepareToPlay()
            prepared = true
        } catch {
            prepared = false
        }
    }

    func play() {
        guard prepared else { return }
        Task {
            do {
                try await player.play()
                started = true   // playback has actually begun
            } catch {
                // Leave `started` false so didFinish can't end the session on a
                // failed start (e.g. "ping did not pong" media-server timeout).
            }
        }
    }

    func stop() {
        player.stop()
        prepared = false
        started = false
    }

    func pause() { player.pause() }

    func resume() { Task { try? await player.play() } }
}
#endif
