//
//  AudioController.swift
//  kemon
//
//  Plays the bundled instrumental and — crucially — exposes `currentTime`,
//  which the rest of the app uses as the master clock for lyric sync and
//  score sampling. AVAudioPlayer is the right tool for a single decoupled
//  backing track; graduate to AVAudioEngine only when you need live mixing,
//  effects, or to route the singer's mic alongside the instrumental.
//

import AVFoundation

@MainActor
final class AudioController {
    private var player: AVAudioPlayer?

    private(set) var isPlaying = false

    var currentTime: TimeInterval { player?.currentTime ?? 0 }
    var duration: TimeInterval { player?.duration ?? 0 }

    /// Loads a bundled resource. Returns false (without throwing) if the file
    /// isn't in the bundle yet, so the emotion/scoring pipeline still runs
    /// during development before you've added instrumentals.
    @discardableResult
    func load(fileName: String, fileExtension: String) -> Bool {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension) else {
            player = nil
            return false
        }
        do {
            #if os(iOS)
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            #endif
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.prepareToPlay()
            player = newPlayer
            return true
        } catch {
            player = nil
            return false
        }
    }

    func play() {
        player?.play()
        isPlaying = player?.isPlaying ?? false
    }

    func stop() {
        player?.stop()
        player?.currentTime = 0
        isPlaying = false
    }

    /// True once playback has run past the end of the track.
    var didFinish: Bool {
        guard let player else { return false }
        return duration > 0 && !player.isPlaying && player.currentTime >= duration - 0.05
    }
}
