//
//  Song.swift
//  kemon
//
//  The persisted catalog item. A song owns its bundled instrumental,
//  its timed lyrics, and a genre that defines the "target vibe" the
//  singer is scored against.
//

import Foundation
import SwiftData

/// The emotional target a genre asks the singer to hit.
enum SongGenre: String, Codable, CaseIterable, Sendable {
    case popEnergetic
    case balladSad
    case upliftingJoy
    case chill

    var displayName: String {
        switch self {
        case .popEnergetic: return "Energetic Pop"
        case .balladSad:    return "Sad Ballad"
        case .upliftingJoy: return "Uplifting"
        case .chill:        return "Chill"
        }
    }

    /// Weighted profile over emotions the singer should express for this genre.
    /// Weights need not sum to 1 — the ScoringMatrix normalises via cosine
    /// similarity, so only the *shape* matters.
    var targetProfile: [Emotion: Double] {
        switch self {
        case .popEnergetic: return [.energetic: 1.0, .happy: 0.6]
        case .balladSad:    return [.sad: 1.0]
        case .upliftingJoy: return [.happy: 1.0, .energetic: 0.4]
        case .chill:        return [.neutral: 1.0, .happy: 0.3]
        }
    }
}

/// One timestamped lyric line. Stored inline in the Song model.
struct LyricLine: Codable, Hashable, Sendable {
    /// Seconds from the start of the track when this line begins.
    var time: TimeInterval
    var text: String
}

@Model
final class Song {
    var title: String
    var artist: String

    /// Bundled audio resource name WITHOUT extension (e.g. "demo_pop").
    /// Add the matching .m4a/.mp3 to the app bundle; playback no-ops if missing
    /// so the rest of the pipeline still runs during development.
    var audioFileName: String
    var audioFileExtension: String

    /// Stored as the raw value so SwiftData indexes it cleanly.
    private var genreRaw: String

    /// SwiftData persists arrays of Codable structs directly.
    var lyrics: [LyricLine]

    var genre: SongGenre {
        get { SongGenre(rawValue: genreRaw) ?? .chill }
        set { genreRaw = newValue.rawValue }
    }

    init(
        title: String,
        artist: String,
        audioFileName: String,
        audioFileExtension: String = "m4a",
        genre: SongGenre,
        lyrics: [LyricLine]
    ) {
        self.title = title
        self.artist = artist
        self.audioFileName = audioFileName
        self.audioFileExtension = audioFileExtension
        self.genreRaw = genre.rawValue
        self.lyrics = lyrics.sorted { $0.time < $1.time }
    }
}
