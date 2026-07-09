//
//  LobbyView.swift
//  Melodash
//
//  The in-game Lobby: an overlay a player can pull up at any point during a
//  battle to see the live progress — which round it is, the full singing order
//  (in the fixed roulette order, so it always mirrors what actually plays), and
//  everyone's running scores. From here they can resume, or exit back to Home
//  after confirming.
//

import SwiftUI

// MARK: - Lobby control (button + overlay)

extension View {
    /// Presents the Lobby overlay when `battle.isLobbyPresented`, and — unless
    /// `showButton` is false — adds the top-trailing "Lobby" button that opens
    /// it. Pass `showButton: false` on screens that already have their own Lobby
    /// entry point (e.g. SongPickView's sidebar).
    func battleLobby(_ battle: BattleController, showButton: Bool = true) -> some View {
        modifier(BattleLobbyControl(battle: battle, showButton: showButton))
    }
}

struct BattleLobbyControl: ViewModifier {
    var battle: BattleController
    var showButton: Bool = true

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                if showButton && !battle.isLobbyPresented {
                    LobbyButton { battle.openLobby() }
                        .padding(.top, 16)
                        .padding(.trailing, 20)
                        .transition(.opacity)
                }
            }
            .overlay {
                if battle.isLobbyPresented {
                    LobbyView(battle: battle)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: battle.isLobbyPresented)
    }
}

/// The compact pill that opens the Lobby from within a battle.
struct LobbyButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "list.bullet.rectangle.portrait")
                Text("LOBBY")
                    .font(.orbitronBold(size: 13))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(Capsule().fill(Color.black.opacity(0.4)))
            .overlay(
                Capsule().stroke(Color.melodashBlue.opacity(isHovered ? 1.0 : 0.6), lineWidth: 1.5)
            )
            .shadow(color: Color.melodashBlue.opacity(isHovered ? 0.6 : 0.3), radius: isHovered ? 12 : 6)
            .scaleEffect(isHovered ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
    }
}

// MARK: - Lobby overlay

struct LobbyView: View {
    var battle: BattleController
    @State private var showExitConfirm = false

    private var turnsThisRound: Int { max(battle.order.count, 1) }
    private var currentTurnNumber: Int { min(battle.turnIndex + 1, turnsThisRound) }

    var body: some View {
        ZStack {
            // Dimmed backdrop — tapping it resumes the battle.
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { battle.dismissLobby() }

            card
                .frame(maxWidth: 560)
                .padding(28)

            if showExitConfirm {
                exitConfirmOverlay
            }
        }
    }

    // MARK: Main card

    private var card: some View {
        VStack(spacing: 22) {
            header

            Divider().overlay(Color.white.opacity(0.15))

            turnOrderList

            HStack(spacing: 16) {
                MelodashGlassButton(title: "Exit to Home", systemImage: "arrow.right.square") {
                    showExitConfirm = true
                }
                MelodashPrimaryButton(title: "Resume", systemImage: "play.fill") {
                    battle.dismissLobby()
                }
            }
            .padding(.top, 4)
        }
        .padding(28)
        .background(Color.melodashSurface.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.melodashBlue.opacity(0.5), lineWidth: 1.5)
        )
        .shadow(color: Color.melodashBlue.opacity(0.35), radius: 24)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("BATTLE LOBBY")
                .font(.orbitronBlack(size: 26))
                .foregroundStyle(.white)
                .meloGlowText()

