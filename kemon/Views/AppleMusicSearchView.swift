//
//  AppleMusicSearchView.swift
//  kemon
//
//  Searches the Apple Music catalog and adds a chosen track to Kemon's catalog
//  as an `.appleMusic` Song. Styled in outerspace theme.
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
    @State private var errorText: String?
    @State private var addedID: String?

    /// Tracks the in-flight debounce task so a keystroke cancels the old one.
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                searchField
                content
            }
            .padding(20)
            .kemonPage(showPlanet: false, showCockpit: false)
            .navigationTitle("Apple Music")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color(red: 0.4, green: 0.8, blue: 1.0))
                }
            }
        }
        .preferredColorScheme(.dark) // Force dark mode so all text is visible on the space theme
        #if os(macOS)
        .frame(width: 600, height: 680)
        #endif
        .task { await requestAuthorizationIfNeeded() }
    }

    // MARK: - Search field

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.6))
            TextField("Search artist, title, album", text: $term)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .onChange(of: term) { _, newValue in scheduleSearch(newValue) }
                .onSubmit {
                    debounceTask?.cancel()
                    Task { await search(query: term) }
                }
            
            if isSearching {
                ProgressView().controlSize(.small)
            } else if !term.isEmpty {
                Button { term = ""; results = [] } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .kemonGlassCard(16)
        .disabled(authorization != .authorized)
    }

    // MARK: - Content states

    @ViewBuilder
    private func content(for auth: MusicAuthorization.Status) -> some View {
        switch auth {
        case .authorized:
            if let errorText {
                errorState(errorText)
            } else if results.isEmpty {
                emptyState
            } else {
                resultList
            }
        case .notDetermined:
            Spacer()
            ProgressView("Requesting access…")
                .foregroundStyle(.white)
            Spacer()
        default:
            unavailable
        }
    }

    @ViewBuilder
    private var content: some View {
        content(for: authorization)
    }

    private var resultList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(results, id: \.id) { song in
                    Button { add(song) } label: { row(for: song) }
                        .buttonStyle(.plain)
                        .disabled(addedID == song.id.rawValue)
                }
            }
        }
    }

    private func row(for song: MusicKit.Song) -> some View {
        HStack(spacing: 12) {
            if let artwork = song.artwork {
                ArtworkImage(artwork, width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "music.note")
                    .frame(width: 48, height: 48)
                    .foregroundStyle(.white)
                    .background(Color(red: 0.4, green: 0.8, blue: 1.0).opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(song.artistName)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            Spacer()
            
            Image(systemName: addedID == song.id.rawValue ? "checkmark.circle.fill" : "plus.circle")
                .font(.title2)
                .foregroundStyle(addedID == song.id.rawValue ? Color.green : Color(red: 0.4, green: 0.8, blue: 1.0))
        }
        .padding(12)
        .kemonGlassCard(14)
    }

    private var emptyState: some View {
        infoBox(
            icon: "magnifyingglass",
            title: term.isEmpty ? "Search Apple Music" : "No results",
            message: term.isEmpty
                ? "Find a song to sing. It plays full-mix — use headphones so the mic hears only you."
                : "Nothing matched “\(term)”. Try another artist or title."
        )
    }

    private func errorState(_ text: String) -> some View {
        infoBox(
            icon: "exclamationmark.triangle.fill",
            title: "Couldn't reach Apple Music",
            message: "\(text)\n\nCatalog search needs the MusicKit capability on the app (Xcode → Signing & Capabilities → + Capability → MusicKit) and an Apple Music subscription signed in on this Mac.",
            tint: .orange
        )
    }

    private var unavailable: some View {
        infoBox(
            icon: "music.note.list",
            title: "Apple Music not available",
            message: "Allow Apple Music access, sign in to an Apple Music subscription, and enable the MusicKit capability to sing along to catalog songs. Bundled songs work without any of this.",
            tint: .orange
        )
    }

    private func infoBox(icon: String, title: String, message: String, tint: Color = .secondary) -> some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: icon).font(.system(size: 44)).foregroundStyle(tint)
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            Text(message)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func requestAuthorizationIfNeeded() async {
        guard authorization == .notDetermined else { return }
        authorization = await MusicAuthorization.request()
    }

    private func scheduleSearch(_ newValue: String) {
        debounceTask?.cancel()
        let query = newValue
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await search(query: query)
        }
    }

    /// Explicit query so the debounce closure captures the value at scheduling time.
    private func search(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { results = []; errorText = nil; return }
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

    private func add(_ song: MusicKit.Song) {
        let newSong = Song(
            title: song.title,
            artist: song.artistName,
            audioFileName: "",
            genre: SongGenre.classify(from: song.genreNames),
            lyrics: [],
            source: .appleMusic,
            appleMusicID: song.id.rawValue,
            artworkURLString: song.artwork?.url(width: 300, height: 300)?.absoluteString
        )
        modelContext.insert(newSong)
        try? modelContext.save()
        addedID = song.id.rawValue
    }
}
#endif
