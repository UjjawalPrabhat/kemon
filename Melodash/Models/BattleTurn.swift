//
//  BattleTurn.swift
//  Melodash
//
//  Per-turn value types: a finished turn's score breakdown, and the turn-order
//  slot shapes the Lobby renders.
//

import Foundation

/// One performance's score, broken down by the metrics the results screen shows.
struct TurnResult {
    let overall: Int
    let pitch: Int
    let facialExpression: Int
}

/// Where a singer sits relative to the turn in progress this round — drives
/// the Lobby's turn-order display.
enum TurnStatus { case done, singing, upcoming }

/// One row of the Lobby's turn-order list: the player, their fixed position
/// in the singing order, and their status in the current round.
struct TurnSlot: Identifiable {
    let id: Int          // position in the order (0-based)
    let player: Player
    let status: TurnStatus
}
