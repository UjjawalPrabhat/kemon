//
//  SongImporter.swift
//  Melodash
//
//  Imports a user-picked local audio file into the catalog as an `.imported`
//  Song. Reads title / artist / genre from the file's embedded metadata (with
//  filename fallbacks) and auto-classifies the genre into one of our scoring
//  buckets. The file is re-opened across launches via a security-scoped
//  bookmark — see `Song.importedURL`.
//

import Foundation
import SwiftData
import AVFoundation
import UniformTypeIdentifiers

enum SongImporter {

    /// Audio file types the picker accepts.
    static let contentTypes: [UTType] = [.audio, .mp3, .mpeg4Audio, .wav, .aiff]

    /// Imports the file at `url` into `context`. Returns the created Song, or
    /// nil if a security-scoped bookmark couldn't be made (without it the file
    /// won't be reachable on a later launch).
    @MainActor
    @discardableResult
    static func importFile(at url: URL, into context: ModelContext) async -> Song? {
        let didScope = url.startAccessingSecurityScopedResource()
        defer { if didScope { url.stopAccessingSecurityScopedResource() } }

        #if os(macOS)
        let bookmark = try? url.bookmarkData(options: [.withSecurityScope],
                                             includingResourceValuesForKeys: nil,
                                             relativeTo: nil)
        #else
        let bookmark = try? url.bookmarkData(options: [],
                                             includingResourceValuesForKeys: nil,
                                             relativeTo: nil)
        #endif
        guard let bookmark else { return nil }

        let meta = await readMetadata(url: url)

        let song = Song(
            title: meta.title,
            artist: meta.artist,
            audioFileName: url.deletingPathExtension().lastPathComponent,
            audioFileExtension: url.pathExtension.isEmpty ? "m4a" : url.pathExtension,
            genre: SongGenre.classify(from: meta.genreNames),
            lyrics: [],
            source: .imported,
            importedBookmark: bookmark,
            durationSeconds: meta.duration,
            displayGenre: DisplayGenre.classify(from: meta.genreNames)
        )
        context.insert(song)
        try? context.save()
        return song
    }

    // MARK: - Metadata

    private struct Meta {
        var title: String
        var artist: String
        var genreNames: [String]
        var duration: Double?
    }

    private static func readMetadata(url: URL) async -> Meta {
        var title = url.deletingPathExtension().lastPathComponent
        var artist = "Local file"
        var genreNames: [String] = []

        let asset = AVURLAsset(url: url)

        // Track length, when readable.
        var duration: Double? = nil
        if let cm = try? await asset.load(.duration) {
            let seconds = CMTimeGetSeconds(cm)
            if seconds.isFinite, seconds > 0 { duration = seconds }
        }

        // Title / artist live in common metadata across formats.
        if let common = try? await asset.load(.commonMetadata) {
            for item in common {
                switch item.commonKey {
                case .commonKeyTitle:
                    if let v = try? await item.load(.stringValue), !v.isEmpty { title = v }
                case .commonKeyArtist:
                    if let v = try? await item.load(.stringValue), !v.isEmpty { artist = v }
                default:
                    break
                }
            }
        }

        // Genre tags are format-specific (ID3 TCON, iTunes genre, QuickTime).
        let genreIDs: Set<AVMetadataIdentifier> = [
            .id3MetadataContentType,
            .iTunesMetadataUserGenre,
            .iTunesMetadataPredefinedGenre,
            .quickTimeMetadataGenre
        ]
        if let formats = try? await asset.load(.availableMetadataFormats) {
            for format in formats {
                guard let items = try? await asset.loadMetadata(for: format) else { continue }
                for item in items where item.identifier.map(genreIDs.contains) ?? false {
                    if let v = try? await item.load(.stringValue), !v.isEmpty {
                        genreNames.append(v)
                    }
                }
            }
        }

        return Meta(title: title, artist: artist, genreNames: genreNames, duration: duration)
    }
}
