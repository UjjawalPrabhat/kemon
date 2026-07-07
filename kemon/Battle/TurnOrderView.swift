//
//  TurnOrderView.swift
//  kemon
//
//  Shows the singing order and lets players shuffle it before the battle starts.
//  Styled in outerspace theme as a jackpot slot machine ("Mic Roulette").
//

import SwiftUI

struct TurnOrderView: View {
    var battle: BattleController

    @State private var isSpinning = false
    @State private var hasSpun = false
    @State private var finishedReelsCount = 0

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("MIC ROULETTE")
                    .font(.orbitronBlack(size: 40))
                    .foregroundStyle(.white)
                    .meloGlowText()
                
                Text("SPIN FOR YOUR TURN")
                    .font(.poppinsBold(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.top, 40)

            Spacer()

            HStack(spacing: 16) {
                ForEach(0..<battle.players.count, id: \.self) { position in
                    VStack(spacing: 12) {
                        // Singing Order Badge (1 to N)
                        Text("\(position + 1)")
                            .font(.orbitronBold(size: 14))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(Color(red: 0.12, green: 0.2, blue: 0.45).opacity(0.8))
                                    .overlay(
                                        Circle()
                                            .stroke(Color.kemonBlue, lineWidth: 1.5)
                                    )
                            )
                            .shadow(color: Color.kemonBlue.opacity(0.5), radius: 6)
                        
                        SlotReelView(
                            position: position,
                            players: battle.players,
                            targetPlayerIndex: battle.order.indices.contains(position) ? battle.order[position] : 0,
                            isSpinning: isSpinning,
                            spinDuration: 1.5 + Double(position) * 0.4,
                            onFinished: {
                                finishedReelsCount += 1
                                if finishedReelsCount == battle.players.count {
                                    isSpinning = false
                                }
                            }
                        )
                        
                        // Player name showing only when finished spinning
                        if !isSpinning && hasSpun {
                            let targetIndex = battle.order.indices.contains(position) ? battle.order[position] : 0
                            if targetIndex < battle.players.count {
                                let player = battle.players[targetIndex]
                                Text(player.displayName)
                                    .font(.poppinsBold(size: 13))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .transition(.opacity.combined(with: .scale))
                            }
                        } else {
                            // Spacer placeholder to avoid vertical layout shift
                            Spacer()
                                .frame(height: 25)
                        }
                    }
                }
            }

            Spacer()

            // Curved console base dashboard at the bottom
            ZStack {
                ConsoleBaseShape()
                    .fill(LinearGradient(
                        colors: [Color(red: 0.12, green: 0.2, blue: 0.38), Color(red: 0.06, green: 0.1, blue: 0.2)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(height: 180)
                    .overlay(
                        ConsoleBaseShape()
                            .stroke(Color(red: 0.2, green: 0.45, blue: 0.8), lineWidth: 3)
                    )
                
                // Controls panel items
                VStack(spacing: 12) {
                    Spacer()
                        .frame(height: 40)
                    
                    if isSpinning {
                        // Spinning Feedback
                        Text("SHUFFLING REELS...")
                            .font(.poppinsBold(size: 16))
                            .foregroundStyle(Color.kemonBlue)
                            .meloGlowText()
                            .padding(.bottom, 24)
                    } else if !hasSpun {
                        // Initial spin state: Show big red button
                        spinButtonView
                            .padding(.bottom, 24)
                    } else {
                        // Finished spin state: Show SPIN AGAIN and START BATTLE
                        HStack(spacing: 40) {
                            spinButtonView
                            
                            KemonPrimaryButton(title: "START BATTLE") {
                                battle.startBattle()
                            }
                        }
                        .padding(.bottom, 24)
                    }
                }
            }
            .frame(height: 180)
            .ignoresSafeArea(edges: .bottom)
        }
        .foregroundStyle(Color.kemonInk)
        .kemonPage(showPlanet: true, showCockpit: false)
        .overlay(alignment: .topLeading) {
            BackButton { battle.confirmSetup() }   // back to avatar selection
        }
    }

    private var spinButtonView: some View {
        Button {
            triggerSpin()
        } label: {
            ZStack {
                // Shadow
                Circle()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 86, height: 86)
                    .offset(y: 4)
                
                // Chrome ring base
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.gray, Color.white, Color.gray],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 82, height: 82)
                
                // Red button body
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.red, Color(red: 0.6, green: 0.0, blue: 0.0)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: 72, height: 72)
                    .shadow(color: .red.opacity(0.6), radius: 8)
                
