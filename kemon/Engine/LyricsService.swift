//
//  LyricsService.swift
//  kemon
//
//  Fetches synced (LRC) lyrics for songs that ship without them — chiefly
//  Apple Music tracks, whose lyrics MusicKit never exposes to third-party apps.
//
//  Strategy: try LRCLIB first (a stable, purpose-built, key-less synced-lyrics
//  service), then fall back to Lyrica's multi-source aggregator (Genius,
//  Musixmatch, NetEase, YT Music, …) for extra coverage. Both return standard
//  LRC text, which LyricsLoader already parses — so nothing new to parse here.
//
//  Everything is best-effort: any failure or no-match returns [], so the caller
//  simply shows no lyrics rather than erroring.
//

import Foundation

enum LyricsService {

    /// Fetches synced lyrics for `title`/`artist`. `duration` (seconds), when
    /// known, disambiguates between multiple LRCLIB matches of the same song.
    static func fetch(title: String, artist: String, duration: TimeInterval? = nil) async -> [LyricLine] {
        if let lines = await lrclib(title: title, artist: artist, duration: duration), !lines.isEmpty {
            return lines
        }
        if let lines = await lyrica(title: title, artist: artist), !lines.isEmpty {
            return lines
        }
        return []
    }

    // MARK: - LRCLIB (primary)

    private struct LRCLibHit: Decodable {
        let duration: Double?
        let instrumental: Bool
        let syncedLyrics: String?
    }

    private static func lrclib(title: String, artist: String, duration: TimeInterval?) async -> [LyricLine]? {
        var comps = URLComponents(string: "https://lrclib.net/api/search")
        comps?.queryItems = [URLQueryItem(name: "q", value: "\(title) \(artist)")]
        guard let url = comps?.url else { return nil }

        var request = URLRequest(url: url)
        // LRCLIB asks clients to identify themselves with a custom User-Agent.
        request.setValue("Kemon/1.0 (https://github.com/babono/kemon)",
                         forHTTPHeaderField: "User-Agent")

        guard let data = try? await URLSession.shared.data(for: request).0,
              let hits = try? JSONDecoder().decode([LRCLibHit].self, from: data) else {
            return nil
        }

        // Only synced, non-instrumental hits are useful for karaoke.
        let candidates = hits.filter { !$0.instrumental && !($0.syncedLyrics ?? "").isEmpty }
        guard !candidates.isEmpty else { return nil }

        // Prefer the hit whose duration is closest to the track we're playing.
        let best: LRCLibHit
        if let duration {
            best = candidates.min {
                abs(($0.duration ?? 0) - duration) < abs(($1.duration ?? 0) - duration)
            }!
        } else {
            best = candidates[0]
        }
        return LyricsLoader.parse(best.syncedLyrics ?? "")
    }

    // MARK: - Lyrica (fallback aggregator)

    private struct LyricaEnvelope: Decodable {
        let data: LyricaData?
        struct LyricaData: Decodable {
            let lyrics: String?
            let hasTimestamps: Bool?
        }
    }

    private static func lyrica(title: String, artist: String) async -> [LyricLine]? {
        var comps = URLComponents(string: "https://wilooper-lyrica.hf.space/lyrics/")
        comps?.queryItems = [
            URLQueryItem(name: "artist", value: artist),
            URLQueryItem(name: "song", value: title),
            URLQueryItem(name: "timestamps", value: "true"),
        ]
        guard let url = comps?.url else { return nil }

        guard let data = try? await URLSession.shared.data(from: url).0,
              let env = try? JSONDecoder().decode(LyricaEnvelope.self, from: data),
              env.data?.hasTimestamps == true,
              let lrc = env.data?.lyrics, !lrc.isEmpty else {
            return nil
        }
        return LyricsLoader.parse(lrc)
    }
}
