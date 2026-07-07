//
//  ScoringMatrix.swift
//  kemon
//
//  On-device "vibe matching". Each frame's emotion vector is compared against
//  the song genre's target profile via cosine similarity, and the running mean
//  becomes the final 0–100 score. All native Swift, no cloud round-trip.
//

import Foundation

struct ScoringMatrix {
    private(set) var accumulatedSimilarity: Double = 0
    /// Number of ingested frames where a face was actually found.
    private(set) var facePresenceCount: Int = 0

    mutating func ingest(_ reading: EmotionReading, genre: SongGenre) {
        guard reading.faceDetected else { return }
        facePresenceCount += 1
        accumulatedSimilarity += Self.cosineSimilarity(
            reading.confidences,
            genre.targetProfile
        )
    }

    mutating func reset() {
        accumulatedSimilarity = 0
        facePresenceCount = 0
    }

    /// Mean similarity over frames where a face was present, as 0–100.
    var normalizedScore: Int {
        guard facePresenceCount > 0 else { return 0 }
        return Int((accumulatedSimilarity / Double(facePresenceCount) * 100).rounded())
    }

    // MARK: - Math

    /// Cosine similarity between two sparse emotion vectors over the full
    /// `Emotion` basis. Returns 0...1 (values are non-negative probabilities).
    static func cosineSimilarity(_ a: [Emotion: Double], _ b: [Emotion: Double]) -> Double {
        var dot = 0.0, normA = 0.0, normB = 0.0
        for emotion in Emotion.allCases {
            let x = a[emotion] ?? 0
            let y = b[emotion] ?? 0
            dot += x * y
            normA += x * x
            normB += y * y
        }
        guard normA > 0, normB > 0 else { return 0 }
        return dot / (normA.squareRoot() * normB.squareRoot())
    }
}