                // Red glow overlay when not spinning
                if !isSpinning {
                    Circle()
                        .stroke(Color.red.opacity(0.4), lineWidth: 4)
                        .frame(width: 76, height: 76)
                }
                
                // Gloss effect
                Circle()
                    .fill(LinearGradient(
                        colors: [.white.opacity(0.45), .clear],
                        startPoint: .top, endPoint: .center
                    ))
                    .frame(width: 62, height: 62)
                    .offset(y: -4)
                
                // Label
                Text("SPIN")
                    .font(.poppinsBold(size: 13))
                    .foregroundStyle(.white)
                    .shadow(color: .black, radius: 2)
            }
            .scaleEffect(isSpinning ? 0.94 : 1.0)
            .animation(.interactiveSpring, value: isSpinning)
        }
        .buttonStyle(.plain)
        .disabled(isSpinning)
    }

    private func triggerSpin() {
        finishedReelsCount = 0
        isSpinning = true
        hasSpun = true
        
        // Randomize the order immediately in controller
        withAnimation {
            battle.randomizeOrder()
        }
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
    
    @State private var scrollOffset: CGFloat = 85
    @State private var reelItems: [Player] = []
    
    private let itemHeight: CGFloat = 110
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // Curved Cylinder Background Asset (purple/red alternating)
                Image((position % 2 == 0) ? "slot-purple" : "slot-red")
                    .resizable()
                    .frame(width: 120, height: 280)
                
                // Vertical scrolling stack of Memoji heads
                VStack(spacing: 0) {
                    ForEach(Array(reelItems.enumerated()), id: \.offset) { itemIndex, player in
                        let distance = abs(scrollOffset + CGFloat(itemIndex) * itemHeight - 85)
                        let fraction = min(distance / itemHeight, 1.0)
                        
                        // Scale from 1.3 (at center) to 0.75 (one slot away)
                        let scale = 1.3 - (0.55 * fraction)
                        // Opacity from 1.0 (at center) to 0.5 (one slot away)
                        let opacity = 1.0 - (0.5 * fraction)
                        
                        ZStack {
                            if let avatar = player.avatar {
                                Image(avatar.imageName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 76, height: 76)
                            } else {
                                Image("avatar-placeholder")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 50, height: 50)
                                    .opacity(0.3)
                            }
                        }
                        .frame(width: geo.size.width, height: itemHeight)
                        .scaleEffect(scale)
                        .opacity(opacity)
                    }
                }
                .offset(y: scrollOffset)
            }
        }
        .frame(width: 120, height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .mask(
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .black, location: 0.15),
                    .init(color: .black, location: 0.85),
                    .init(color: .clear, location: 1.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onAppear {
            setupReel()
        }
        .onChange(of: isSpinning) { _, newValue in
            if newValue {
                startSpin()
            }
        }
    }
    
    private func setupReel() {
        if targetPlayerIndex < players.count {
            reelItems = [players[targetPlayerIndex]]
        } else {
            reelItems = players.isEmpty ? [] : [players[0]]
        }
        scrollOffset = 85
    }
    
    private func startSpin() {
        guard !players.isEmpty else { return }
        
        let currentItem = reelItems.first ?? players[0]
        var items: [Player] = [currentItem]
        
        let totalItems = Int(spinDuration * 12)
        for _ in 0..<totalItems {
            if let randomPlayer = players.randomElement() {
                items.append(randomPlayer)
            }
        }
        
        if targetPlayerIndex < players.count {
            items.append(players[targetPlayerIndex])
        }
        
        reelItems = items
        scrollOffset = 85
        
        let targetOffset = -itemHeight * CGFloat(items.count - 1)
        let centeredOffset = targetOffset + 85
        
        withAnimation(.easeOut(duration: spinDuration)) {
            scrollOffset = centeredOffset
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + spinDuration) {
            if targetPlayerIndex < players.count {
                reelItems = [players[targetPlayerIndex]]
                scrollOffset = 85
            }
            onFinished()
        }
    }
}

#Preview {
    TurnOrderView(battle: BattleController())
}
