//
//  Emotion.swift
//  kemon
//
//  The vocabulary of expressions Kemon reasons about. These map to the FOUR
//  categories the Core ML model is trained on:
//
//      Happy   → .happy       (Pop / Dance / Upbeat)
//      Sad     → .sad         (Ballads / Melancholic / R&B)
//      Angry   → .energetic   (Rock / Metal / Rap — intense passion)
//      Neutral → .neutral     (baseline, calmly reading lyrics)
//
//  The label→emotion mapping (including Angry→energetic) lives in
//  CoreMLEmotionAnalyzer so the model's raw class names can differ in casing.
//

import Foundation

/// A single expression Kemon can recognise.
enum Emotion: String, CaseIterable, Codable, Identifiable, Sendable {
    case happy
    case sad
    case energetic
    case neutral

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .happy:     return "Happy"
        case .sad:       return "Sad"
        case .energetic: return "Energetic"
        case .neutral:   return "Neutral"
        }
    }

    /// SF Symbol used in the live feedback badge.
    var symbolName: String {
        switch self {
        case .happy:     return "face.smiling.inverse"
        case .sad:       return "cloud.rain.fill"
        case .energetic: return "bolt.fill"
        case .neutral:   return "face.dashed"
        }
    }
}

/// One classification result for one video frame.
///
/// `confidences` is the full probability vector so the ScoringMatrix can do a
/// soft comparison against the song's target profile instead of only looking at
/// the single winning label.
struct EmotionReading: Sendable {
    var dominant: Emotion
    var confidences: [Emotion: Double]
    var faceDetected: Bool
    /// Media time (audio clock) the reading corresponds to, when available.
    var mediaTime: TimeInterval
    /// Model-free smile score (0...1) from Vision landmark geometry.
    var smile: Double = 0

    static let empty = EmotionReading(
        dominant: .neutral,
        confidences: [.neutral: 1.0],
        faceDetected: false,
        mediaTime: 0
    )

    /// Convenience: confidence of a given emotion, 0 if absent.
    func confidence(of emotion: Emotion) -> Double {
        confidences[emotion] ?? 0
    }
}
