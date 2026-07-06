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

    /// An SF Symbol representing the genre, used on the genre browse cards.
    var symbol: String {
        switch self {
        case .popEnergetic: return "bolt.fill"
        case .balladSad:    return "cloud.rain.fill"
        case .upliftingJoy: return "sun.max.fill"
        case .chill:        return "moon.stars.fill"
        }
    }

    /// Best-effort mapping from free-form genre tag(s) — as reported by Apple
    /// Music (`genreNames`) or embedded in a local file's metadata — onto one of
    /// our four scoring buckets. Falls back to `.chill` when nothing matches.
    static func classify(from names: [String]) -> SongGenre {
        let text = names.joined(separator: " ").lowercased()
        func has(_ keywords: [String]) -> Bool { keywords.contains { text.contains($0) } }

        if has(["ballad", "sad", "blues", "melanchol", "slow", "emo", "requiem"]) { return .balladSad }
        if has(["dance", "edm", "electro", "house", "techno", "disco", "funk",
                "party", "gospel", "uplift", "happy", "joy", "reggae", "afrobeat"]) { return .upliftingJoy }
        if has(["pop", "rock", "metal", "punk", "hip hop", "hip-hop", "hiphop",
                "rap", "trap", "k-pop", "kpop", "dubstep", "energetic", "workout"]) { return .popEnergetic }
        if has(["chill", "lo-fi", "lofi", "r&b", "rnb", "soul", "jazz", "ambient",
                "acoustic", "indie", "folk", "neo", "classical", "downtempo"]) { return .chill }
        return .chill
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

/// Where a song's audio comes from — selects the PlaybackSource. Bundled and
/// imported are local PCM (suppressible); Apple Music is a DRM stream (not).
enum SongSourceKind: String, Codable, CaseIterable, Sendable {
    case bundled      // audioFileName in the app bundle
    case imported     // a user file, referenced by a security-scoped bookmark
    case appleMusic   // a MusicKit catalog/library item
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

    /// Audio source, stored raw for clean indexing. Has a default so adding it
    /// to the model is an automatic lightweight SwiftData migration (existing
    /// rows become `.bundled`) rather than a store-open failure.
    private var sourceKindRaw: String = SongSourceKind.bundled.rawValue

    /// Security-scoped bookmark for an imported file (nil for bundled/Apple Music).
    var importedBookmark: Data?

    /// Whether the user has starred this song. Defaults to false so adding it is
    /// an automatic lightweight SwiftData migration for existing rows.
    var isFavourite: Bool = false

    /// MusicKit item id for an Apple Music song (nil otherwise).
    var appleMusicID: String?
    
    /// MusicKit artwork image URL template as absolute string (nil otherwise).
    var artworkURLString: String?

    var genre: SongGenre {
        get { SongGenre(rawValue: genreRaw) ?? .chill }
        set { genreRaw = newValue.rawValue }
    }

    var source: SongSourceKind {
        get { SongSourceKind(rawValue: sourceKindRaw) ?? .bundled }
        set { sourceKindRaw = newValue.rawValue }
    }

    /// Resolves the imported file from its bookmark, starting security-scoped
    /// access. Callers are responsible for balancing `stopAccessingSecurityScopedResource`.
    var importedURL: URL? {
        guard let importedBookmark else { return nil }
        var stale = false
        // macOS sandbox requires security-scoped bookmarks; the resolve options
        // must match how the bookmark was created (see SongImporter).
        #if os(macOS)
        let options: URL.BookmarkResolutionOptions = [.withSecurityScope]
        #else
        let options: URL.BookmarkResolutionOptions = []
        #endif
        guard let url = try? URL(resolvingBookmarkData: importedBookmark,
                                 options: options,
                                 relativeTo: nil,
                                 bookmarkDataIsStale: &stale) else { return nil }
        _ = url.startAccessingSecurityScopedResource()
        return url
    }

    init(
        title: String,
        artist: String,
        audioFileName: String,
        audioFileExtension: String = "m4a",
        genre: SongGenre,
        lyrics: [LyricLine],
        source: SongSourceKind = .bundled,
        importedBookmark: Data? = nil,
        appleMusicID: String? = nil,
        artworkURLString: String? = nil
    ) {
        self.title = title
        self.artist = artist
        self.audioFileName = audioFileName
        self.audioFileExtension = audioFileExtension
        self.genreRaw = genre.rawValue
        self.lyrics = lyrics.sorted { $0.time < $1.time }
        self.sourceKindRaw = source.rawValue
        self.importedBookmark = importedBookmark
        self.appleMusicID = appleMusicID
        self.artworkURLString = artworkURLString
    }
}
