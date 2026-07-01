//
//  ContentView.swift
//  kemon
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        SongListView()
            .onAppear { SampleData.seedIfNeeded(modelContext) }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Song.self, inMemory: true)
}
