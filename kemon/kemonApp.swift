//
//  kemonApp.swift
//  kemon
//
//  Created by Muhammad Nurul Akbar on 01/07/26.
//

import SwiftUI
import SwiftData

@main
struct kemonApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Song.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1152, idealWidth: 1280, maxWidth: .infinity, minHeight: 720, idealHeight: 800, maxHeight: .infinity)
        }
        .modelContainer(sharedModelContainer)
    }
}
