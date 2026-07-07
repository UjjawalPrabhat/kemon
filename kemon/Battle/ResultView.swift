//
//  ResultView.swift
//  kemon
//
//  The fullscreen results screen shown after each turn: score breakdown for
//  the singer who just finished, plus an auto-advancing "up next" countdown
//  for whoever sings next (or a wrap-up message on the battle's last turn).
//

import SwiftUI

struct ResultView: View {
    var battle: BattleController

    /// Seconds left before auto-advancing to the next screen.
    @State private var secondsRemaining = 5

    private var player: Player? { battle.currentPlayer }
    private var result: TurnResult { battle.lastTurnResult }

    var body: some View {
        ZStack {
            if let player {
                playerCard(player)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .padding(.leading, 120)
                    .offset(y: 70)
            }

            // Right-hand content column: metric bars (top), score (middle),
            // next-up panel (bottom).
            VStack(spacing: 0) {
                HStack {
                    Spacer(minLength: 0)
                    VStack(alignment: .leading, spacing: 20) {
                        metricRow("Pitch", result.pitch)
                        metricRow("Facial Expression", result.facialExpression)
                    }
                    .padding(.trailing, 90)
                }
                .padding(.top, 72)

                Spacer(minLength: 0)

                // "Your Score..." + big glowing number, centered clear of the card.
                HStack(alignment: .center, spacing: 44) {
                    Text("Your\nScore...")
                        .font(.orbitronBold(size: 54))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)

                    Text("\(result.overall)")
                        .font(.orbitronBlack(size: 150))
                        .foregroundStyle(Color.kemonBlue)
                        .meloGlowText()
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.leading, 240)

                Spacer(minLength: 0)

                HStack {
                    Spacer(minLength: 0)
                    nextUpPanel
                }
                .padding(.trailing, 60)
                .padding(.bottom, 52)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(resultBackground)
        .contentShape(Rectangle())
        .onTapGesture { advance() }
        .task { await runCountdown() }
    }

    // MARK: - Background

    /// Custom scene for the score screen: gradient + stars, a moon along the
    /// bottom, the big spotlight UFO haloing the player card on the left, and a
    /// small planet in the top-right. No small drifting UFOs.
    private var resultBackground: some View {
        ZStack {
            LinearGradient.kemonSpace

            MovingStarsView()

            // Moon along the bottom edge.
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Image("moon")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 260)
                    .clipped()
            }

            // Planet, top-right.
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Image("planet")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 130)
                        .padding(.top, 40)
                        .padding(.trailing, 90)
                }
                Spacer(minLength: 0)
            }

            // Big spotlight UFO, top-left, beam pointing down at the card.
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Image("ufo-spotlight")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 720)
                        .offset(x: -70, y: -30)
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Player Card

    private func playerCard(_ player: Player) -> some View {
        VStack(spacing: 20) {
            Text(player.displayName.uppercased())
                .font(.poppinsBold(size: 15))
                .foregroundStyle(Color.kemonInkBlue)
                .padding(.horizontal, 18)
                .padding(.vertical, 7)
                .background(
                    Capsule().stroke(Color.kemonInkBlue, lineWidth: 1.5)
                )

            AvatarImage(imageName: player.avatar?.imageName)
                .scaledToFit()
                .frame(width: 150, height: 150)
        }
        .padding(28)
        .frame(width: 260, height: 320)
        .background(Color.kemonCyan)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .shadow(color: Color.kemonCyan.opacity(0.5), radius: 24)
    }

    // MARK: - Metric Row (slanted lavender bar, matches the mockup)

    private func metricRow(_ label: String, _ value: Int) -> some View {
        HStack(spacing: 24) {
            Text(label)
                .font(.poppinsBold(size: 18))
            Spacer(minLength: 40)
            Text("\(value)")
                .font(.orbitronBold(size: 20))
        }
        .foregroundStyle(Color.kemonInkBlue)
        .padding(.horizontal, 34)
        .padding(.vertical, 18)
        .frame(width: 470)
        .background(
            SkewedBarShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.91, green: 0.93, blue: 1.0),
                            Color(red: 0.82, green: 0.86, blue: 1.0)
                        ],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .shadow(color: Color.kemonBlue.opacity(0.55), radius: 10)
        )
    }

    // MARK: - Next Up Panel

    @ViewBuilder
    private var nextUpPanel: some View {
        if let upcoming = battle.upcomingPlayer {
            HStack(spacing: 18) {
                // Avatar in a cyan mini-card with a name capsule, mockup-style.
                VStack(spacing: 8) {
                    if let imageName = upcoming.avatar?.imageName {
                        Image(imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 56, height: 56)
                    } else {
                        Image("avatar-placeholder")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 56, height: 56)
                            .opacity(0.5)
                    }

                    Text(upcoming.displayName)
                        .font(.poppinsBold(size: 12))
                        .foregroundStyle(Color.kemonInkBlue)
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Capsule().stroke(Color.kemonInkBlue, lineWidth: 1.2))
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color.kemonCyan))

                Text(String(format: "Next Up in %02d…", secondsRemaining))
                    .font(.poppinsBold(size: 22))
                    .foregroundStyle(.white)
                    .meloGlowText()
                    .padding(.trailing, 8)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 22).fill(Color.black.opacity(0.4)))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.kemonBlue.opacity(0.7), lineWidth: 2)
            )
            .shadow(color: Color.kemonBlue.opacity(0.5), radius: 14)
        } else {
            HStack(spacing: 12) {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(.yellow)
                Text(String(format: "Final results in %02d…", secondsRemaining))
                    .font(.poppinsBold(size: 20))
                    .foregroundStyle(.white)
                    .meloGlowText(color: .yellow)
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 22).fill(Color.black.opacity(0.4)))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.yellow.opacity(0.6), lineWidth: 2)
            )
        }
    }

    // MARK: - Countdown

    private func runCountdown() async {
        secondsRemaining = 5
        while secondsRemaining > 0 {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            // Hold the countdown while the player is in the Lobby.
            guard !battle.isLobbyPresented else { continue }
            secondsRemaining -= 1
        }
        advance()
    }

    private func advance() {
        guard battle.screen == .result, !battle.isLobbyPresented else { return }
        battle.advanceFromResult()
    }
}

/// A parallelogram, slanted like the stat bars in the results mockup.
struct SkewedBarShape: Shape {
    var skew: CGFloat = 18

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + skew, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - skew, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    let battle = BattleController()
    battle.confirmSetup()
    battle.confirmPlayers()
    battle.startBattle()
    battle.showResult(TurnResult(overall: 82, pitch: 80, facialExpression: 85))
    return ResultView(battle: battle)
}