            HStack(spacing: 10) {
                progressChip("ROUND", "\(battle.currentRound) / \(battle.roundCount)")
                progressChip("TURN", "\(currentTurnNumber) / \(turnsThisRound)")
            }
        }
    }

    private func progressChip(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.poppinsBold(size: 11))
                .foregroundStyle(.white.opacity(0.55))
            Text(value)
                .font(.orbitronBold(size: 14))
                .foregroundStyle(Color.melodashBlue)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color.white.opacity(0.07)))
    }

    // MARK: Turn order

    private var turnOrderList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SINGING ORDER")
                .font(.poppinsBold(size: 12))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(1.5)

            VStack(spacing: 8) {
                ForEach(battle.turnOrder) { slot in
                    turnRow(slot)
                }
            }
        }
    }

    private func turnRow(_ slot: TurnSlot) -> some View {
        let isSinging = slot.status == .singing
        return HStack(spacing: 14) {
            // Position badge
            Text("\(slot.id + 1)")
                .font(.orbitronBold(size: 14))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(
                    Circle().fill(isSinging ? Color.melodashBlue.opacity(0.9)
                                            : Color.melodashSurfaceActive.opacity(0.8))
                )

            AvatarBubble(avatar: slot.player.avatar, size: 44)

            Text(slot.player.displayName)
                .font(.poppinsBold(size: 16))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 8)

            statusBadge(for: slot)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSinging ? Color.melodashBlue.opacity(0.14) : Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSinging ? Color.melodashBlue.opacity(0.7) : Color.clear, lineWidth: 1.5)
        )
    }

    @ViewBuilder
    private func statusBadge(for slot: TurnSlot) -> some View {
        let hasScores = !slot.player.scores.isEmpty
        HStack(spacing: 10) {
            if hasScores {
                // Running average score so far.
                HStack(spacing: 4) {
                    Image(systemName: "star.fill").font(.system(size: 10))
                    Text("\(slot.player.average)")
                        .font(.orbitronBold(size: 14))
                }
                .foregroundStyle(Color.melodashBlue)
            }

            switch slot.status {
            case .done:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green.opacity(0.9))
            case .singing:
                Text("SINGING")
                    .font(.poppinsBold(size: 10))
                    .foregroundStyle(Color.melodashBlue)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().stroke(Color.melodashBlue, lineWidth: 1))
            case .upcoming:
                Text("UP NEXT")
                    .font(.poppinsBold(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    // MARK: Exit confirmation

    private var exitConfirmOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { showExitConfirm = false }

            VStack(spacing: 22) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.yellow)
                    .meloGlowText(color: .yellow)

                VStack(spacing: 8) {
                    Text("Exit the battle?")
                        .font(.orbitronBold(size: 22))
                        .foregroundStyle(.white)
                    Text("You'll head back to the home screen and this game's\nprogress and scores will be lost.")
                        .font(.poppinsBold(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 16) {
                    MelodashGlassButton(title: "Keep Playing") {
                        showExitConfirm = false
                    }
                    DestructiveButton(title: "Exit to Home", systemImage: "house.fill") {
                        battle.reset()
                    }
                }
            }
            .padding(36)
            .frame(maxWidth: 440)
            .background(Color.melodashSurface.opacity(0.98))
            .clipShape(RoundedRectangle(cornerRadius: 26))
            .overlay(
                RoundedRectangle(cornerRadius: 26)
                    .stroke(Color.yellow.opacity(0.4), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.5), radius: 24)
            .padding(28)
        }
        .transition(.opacity)
    }
}

/// A red-tinted glass button for the destructive "exit" action.
struct DestructiveButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
                    .font(.poppinsBold(size: 16))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 13)
            .background(Capsule().fill(Color.red.opacity(isHovered ? 0.85 : 0.7)))
            .overlay(Capsule().stroke(Color.red.opacity(0.9), lineWidth: 1.5))
            .shadow(color: .red.opacity(isHovered ? 0.6 : 0.35), radius: isHovered ? 14 : 8)
            .scaleEffect(isHovered ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
    }
}

#Preview {
    let battle = BattleController()
    battle.confirmSetup()
    battle.setName("Aria", for: 0)
    battle.setName("Kai", for: 1)
    battle.setAvatar(Avatar.catalog[0], for: 0)
    battle.setAvatar(Avatar.catalog[1], for: 1)
    battle.confirmPlayers()
    battle.startBattle()
    battle.openLobby()
    return LobbyView(battle: battle)
        .melodashPage(showPlanet: true)
}
