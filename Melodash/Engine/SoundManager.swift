//
//  SoundManager.swift
//  Melodash
//
//  Plays the game's non-karaoke audio: a looping background-music bed for the
//  menu/lobby screens, plus one-shot sound effects (roulette spin, result-score
//  stingers, countdown, button buzz) and the finale leaderboard loop.
//
//  Everything here is muted the moment a karaoke session begins — see
//  `stopAll()`, called from PerformanceView as the engine starts — so nothing
//  competes with the singer's backing track or the mic-based scoring.
//

import Foundation
import AVFoundation

@MainActor
final class SoundManager {
    static let shared = SoundManager()
    private init() { configureSessionIfNeeded() }

    /// Bundled audio cues (file names in Resources, without extension).
    enum Sound: String {
        case bgm = "BGM"
        case spinning = "spinning"
        case countdown = "countdown"
        case buzz = "buzz button"
        case highScore = "high score"
        case midScore = "mid score"
        case lowScore = "low score"
        case finalLeaderboard = "final leaderboard"
    }

    private var bgmPlayer: AVAudioPlayer?
    private var loopPlayer: AVAudioPlayer?        // non-BGM loop (finale leaderboard)
    private var spinPlayer: AVAudioPlayer?        // the roulette reel, stopped on demand
    private var sfxPlayers: [AVAudioPlayer] = []  // transient one-shots

    // MARK: - Background music

    /// Starts (or resumes) the looping menu/lobby background music. Idempotent —
    /// calling it while BGM is already playing is a no-op, so it plays
    /// continuously across menu screens without restarting.
    func startBGM(volume: Float = 0.45) {
        if let player = bgmPlayer, player.isPlaying { return }
        if bgmPlayer == nil {
            bgmPlayer = makePlayer(.bgm, loops: -1, volume: volume)
        }
        bgmPlayer?.play()
    }

    func stopBGM() {
        bgmPlayer?.stop()
        bgmPlayer?.currentTime = 0
    }

    // MARK: - One-shots

    /// Plays a transient sound effect. Multiple can overlap; finished players are
    /// reaped on the next call so references don't accumulate.
    func play(_ sound: Sound, volume: Float = 0.9) {
        sfxPlayers.removeAll { !$0.isPlaying }
        guard let player = makePlayer(sound, loops: 0, volume: volume) else { return }
        sfxPlayers.append(player)
        player.play()
    }

    /// Score-reveal stinger by tier, played on the results screen.
    func playScore(for overall: Int) {
        let sound: Sound = overall >= 75 ? .highScore : (overall >= 45 ? .midScore : .lowScore)
        play(sound)
    }

    // MARK: - The roulette reel (start/stop on demand)

    func startSpinning(volume: Float = 0.8) {
        spinPlayer?.stop()
        spinPlayer = makePlayer(.spinning, loops: -1, volume: volume)
        spinPlayer?.play()
    }

    func stopSpinning() {
        spinPlayer?.stop()
        spinPlayer = nil
    }

    // MARK: - Non-BGM loop (finale leaderboard)

    func startLoop(_ sound: Sound, volume: Float = 0.6) {
        loopPlayer?.stop()
        loopPlayer = makePlayer(sound, loops: -1, volume: volume)
        loopPlayer?.play()
    }

    func stopLoop() {
        loopPlayer?.stop()
        loopPlayer = nil
    }

    // MARK: - Kill switch (karaoke session start)

    /// Silences every non-karaoke sound. Called as a performance begins so the
    /// backing track and mic scoring have a clean audio field.
    func stopAll() {
        bgmPlayer?.stop(); bgmPlayer?.currentTime = 0
        loopPlayer?.stop(); loopPlayer = nil
        spinPlayer?.stop(); spinPlayer = nil
        sfxPlayers.forEach { $0.stop() }
        sfxPlayers.removeAll()
    }

    // MARK: - Helpers

    private func makePlayer(_ sound: Sound, loops: Int, volume: Float) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "mp3") else {
            return nil
        }
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.numberOfLoops = loops
        player.volume = volume
        player.prepareToPlay()
        return player
    }

    /// On iOS, use the ambient category so menu music mixes politely and honors
    /// the silent switch. macOS needs no session. Non-fatal if it fails.
    private func configureSessionIfNeeded() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        #endif
    }
}
