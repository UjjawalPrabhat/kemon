//
//  AvatarPickView.swift
//  kemon
//
//  Fighter selection screen: Shows all player slots at the top, a grid of 12
//  emojis below it, name editor, and transitions directly to TurnOrderView.
//

import SwiftUI

struct AvatarPickView: View {
    var battle: BattleController

    /// Which player (0-based) is currently being edited.
    @State private var index = 0

    var body: some View {
        VStack(spacing: 24) {
            // Screen Title
            Text("Karoeke Battle")
                .font(.orbitronBlack(size: 44))
                .foregroundStyle(.white)
                .meloGlowText()
            
            // Subtitle 1: CHOSEE YOU FIGHTER
            HStack {
                VStack { Divider().background(Color.white.opacity(0.2)) }
                Text("CHOSEE YOU FIGHTER")
                    .font(.poppinsBold(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 8)
                VStack { Divider().background(Color.white.opacity(0.2)) }
            }
            .padding(.horizontal, 24)
            
            // Player slots row
            HStack(spacing: 16) {
                ForEach(0..<battle.playerCount, id: \.self) { pIndex in
                    if battle.players.indices.contains(pIndex) {
                        Button {
                            index = pIndex
                        } label: {
                            PlayerSlotCard(
                                index: pIndex,
                                player: battle.players[pIndex],
                                isActive: index == pIndex
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            
            // Name editor text field
            if battle.players.indices.contains(index) {
                TextField("Fighter Name", text: nameBinding)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .font(.poppinsBold(size: 18))
                    .foregroundStyle(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: 240)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.1)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(red: 0.4, green: 0.8, blue: 1.0).opacity(0.5), lineWidth: 1.5)
                    )
            }
            
            // Subtitle 2: CHOSEE YOU AVATAR with selector indicator
            HStack(spacing: 12) {
                VStack { Divider().background(Color.white.opacity(0.2)) }
                
                Text("CHOSEE YOU AVATAR")
                    .font(.poppinsBold(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 4)
                
                Text("• P\(index + 1) SELECTING")
                    .font(.poppinsBold(size: 11))
                    .foregroundStyle(Color(red: 0.4, green: 0.8, blue: 1.0))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .stroke(Color(red: 0.4, green: 0.8, blue: 1.0), lineWidth: 1.5)
                    )
                
                VStack { Divider().background(Color.white.opacity(0.2)) }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            // Avatar grid 2x6
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 6), spacing: 14) {
                ForEach(Avatar.catalog) { avatar in
                    Button {
                        battle.setAvatar(avatar, for: index)
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.35))
                                .frame(height: 68)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            isAvatarSelectedForCurrentPlayer(avatar) ? Color(red: 0.4, green: 0.8, blue: 1.0) : Color.white.opacity(0.15),
                                            lineWidth: 1.5
                                        )
                                )
                                .shadow(color: Color(red: 0.4, green: 0.8, blue: 1.0), radius: isAvatarSelectedForCurrentPlayer(avatar) ? 4 : 0)
                            
                            Text(avatar.emoji)
                                .font(.system(size: 34))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Bottom Action buttons
            HStack(spacing: 24) {
                KemonGlassButton(title: "BACK") {
                    battle.beginSetup()
                }
                
                KemonPrimaryButton(title: "START THE BATTLE") {
                    battle.confirmPlayers()
                }
            }
            .padding(.bottom, 24)
        }
        .foregroundStyle(Color.kemonInk)
        .kemonPage(showPlanet: false, showCockpit: false)
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { battle.players.indices.contains(index) ? battle.players[index].name : "" },
            set: { battle.setName($0, for: index) }
        )
    }
    
    private func isAvatarSelectedForCurrentPlayer(_ avatar: Avatar) -> Bool {
        guard battle.players.indices.contains(index) else { return false }
        return battle.players[index].avatar == avatar
    }
}

/// A horizontal card slot for fighters on the selection screen.
struct PlayerSlotCard: View {
    let index: Int
    let player: Player
    let isActive: Bool
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Main card
            VStack(spacing: 8) {
                Spacer().frame(height: 12)
                
                // Avatar representation
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.35))
                        .frame(width: 58, height: 58)
                        .overlay(
                            Circle()
                                .stroke(
                                    isActive ? Color(red: 0.4, green: 0.8, blue: 1.0) : Color.white.opacity(0.2),
                                    style: StrokeStyle(lineWidth: 1.5, dash: isActive ? [] : [4])
                                )
                        )
                    
                    Text(player.avatar.emoji)
                        .font(.system(size: 32))
                }
                
                Text(player.displayName)
                    .font(.poppinsBold(size: 13))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(maxWidth: 84)
            }
            .frame(width: 96, height: 104)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.25))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isActive ? Color(red: 0.4, green: 0.8, blue: 1.0) : Color.clear, lineWidth: 2)
                            .shadow(color: Color(red: 0.4, green: 0.8, blue: 1.0), radius: isActive ? 6 : 0)
                    )
            )
            
            // Index number circular badge
            Text("\(index + 1)")
                .font(.poppinsBold(size: 9))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(isActive ? Color(red: 0.4, green: 0.8, blue: 1.0) : Color.white.opacity(0.25)))
                .offset(x: 6, y: 6)
        }
    }
}

#Preview {
    AvatarPickView(battle: BattleController())
}
