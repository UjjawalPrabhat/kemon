//
//  EmotionFusion.swift
//  kemon
//
//  Fuses raw per-frame emotion readings (Core ML confidences + a Vision smile
//  score) into a smoothed probability vector for scoring and the live badge.
//  Owns the exponential-moving-average state across frames so KemonEngine can
//  stay a wiring layer; `reset()` clears it between performances.
//

import Foundation

struct EmotionFusion {
    /// Per-emotion sensitivity applied to the raw model output before picking a
    /// winner. `happy` is carried mostly by Vision geometry (below), so this is
    /// a gentle nudge, not a crutch.
    private let sensitivity: [Emotion: Double] = [
        .happy:     1.2,
        .energetic: 1.3,
        .sad:       1.1,
        .neutral:   1.0,
    ]

    /// How much the geometric smile (Vision landmarks) vs the model contributes
    /// to `happy`. Vision leads, but not so hard it swamps the other emotions.
    /// Smiles below `smileGate` are ignored so a relaxed mouth doesn't drift
    /// into "happy".
    private let happyModelWeight  = 0.4
    private let happyVisionWeight = 0.6
    private let smileGate         = 0.35

    /// EMA weight for the newest frame (0–1). Lower = smoother/steadier badge,
    /// higher = snappier. Smoothing stops the label flickering frame-to-frame.
    private let smoothingFactor = 0.45
    private var smoothed: [Emotion: Double] = [:]

    /// Clears the smoothing history so a new performance starts fresh.
    mutating func reset() { smoothed = [:] }

    /// Fuses one face-present frame into a smoothed reading (dominant label +
    /// full probability vector). The caller guards `faceDetected`.
    mutating func fuse(_ reading: EmotionReading) -> EmotionReading {
        // Sensitivity-scale the classifier, then fuse the gated Vision smile
        // into `happy` (which the static-image model reads weakly while singing).
        var calibrated: [Emotion: Double] = [:]
        for e in Emotion.allCases {
            calibrated[e] = reading.confidence(of: e) * (sensitivity[e] ?? 1)
        }
        let gatedSmile = reading.smile < smileGate ? 0 : reading.smile
        calibrated[.happy] = calibrated[.happy]! * happyModelWeight
                           + gatedSmile * happyVisionWeight

        // Renormalise to a probability vector.
        let total = calibrated.values.reduce(0, +)
        if total > 0 { for e in Emotion.allCases { calibrated[e]! /= total } }

        // Exponential moving average over recent frames.
        for e in Emotion.allCases {
            let prev = smoothed[e] ?? calibrated[e]!
            smoothed[e] = prev * (1 - smoothingFactor) + calibrated[e]! * smoothingFactor
        }

        let dominant = smoothed.max { $0.value < $1.value }?.key ?? .neutral
        return EmotionReading(
            dominant: dominant,
            confidences: smoothed,
            faceDetected: true,
            smile: reading.smile
        )
    }
}
