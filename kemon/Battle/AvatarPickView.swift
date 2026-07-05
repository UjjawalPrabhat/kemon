//
//  AvatarPickView.swift
//  kemon
//
//  Fighter selection screen: Shows all player slots at the top, a grid of 12
//  Memojis below it, inline name editor, and transitions directly to TurnOrderView.
//

import SwiftUI

struct AvatarPickView: View {
    @Bindable var battle: BattleController

    /// Which player (0-based) is currently being edited.
    @State private var index = 0
    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(spacing: 28) {
            Spacer().frame(height: 8)
            
            // Screen Title
            Text("Karoeke Battle")
                .font(.orbitronBlack(size: 44))
                .foregroundStyle(.white)
                .meloGlowText()
            
            // Player slots row
            HStack(spacing: 20) {
                ForEach(0..<battle.playerCount, id: \.self) { pIndex in
                    if battle.players.indices.contains(pIndex) {
                        PlayerSlotCard(
                            index: pIndex,
                            player: battle.players[pIndex],
                            isActive: index == pIndex,
                            isFocused: $isNameFocused,
                            onSelect: {
                                index = pIndex
                                isNameFocused = true
                            },
                            setName: { newName in
                                battle.setName(newName, for: pIndex)
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            
            // Subtitle & Avatar grid wrapped in a fixed-width container to force square cells and perfect alignment
            VStack(spacing: 18) {
                HStack {
                    Text("CHOSEE YOUR AVATAR")
                        .font(.orbitronBold(size: 15))
                        .foregroundStyle(.white.opacity(0.8))
                    
                    Spacer()
                    
                    Text("• P\(index + 1) SELECTING")
                        .font(.poppinsBold(size: 12))
                        .foregroundStyle(Color(red: 0.4, green: 0.8, blue: 1.0))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .stroke(Color(red: 0.4, green: 0.8, blue: 1.0), lineWidth: 1.5)
                        )
                }
                
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(108), spacing: 20), count: 6), spacing: 20) {
                    ForEach(Avatar.catalog) { avatar in
                        Button {
                            battle.setAvatar(avatar, for: index)
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color.white.opacity(0.06))
                                    .frame(width: 108, height: 108)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(
                                                isAvatarSelectedForCurrentPlayer(avatar) ? Color(red: 0.4, green: 0.8, blue: 1.0) : Color.white.opacity(0.12),
                                                lineWidth: isAvatarSelectedForCurrentPlayer(avatar) ? 2.5 : 1
                                            )
                                            .shadow(color: Color(red: 0.4, green: 0.8, blue: 1.0), radius: isAvatarSelectedForCurrentPlayer(avatar) ? 8 : 0)
                                    )
                                
                                Image(avatar.imageName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 78, height: 78)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: 748)
            
            Spacer()
            
            // Bottom Action buttons
            HStack(spacing: 24) {
                Button {
                    battle.beginSetup()
                } label: {
                    Text("BACK")
                        .font(.poppinsBold(size: 16))
                        .foregroundStyle(.white)
                        .frame(width: 140, height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
                
                KemonPrimaryButton(title: "START THE BATTLE") {
                    battle.confirmPlayers()
                }
            }
            .padding(.bottom, 32)
        }
        .foregroundStyle(Color.kemonInk)
        .kemonPage(showPlanet: false, showMoon: true, showCockpit: false, ufoStyle: .greenYellow)
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
    var isFocused: FocusState<Bool>.Binding
    let onSelect: () -> Void
    let setName: (String) -> Void
    
    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .topLeading) {
                VStack(spacing: 8) {
                    Spacer().frame(height: 12)
                    
                    // Avatar socket image
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
                        
                        if let avatar = player.avatar {
                            Image(avatar.imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50, height: 50)
                        } else {
                            Image("avatar-placeholder")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                                .opacity(0.25)
                        }
                    }
                    
                    // Name label with pencil icon
                    HStack(spacing: 4) {
                        if isActive {
                            TextField("NAME", text: Binding(
                                get: { player.name },
                                set: setName
                            ))
                            .focused(isFocused)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.center)
                            .font(.poppinsBold(size: 13))
                            .foregroundStyle(.white)
                            .frame(maxWidth: 80)
                        } else {
                            Text(player.name.isEmpty ? "NAME" : player.name.uppercased())
                                .font(.poppinsBold(size: 13))
                                .foregroundStyle(player.name.isEmpty ? .white.opacity(0.4) : .white)
                                .lineLimit(1)
                                .frame(maxWidth: 80)
                        }
                        
                        Image(systemName: "pencil")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.bottom, 6)
                }
                .frame(width: 104, height: 112)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(isActive ? 0.08 : 0.03))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isActive ? Color(red: 0.4, green: 0.8, blue: 1.0) : Color.white.opacity(0.12), lineWidth: 1.5)
                                .shadow(color: Color(red: 0.4, green: 0.8, blue: 1.0), radius: isActive ? 6 : 0)
                        )
                )
                
                // Index number circular badge
                Text("\(index + 1)")
                    .font(.poppinsBold(size: 9))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(
                        Circle()
                            .fill(Color(red: 0.05, green: 0.5, blue: 0.85))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.4), lineWidth: 1)
                    )
                    .offset(x: -4, y: -4)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AvatarPickView(battle: BattleController())
}
