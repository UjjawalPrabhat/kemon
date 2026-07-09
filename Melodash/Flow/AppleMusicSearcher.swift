//
//  AppleMusicSearcher.swift
//  Melodash
//
//  Reusable, debounced Apple Music catalog search. Shared by the sidebar Search
//  tab in SongPickView (inline results) and available to any other caller. Adds
//  a chosen catalog track to the local catalog as an `.appleMusic` Song, storing
//  its duration and browse genre alongside title/artist/artwork.
//

import SwiftUI
import SwiftData

#if canImport(MusicKit)
import MusicKit

@MainActor
@Observable
final class AppleMusicSearcher {
    var authorization = MusicAuthorization.currentStatus
    private(set) var results: [MusicKit.Song] = []
    private(set) var isSearching = false
    private(set) var errorText: String?

    /// Tracks the in-flight debounce task so a keystroke cancels the old one.
    private var debounceTask: Task<Void, Never>?

    func requestAuthorizationIfNeeded() async {
        guard authorization == .notDetermined else { return }
        authorization = await MusicAuthorization.request()
    }

    /// Debounced entry point — call on every keystroke.
    func schedule(term: String) {
        debounceTask?.cancel()
        let query = term
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await self?.search(query: query)
        }
    }

    func search(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard authorization == .authorized, !trimmed.isEmpty else {
            results = []; errorText = nil; return
        }
        isSearching = true
        errorText = nil
        defer { isSearching = false }
        do {
            var request = MusicCatalogSearchRequest(term: trimmed, types: [MusicKit.Song.self])
            request.limit = 20
            let response = try await request.response()
            guard !Task.isCancelled else { return }
            results = Array(response.songs)
        } catch {
            guard !Task.isCancelled else { return }
            results = []
            errorText = error.localizedDescription
        }
    }

    func clear() {
        debounceTask?.cancel()
        results = []
        errorText = nil
    }

    /// Inserts the chosen catalog song into the local catalog, capturing its
    /// duration and browse genre. Returns the created Song.
    @discardableResult
    func add(_ song: MusicKit.Song, into context: ModelContext) -> Song {
        let newSong = Song(
            title: song.title,
            artist: song.artistName,
            audioFileName: "",
            genre: SongGenre.classify(from: song.genreNames),
            lyrics: [],
            source: .appleMusic,
            appleMusicID: song.id.rawValue,
            artworkURLString: song.artwork?.url(width: 300, height: 300)?.absoluteString,
            durationSeconds: song.duration,
            displayGenre: DisplayGenre.classify(from: song.genreNames)
        )
        context.insert(newSong)
        try? context.save()
        return newSong
    }
}
#endif
