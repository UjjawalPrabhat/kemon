//
//  RoundIntroView.swift
//  Melodash
//
//  A brief "up next" card shown before each singer's turn: which round it is and
//  whose turn it is. Styled in outerspace theme.
//

import SwiftUI

struct RoundIntroView: View {
    var battle: BattleController

    var body: some View {
        VStack(spacing: 32) {
            Text("Round \(battle.currentRound) of \(battle.roundCount)")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.melodashBlue)
                .tracking(2.0)
                .meloGlowText()

            if let player = battle.currentPlayer {
                VStack(spacing: 24) {
                    AvatarBubble(avatar: player.avatar, size: 140)
                    
                    VStack(spacing: 8) {
                        Text(player.displayName)
                            .font(.system(size: 40, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                        
                        Text(battle.isFirstTurnOfRound ? "YOU SING FIRST" : "YOU'RE UP NEXT")
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                            .tracking(1.0)
                    }
                }
                .padding(32)
                .frame(maxWidth: 380)
                .melodashGlassCard(24)
            }

            MelodashPrimaryButton(title: "Pick a Song", systemImage: "music.note.list") {
                battle.beginTurn()
            }
            .padding(.top, 8)
        }
        .foregroundStyle(Color.melodashInk)
        .melodashPage(showPlanet: true, showCockpit: false)
    }
}

#Preview {
    RoundIntroView(battle: BattleController())
}
