//
//  SongPickView.swift
//  kemon
//
//  "Pick the song!" — the current singer chooses a track. Styled with space theme
//  and showing a banner indicating whose turn it is to select.
//

import SwiftUI
import SwiftData

struct SongPickView: View {
    var battle: BattleController

    @Query(sort: \Song.title) private var songs: [Song]
    @State private var search = ""
    @State private var showingAppleMusic = false

    private var filtered: [Song] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return songs }
        return songs.filter {
            $0.title.lowercased().contains(q) || $0.artist.lowercased().contains(q)
        }
    }

    var body: some View {
        ZStack {
            // Outerspace Background
            SpaceBackgroundView(showPlanet: false, showCockpit: false)
            
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Current Selecting Player Indicator Header
                        if let currentPlayer = battle.currentPlayer {
                            HStack {
                                Spacer()
                                Text("• \(currentPlayer.displayName.uppercased()) SELECTING")
                                    .font(.poppinsBold(size: 13))
                                    .foregroundStyle(Color(red: 0.4, green: 0.8, blue: 1.0))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .stroke(Color(red: 0.4, green: 0.8, blue: 1.0), lineWidth: 1.5)
                                    )
                                    .meloGlowText()
                                Spacer()
                            }
                            .padding(.top, 8)
                        }
                        
                        #if canImport(MusicKit)
                        appleMusicCTA
                        #endif
                        
                        if !filtered.isEmpty {
                            recommendedStrip
                        }
                        songList
                    }
                    .padding(24)
                }
                .background(Color.clear)
                .navigationTitle("Pick the Song!")
                .searchable(text: $search, prompt: "Search artist, title, album")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { battle.startBattle() } label: {
                            Image(systemName: "chevron.backward")
                                .foregroundStyle(.white)
                        }
                    }
                    #if canImport(MusicKit)
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingAppleMusic = true
                        } label: {
                            Label("Apple Music", systemImage: "music.note")
                                .foregroundStyle(Color(red: 0.4, green: 0.8, blue: 1.0))
                        }
                    }
                    #endif
                }
                #if os(iOS) && !targetEnvironment(macCatalyst)
                .toolbarColorScheme(.dark, for: .navigationBar)
                #endif
            }
            .tint(Color(red: 0.4, green: 0.8, blue: 1.0))
            #if canImport(MusicKit)
            .sheet(isPresented: $showingAppleMusic) {
                AppleMusicSearchView()
            }
            #endif
        }
    }

    // MARK: - Pieces

    #if canImport(MusicKit)
    /// A prominent, glassy entry point to Apple Music catalog search.
    private var appleMusicCTA: some View {
        Button {
            showingAppleMusic = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "music.note")
                    .font(.title2)
                    .frame(width: 46, height: 46)
                    .foregroundStyle(.white)
                    .background(Color(red: 0.4, green: 0.8, blue: 1.0).opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Search Apple Music")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Millions of songs — subscription required")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.6))
            }
            .padding(14)
            .kemonGlassCard(16)
        }
        .buttonStyle(.plain)
    }
    #endif

    private var recommendedStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommended")
                .font(.orbitronBold(size: 18))
                .foregroundStyle(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(filtered.prefix(8)) { song in
                        Button { battle.pickSong(song) } label: {
                            recommendedCard(song)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func recommendedCard(_ song: Song) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            artwork(for: song, size: 150)
            Text(song.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(song.artist)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
        }
        .frame(width: 150)
        .padding(10)
        .kemonGlassCard(16)
    }

    private var songList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Songs")
                .font(.orbitronBold(size: 18))
                .foregroundStyle(.white)
            
            ForEach(filtered) { song in
                Button { battle.pickSong(song) } label: {
                    row(for: song)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func row(for song: Song) -> some View {
        HStack(spacing: 14) {
            artwork(for: song, size: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(song.artist)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            Text(song.genre.displayName)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.white.opacity(0.12), in: Capsule())
            
            Image(systemName: "play.circle.fill")
                .font(.title2)
                .foregroundStyle(Color(red: 0.4, green: 0.8, blue: 1.0))
        }
        .padding(12)
        .kemonGlassCard(14)
    }

    @ViewBuilder
    private func artwork(for song: Song, size: CGFloat) -> some View {
        if let urlString = song.artworkURLString, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                default:
                    defaultGradientArtwork(for: song, size: size)
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size > 80 ? 14 : 8))
        } else {
            defaultGradientArtwork(for: song, size: size)
        }
    }

    private func defaultGradientArtwork(for song: Song, size: CGFloat) -> some View {
        let hue = Double(abs(song.title.hashValue) % 100) / 100.0
        return RoundedRectangle(cornerRadius: size > 80 ? 14 : 8)
            .fill(LinearGradient(
                colors: [
                    Color(hue: hue, saturation: 0.5, brightness: 0.75),
                    Color(hue: hue, saturation: 0.6, brightness: 0.45),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.3))
                    .foregroundStyle(.white.opacity(0.9))
            }
    }
}

#Preview {
    let container = try! ModelContainer(for: Song.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    return SongPickView(battle: BattleController())
        .modelContainer(container)
}
