//
//  BattleController.swift
//  Melodash
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

// MARK: - Controller

@MainActor
@Observable
final class BattleController {

    enum Screen {
        case home, setup, avatars, order, roundIntro, songPick, performing, result, winners
    }

    private(set) var screen: Screen = .home

    /// Whether the in-game Lobby overlay (progress + turn order + exit) is showing.
    /// Presented on top of the active battle screens; dismissing it resumes play.
    var isLobbyPresented = false

    // Setup choices.
    var playerCount = 2          // 2…5
    var roundCount = 2           // 1…5

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

    /// Players sorted best-first (by average score), for the finale leaderboard.
    var leaderboard: [Player] {
        players.sorted { $0.average > $1.average }
    }

    /// The singing order for this battle, in fixed roulette order, each tagged
    /// with whether they've sung / are singing / are up next *this round*. This
    /// reads straight from `order`, so it always mirrors what actually plays.
    var turnOrder: [TurnSlot] {
        order.indices.map { position in
            let status: TurnStatus
            if position < turnIndex { status = .done }
            else if position == turnIndex { status = .singing }
            else { status = .upcoming }
            return TurnSlot(id: position, player: players[order[position]], status: status)
        }
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

    /// Every player must have both a non-empty name and a chosen avatar before
    /// the battle can start.
    var allPlayersReady: Bool {
        !players.isEmpty && players.allSatisfy { player in
            !player.name.trimmingCharacters(in: .whitespaces).isEmpty && player.avatar != nil
        }
    }

    /// Avatar selection complete → turn-order screen.
    func confirmPlayers() {
        guard allPlayersReady else { return }
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

    /// Abandons the in-progress performance without scoring and returns to song
    /// selection so the same singer can pick a different track.
    func changeSong() {
        selectedSong = nil
        screen = .songPick
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
        // Keep the singing order players spun for — don't silently reshuffle
        // it back to 1-2-3 on replay.
        currentRound = 1
        turnIndex = 0
        selectedSong = nil
        isLobbyPresented = false
        screen = .roundIntro
    }

    /// Full reset back to Home for a new battle.
    func reset() {
        players = []
        order = []
        currentRound = 1
        turnIndex = 0
        selectedSong = nil
        isLobbyPresented = false
        screen = .home
    }

    // MARK: - Lobby

    /// Opens the in-game Lobby overlay (progress, turn order, exit).
    func openLobby() { isLobbyPresented = true }

    /// Closes the Lobby and resumes the battle where it left off.
    func dismissLobby() { isLobbyPresented = false }
}
