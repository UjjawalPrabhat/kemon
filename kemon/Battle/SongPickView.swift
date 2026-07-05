//
//  SongPickView.swift
//  kemon
//
//  "Pick the song!" — the current singer chooses a track.
//  Redesigned as a premium space dashboard with a sidebar and a Discover tab
//  featuring the ufo-purple-jumbo asset ornament.
//

import SwiftUI
import SwiftData

struct SongPickView: View {
    var battle: BattleController

    @Query(sort: \Song.title) private var songs: [Song]
    @State private var search = ""
    @State private var activeTab: ActiveTab = .discover

    enum ActiveTab {
        case discover
        case genre
        case topCharts
        case favourites
        case addSong
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
            // Left Navigation Sidebar
            sidebarView
            
            // Right Main Content View
            mainContentView
        }
        .foregroundStyle(.white)
        .kemonPage(showPlanet: false, showCockpit: false)
    }

    // MARK: - Sidebar Layout
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 28) {
            // App branding header
            Text("MELODASH")
                .font(.orbitronBlack(size: 20))
                .foregroundStyle(Color(red: 0.4, green: 0.8, blue: 1.0))
                .meloGlowText()
                .padding(.bottom, 12)
            
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
                }
                sidebarButton(title: "TOP CHARTS", icon: "chart.bar", isActive: activeTab == .topCharts) {
                    activeTab = .topCharts
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
                sidebarButton(title: "ADD YOUR SONG", icon: "plus.circle", isActive: activeTab == .addSong) {
                    activeTab = .addSong
                }
            }
            
            Spacer()
            
            // Back to lobby button
            Button {
                battle.startBattle()
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
        .padding(.vertical, 32)
        .padding(.horizontal, 16)
        .frame(width: 220)
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
                    .foregroundStyle(isActive ? Color(red: 0.4, green: 0.8, blue: 1.0) : .white.opacity(0.6))
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
        VStack(alignment: .leading, spacing: 20) {
            // Top utility header
            HStack(alignment: .center) {
                if let currentPlayer = battle.currentPlayer {
                    Text("• \(currentPlayer.displayName.uppercased()) SELECTING")
                        .font(.poppinsBold(size: 12))
                        .foregroundStyle(Color(red: 0.4, green: 0.8, blue: 1.0))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .stroke(Color(red: 0.4, green: 0.8, blue: 1.0), lineWidth: 1.5)
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
                case .topCharts:
                    topChartsView
                case .favourites:
                    favouritesView
                case .addSong:
                    addSongView
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            
            VStack(alignment: .leading, spacing: 22) {
                // Main visual greeting
                Text("IT'S TIME TO SHINE")
                    .font(.orbitronBlack(size: 32))
                    .foregroundStyle(.white)
                    .meloGlowText()
                
                // TOP ALBUMS Horizontal Strip
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("TOP ALBUMS")
                            .font(.orbitronBold(size: 13))
                            .foregroundStyle(.white.opacity(0.5))
                        
                        Spacer()
                        
                        Button {} label: {
                            Text("See All")
                                .font(.poppinsBold(size: 11))
                                .foregroundStyle(Color(red: 0.4, green: 0.8, blue: 1.0))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .stroke(Color(red: 0.4, green: 0.8, blue: 1.0), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    HStack(spacing: 16) {
                        Image(systemName: "chevron.left")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white.opacity(0.3))
                        
                        ForEach(songs.prefix(5)) { song in
                            Button {
                                battle.pickSong(song)
                            } label: {
                                artwork(for: song, size: 94)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
                
                // RECOMMENDATIONS FOR YOU Vertical Row list
                VStack(alignment: .leading, spacing: 10) {
                    Text("RECOMMENDATIONS FOR YOU")
                        .font(.orbitronBold(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                    
                    VStack(spacing: 8) {
                        ForEach(Array(songs.prefix(4).enumerated()), id: \.element.id) { index, song in
                            recommendationRow(index: index, song: song)
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
    }

    private func recommendationRow(index: Int, song: Song) -> some View {
        HStack(spacing: 16) {
            // Index counter e.g. "00"
            Text(String(format: "%02d", index))
                .font(.orbitronBold(size: 12))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 24)
            
            // Action button placeholder
            Button {} label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
            
            // Circle bubble artwork
            artwork(for: song, size: 34)
                .clipShape(Circle())
            
            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.poppinsBold(size: 13))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Text(song.artist)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Custom SING button
            Button {
                battle.pickSong(song)
            } label: {
                Text("SING")
                    .font(.orbitronBold(size: 11))
                    .foregroundStyle(Color(red: 0.4, green: 0.8, blue: 1.0))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .stroke(Color(red: 0.4, green: 0.8, blue: 1.0), lineWidth: 1.5)
                    )
                    .shadow(color: Color(red: 0.4, green: 0.8, blue: 1.0).opacity(0.3), radius: 4)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
            
            if filtered.isEmpty {
                Text("No songs found for \"\(search)\"")
                    .font(.poppinsBold(size: 14))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 20)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { index, song in
                            recommendationRow(index: index, song: song)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Generic Tab Content Views
    private var genreView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("GENRES")
                .font(.orbitronBold(size: 14))
                .foregroundStyle(.white.opacity(0.5))
            
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                        recommendationRow(index: index, song: song)
                    }
                }
            }
        }
        .padding(.horizontal, 32)
    }
    
    private var topChartsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TOP CHARTS")
                .font(.orbitronBold(size: 14))
                .foregroundStyle(.white.opacity(0.5))
            
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                        recommendationRow(index: index, song: song)
                    }
                }
            }
        }
        .padding(.horizontal, 32)
    }
    
    private var favouritesView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("FAVOURITES")
                .font(.orbitronBold(size: 14))
                .foregroundStyle(.white.opacity(0.5))
            
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(songs.prefix(3).enumerated()), id: \.element.id) { index, song in
                        recommendationRow(index: index, song: song)
                    }
                }
            }
        }
        .padding(.horizontal, 32)
    }
    
    private var addSongView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("ADD YOUR SONG")
                .font(.orbitronBold(size: 14))
                .foregroundStyle(.white.opacity(0.5))
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Want to add custom tracks?")
                    .font(.headline)
                Text("You can import local MP3 files or sync with your Apple Music library to sing custom tracks.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(20)
            .kemonGlassCard(16)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Artwork Helpers
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
