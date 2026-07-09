//
//  TurnOrderView.swift
//  Melodash
//
//  "Mic Roulette": spin to shuffle the singing order before the battle starts.
//  The space-capsule slot machine is the `capsule` art (a 5-window glass drum);
//  we overlay the number badges, spinning avatar reels, and names onto it.
//

import SwiftUI

struct TurnOrderView: View {
    var battle: BattleController

    @State private var isSpinning = false
    @State private var hasSpun = false
    @State private var finishedReelsCount = 0

    /// Player count, clamped to the range the capsule art covers (2…5).
    private var count: Int { min(5, max(2, battle.players.count)) }

    /// The per-count capsule art (`capsule-2` … `capsule-5`).
    private var capsuleName: String { "capsule-\(count)" }

    /// Each capsule keeps the same ~491px height; only the width grows with the
    /// window count, so we render at a fixed height and derive the width.
    private let capsuleDisplayHeight: CGFloat = 300
    private var capsuleAspect: CGFloat {
        switch count {
        case 2:  return 778.0 / 491.0
        case 3:  return 981.0 / 492.0
        case 4:  return 1237.0 / 489.0
        default: return 1448.0 / 491.0
        }
    }
    private var capsuleDisplayWidth: CGFloat { capsuleDisplayHeight * capsuleAspect }

    /// Window centres as fractions of the image width (fixed ~140px end-caps, the
    /// remainder split evenly), symmetric around 0.5.
    private var windowCentersX: [CGFloat] {
        switch count {
        case 2:  return [0.340, 0.660]
        case 3:  return [0.262, 0.500, 0.738]
        case 4:  return [0.210, 0.403, 0.596, 0.790]
        default: return [0.177, 0.339, 0.500, 0.661, 0.823]
        }
    }

    // Vertical overlay alignment, as fractions of the image height (shared by all).
    private let badgeY: CGFloat = 0.05      // number badge centre (on the top rim)
    private let avatarY: CGFloat = 0.42     // avatar centre
    private let nameY: CGFloat = 0.72       // name baseline

    var body: some View {
        VStack(spacing: 24) {
            Text("MIC ROULETTE")
                .font(.orbitronBlack(size: 40))
                .foregroundStyle(.white)
                .meloGlowText()
                .padding(.top, 44)

            Spacer()

            capsule

            Spacer()

            actionArea
                .padding(.bottom, 44)
        }
        .foregroundStyle(Color.melodashInk)
        .melodashPage(showPlanet: true, showCockpit: false)
        .overlay(alignment: .topLeading) {
            BackButton { battle.confirmSetup() }   // back to avatar selection
        }
    }

    // MARK: - Capsule (art + overlaid content)

