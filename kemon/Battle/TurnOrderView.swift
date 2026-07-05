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
            // Title Header
            VStack(spacing: 6) {
                Text("MIC ROULETTE")
                    .font(.orbitronBold(size: 40))
                    .foregroundStyle(.white)
                    .meloGlowText()
                
                Text("SPIN FOR YOUR TURN")
                    .font(.poppinsBold(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.top, 40)

            Spacer()

            // Slot Machine Reels Panel
            HStack(spacing: 0) {
                ForEach(0..<battle.players.count, id: \.self) { position in
                    if position > 0 {
                        // Metallic separator line between reels
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [Color.gray.opacity(0.3), Color.white.opacity(0.6), Color.gray.opacity(0.3)],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: 3)
                            .frame(height: 230)
                    }
                    
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
                }
            }
            .background(Color.black.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.25), lineWidth: 2)
            )
            .shadow(color: Color(red: 0.4, green: 0.8, blue: 1.0).opacity(0.3), radius: 12)

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
                            .foregroundStyle(Color(red: 0.4, green: 0.8, blue: 1.0))
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
                            
                            KemonPrimaryButton(title: "START BATTLE", systemImage: "flag.checkered") {
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

struct SlotReelView: View {
    let position: Int
    let players: [Player]
    let targetPlayerIndex: Int
    let isSpinning: Bool
    let spinDuration: Double
    let onFinished: () -> Void
    
    @State private var scrollOffset: CGFloat = 60
    @State private var reelItems: [Player] = []
    
    private let itemHeight: CGFloat = 110
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background cylinder fill
                Color.black.opacity(0.4)
                
                // Vertical scrolling stack
                VStack(spacing: 0) {
                    ForEach(Array(reelItems.enumerated()), id: \.offset) { _, player in
                        VStack(spacing: 8) {
                            AvatarBubble(avatar: player.avatar, size: 70)
                            Text(player.displayName)
                                .font(.poppinsBold(size: 11))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                        .frame(width: geo.size.width, height: itemHeight)
                    }
                }
                .offset(y: scrollOffset)
                
                // Overlay cylinder shadow for 3D depth
                LinearGradient(
                    colors: [
                        .black.opacity(0.85),
                        .black.opacity(0.4),
                        .clear,
                        .clear,
                        .black.opacity(0.4),
                        .black.opacity(0.85)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .allowsHitTesting(false)
                
                // Middle selector highlight guide
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(red: 0.4, green: 0.8, blue: 1.0).opacity(0.8), lineWidth: 2)
                    .frame(height: itemHeight - 10)
                    .padding(.horizontal, 4)
                    .shadow(color: Color(red: 0.4, green: 0.8, blue: 1.0), radius: 4)
                    .shadow(color: Color(red: 0.4, green: 0.8, blue: 1.0), radius: 8)
            }
        }
        .frame(width: 100, height: 230)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
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
        scrollOffset = 60
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
        scrollOffset = 60
        
        let targetOffset = -itemHeight * CGFloat(items.count - 1)
        let centeredOffset = targetOffset + 60
        
        withAnimation(.easeOut(duration: spinDuration)) {
            scrollOffset = centeredOffset
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + spinDuration) {
            if targetPlayerIndex < players.count {
                reelItems = [players[targetPlayerIndex]]
                scrollOffset = 60
            }
            onFinished()
        }
    }
}

#Preview {
    TurnOrderView(battle: BattleController())
}
