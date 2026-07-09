//
//  MusicKitPlaybackSource.swift
//  Melodash
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

    /// Track length from the resolved catalog item, when MusicKit provides it.
    /// Used as a fallback end-of-track signal since the player's status doesn't
    /// always land on `.stopped` at the end of a single-item queue.
    private var trackDuration: TimeInterval?

    var currentTime: TimeInterval { player.playbackTime }

    let sessionActivation: SessionActivation = .afterPrepare

    // No sample access → suppression can never be offered, so this source does
    // not conform to VocalSuppressing (and the toggle is never shown for it).

    /// Set by `prepare` when the track can't play — almost always a missing or
    /// inactive Apple Music subscription. Read by the engine to warn the user.
    private(set) var unavailableReason: String?

    /// Finished when playback that actually started has either stopped, or has
    /// reached the end of the known track length. The duration fallback covers
    /// queues that end on `.paused` instead of `.stopped`; it can't false-fire on
    /// a user pause because that happens well before the track's final second.
    var didFinish: Bool {
        guard started else { return false }
        if player.state.playbackStatus == .stopped { return true }
        if let trackDuration, trackDuration > 0, player.playbackTime >= trackDuration - 0.75 {
            return true
        }
        return false
    }

    func prepare(for song: Song) async {
        unavailableReason = nil
        guard let id = song.appleMusicID else { return }

        // Verify the account can actually stream catalog content before queuing.
        // Without an active subscription, prepareToPlay/play fail silently — so
        // catch it here and hand the engine a clear message to show the user.
        if let subscription = try? await MusicSubscription.current,
           !subscription.canPlayCatalogContent {
            unavailableReason = """
            Playing Apple Music tracks needs an active Apple Music subscription \
            signed in on this device. Pick a bundled or imported song to sing \
            without one.
            """
            prepared = false
            return
        }

        do {
            let request = MusicCatalogResourceRequest<MusicKit.Song>(
                matching: \.id, equalTo: MusicItemID(id)
            )
            let response = try await request.response()
            guard let item = response.items.first else { return }
            trackDuration = item.duration
            player.queue = [item]
            try await player.prepareToPlay()
            prepared = true
        } catch {
            prepared = false
            unavailableReason = """
            This Apple Music track couldn't be loaded. Check your connection and \
            that you're signed in with an active Apple Music subscription, or pick \
            a bundled song.
            """
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
        trackDuration = nil
    }

    func seek(to time: TimeInterval) {
        player.playbackTime = max(0, time)
    }

    func pause() { player.pause() }

    func resume() { Task { try? await player.play() } }
}
#endif
