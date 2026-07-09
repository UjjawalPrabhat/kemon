//
//  SongPickView.swift
//  Melodash
//
//  "Pick the song!" — the current singer chooses a track. A premium space
//  dashboard with a left sidebar (Browse / Library tabs + Lobby + Add Song) and
//  a Discover feed, an inline Search that spans the local catalog *and* Apple
//  Music, a browse-by-genre grid, Favorites, and Your Songs.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SongPickView: View {
    var battle: BattleController

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Song.title) private var songs: [Song]
    @State private var search = ""
    @State private var activeTab: ActiveTab = .discover

    /// Songs highlighted at the top of Discover — a random slice of the catalog,
    /// chosen once when the screen appears.
    @State private var topHits: [Song] = []
    /// The genre the user has drilled into on the Genre tab (nil = grid of genres).
    @State private var selectedGenre: DisplayGenre?
    /// Local-file import state.
    @State private var showingFileImporter = false
    @State private var importError: String?
    @State private var isImporting = false

    #if canImport(MusicKit)
    @State private var musicSearcher = AppleMusicSearcher()
    #endif

    enum ActiveTab {
        case discover
        case search
        case genre
        case favorites
        case yourSongs
    }

    private var favorites: [Song] { songs.filter(\.isFavorite) }
    private var yourSongs: [Song] { songs.filter { $0.source == .imported } }

    /// Browse genres that actually have songs, in display order.
    private var populatedGenres: [DisplayGenre] {
        DisplayGenre.browseOrder.filter { genre in songs.contains { $0.displayGenre == genre } }
    }

    private var filtered: [Song] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return songs }
        return songs.filter {
            $0.title.lowercased().contains(q) || $0.artist.lowercased().contains(q)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebarView
            mainContentView
        }
        .foregroundStyle(.white)
        .melodashPage(showPlanet: false, showCockpit: false)
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: SongImporter.contentTypes,
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert("Couldn't add that file", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "")
        }
        .onAppear {
            if topHits.isEmpty { topHits = Array(songs.shuffled().prefix(8)) }
        }
    }

    // MARK: - Local file upload

    private var addSongButton: some View {
        Button {
            showingFileImporter = true
        } label: {
            HStack(spacing: 10) {
                if isImporting {
                    ProgressView().controlSize(.small).tint(.white)
                } else {
                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.system(size: 14, weight: .bold))
                }
                Text(isImporting ? "ADDING…" : "ADD SONG")
                    .font(.orbitronBold(size: 12))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.06), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(isImporting)
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importError = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            isImporting = true
            Task {
                let song = await SongImporter.importFile(at: url, into: modelContext)
                isImporting = false
                if song == nil {
                    importError = "Couldn't read that audio file. Try an .mp3, .m4a, or .wav."
                }
            }
        }
    }

    // MARK: - Sidebar Layout
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Lobby — top-left, above the brand.
            Button {
                battle.openLobby()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 11, weight: .bold))
                    Text("LOBBY")
                        .font(.orbitronBold(size: 11))
                }
                .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .padding(.leading, 12)

            // App branding header
            Text("MELODASH")
                .font(.orbitronBlack(size: 20))
                .foregroundStyle(Color.melodashBlue)
                .meloGlowText()
                .padding(.leading, 12)

            // Browse Tab section
            VStack(alignment: .leading, spacing: 14) {
                sectionLabel("BROWSE")
                sidebarButton(title: "DISCOVER", icon: "safari", isActive: activeTab == .discover) {
                    activeTab = .discover
                }
                sidebarButton(title: "SEARCH", icon: "magnifyingglass", isActive: activeTab == .search) {
                    activeTab = .search
                }
                sidebarButton(title: "GENRE", icon: "guitars", isActive: activeTab == .genre) {
                    activeTab = .genre
                    selectedGenre = nil
                }
            }

            // Library Tab section
            VStack(alignment: .leading, spacing: 14) {
                sectionLabel("LIBRARY")
                sidebarButton(title: "FAVORITES", icon: "star", isActive: activeTab == .favorites) {
                    activeTab = .favorites
                }
                sidebarButton(title: "YOUR SONGS", icon: "music.note", isActive: activeTab == .yourSongs) {
                    activeTab = .yourSongs
                }
            }

            Spacer()

            addSongButton
        }
        .padding(.top, 56) // Push down to avoid overlapping window controls
        .padding(.bottom, 32)
        .padding(.horizontal, 20)
        .frame(width: 250, alignment: .leading)
        .frame(maxHeight: .infinity)
        .background(Color.black.opacity(0.35))
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1),
            alignment: .trailing
        )
    }

    private func sectionLabel(_ text: String) -> some View {
        SectionLabel(text: text)
            .padding(.leading, 12)
    }

    private func sidebarButton(title: String, icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isActive ? Color.melodashBlue : .white.opacity(0.6))
                    .frame(width: 20)

                Text(title)
                    .font(.orbitronBold(size: 12))
                    .foregroundStyle(isActive ? .white : .white.opacity(0.6))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isActive ? Color.white.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Main Content Area
    private var mainContentView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // Top utility header: who's picking.
                HStack(alignment: .center) {
                    Spacer()
                    if let currentPlayer = battle.currentPlayer {
                        SelectingChip(subject: currentPlayer.displayName.uppercased())
                    }
                }
                .padding(.top, 28)
                .padding(.horizontal, 32)

                switch activeTab {
                case .discover:   discoverView
                case .search:     searchView
                case .genre:      genreView
                case .favorites: favoritesView
                case .yourSongs:  yourSongsView
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.trailing, 48)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: - Discover Dashboard View
    private var discoverView: some View {
        ZStack(alignment: .topTrailing) {
            // Jumbo UFO ornament casting a spotlight beam
            Image("ufo-purple-jumbo")
                .resizable()
                .scaledToFit()
                .frame(width: 290, height: 230)
                .offset(x: 20, y: -45)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 24) {
                Text("IT'S TIME TO SHINE")
                    .font(.orbitronBlack(size: 32))
                    .foregroundStyle(.white)
                    .meloGlowText()

                // TOP SONGS FOR YOU — a horizontal shelf of artwork tiles.
                if !topHits.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Text("TOP SONGS FOR YOU")
                                .font(.orbitronBold(size: 14))
                                .foregroundStyle(.white.opacity(0.85))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white.opacity(0.6))
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 18) {
                                ForEach(topHits) { song in
                                    TopSongTile(song: song) { battle.pickSong(song) }
                                }
                            }
                            .padding(.bottom, 4)
                        }
                    }
                }

                // RECOMMENDATIONS FOR YOU — the full catalog as selectable rows.
                VStack(alignment: .leading, spacing: 10) {
                    Text("RECOMMENDATIONS FOR YOU")
                        .font(.orbitronBold(size: 14))
                        .foregroundStyle(.white.opacity(0.85))

                    if songs.isEmpty {
                        emptyMessage("No songs yet", "Add songs from Search or upload your own with Add Song.")
                    } else {
                        songList(songs)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
    }

    /// A vertical list of selectable song rows.
    private func songList(_ list: [Song]) -> some View {
        VStack(spacing: 4) {
            ForEach(list) { song in
                SongRow(
                    song: song,
                    onPick: { battle.pickSong(song) },
                    onToggleFavorite: { toggleFavorite(song) }
                )
            }
        }
    }

    private func toggleFavorite(_ song: Song) {
        song.isFavorite.toggle()
        try? modelContext.save()
    }

    // MARK: - Search Tab (local catalog + Apple Music, inline)
    private var searchView: some View {
        VStack(alignment: .leading, spacing: 16) {
            searchField

            if search.trimmingCharacters(in: .whitespaces).isEmpty {
                emptyMessage("Search your catalog and Apple Music",
                             "Type an artist, title, or album. Local songs match instantly; Apple Music results appear below.")
            } else {
                // Local catalog matches.
                VStack(alignment: .leading, spacing: 10) {
                    Text("YOUR CATALOG")
                        .font(.orbitronBold(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                    if filtered.isEmpty {
                        Text("No local songs match “\(search)”")
                            .font(.poppinsMedium(size: 13))
                            .foregroundStyle(.white.opacity(0.45))
                    } else {
                        songList(filtered)
                    }
                }

                #if canImport(MusicKit)
                appleMusicResults
                #endif
            }
        }
        .padding(.horizontal, 32)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.4))
            TextField("Search artist, title, album…", text: $search)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                #if canImport(MusicKit)
                .onChange(of: search) { _, newValue in musicSearcher.schedule(term: newValue) }
                #endif
            if !search.isEmpty {
                Button {
                    search = ""
                    #if canImport(MusicKit)
                    musicSearcher.clear()
                    #endif
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        #if canImport(MusicKit)
        .task { await musicSearcher.requestAuthorizationIfNeeded() }
        #endif
    }

    #if canImport(MusicKit)
    @ViewBuilder
    private var appleMusicResults: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("APPLE MUSIC")
                    .font(.orbitronBold(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
                if musicSearcher.isSearching {
                    ProgressView().controlSize(.small)
                }
            }

            if musicSearcher.authorization != .authorized {
                Text("Allow Apple Music access and sign in to a subscription to search the catalog. Local songs still work.")
                    .font(.poppinsMedium(size: 12))
                    .foregroundStyle(.white.opacity(0.45))
            } else if let error = musicSearcher.errorText {
                Text(error)
                    .font(.poppinsMedium(size: 12))
                    .foregroundStyle(.orange.opacity(0.9))
            } else if musicSearcher.results.isEmpty && !musicSearcher.isSearching {
                Text("No Apple Music results for “\(search)”")
                    .font(.poppinsMedium(size: 13))
                    .foregroundStyle(.white.opacity(0.45))
            } else {
                VStack(spacing: 4) {
                    ForEach(musicSearcher.results, id: \.id) { result in
                        AppleMusicResultRow(song: result, alreadyAdded: isAlreadyAdded(result)) {
                            addFromAppleMusic(result)
                        }
                    }
                }
            }
        }
    }

    private func isAlreadyAdded(_ song: MusicKit.Song) -> Bool {
        songs.contains { $0.appleMusicID == song.id.rawValue }
    }

    private func addFromAppleMusic(_ song: MusicKit.Song) {
        musicSearcher.add(song, into: modelContext)
    }
    #endif

    // MARK: - Genre Tab (browse by genre, then drill into one)
    @ViewBuilder
    private var genreView: some View {
        if let selectedGenre {
            genreSongsView(selectedGenre)
        } else {
            genreGridView
        }
    }

    private var genreGridView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if populatedGenres.isEmpty {
                emptyMessage("No songs yet", "Add songs from Search or upload your own to browse by genre.")
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 24)], spacing: 28) {
                    ForEach(populatedGenres, id: \.self) { genre in
                        GenreTile(genre: genre) {
                            withAnimation(.easeInOut(duration: 0.2)) { selectedGenre = genre }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 32)
    }

    private func genreSongsView(_ genre: DisplayGenre) -> some View {
        let list = songs.filter { $0.displayGenre == genre }
        return VStack(alignment: .leading, spacing: 20) {
            // Back to the genre grid — its own row, above the header.
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { selectedGenre = nil }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left").font(.system(size: 11, weight: .bold))
                    Text("GENRES").font(.orbitronBold(size: 12))
                }
                .foregroundStyle(Color.melodashBlue)
            }
            .buttonStyle(.plain)

            // Big header: artwork + title + count.
            HStack(alignment: .center, spacing: 20) {
                GenreTileArtwork(genre: genre, size: 150, cornerRadius: 16)

                VStack(alignment: .leading, spacing: 8) {
                    Text(genre.displayName.uppercased())
                        .font(.orbitronBlack(size: 40))
                        .foregroundStyle(.white)
                        .meloGlowText()

                    Text("\(list.count) Song\(list.count == 1 ? "" : "s")")
                        .font(.poppinsMedium(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
            }

            // SONG / TIME column header + rows.
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("SONG")
                        .font(.orbitronBold(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                    Text("TIME")
                        .font(.orbitronBold(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 16)

                songList(list)
            }
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Favorites Tab
    private var favoritesView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("FAVORITES")
                .font(.orbitronBold(size: 14))
                .foregroundStyle(.white.opacity(0.85))

            if favorites.isEmpty {
                emptyMessage("No favorites yet", "Hover a song and tap the ☆ star to save it here.")
            } else {
                songList(favorites)
            }
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Your Songs Tab (uploaded from device)
    private var yourSongsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("YOUR SONGS")
                .font(.orbitronBold(size: 14))
                .foregroundStyle(.white.opacity(0.85))

            if yourSongs.isEmpty {
                emptyMessage("No uploads yet", "Use Add Song to import an .mp3, .m4a, or .wav from your device.")
            } else {
                songList(yourSongs)
            }
        }
        .padding(.horizontal, 32)
    }

    private func emptyMessage(_ title: String, _ message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.poppinsBold(size: 15))
                .foregroundStyle(.white.opacity(0.7))
            Text(message)
                .font(.poppinsMedium(size: 12))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(.top, 10)
    }
}

// MARK: - Selectable song row

/// One song in a list. The whole row is the pick target and highlights on hover;
/// the favorite star shows only on hover (or when already starred); the track's
/// duration is right-aligned when known.
private struct SongRow: View {
    let song: Song
    let onPick: () -> Void
    let onToggleFavorite: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onToggleFavorite) {
                Image(systemName: song.isFavorite ? "star.fill" : "star")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(song.isFavorite ? Color.yellow : .white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .opacity(song.isFavorite || isHovered ? 1 : 0)
            .frame(width: 20)

            SongArtworkView(song: song, size: 44, cornerRadius: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.poppinsBold(size: 14))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(song.artist)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                    if song.source == .imported {
                        Text("LOCAL")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Capsule().fill(Color.white.opacity(0.12)))
                    }
                }
            }

            Spacer()

            if let duration = song.formattedDuration {
                Text(duration)
                    .font(.poppinsMedium(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isHovered ? Color.white.opacity(0.07) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(isHovered ? 0.14 : 0), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onPick)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Top songs shelf tile

private struct TopSongTile: View {
    let song: Song
    let onPick: () -> Void

    var body: some View {
        Button(action: onPick) {
            VStack(alignment: .leading, spacing: 8) {
                SongArtworkView(song: song, size: 150, cornerRadius: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                Text(song.title)
                    .font(.poppinsBold(size: 14))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(song.artist)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }
            .frame(width: 150, alignment: .leading)
            .melodashHoverScale(1.03)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Genre grid tile

private struct GenreTile: View {
    let genre: DisplayGenre
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(spacing: 12) {
                GenreTileArtwork(genre: genre, size: 170, cornerRadius: 16)
                Text(genre.displayName.uppercased())
                    .font(.poppinsBold(size: 14))
                    .foregroundStyle(.white)
            }
            .melodashHoverScale(1.03)
        }
        .buttonStyle(.plain)
    }
}

#if canImport(MusicKit)
import MusicKit

/// An Apple Music search hit shown inline in the Search tab.
private struct AppleMusicResultRow: View {
    let song: MusicKit.Song
    let alreadyAdded: Bool
    let onAdd: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 16) {
            if let artwork = song.artwork {
                ArtworkImage(artwork, width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Image(systemName: "music.note")
                    .frame(width: 44, height: 44)
                    .foregroundStyle(.white)
                    .background(Color.melodashBlue.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.poppinsBold(size: 14))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(song.artistName)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: alreadyAdded ? "checkmark.circle.fill" : "plus.circle")
                .font(.title3)
                .foregroundStyle(alreadyAdded ? Color.green : Color.melodashBlue)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isHovered ? Color.white.opacity(0.07) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { if !alreadyAdded { onAdd() } }
        .onHover { isHovered = $0 }
    }
}
#endif

#Preview {
    let container = try! ModelContainer(for: Song.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    return SongPickView(battle: BattleController())
        .modelContainer(container)
}
