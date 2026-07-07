//
//  WinnersView.swift
//  kemon
//
//  The finale: a split "The Final Winner" screen. The left holds the glowing
//  title and the Back-to-Home / Start-New-Round actions; the right holds the
//  1-2-3 podium of colored bars with floating avatar cards, and any 4th-place
//  and beyond players in frosted overflow rows across the bars' base.
//

import SwiftUI

struct WinnersView: View {
    var battle: BattleController

    private var leaderboard: [Player] { battle.leaderboard }

    // Podium accent colors, by rank.
    private static let gold = Color(red: 0.96, green: 0.77, blue: 0.09)      // #F5C518
    private static let periwinkle = Color(red: 0.72, green: 0.78, blue: 0.95) // #B9C6F2
    private static let orange = Color(red: 0.96, green: 0.46, blue: 0.12)     // #F5751E

    var body: some View {
        ZStack {
            // LEFT — title + actions, vertically centered against the left edge.
            HStack {
                leftColumn
                Spacer(minLength: 0)
            }
            .padding(.leading, 72)

            // RIGHT — podium, anchored to the bottom-right so the bars run off
            // the bottom edge like the mockup.
            HStack {
                Spacer(minLength: 0)
                podium
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.trailing, 56)
        }
        .foregroundStyle(Color.kemonInk)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(finaleBackground)
    }

    // MARK: - Background

    /// A pared-back finale backdrop: just the gradient + drifting stars, the
    /// `moon-side` blobs hugging the left edge, and the jumbo lime UFO up top —
    /// none of the default page's planet / small UFOs / comet ornaments.
    private var finaleBackground: some View {
        ZStack {
            LinearGradient.kemonSpace

            MovingStarsView()

            // moon-side blobs, full height against the leading edge.
            HStack(spacing: 0) {
                Image("moon-side")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: .infinity)
                    .offset(x: -20)
                Spacer(minLength: 0)
            }

            // Jumbo lime UFO with its beam, near the top center.
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    FloatingUFOView(name: "ufo-lime-jumbo", size: 460)
                        .offset(x: -40)
                    Spacer()
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 20)
        }
        .ignoresSafeArea()
    }

    // MARK: - Left column

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 40) {
            Text("The Final Winner")
                .font(.poppinsBlack(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, Color.kemonBlue],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .meloGlowText()
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 460, alignment: .leading)

            HStack(spacing: 20) {
                KemonDarkButton(title: "BACK TO HOME") { battle.reset() }
                KemonPrimaryButton(title: "START NEW ROUND") { battle.startNewRound() }
            }
        }
    }

    // MARK: - Podium

    private var podium: some View {
        ZStack(alignment: .bottom) {
            // The three colored bars with their floating avatar cards.
            HStack(alignment: .bottom, spacing: 12) {
                if leaderboard.indices.contains(1) {
                    podiumColumn(leaderboard[1], rank: 2, height: 470,
                                 accent: Self.periwinkle, scoreColor: .white)
                }
                if leaderboard.indices.contains(0) {
                    podiumColumn(leaderboard[0], rank: 1, height: 570,
                                 accent: Self.gold, scoreColor: Self.gold)
                }
                if leaderboard.indices.contains(2) {
                    podiumColumn(leaderboard[2], rank: 3, height: 410,
                                 accent: Self.orange, scoreColor: Self.orange)
                }
            }

            // 4th place and beyond, frosted rows across the bars' lower half.
            VStack(spacing: 16) {
                ForEach(Array(leaderboard.enumerated()), id: \.element.id) { index, player in
                    if index >= 3 {
                        overflowRow(rank: index + 1, player: player)
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 48)
        }
        .frame(width: 486)
    }

    /// One podium slot: the avatar card floats above a tall colored bar. Because
    /// the bars are bottom-aligned, taller ranks lift their card higher.
    private func podiumColumn(_ player: Player, rank: Int, height: CGFloat,
                              accent: Color, scoreColor: Color) -> some View {
        VStack(spacing: 12) {
            avatarCard(player, accent: accent, scoreColor: scoreColor)

            ZStack(alignment: .top) {
                Rectangle()
                    .fill(accent)
                    .frame(width: 150, height: height)
                    .clipShape(.rect(topLeadingRadius: 22, topTrailingRadius: 22))

                Text("\(rank)")
                    .font(.orbitronBlack(size: 68))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                    .padding(.top, 22)
            }
        }
    }

    private func avatarCard(_ player: Player, accent: Color, scoreColor: Color) -> some View {
        VStack(spacing: 10) {
            Text(player.displayName)
                .font(.poppinsBold(size: 15))
                .foregroundStyle(scoreColor)
                .lineLimit(1)
                .padding(.horizontal, 18)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.5))
                        .overlay(Capsule().stroke(accent.opacity(0.6), lineWidth: 1))
                )

            avatarImage(player, size: 60)

            Text("Score \(player.average)")
                .font(.poppinsBold(size: 15))
                .foregroundStyle(scoreColor)
        }
        .padding(.vertical, 16)
        .frame(width: 150)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(red: 0.05, green: 0.06, blue: 0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(accent, lineWidth: 2)
        )
        .shadow(color: accent.opacity(0.6), radius: 14)
    }

    /// A frosted row for a 4th-or-worse finisher, laid over the bars' base.
    private func overflowRow(rank: Int, player: Player) -> some View {
        HStack(spacing: 18) {
            Text(String(format: "%02d", rank))
                .font(.poppinsBold(size: 16))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 34, alignment: .leading)

            avatarImage(player, size: 42)

            Text(player.displayName)
                .font(.poppinsBold(size: 18))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 12)

            Text("Score \(player.average)")
                .font(.poppinsBold(size: 16))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white.opacity(0.08))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func avatarImage(_ player: Player, size: CGFloat) -> some View {
        AvatarImage(imageName: player.avatar?.imageName)
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

/// A dark frosted rounded-rect button, sized to sit beside `KemonPrimaryButton`.
struct KemonDarkButton: View {
    let title: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.poppinsBlack(size: 22))
                .foregroundStyle(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 20)
                .background {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.black.opacity(0.4))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
                }
                .scaleEffect(isHovered ? 1.06 : 1.0)
                .animation(.spring(response: 0.35, dampingFraction: 0.6), value: isHovered)
                .onHover { isHovered = $0 }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let battle = BattleController()
    battle.playerCount = 5
    battle.confirmSetup()
    battle.setName("Bono", for: 0)
    battle.setName("Tami", for: 1)
    battle.setName("Cio", for: 2)
    battle.setName("Nico", for: 3)
    battle.setName("Ujiii", for: 4)
    battle.confirmPlayers()
    let totals = [93, 88, 85, 80, 77]
    for t in totals {
        battle.showResult(TurnResult(overall: t, pitch: t, facialExpression: t))
        battle.advanceFromResult()
    }
    return WinnersView(battle: battle)
}
