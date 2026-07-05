//
//  WinnersView.swift
//  kemon
//
//  The finale: crowns the highest total score, shows the final rank podium,
//  lists other rankings in glass rows, and returns to Home.
//

import SwiftUI

struct WinnersView: View {
    var battle: BattleController

    private var leaderboard: [Player] {
        battle.leaderboard
    }

    var body: some View {
        VStack(spacing: 24) {
            // Title & Subtitle
            VStack(spacing: 6) {
                Text("LEADERBOARD")
                    .font(.orbitronBlack(size: 40))
                    .foregroundStyle(.white)
                    .meloGlowText()
                
                Text("FINAL RANK")
                    .font(.poppinsBold(size: 14))
                    .foregroundStyle(Color(red: 0.4, green: 0.8, blue: 1.0))
                    .tracking(1.5)
            }
            .padding(.top, 16)
            
            // The Podium (1st, 2nd, 3rd)
            HStack(alignment: .bottom, spacing: 20) {
                // 2nd Place
                if leaderboard.indices.contains(1) {
                    PodiumSlotView(player: leaderboard[1], rank: 2, points: leaderboard[1].total)
                }
                
                // 1st Place (sits slightly higher)
                if leaderboard.indices.contains(0) {
                    PodiumSlotView(player: leaderboard[0], rank: 1, points: leaderboard[0].total)
                        .offset(y: -20)
                }
                
                // 3rd Place
                if leaderboard.indices.contains(2) {
                    PodiumSlotView(player: leaderboard[2], rank: 3, points: leaderboard[2].total)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            // Remaining players (4th, 5th, etc.) in glass rows
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(Array(leaderboard.enumerated()), id: \.element.id) { index, player in
                        if index >= 3 {
                            HStack(spacing: 16) {
                                Text(String(format: "%02d", index + 1))
                                    .font(.poppinsBold(size: 14))
                                    .foregroundStyle(.white.opacity(0.5))
                                    .frame(width: 24, alignment: .leading)
                                
                                if let imageName = player.avatar?.imageName {
                                    Image(imageName)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 28, height: 28)
                                        .frame(width: 36, height: 36)
                                        .background(Circle().fill(Color.white.opacity(0.1)))
                                } else {
                                    Image("avatar-placeholder")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 28, height: 28)
                                        .frame(width: 36, height: 36)
                                        .background(Circle().fill(Color.white.opacity(0.1)))
                                        .opacity(0.4)
                                }
                                
                                Text(player.displayName)
                                    .font(.poppinsBold(size: 15))
                                    .foregroundStyle(.white)
                                
                                Spacer()
                                
                                Text("\(player.total) POINTS")
                                    .font(.poppinsBold(size: 14))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .kemonGlassCard(12)
                        }
                    }
                }
                .frame(maxWidth: 440)
            }
            
            Spacer()
            
            // Done Button
            KemonPrimaryButton(title: "DONE", systemImage: "house.fill") {
                battle.reset()
            }
            .padding(.bottom, 24)
        }
        .foregroundStyle(Color.kemonInk)
        .kemonPage(showPlanet: true, showCockpit: false)
    }
}

/// A card for one podium place on the final ranks leaderboard.
struct PodiumSlotView: View {
    let player: Player
    let rank: Int
    let points: Int
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 8) {
                Spacer().frame(height: 10)
                
                // Avatar emoji
                if let imageName = player.avatar?.imageName {
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 52, height: 52)
                        .frame(width: 68, height: 68)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                } else {
                    Image("avatar-placeholder")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 52, height: 52)
                        .frame(width: 68, height: 68)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                        .opacity(0.4)
                }
                
                Text(player.displayName)
                    .font(.poppinsBold(size: 13))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(maxWidth: 100)
                
                Text("\(points) POINTS")
                    .font(.poppinsBold(size: 11))
                    .foregroundStyle(Color(red: 0.4, green: 0.8, blue: 1.0))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .frame(width: 116, height: 138)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                    )
            )
            
            // Glowing Crown Above Card
            if rank == 1 {
                Image(systemName: "crown.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.yellow)
                    .shadow(color: .orange, radius: 4)
                    .offset(x: 10, y: -14)
            } else if rank == 2 {
                Image(systemName: "crown.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(white: 0.8))
                    .shadow(color: .gray, radius: 2)
                    .offset(x: 8, y: -10)
            } else if rank == 3 {
                Image(systemName: "crown.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(red: 0.8, green: 0.5, blue: 0.2))
                    .shadow(color: .orange.opacity(0.5), radius: 2)
                    .offset(x: 8, y: -8)
            }
        }
    }
}

#Preview {
    let battle = BattleController()
    battle.confirmSetup()
    battle.finishTurn(score: 1000)
    battle.finishTurn(score: 800)
    return WinnersView(battle: battle)
}
