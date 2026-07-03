//
//  VoiceReading.swift
//  kemon
//
//  The voice analog of `EmotionReading`: one pitch/energy measurement for one
//  analysis frame. A value type so it can cross from the realtime audio thread
//  (where the mic tap runs) back to the main actor without data races, exactly
//  like `EmotionReading` crosses from the camera queue.
//

import Foundation

/// One frame of voice analysis from the microphone. `nonisolated` because it is
/// produced on the realtime audio thread and read on the main actor.
nonisolated struct VoiceReading: Sendable {
    /// Detected fundamental frequency in Hz, or nil when the frame is unvoiced
    /// (silence, breath, or the pitch detector wasn't confident).
    var f0: Double?

    /// Nearest equal-tempered semitone, or nil when unvoiced.
    var nearestNote: Int?

    /// Signed cents from `nearestNote`, in −50...+50, or nil when unvoiced.
    var centsOff: Double?

    /// Linear RMS amplitude of the frame (0...~1).
    var rms: Double

    /// RMS in dBFS (20·log10(rms)), floored around −80 for silence.
    var db: Double

    /// Pitch-detector confidence, 0...1 (normalised autocorrelation peak).
    var confidence: Double

    /// True when the frame carries a usable sung note — gated by RMS and
    /// confidence. Only voiced frames are scored, mirroring the face-presence
    /// gate in `ScoringMatrix`.
    var isVoiced: Bool

    /// Media time (audio clock) the reading corresponds to, when available.
    var mediaTime: TimeInterval

    static let empty = VoiceReading(
        f0: nil,
        nearestNote: nil,
        centsOff: nil,
        rms: 0,
        db: -80,
        confidence: 0,
        isVoiced: false,
        mediaTime: 0
    )

    /// Name of `nearestNote` (e.g. "A4"), or "—" when unvoiced.
    var noteName: String {
        guard let nearestNote else { return "—" }
        return Self.noteName(forMIDI: nearestNote)
    }

    /// Human-readable note name for a MIDI number using sharps (MIDI 69 = A4).
    static func noteName(forMIDI midi: Int) -> String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = midi / 12 - 1
        let name = names[((midi % 12) + 12) % 12]
        return "\(name)\(octave)"
    }
}
