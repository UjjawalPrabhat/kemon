//
//  PitchDetector.swift
//  Melodash
//
//  Pure DSP: estimates the fundamental frequency of a mono frame using
//  autocorrelation, computed the fast way via the Wiener–Khinchin theorem —
//  autocorrelation = IFFT(|FFT(x)|²). This is O(N log N) instead of the naive
//  O(N·lags) time-domain sum, which matters because `detect` runs on the
//  realtime audio-tap thread for every window while singing.
//
//  No UIKit, no actor state; all buffers and the FFT setup are preallocated so
//  `detect` allocates nothing in steady state. YIN or an FFT-cepstrum could
//  replace this type behind the same `detect` signature without touching callers.
//

import Accelerate

/// Estimates fundamental frequency from mono Float samples.
///
/// `nonisolated`/`@unchecked Sendable`: it runs on the realtime audio-tap
/// thread, and its buffers/FFT setup are only ever touched from that one thread.
nonisolated final class PitchDetector: @unchecked Sendable {

    /// Musical range we search, in Hz. Covers low male (~80 Hz) to high
    /// soprano/whistle onset (~1100 Hz); restricting the lag search avoids
    /// spurious sub-harmonic peaks.
    private let minFrequency: Double = 70
    private let maxFrequency: Double = 1100

    // FFT state, (re)built only when the frame size changes.
    private var n = 0                  // window length (samples)
    private var m = 0                  // FFT length: smallest power of two ≥ 2n
    private var log2n: vDSP_Length = 0
    private var fftSetup: FFTSetup?

    // Preallocated scratch. hann/windowed are length n; the complex FFT buffers
    // and power spectrum are length m.
    private var hann: UnsafeMutablePointer<Float>?
    private var windowed: UnsafeMutablePointer<Float>?
    private var realp: UnsafeMutablePointer<Float>?
    private var imagp: UnsafeMutablePointer<Float>?
    private var power: UnsafeMutablePointer<Float>?

    /// Result of a single-frame estimate.
    struct Estimate {
        var f0: Double?
        var confidence: Double
    }

    deinit {
        if let fftSetup { vDSP_destroy_fftsetup(fftSetup) }
        hann?.deallocate()
        windowed?.deallocate()
        realp?.deallocate()
        imagp?.deallocate()
        power?.deallocate()
    }

    /// Estimate f0 for `count` mono samples. `sampleRate` MUST be the real input
    /// rate (Bluetooth often forces 16/24 kHz) — the lag→Hz conversion depends
    /// on it.
    func detect(_ samples: UnsafePointer<Float>, count: Int, sampleRate: Double) -> Estimate {
        guard count >= 256, sampleRate > 0 else { return Estimate(f0: nil, confidence: 0) }
        ensureBuffers(count: count)
        guard let hann, let windowed, let realp, let imagp, let power, let fftSetup else {
            return Estimate(f0: nil, confidence: 0)
        }

        let stride = MemoryLayout<Float>.stride

        // Hann-window the frame to reduce edge discontinuity.
        vDSP_vmul(samples, 1, hann, 1, windowed, 1, vDSP_Length(count))

        // Load into the complex FFT input, zero-padded to m ≥ 2n. Zero-padding
        // makes the (circular) FFT autocorrelation equal the linear one for every
        // lag we search.
        memset(realp, 0, m * stride)
        memset(imagp, 0, m * stride)
        memcpy(realp, windowed, count * stride)

        // autocorrelation = IFFT(|FFT(x)|²).
        var split = DSPSplitComplex(realp: realp, imagp: imagp)
        vDSP_fft_zip(fftSetup, &split, 1, log2n, FFTDirection(kFFTDirection_Forward))
        vDSP_zvmags(&split, 1, power, 1, vDSP_Length(m))   // power = |X|²
        memcpy(realp, power, m * stride)                    // real ← power spectrum
        memset(imagp, 0, m * stride)                        // imag ← 0
        vDSP_fft_zip(fftSetup, &split, 1, log2n, FFTDirection(kFFTDirection_Inverse))
        // realp[lag] now holds the unnormalised autocorrelation; realp[0] = energy.
        // Normalising by realp[0] cancels the IFFT's unscaled factor, so the
        // confidence stays 0...1 exactly as the old time-domain version.

        let energy = realp[0]
        guard energy > 0 else { return Estimate(f0: nil, confidence: 0) }

        let maxLag = min(count - 1, Int(sampleRate / minFrequency))
        let minLag = max(1, Int(sampleRate / maxFrequency))
        guard maxLag > minLag else { return Estimate(f0: nil, confidence: 0) }

        // Accept the first strong local maximum rather than the global one, so we
        // lock onto the true period instead of a higher-lag harmonic of it.
        var bestLag = -1
        var bestValue: Float = 0
        var prev: Float = 0      // r(lag-1)
        var prevPrev: Float = 0  // r(lag-2)
        for lag in minLag...maxLag {
            let r = realp[lag] / energy
            if prev > prevPrev && prev >= r && prev > bestValue && (lag - 1) >= minLag {
                bestValue = prev
                bestLag = lag - 1
                if bestValue > 0.9 { break } // clearly periodic — stop early
            }
            prevPrev = prev
            prev = r
        }

        guard bestLag > 0, bestValue > 0 else { return Estimate(f0: nil, confidence: 0) }

        // Parabolic interpolation using the autocorrelation values we already have
        // (O(1) — no extra dot products).
        let refined = parabolicPeak(realp, lag: bestLag, energy: energy)
        let f0 = sampleRate / refined
        guard f0 >= minFrequency, f0 <= maxFrequency else {
            return Estimate(f0: nil, confidence: 0)
        }
        return Estimate(f0: f0, confidence: Double(min(max(bestValue, 0), 1)))
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

    /// Refines the integer peak lag using a parabola through r(lag-1..+1).
    private func parabolicPeak(_ r: UnsafePointer<Float>, lag: Int, energy: Float) -> Double {
        let a = r[lag - 1] / energy
        let b = r[lag] / energy
        let c = r[lag + 1] / energy
        let denom = a - 2 * b + c
        guard denom != 0 else { return Double(lag) }
        return Double(lag) + 0.5 * Double(a - c) / Double(denom)
    }

    /// (Re)builds the FFT setup, Hann window, and scratch buffers when the frame
    /// size changes (typically once, on the first frame).
    private func ensureBuffers(count: Int) {
        guard n != count else { return }

        if let fftSetup { vDSP_destroy_fftsetup(fftSetup) }
        hann?.deallocate()
        windowed?.deallocate()
        realp?.deallocate()
        imagp?.deallocate()
        power?.deallocate()

        n = count
        var length = 1
        var log: vDSP_Length = 0
        while length < 2 * count { length <<= 1; log += 1 }
        m = length
        log2n = log
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))

        let h = UnsafeMutablePointer<Float>.allocate(capacity: count)
        vDSP_hann_window(h, vDSP_Length(count), Int32(vDSP_HANN_NORM))
        hann = h
        windowed = .allocate(capacity: count)
        realp = .allocate(capacity: m)
        imagp = .allocate(capacity: m)
        power = .allocate(capacity: m)
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
