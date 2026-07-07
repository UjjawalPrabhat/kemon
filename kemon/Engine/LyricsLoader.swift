//
//  LyricsLoader.swift
//  kemon
//
//  Loads timed lyrics from a bundled `.lrc` file (the standard synced-lyrics
//  karaoke format) so lyrics stay decoupled from code and you can drop in
//  properly-sourced/licensed lyrics per song.
//
//  LRC format (one line per lyric, timestamp in [mm:ss.xx]):
//      [00:12.30]First line of the song
//      [00:16.80]Second line
//  Optional metadata tags like [ti:], [ar:], [offset:] are ignored except
//  [offset:] (milliseconds, shifts every timestamp — handy to nudge sync).
//
//  Put `<audioFileName>.lrc` next to the audio in kemon/Resources/.
//

import Foundation

enum LyricsLoader {

    /// Resolves lyrics for a song: a bundled `.lrc` file wins; otherwise the
    /// lyrics stored on the model (empty for the seeded catalog).
    static func lyrics(for song: Song) -> [LyricLine] {
        if let fromFile = loadLRC(named: song.audioFileName), !fromFile.isEmpty {
            return fromFile
        }
        return song.lyrics
    }

    /// Fetches synced lyrics off the network for songs that have none locally.
    /// Only Apple Music songs qualify — bundled/imported songs rely on their
    /// `.lrc` so the timing matches the actual recording. Returns [] otherwise.
    static func remoteLyrics(for song: Song) async -> [LyricLine] {
        guard song.source == .appleMusic else { return [] }
        return await LyricsService.fetch(title: song.title, artist: song.artist)
    }

    /// Parses `<name>.lrc` from the app bundle. Returns nil if the file is absent.
    static func loadLRC(named name: String) -> [LyricLine]? {
        // An empty name (e.g. an Apple Music song, which has no bundled audio)
        // must NOT be looked up: `Bundle.url(forResource: "", ...)` returns the
        // first `.lrc` in the bundle, which would show another song's lyrics.
        guard !name.isEmpty else { return nil }
        guard let url = Bundle.main.url(forResource: name, withExtension: "lrc"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        return parse(text)
    }

    /// Parses LRC text into sorted lyric lines.
    static func parse(_ text: String) -> [LyricLine] {
        var offset: TimeInterval = 0
        var lines: [LyricLine] = []

        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            // [offset:+/-milliseconds] metadata tag.
            if let ms = metadataInt(in: line, tag: "offset") {
                offset = TimeInterval(ms) / 1000.0
                continue
            }

            let (stamps, content) = timestamps(in: line)
            guard !stamps.isEmpty else { continue }
            let cleaned = content.trimmingCharacters(in: .whitespaces)
            for stamp in stamps {
                lines.append(LyricLine(time: max(0, stamp + offset), text: cleaned))
            }
        }
        return lines.sorted { $0.time < $1.time }
    }

    // MARK: - Parsing helpers

    /// Extracts all `[mm:ss.xx]` timestamps at the head of a line and returns
    /// the remaining lyric text.
    private static func timestamps(in line: String) -> (times: [TimeInterval], text: String) {
        var times: [TimeInterval] = []
        var rest = Substring(line)

        while rest.first == "[" {
            guard let close = rest.firstIndex(of: "]") else { break }
            let inside = rest[rest.index(after: rest.startIndex)..<close]
            if let seconds = parseTimestamp(String(inside)) {
                times.append(seconds)
                rest = rest[rest.index(after: close)...]
            } else {
                break // a non-time tag like [ti:...] — stop consuming stamps
            }
        }
        return (times, String(rest))
    }

    /// "mm:ss.xx" or "mm:ss" → seconds. Returns nil for non-time tags.
    private static func parseTimestamp(_ s: String) -> TimeInterval? {
        let parts = s.split(separator: ":")
        guard parts.count == 2,
              let minutes = Double(parts[0]),
              let seconds = Double(parts[1]) else { return nil }
        return minutes * 60 + seconds
    }

    private static func metadataInt(in line: String, tag: String) -> Int? {
        let prefix = "[\(tag):"
        guard line.hasPrefix(prefix), line.hasSuffix("]") else { return nil }
        let value = line.dropFirst(prefix.count).dropLast()
        return Int(value.trimmingCharacters(in: .whitespaces))
    }
}

extension String {
    /// A Latin transliteration of this string (e.g. Japanese/Korean/Cyrillic →
    /// romanised), diacritics stripped. Returns the original when it can't be
    /// transformed. Used to offer a "romanize" toggle for non-Latin lyrics.
    var romanizedLatin: String {
        applyingTransform(.toLatin, reverse: false)?
            .applyingTransform(.stripDiacritics, reverse: false) ?? self
    }

    /// True when romanising actually changes the string, i.e. it contains
    /// non-Latin script worth offering a toggle for.
    var containsNonLatinScript: Bool {
        guard let transformed = applyingTransform(.toLatin, reverse: false) else { return false }
        return transformed != self
    }
}
