//
//  Player.swift
//  Melodash
//
//  The battle participants. Ephemeral — a battle is a single sitting, so these
//  aren't persisted (unlike the `Song` catalog).
//

import Foundation

/// A pickable player avatar backed by a Memoji-style image asset.
struct Avatar: Identifiable, Equatable {
    let id: Int
    let imageName: String

    static let catalog: [Avatar] = (1...12).map {
        Avatar(id: $0 - 1, imageName: "memoji-\($0)")
    }
}

/// One battle participant.
struct Player: Identifiable {
    let id = UUID()
    var name: String
    var avatar: Avatar?
    /// One score per turn taken (index = round - 1).
    var scores: [Int] = []

    var total: Int { scores.reduce(0, +) }
    /// Mean score across the turns taken (0 if none yet), rounded to a whole
    /// number — the 0–100 figure the results and finale screens display.
    var average: Int {
        scores.isEmpty ? 0 : Int((Double(total) / Double(scores.count)).rounded())
    }
    /// A display name that's never empty.
    var displayName: String {
        name.trimmingCharacters(in: .whitespaces).isEmpty ? "Singer" : name
    }
}
