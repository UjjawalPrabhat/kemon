//
//  ContentView.swift
//  Melodash
//
//  The root of the singing-battle wizard. Owns the BattleController and swaps
//  the on-screen view based on `battle.screen`; the song catalog is seeded once
//  on first appearance.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var battle = BattleController()

    var body: some View {
        content
            .onAppear { SampleData.seedIfNeeded(modelContext) }
    }

    @ViewBuilder
    private var content: some View {
        switch battle.screen {
        case .home:
            HomeView(battle: battle)
        case .setup:
            BattleSetupView(battle: battle)
        case .avatars:
            AvatarPickView(battle: battle)
        case .order:
            TurnOrderView(battle: battle)
        case .roundIntro:
            RoundIntroView(battle: battle)
                .battleLobby(battle)
        case .songPick:
            SongPickView(battle: battle)
                .battleLobby(battle, showButton: false)   // uses its own sidebar Lobby button
        case .performing:
            if let song = battle.selectedSong {
                PerformanceView(
                    song: song,
                    playerName: battle.currentPlayer?.displayName ?? "",
                    avatarImageName: battle.currentPlayer?.avatar?.imageName ?? "",
                    onCancel: { battle.changeSong() }
                ) { result in
                    battle.showResult(result)
                }
                // Fresh MelodashEngine per turn (new round/turn ⇒ new identity).
                .id("\(battle.currentRound)-\(battle.turnIndex)")
            } else {
                // Shouldn't happen, but never strand the user.
                Color.melodashCream.ignoresSafeArea()
                    .onAppear { battle.beginTurn() }
            }
        case .result:
            ResultView(battle: battle)
                .battleLobby(battle)
        case .winners:
            WinnersView(battle: battle)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Song.self, inMemory: true)
}
