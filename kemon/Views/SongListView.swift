//
//  SongListView.swift
//  kemon
//
//  The catalog. Pick a song to walk onto the Kemon stage.
//

import SwiftUI
import SwiftData

struct SongListView: View {
    @Query(sort: \Song.title) private var songs: [Song]

    var body: some View {
        NavigationStack {
            List(songs) { song in
                NavigationLink {
                    PerformanceView(song: song)
                } label: {
                    row(for: song)
                }
            }
            .navigationTitle("Kemon")
            .overlay {
                if songs.isEmpty {
                    ContentUnavailableView(
                        "No songs yet",
                        systemImage: "music.note.list",
                        description: Text("Songs are seeded on first launch.")
                    )
                }
            }
        }
    }

    private func row(for song: Song) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "music.mic")
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title).font(.headline)
                Text(song.artist).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Text(song.genre.displayName)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(.secondary.opacity(0.15), in: Capsule())
        }
        .padding(.vertical, 4)
    }
}
