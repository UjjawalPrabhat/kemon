//
//  AppleMusicSearchView.swift
//  kemon
//
//  Searches the Apple Music catalog and adds a chosen track to Kemon's catalog
//  as an `.appleMusic` Song, which then flows through the normal karaoke
//  session (played full-mix — no vocal suppression is possible on DRM audio).
//
//  Requires the MusicKit capability on the App ID and an Apple Music
//  subscription on a real device; on Simulator / without a subscription the
//  search and playback won't work.
//

import SwiftUI
import SwiftData

#if canImport(MusicKit)
import MusicKit

struct AppleMusicSearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var authorization = MusicAuthorization.currentStatus
    @State private var term = ""
    @State private var results: [MusicKit.Song] = []
    @State private var isSearching = false
    @State private var addedID: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Apple Music")
                .navigationBarTitleDisplayModeInlineIfAvailable()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .task { await requestAuthorizationIfNeeded() }
    }

    @ViewBuilder
    private var content: some View {
        switch authorization {
        case .authorized:
            searchList
        case .notDetermined:
            ProgressView("Requesting access…")
        default:
            unavailable
        }
    }

    private var searchList: some View {
        List {
            ForEach(results, id: \.id) { song in
                Button {
                    add(song)
                } label: {
                    row(for: song)
                }
                .disabled(addedID == song.id.rawValue)
            }
        } // List
        .overlay {
            if results.isEmpty {
                ContentUnavailableView(
                    isSearching ? "Searching…" : "Search Apple Music",
                    systemImage: "magnifyingglass",
                    description: Text("Find a song to sing. It plays full-mix; use headphones so the mic hears only you.")
                )
            }
        }
        .searchable(text: $term, prompt: "Songs on Apple Music")
        .onSubmit(of: .search) { Task { await search() } }
    }

    private func row(for song: MusicKit.Song) -> some View {
        HStack(spacing: 12) {
            if let artwork = song.artwork {
                ArtworkImage(artwork, width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: "music.note")
                    .frame(width: 44, height: 44)
                    .background(.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title).font(.headline)
                Text(song.artistName).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: addedID == song.id.rawValue ? "checkmark.circle.fill" : "plus.circle")
                .foregroundStyle(addedID == song.id.rawValue ? Color.green : Color.accentColor)
        }
    }

    private var unavailable: some View {
        ContentUnavailableView {
            Label("Apple Music not available", systemImage: "music.note.list")
        } description: {
            Text("Enable the MusicKit capability and sign in to an Apple Music subscription on a real device to sing along to Apple Music songs.")
        }
    }

    // MARK: - Actions

    private func requestAuthorizationIfNeeded() async {
        guard authorization == .notDetermined else { return }
        authorization = await MusicAuthorization.request()
    }

    private func search() async {
        let query = term.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { results = []; return }
        isSearching = true
        defer { isSearching = false }
        do {
            var request = MusicCatalogSearchRequest(term: query, types: [MusicKit.Song.self])
            request.limit = 25
            let response = try await request.response()
            results = Array(response.songs)
        } catch {
            results = []
        }
    }

    /// Adds the track to Kemon's catalog. Genre defaults to `.chill` (a neutral
    /// emotion target) since we can't know an arbitrary track's mood.
    private func add(_ song: MusicKit.Song) {
        let newSong = Song(
            title: song.title,
            artist: song.artistName,
            audioFileName: "",
            genre: .chill,
            lyrics: [],
            source: .appleMusic,
            appleMusicID: song.id.rawValue
        )
        modelContext.insert(newSong)
        try? modelContext.save()
        addedID = song.id.rawValue
    }
}

private extension View {
    @ViewBuilder
    func navigationBarTitleDisplayModeInlineIfAvailable() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
#endif
