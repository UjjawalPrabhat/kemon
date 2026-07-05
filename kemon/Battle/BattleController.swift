//
//  BattleController.swift
//  kemon
//
//  The singing-battle state machine. Drives a kiosk-style single-window wizard:
//  the root view switches on `screen`, and this object owns all battle state
//  (players, turn order, rounds, scores) and the transitions between screens.
//
//  It is intentionally UI-framework-light: pure @Observable state the SwiftUI
//  battle screens read and mutate through the small API at the bottom.
//

import SwiftUI
import Observation

// MARK: - Models

/// A pickable player avatar: an SF Symbol on a pastel disc. Swap `symbol` for an
/// asset name later to use real character/Memoji art.
struct Avatar: Identifiable, Equatable {
    let id: Int
    let imageName: String
    let emoji: String

    static let catalog: [Avatar] = [
        Avatar(id: 0, imageName: "memoji-1", emoji: "😲"),
        Avatar(id: 1, imageName: "memoji-2", emoji: "😜"),
        Avatar(id: 2, imageName: "memoji-3", emoji: "👩"),
        Avatar(id: 3, imageName: "memoji-4", emoji: "😅"),
        Avatar(id: 4, imageName: "memoji-5", emoji: "😍"),
        Avatar(id: 5, imageName: "memoji-6", emoji: "👦"),
        Avatar(id: 6, imageName: "memoji-7", emoji: "🙋‍♂️"),
        Avatar(id: 7, imageName: "memoji-8", emoji: "🧑‍🦱"),
        Avatar(id: 8, imageName: "memoji-9", emoji: "🤯"),
        Avatar(id: 9, imageName: "memoji-10", emoji: "🙌"),
        Avatar(id: 10, imageName: "memoji-11", emoji: "👵"),
        Avatar(id: 11, imageName: "memoji-12", emoji: "👧")
    ]
}

/// One battle participant. Ephemeral — the battle is a single sitting, so this
/// isn't persisted (unlike the `Song` catalog).
struct Player: Identifiable {
    let id = UUID()
    var name: String
    var avatar: Avatar? // Made optional for placeholder state
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

/// One performance's score, broken down by the metrics the results screen shows.
struct TurnResult {
    let overall: Int
    let pitch: Int
    let facialExpression: Int
}

// MARK: - Controller

@MainActor
@Observable
final class BattleController {

    enum Screen {
        case home, setup, avatars, order, roundIntro, songPick, performing, result, winners
    }

    private(set) var screen: Screen = .home

    // Setup choices.
    var playerCount = 2          // 2…5
    var roundCount = 2           // 1…5
    var isSignedIn = false

    // Battle state.
    private(set) var players: [Player] = []
    /// Player indices in the order they sing each round.
    private(set) var order: [Int] = []
    private(set) var currentRound = 1        // 1-based
    private(set) var turnIndex = 0           // index into `order`

    /// The song chosen for the turn in progress.
    private(set) var selectedSong: Song?

    /// The breakdown for the turn just finished, shown on the results screen.
    private(set) var lastTurnResult = TurnResult(overall: 0, pitch: 0, facialExpression: 0)

    // MARK: Derived

    /// The player whose turn it is right now.
    var currentPlayer: Player? {
        guard order.indices.contains(turnIndex) else { return nil }
        return players[order[turnIndex]]
    }

    /// True on the first turn of a round (drives the "sing first" wording).
    var isFirstTurnOfRound: Bool { turnIndex == 0 }

    /// Whoever sings after the results screen for the current turn is dismissed.
    /// `nil` when the turn that just finished was the battle's last.
    var upcomingPlayer: Player? {
        let nextInRound = turnIndex + 1
        if order.indices.contains(nextInRound) {
            return players[order[nextInRound]]
        }
        guard currentRound < roundCount, order.indices.contains(0) else { return nil }
        return players[order[0]]
    }

    /// Winner(s): everyone tied for the highest average. Usually one player.
    var winners: [Player] {
        guard let top = players.map(\.average).max() else { return [] }
        return players.filter { $0.average == top }
    }

    /// Players sorted best-first (by average score), for the finale leaderboard.
    var leaderboard: [Player] {
        players.sorted { $0.average > $1.average }
    }

    // MARK: - Navigation / actions

    func goHome() { screen = .home }

    /// From Home → setup.
    func beginSetup() { screen = .setup }

    /// Commits the player/round counts and creates blank players, then moves to
    /// avatar selection.
    func confirmSetup() {
        players = (0..<playerCount).map { _ in
            Player(name: "", avatar: nil)
        }
        order = Array(0..<playerCount)
        screen = .avatars
    }

    /// Edits made in the avatar screen write straight back to `players[index]`.
    func setAvatar(_ avatar: Avatar, for index: Int) {
        guard players.indices.contains(index) else { return }
        players[index].avatar = avatar
    }

    func setName(_ name: String, for index: Int) {
        guard players.indices.contains(index) else { return }
        players[index].name = name
    }

    /// Avatar selection complete → turn-order screen.
    func confirmPlayers() {
        for i in 0..<players.count {
            if players[i].name.trimmingCharacters(in: .whitespaces).isEmpty {
                players[i].name = "PLAYER \(i + 1)"
            }
            if players[i].avatar == nil {
                players[i].avatar = Avatar.catalog[i % Avatar.catalog.count]
            }
        }
        screen = .order
    }

    /// Shuffles the singing order.
    func randomizeOrder() { order.shuffle() }

    /// Kicks off round 1.
    func startBattle() {
        currentRound = 1
        turnIndex = 0
        screen = .roundIntro
    }

    /// Turn intro → song pick.
    func beginTurn() { screen = .songPick }

    /// A song was chosen for the current turn → go perform.
    func pickSong(_ song: Song) {
        selectedSong = song
        screen = .performing
    }

    /// Records the finished turn's score and shows the fullscreen results
    /// screen (breakdown + "up next" countdown) before advancing.
    func showResult(_ result: TurnResult) {
        if order.indices.contains(turnIndex) {
            players[order[turnIndex]].scores.append(result.overall)
        }
        lastTurnResult = result
        selectedSong = nil
        screen = .result
    }

    /// Leaves the results screen and advances to the next turn, next round,
    /// or the winners screen.
    func advanceFromResult() {
        turnIndex += 1
        if turnIndex >= order.count {
            turnIndex = 0
            currentRound += 1
            if currentRound > roundCount {
                screen = .winners
                return
            }
        }
        screen = .roundIntro
    }

    /// Replays a fresh battle with the same players/avatars: clears scores and
    /// restarts from round 1. Backs the "Start New Round" button on the finale.
    func startNewRound() {
        for i in players.indices { players[i].scores = [] }
        order = Array(0..<players.count)
        currentRound = 1
        turnIndex = 0
        selectedSong = nil
        screen = .roundIntro
    }

    /// Full reset back to Home for a new battle.
    func reset() {
        players = []
        order = []
        currentRound = 1
        turnIndex = 0
        selectedSong = nil
        screen = .home
    }
}
