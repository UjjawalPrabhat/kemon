//
//  SampleData.swift
//  Melodash
//
//  The bundled catalog. Songs map to the .m4a files in Melodash/Resources/.
//  Timed lyrics are loaded at runtime from a matching `<name>.lrc` file (see
//  LyricsLoader); the stored `lyrics` array is left empty here.
//

import Foundation
import SwiftData

enum SampleData {
    /// Reconciles the store with the bundled catalog: inserts missing songs and
    /// removes stale ones (e.g. the old placeholder demo tracks). Idempotent —
    /// safe to call on every launch.
    @MainActor
    static func seedIfNeeded(_ context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Song>())) ?? []
        let desired = songs
        let desiredKeys = Set(desired.map(\.audioFileName))
        let existingKeys = Set(existing.filter { $0.source == .bundled }.map(\.audioFileName))

        // Only reconcile the BUNDLED catalog — never touch songs the user added
        // (imported files or Apple Music tracks).
        for song in existing where song.source == .bundled && !desiredKeys.contains(song.audioFileName) {
            context.delete(song)
        }
        for song in desired where !existingKeys.contains(song.audioFileName) {
            context.insert(song)
        }
        try? context.save()
    }

    static var songs: [Song] {
        [
            // Energetic Indonesian line-dance/party anthem — high energy, joyful.
            Song(
                title: "Maumere",
                artist: "Traditional / NTT",
                audioFileName: "Maumere",
                genre: .popEnergetic,
                lyrics: [],
                displayGenre: .pop
            ),
            // Upbeat viral track — treat as happy/uplifting. (Confirm the vibe.)
            Song(
                title: "Mas Bahlil Ganteng",
                artist: "Viral",
                audioFileName: "MasBahlilGanteng",
                genre: .upliftingJoy,
                lyrics: [],
                displayGenre: .pop
            ),
            // Neo-soul / R&B love song — mellow, warm, content.
            Song(
                title: "Get You",
                artist: "Daniel Caesar",
                audioFileName: "GetYou_DanielCaesar",
                genre: .chill,
                lyrics: [],
                displayGenre: .pop
            ),
            // Reflective, slow-building emotional standard.
            Song(
                title: "My Way",
                artist: "Frank Sinatra",
                audioFileName: "MyWay_FrankSinatra",
                genre: .balladSad,
                lyrics: [],
                displayGenre: .jazz
            ),
            Song(
                title: "Butterflies",
                artist: "Brent Faiyaz",
                audioFileName: "Butterflies_BrentFaiyaz",
                genre: .balladSad,
                lyrics: [],
                displayGenre: .pop
            ),
        ]
    }
}
