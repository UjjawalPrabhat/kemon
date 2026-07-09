//
//  VoiceScoringMatrix.swift
//  Melodash
//
//  The voice analogue of ScoringMatrix. It ingests per-frame VoiceReadings
//  (only voiced frames count, mirroring the face-presence gate) and produces a
//  0–100 score from four relative sub-scores — no reference melody needed yet:
//
//    • in-tune-ness — closeness to the nearest equal-tempered note
//    • stability    — steadiness of sustained notes (low cents wobble)
//    • timing       — vocal onsets landing near the lyric line starts
//    • dynamics     — how much the singer varies loudness (expression)
//
//  The emotion↔voice blend and the combined summary live here too, so there is
//  no separate two-number "overall" type.
//

import Foundation

struct VoiceScoringMatrix {

    // In-tune-ness accumulation.
    private var inTuneSum: Double = 0
    private var voicedCount: Int = 0

    // Stability: cents spread within runs on the same note, length-weighted.
    private var runNote: Int?
    private var runCents: [Double] = []
    private var stabilitySum: Double = 0
    private var stabilityWeight: Double = 0

    // Dynamics: voiced loudness samples (dBFS).
    private var dbSamples: [Double] = []

    // Timing: detected vocal onsets vs the song's lyric line times.
    private var wasVoiced = false
    private var onsetTimes: [TimeInterval] = []
    private var lyricLineTimes: [TimeInterval] = []

    // MARK: - Ingest

    /// Seeds the lyric line start times used for timing scoring. Call once at
    /// the start of a performance.
    mutating func setLyricLines(_ lines: [LyricLine]) {
        lyricLineTimes = lines.map(\.time).sorted()
    }

    mutating func ingest(_ reading: VoiceReading) {
        // Onset = unvoiced → voiced transition.
        if reading.isVoiced && !wasVoiced { onsetTimes.append(reading.mediaTime) }
        wasVoiced = reading.isVoiced

        guard reading.isVoiced else { return }
        voicedCount += 1

        if let cents = reading.centsOff {
            inTuneSum += max(0, 1 - abs(cents) / 50)
        }

        if let note = reading.nearestNote, let cents = reading.centsOff {
            if runNote == note {
                runCents.append(cents)
            } else {
                flushRun()
                runNote = note
                runCents = [cents]
            }
        }
        dbSamples.append(reading.db)
    }

    /// Flushes the pending note run into the stability accumulator. Call before
    /// reading final scores.
    mutating func finalize() { flushRun() }

    mutating func reset() {
        self = VoiceScoringMatrix()
    }

    private mutating func flushRun() {
        defer { runCents = [] }
        guard runCents.count >= 3 else { return }
        let sd = Self.standardDeviation(runCents)
        let stability = exp(-sd / 30)           // σ≈0 → 1.0, σ≈30 cents → ~0.37
        let weight = Double(runCents.count)
        stabilitySum += stability * weight
        stabilityWeight += weight
    }

    // MARK: - Sub-scores (0–100, nil when not measurable)

    var inTuneness: Int? {
        guard voicedCount > 0 else { return nil }
        return Int((inTuneSum / Double(voicedCount) * 100).rounded())
    }

    var stability: Int? {
        guard stabilityWeight > 0 else { return nil }
        return Int((stabilitySum / stabilityWeight * 100).rounded())
    }

    var timing: Int? {
        guard !lyricLineTimes.isEmpty, !onsetTimes.isEmpty else { return nil }
        let tolerance = 0.6
        var sum = 0.0
        for line in lyricLineTimes {
            let nearest = onsetTimes.min { abs($0 - line) < abs($1 - line) } ?? .infinity
            sum += max(0, 1 - abs(nearest - line) / tolerance)
        }
        return Int((sum / Double(lyricLineTimes.count) * 100).rounded())
    }

    var dynamics: Int? {
        guard dbSamples.count >= 8 else { return nil }
        let sorted = dbSamples.sorted()
        let p10 = sorted[Int(Double(sorted.count) * 0.10)]
        let p90 = sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.90))]
        let range = p90 - p10                    // dB spread over the performance
        let normalized = (range - 3) / (18 - 3)  // 3 dB → 0, 18 dB → 100
        return Int((min(max(normalized, 0), 1) * 100).rounded())
    }

    /// Weighted voice score over the sub-scores that could be measured, or nil
    /// if the singer was never voiced (e.g. mic off).
    var normalizedScore: Int? {
        let parts: [(value: Int?, weight: Double)] = [
            (inTuneness, 0.40),
            (stability, 0.25),
            (timing, 0.20),
            (dynamics, 0.15),
        ]
        var sum = 0.0, weight = 0.0
        for part in parts {
            guard let value = part.value else { continue }
            sum += Double(value) * part.weight
            weight += part.weight
        }
        guard weight > 0 else { return nil }
        return Int((sum / weight).rounded())
    }

    // MARK: - Blend with emotion

    /// Overall score blending the facial-emotion score with the voice score.
    /// Degrades gracefully: if only one dimension was measurable, that one
    /// stands alone.
    func overall(emotionScore: Int) -> Int {
        guard let voice = normalizedScore else { return emotionScore }
        return Int((0.4 * Double(emotionScore) + 0.6 * Double(voice)).rounded())
    }

    // MARK: - Math

    private static func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        return variance.squareRoot()
    }
}
