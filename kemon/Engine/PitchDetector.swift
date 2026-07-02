//
//  PitchDetector.swift
//  kemon
//
//  Pure DSP: estimates the fundamental frequency of a mono frame of samples
//  using normalised autocorrelation (Accelerate/vDSP), with parabolic peak
//  interpolation for sub-bin accuracy. No UIKit, no actor state — it is called
//  from the realtime audio tap thread, so all scratch buffers are preallocated
//  and it does no allocation in `detect`.
//
//  Autocorrelation is chosen over FFT-only pitch because it handles low male
//  fundamentals well at a modest window size, and its normalised peak doubles
//  as a confidence metric. YIN or an FFT-cepstrum can replace this type behind
//  the same `detect` signature without touching callers.
//

import Accelerate

/// Estimates fundamental frequency from mono Float samples.
///
/// `nonisolated`/`@unchecked Sendable`: it runs on the realtime audio-tap
/// thread, and its mutable scratch buffers are only ever touched from that one
/// thread, never concurrently.
nonisolated final class PitchDetector: @unchecked Sendable {

    /// Musical range we search, in Hz. Covers low male (~80 Hz) to high
    /// soprano/whistle onset (~1100 Hz); restricting the lag search avoids
    /// spurious sub-harmonic peaks.
    private let minFrequency: Double = 70
    private let maxFrequency: Double = 1100

    /// Reused Hann window and windowed-sample scratch, sized to the largest
    /// frame we expect. Grown on demand (rare) so `detect` stays allocation-free
    /// in steady state.
    private var window: [Float] = []
    private var windowed: [Float] = []

    /// Result of a single-frame estimate.
    struct Estimate {
        var f0: Double?
        var confidence: Double
    }

    /// Estimate f0 for `count` mono samples. `sampleRate` MUST be the real input
    /// rate (Bluetooth often forces 16/24 kHz) — the lag→Hz conversion depends
    /// on it.
    func detect(_ samples: UnsafePointer<Float>, count: Int, sampleRate: Double) -> Estimate {
        guard count >= 256, sampleRate > 0 else { return Estimate(f0: nil, confidence: 0) }
        ensureBuffers(count: count)

        // Hann-window the frame to reduce edge discontinuity before autocorrelation.
        window.withUnsafeBufferPointer { win in
            windowed.withUnsafeMutableBufferPointer { out in
                vDSP_vmul(samples, 1, win.baseAddress!, 1, out.baseAddress!, 1, vDSP_Length(count))
            }
        }

        // Lag search range (in samples) for the frequency band of interest.
        let maxLag = min(count - 1, Int(sampleRate / minFrequency))
        let minLag = max(1, Int(sampleRate / maxFrequency))
        guard maxLag > minLag else { return Estimate(f0: nil, confidence: 0) }

        return windowed.withUnsafeBufferPointer { buf -> Estimate in
            let x = buf.baseAddress!

            // Energy at lag 0 normalises the autocorrelation into 0...1.
            var energy: Float = 0
            vDSP_dotpr(x, 1, x, 1, &energy, vDSP_Length(count))
            guard energy > 0 else { return Estimate(f0: nil, confidence: 0) }

            // Autocorrelation r(lag) = Σ x[i]·x[i+lag], normalised by energy.
            var bestLag = -1
            var bestValue: Float = 0
            var prev: Float = 0      // r(lag-1), for local-maximum detection
            var prevPrev: Float = 0  // r(lag-2)
            for lag in minLag...maxLag {
                var r: Float = 0
                vDSP_dotpr(x, 1, x + lag, 1, &r, vDSP_Length(count - lag))
                r /= energy

                // Accept the first strong local maximum rather than the global
                // one, so we lock onto the true period instead of a higher-lag
                // harmonic of it.
                if prev > prevPrev && prev >= r && prev > bestValue && (lag - 1) >= minLag {
                    bestValue = prev
                    bestLag = lag - 1
                    if bestValue > 0.9 { break } // clearly periodic — stop early
                }
                prevPrev = prev
                prev = r
            }

            guard bestLag > 0, bestValue > 0 else { return Estimate(f0: nil, confidence: 0) }

            // Parabolic interpolation around the peak lag for sub-sample accuracy.
            let refined = parabolicPeak(x: x, count: count, lag: bestLag, energy: energy)
            let f0 = sampleRate / refined
            guard f0 >= minFrequency, f0 <= maxFrequency else {
                return Estimate(f0: nil, confidence: 0)
            }
            return Estimate(f0: f0, confidence: Double(min(max(bestValue, 0), 1)))
        }
    }

    /// Linear RMS of a frame. Separate helper so callers can gate on energy
    /// before trusting a pitch estimate.
    func rms(_ samples: UnsafePointer<Float>, count: Int) -> Double {
        guard count > 0 else { return 0 }
        var value: Float = 0
        vDSP_rmsqv(samples, 1, &value, vDSP_Length(count))
        return Double(value)
    }

    // MARK: - Helpers

    /// Refines the integer peak lag using a parabola through r(lag-1), r(lag),
    /// r(lag+1). Returns a fractional lag.
    private func parabolicPeak(x: UnsafePointer<Float>, count: Int, lag: Int, energy: Float) -> Double {
        func r(_ l: Int) -> Float {
            guard l >= 1, l < count else { return 0 }
            var v: Float = 0
            vDSP_dotpr(x, 1, x + l, 1, &v, vDSP_Length(count - l))
            return v / energy
        }
        let a = r(lag - 1), b = r(lag), c = r(lag + 1)
        let denom = a - 2 * b + c
        guard denom != 0 else { return Double(lag) }
        let offset = 0.5 * Double(a - c) / Double(denom)
        return Double(lag) + offset
    }

    /// (Re)build the Hann window and scratch buffer when the frame size changes.
    private func ensureBuffers(count: Int) {
        guard window.count != count else { return }
        window = [Float](repeating: 0, count: count)
        windowed = [Float](repeating: 0, count: count)
        vDSP_hann_window(&window, vDSP_Length(count), Int32(vDSP_HANN_NORM))
    }
}

// MARK: - Note conversion

enum PitchMath {
    /// MIDI note number for a frequency (A4 = MIDI 69 = 440 Hz). Continuous.
    /// `nonisolated` so the realtime audio thread can call it.
    nonisolated static func midi(fromHz hz: Double) -> Double {
        69 + 12 * log2(hz / 440)
    }

    /// Splits a continuous MIDI value into its nearest semitone and the signed
    /// cents offset from it (−50...+50).
    nonisolated static func nearestNoteAndCents(fromMIDI midi: Double) -> (note: Int, cents: Double) {
        let note = Int(midi.rounded())
        let cents = (midi - Double(note)) * 100
        return (note, cents)
    }
}
