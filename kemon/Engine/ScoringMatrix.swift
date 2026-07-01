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
    private(set) var sampleCount: Int = 0
    /// Fraction of ingested frames where a face was actually found.
    private(set) var facePresenceCount: Int = 0

    /// Similarity of the most recent frame, 0...1 — drives live UI feedback.
    private(set) var lastSimilarity: Double = 0

    mutating func ingest(_ reading: EmotionReading, genre: SongGenre) {
        sampleCount += 1
        guard reading.faceDetected else {
            lastSimilarity = 0
            return
        }
        facePresenceCount += 1
        let similarity = Self.cosineSimilarity(
            reading.confidences,
            genre.targetProfile
        )
        lastSimilarity = similarity
        accumulatedSimilarity += similarity
    }

    mutating func reset() {
        accumulatedSimilarity = 0
        sampleCount = 0
        facePresenceCount = 0
        lastSimilarity = 0
    }

    /// Mean similarity over frames where a face was present, as 0–100.
    var normalizedScore: Int {
        guard facePresenceCount > 0 else { return 0 }
        return Int((accumulatedSimilarity / Double(facePresenceCount) * 100).rounded())
    }

    func summary(for song: Song) -> String {
        let score = normalizedScore
        let vibe = song.genre.displayName.lowercased()
        switch score {
        case 85...:
            return "You nailed the \(vibe) vibe of \"\(song.title)\"! Score: \(score)%"
        case 65..<85:
            return "Strong performance — you mostly matched the \(vibe) energy. Score: \(score)%"
        case 40..<65:
            return "You found the vibe in flashes. Lean further into it next time. Score: \(score)%"
        default:
            return "The expression didn't quite match the \(vibe) mood yet. Score: \(score)%"
        }
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