    private var capsule: some View {
        Image(capsuleName)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: capsuleDisplayWidth, height: capsuleDisplayHeight)
            .overlay {
                GeometryReader { geo in
                    ForEach(0..<count, id: \.self) { position in
                        window(position, in: geo.size)
                    }
                }
            }
            // Headroom so the badges can straddle the top rim without clipping.
            .padding(.top, 24)
    }

    @ViewBuilder
    private func window(_ position: Int, in size: CGSize) -> some View {
        let cx = windowCentersX[position] * size.width
        let colWidth: CGFloat = 128

        // Spinning avatar reel.
        SlotReelView(
            position: position,
            players: battle.players,
            targetPlayerIndex: battle.order.indices.contains(position) ? battle.order[position] : 0,
            isSpinning: isSpinning,
            spinDuration: 1.5 + Double(position) * 0.4,
            onFinished: {
                finishedReelsCount += 1
                if finishedReelsCount == battle.players.count { isSpinning = false }
            }
        )
        .frame(width: colWidth, height: size.height * 0.5)
        .position(x: cx, y: avatarY * size.height)

        // Player name (hidden mid-spin).
        Text(isSpinning ? " " : nameForPosition(position))
            .font(.poppinsBold(size: 15))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: colWidth)
            .opacity(isSpinning ? 0 : 1)
            .position(x: cx, y: nameY * size.height)

        // Number badge on the top rim.
        NumberBadge(number: position + 1)
            .position(x: cx, y: badgeY * size.height)
    }

    private func nameForPosition(_ position: Int) -> String {
        guard battle.order.indices.contains(position) else { return "" }
        let playerIndex = battle.order[position]
        guard battle.players.indices.contains(playerIndex) else { return "" }
        return battle.players[playerIndex].displayName.uppercased()
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionArea: some View {
        if isSpinning {
            Text("SHUFFLING REELS…")
                .font(.poppinsBold(size: 16))
                .foregroundStyle(Color.melodashBlue)
                .meloGlowText()
                .frame(height: 64)
        } else if hasSpun {
            HStack(spacing: 24) {
                spinButton(title: "SPIN AGAIN", width: 220)
                MelodashPrimaryButton(title: "START BATTLE") { battle.startBattle() }
            }
        } else {
            spinButton(title: "SPIN", width: 300)
        }
    }

    private func spinButton(title: String, width: CGFloat) -> some View {
        Button { triggerSpin() } label: {
            Text(title)
                .font(.orbitronBold(size: 20))
                .foregroundStyle(.white)
                .frame(width: width, height: 64)
                .background(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .fill(
                            LinearGradient(colors: [Roulette.spinTop, Roulette.spinBottom],
                                           startPoint: .top, endPoint: .bottom)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .stroke(Color.white.opacity(0.25), lineWidth: Stroke.thin)
                )
                .shadow(color: Roulette.spinBottom.opacity(0.6), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .melodashHoverScale()
        .disabled(isSpinning)
    }

    private func triggerSpin() {
        finishedReelsCount = 0
        isSpinning = true
        hasSpun = true
        withAnimation { battle.randomizeOrder() }
    }
}

// MARK: - Palette (SPIN button)

private enum Roulette {
    static let spinTop    = Color(red: 0.40, green: 0.31, blue: 0.85)
    static let spinBottom = Color(red: 0.30, green: 0.22, blue: 0.70)
}

// MARK: - Number badge

private struct NumberBadge: View {
    let number: Int

    var body: some View {
        Text("\(number)")
            .font(.orbitronBold(size: 20))
            .foregroundStyle(Color.melodashInkBlue)
            .frame(width: 42, height: 42)
            .background(
                Circle().fill(
                    LinearGradient(colors: [.white, Color(red: 0.85, green: 0.87, blue: 1.0)],
                                   startPoint: .top, endPoint: .bottom)
                )
            )
            .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 5, y: 2)
    }
}

// MARK: - Slot Reel View

private struct SlotReelView: View {
    let position: Int
    let players: [Player]
    let targetPlayerIndex: Int
    let isSpinning: Bool
    let spinDuration: Double
    let onFinished: () -> Void

    @State private var scrollOffset: CGFloat = 0
    @State private var reelItems: [Player] = []

    private let itemHeight: CGFloat = 96

    var body: some View {
        GeometryReader { geo in
            let center = geo.size.height / 2 - itemHeight / 2
            VStack(spacing: 0) {
                ForEach(Array(reelItems.enumerated()), id: \.offset) { itemIndex, player in
                    let distance = abs(scrollOffset + CGFloat(itemIndex) * itemHeight - center)
                    let fraction = min(distance / itemHeight, 1.0)
                    let scale = 1.15 - (0.45 * fraction)
                    let opacity = 1.0 - (0.6 * fraction)

                    avatar(player)
                        .frame(width: geo.size.width, height: itemHeight)
                        .scaleEffect(scale)
                        .opacity(opacity)
                }
            }
            .offset(y: scrollOffset)
            .onAppear { setupReel(center: center) }
            .onChange(of: isSpinning) { _, newValue in
                if newValue { startSpin(center: center) }
            }
        }
        .clipShape(Rectangle())
        .mask(
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .black, location: 0.25),
                    .init(color: .black, location: 0.75),
                    .init(color: .clear, location: 1.0)
                ]),
                startPoint: .top, endPoint: .bottom
            )
        )
    }

    @ViewBuilder
    private func avatar(_ player: Player) -> some View {
        if let avatar = player.avatar {
            Image(avatar.imageName)
                .resizable().scaledToFit()
                .frame(width: 82, height: 82)
        } else {
            Image("avatar-placeholder")
                .resizable().scaledToFit()
                .frame(width: 52, height: 52)
                .opacity(0.3)
        }
    }

    private func setupReel(center: CGFloat) {
        if targetPlayerIndex < players.count {
            reelItems = [players[targetPlayerIndex]]
        } else {
            reelItems = players.isEmpty ? [] : [players[0]]
        }
        scrollOffset = center
    }

    private func startSpin(center: CGFloat) {
        guard !players.isEmpty else { return }

        let currentItem = reelItems.first ?? players[0]
        var items: [Player] = [currentItem]

        let totalItems = Int(spinDuration * 12)
        for _ in 0..<totalItems {
            if let randomPlayer = players.randomElement() { items.append(randomPlayer) }
        }
        if targetPlayerIndex < players.count { items.append(players[targetPlayerIndex]) }

        reelItems = items
        scrollOffset = center

        let targetOffset = -itemHeight * CGFloat(items.count - 1) + center
        withAnimation(.easeOut(duration: spinDuration)) {
            scrollOffset = targetOffset
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + spinDuration) {
            if targetPlayerIndex < players.count {
                reelItems = [players[targetPlayerIndex]]
                scrollOffset = center
            }
            onFinished()
        }
    }
}

#Preview {
    TurnOrderView(battle: BattleController())
}
