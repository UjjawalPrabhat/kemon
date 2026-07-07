//
//  SongPickView.swift
//  kemon
//
//  "Pick the song!" — the current singer chooses a track.
//  Redesigned as a premium space dashboard with a sidebar and a Discover tab
//  featuring the ufo-purple-jumbo asset ornament and prominent Apple Music CTAs.
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
    @State private var showingAppleMusic = false

    /// Five songs highlighted at the top of Discover — a random slice of the
    /// catalog, chosen once when the screen appears.
    @State private var topHits: [Song] = []
    /// The genre the user has drilled into on the Genre tab (nil = grid of genres).
    @State private var selectedGenre: SongGenre?
    /// Local-file import state.
    @State private var showingFileImporter = false
    @State private var importError: String?
    @State private var isImporting = false

    enum ActiveTab {
        case discover
        case genre
        case favourites
    }

    private var favourites: [Song] { songs.filter(\.isFavourite) }

    /// Songs grouped by genre, only genres that actually have songs.
    private var songsByGenre: [(genre: SongGenre, songs: [Song])] {
        SongGenre.allCases.compactMap { genre in
            let matches = songs.filter { $0.genre == genre }
            return matches.isEmpty ? nil : (genre, matches)
        }
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
            // Left Navigation Sidebar (pinned fixed width)
            sidebarView

            // Right Main Content View (fully scrollable, maximized width)
            mainContentView
        }
        .foregroundStyle(.white)
        .kemonPage(showPlanet: false, showCockpit: false)
        .overlay(alignment: .bottomTrailing) { uploadButton }
        #if canImport(MusicKit)
        .sheet(isPresented: $showingAppleMusic) {
            AppleMusicSearchView()
        }
        #endif
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
            if topHits.isEmpty { topHits = Array(songs.shuffled().prefix(5)) }
        }
    }

    // MARK: - Local file upload

    /// A floating action button (bottom-right) to import a song from the device.
    private var uploadButton: some View {
        Button {
            showingFileImporter = true
        } label: {
            HStack(spacing: 10) {
                if isImporting {
                    ProgressView().controlSize(.small).tint(.white)
                } else {
                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.system(size: 16, weight: .bold))
                }
                Text(isImporting ? "ADDING…" : "UPLOAD SONG")
                    .font(.orbitronBold(size: 13))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.kemonBlue, Color(red: 0.2, green: 0.45, blue: 0.9)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                in: Capsule()
            )
            .shadow(color: Color.kemonBlue.opacity(0.5), radius: 14, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(isImporting)
        .padding(.trailing, 40)
        .padding(.bottom, 32)
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
        VStack(alignment: .leading, spacing: 28) {
            // App branding header
            Text("MELODASH")
                .font(.orbitronBlack(size: 20))
                .foregroundStyle(Color.kemonBlue)
                .meloGlowText()
                .padding(.bottom, 12)
                .padding(.leading, 12)
            
            // Browse Tab section
            VStack(alignment: .leading, spacing: 14) {
                Text("BROWSE")
                    .font(.orbitronBold(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.leading, 12)
                
                sidebarButton(title: "DISCOVER", icon: "safari", isActive: activeTab == .discover) {
                    activeTab = .discover
                    search = ""
                }
                sidebarButton(title: "GENRE", icon: "guitars", isActive: activeTab == .genre) {
                    activeTab = .genre
                    selectedGenre = nil
                }
            }

            // Library Tab section
            VStack(alignment: .leading, spacing: 14) {
                Text("LIBRARY")
                    .font(.orbitronBold(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.leading, 12)

                sidebarButton(title: "FAVOURITES", icon: "star", isActive: activeTab == .favourites) {
                    activeTab = .favourites
                }
            }
            
            Spacer()
            
            // Open the in-game Lobby (progress, turn order, exit).
            Button {
                battle.openLobby()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.backward")
                        .font(.body.weight(.bold))
                    Text("LOBBY")
                        .font(.poppinsBold(size: 13))
                }
                .foregroundStyle(.white.opacity(0.6))
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 56) // Push down to avoid overlapping with window controls
        .padding(.bottom, 32)
        .padding(.horizontal, 20)
        .frame(width: 250, alignment: .leading) // Set width to 250 and align leading
        .frame(maxHeight: .infinity)
        .background(Color.black.opacity(0.35))
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1),
            alignment: .trailing
        )
    }

    private func sidebarButton(title: String, icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isActive ? Color.kemonBlue : .white.opacity(0.6))
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
                // Top utility header
                HStack(alignment: .center) {
                    if let currentPlayer = battle.currentPlayer {
                        Text("• \(currentPlayer.displayName.uppercased()) SELECTING")
                            .font(.poppinsBold(size: 12))
                            .foregroundStyle(Color.kemonBlue)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .stroke(Color.kemonBlue, lineWidth: 1.5)
                            )
                            .meloGlowText()
                    }
                    
                    Spacer()
                    
                    // Sleek Search bar
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.white.opacity(0.4))
                        TextField("Search artist, title, album...", text: $search)
                            .textFieldStyle(.plain)
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(width: 260)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                }
                .padding(.top, 28)
                .padding(.horizontal, 32)
                
                // Content Switcher
                if !search.isEmpty {
                    searchResultsView
                } else {
                    switch activeTab {
                    case .discover:
                        discoverView
                    case .genre:
                        genreView
                    case .favourites:
                        favouritesView
                    }
                }
            }
            .frame(maxWidth: .infinity) // Maximize width usage
            .padding(.trailing, 48) // Margin on the right
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: - Discover Dashboard View
    private var discoverView: some View {
        ZStack(alignment: .topTrailing) {
            // Jumbo UFO Ornament casting a spotlight beam
            Image("ufo-purple-jumbo")
                .resizable()
                .scaledToFit()
                .frame(width: 290, height: 230)
                .offset(x: 20, y: -45)
                .allowsHitTesting(false)
            
            VStack(alignment: .leading, spacing: 20) {
                // Main visual greeting
                Text("IT'S TIME TO SHINE")
                    .font(.orbitronBlack(size: 32))
                    .foregroundStyle(.white)
                    .meloGlowText()
                
                // Prominent Apple Music CTA Banner
                Button {
                    showingAppleMusic = true
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "music.note")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .foregroundStyle(.white)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 1.0, green: 0.17, blue: 0.33), Color(red: 0.86, green: 0.1, blue: 0.6)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text("EXPLORE APPLE MUSIC")
                                .font(.orbitronBold(size: 13))
                                .foregroundStyle(.white)
                            Text("Search and sing millions of tracks from the Music Kit catalog.")
                                .font(.poppinsMedium(size: 11))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        Text("OPEN CATALOG")
                            .font(.orbitronBold(size: 10))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.12), in: Capsule())
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color(red: 1.0, green: 0.17, blue: 0.33).opacity(0.4), Color.clear],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                    )
                    .shadow(color: Color(red: 1.0, green: 0.17, blue: 0.33).opacity(0.1), radius: 8)
                }
                .buttonStyle(.plain)
                
                // TOP HITS — a handful of highlighted tracks as artwork tiles.
                if !topHits.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("TOP HITS")
                            .font(.orbitronBold(size: 13))
                            .foregroundStyle(.white.opacity(0.5))

                        HStack(spacing: 16) {
                            ForEach(topHits) { song in
                                Button {
                                    battle.pickSong(song)
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        SongArtworkView(song: song, size: 94, cornerRadius: 14)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                            )
                                        Text(song.title)
                                            .font(.poppinsBold(size: 11))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                            .frame(width: 94, alignment: .leading)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // ALL SONGS — the full catalog.
                VStack(alignment: .leading, spacing: 10) {
                    Text("ALL SONGS")
                        .font(.orbitronBold(size: 13))
                        .foregroundStyle(.white.opacity(0.5))

                    songList(songs)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
    }

    /// A vertical list of song rows with a stable "00, 01, …" counter.
    private func songList(_ list: [Song]) -> some View {
        VStack(spacing: 8) {
            ForEach(Array(list.enumerated()), id: \.element.id) { index, song in
                recommendationRow(index: index, song: song)
            }
        }
    }

    private func recommendationRow(index: Int, song: Song) -> some View {
        HStack(spacing: 16) {
            // Index counter e.g. "00"
            Text(String(format: "%02d", index))
                .font(.orbitronBold(size: 12))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 24)

            // Favourite toggle
            Button {
                toggleFavourite(song)
            } label: {
                Image(systemName: song.isFavourite ? "star.fill" : "star")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(song.isFavourite ? Color.yellow : Color.white.opacity(0.5))
            }
            .buttonStyle(.plain)

            SongArtworkView(song: song, size: 34, cornerRadius: 8)
                .clipShape(Circle())

            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.poppinsBold(size: 13))
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

            // Custom SING button
            Button {
                battle.pickSong(song)
            } label: {
                Text("SING")
                    .font(.orbitronBold(size: 11))
                    .foregroundStyle(Color.kemonBlue)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .stroke(Color.kemonBlue, lineWidth: 1.5)
                    )
                    .shadow(color: Color.kemonBlue.opacity(0.3), radius: 4)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func toggleFavourite(_ song: Song) {
        song.isFavourite.toggle()
        try? modelContext.save()
    }

    // MARK: - Search Results Tab
    private var searchResultsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("SEARCH RESULTS")
                    .font(.orbitronBold(size: 14))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Button {
                    search = ""
                } label: {
                    Text("Clear")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            
            // Apple Music Search Recommendation
            Button {
                showingAppleMusic = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "music.note")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.17, blue: 0.33), Color(red: 0.86, green: 0.1, blue: 0.6)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            in: Circle()
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Search Apple Music for \"\(search)\"")
                            .font(.poppinsBold(size: 13))
                            .foregroundStyle(.white)
                        Text("Explore millions of songs in the global catalog")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.forward")
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(red: 1.0, green: 0.17, blue: 0.33).opacity(0.3), lineWidth: 1)
                        )
                )
                .shadow(color: Color(red: 1.0, green: 0.17, blue: 0.33).opacity(0.15), radius: 8)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 6)
            
            if filtered.isEmpty {
                Text("No local songs found for \"\(search)\"")
                    .font(.poppinsBold(size: 14))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 10)
            } else {
                songList(filtered)
            }
        }
        .padding(.horizontal, 32)
    }

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
        VStack(alignment: .leading, spacing: 14) {
            Text("GENRES")
                .font(.orbitronBold(size: 14))
                .foregroundStyle(.white.opacity(0.5))

            if songsByGenre.isEmpty {
                emptyMessage("No songs yet", "Add songs from Apple Music or upload your own to browse by genre.")
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 16)], spacing: 16) {
                    ForEach(songsByGenre, id: \.genre) { entry in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { selectedGenre = entry.genre }
                        } label: {
                            genreCard(entry.genre, count: entry.songs.count)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 32)
    }

    private func genreCard(_ genre: SongGenre, count: Int) -> some View {
        HStack(spacing: 14) {
            Image(systemName: genre.symbol)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(
                    LinearGradient(
                        colors: [Color.kemonBlue, Color(red: 0.2, green: 0.35, blue: 0.85)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 12)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(genre.displayName)
                    .font(.poppinsBold(size: 15))
                    .foregroundStyle(.white)
                Text("\(count) song\(count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func genreSongsView(_ genre: SongGenre) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedGenre = nil }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left").font(.system(size: 12, weight: .bold))
                        Text("GENRES").font(.orbitronBold(size: 12))
                    }
                    .foregroundStyle(Color.kemonBlue)
                }
                .buttonStyle(.plain)

                Text(genre.displayName.uppercased())
                    .font(.orbitronBold(size: 14))
                    .foregroundStyle(.white.opacity(0.5))
            }

            songList(songs.filter { $0.genre == genre })
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Favourites Tab
    private var favouritesView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("FAVOURITES")
                .font(.orbitronBold(size: 14))
                .foregroundStyle(.white.opacity(0.5))

            if favourites.isEmpty {
                emptyMessage("No favourites yet", "Tap the ☆ star on any song to save it here.")
            } else {
                songList(favourites)
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

#Preview {
    let container = try! ModelContainer(for: Song.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    return SongPickView(battle: BattleController())
        .modelContainer(container)
}
