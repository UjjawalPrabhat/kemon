//
//  BattleSetupView.swift
//  kemon
//
//  "Battle Setting" — choose how many players (2–5) and how many rounds (1–5),
//  then continue to avatar selection. Styled in outerspace theme.
//

import SwiftUI

struct BattleSetupView: View {
    @Bindable var battle: BattleController

    var body: some View {
        VStack(spacing: 44) {
            // Screen Title
            Text("Ready to Battle ?")
                .font(.orbitronBold(size: 48))
                .foregroundStyle(.white)
                .meloGlowText()
            
            // Stepper controls inside a sleek glass card
            VStack(spacing: 28) {
                SpaceCounterRow(title: "Numbers of Singers", value: $battle.playerCount, range: 2...5)
                
                Divider()
                    .background(Color.white.opacity(0.2))
                
                SpaceCounterRow(title: "How many rounds", value: $battle.roundCount, range: 1...5)
            }
            .padding(32)
            .frame(maxWidth: 460)
            .kemonGlassCard(24)
            
            // Next button
            KemonPrimaryButton(title: "NEXT", systemImage: "arrow.right") {
                battle.confirmSetup()
            }
        }
        .foregroundStyle(Color.kemonInk)
        .kemonPage(showPlanet: true, showCockpit: false, ufoColors: [.green, .yellow])
        .overlay(alignment: .topLeading) {
            BackButton { battle.goHome() }
        }
    }
}

/// A horizontal counter row styling custom buttons inside white borders matching the mockup.
private struct SpaceCounterRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    
    var body: some View {
        HStack {
            Text(title)
                .font(.poppinsBold(size: 20))
                .foregroundStyle(.white)
            
            Spacer()
            
            HStack(spacing: 14) {
                // Minus button
                Button {
                    if value > range.lowerBound { value -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                        )
                }
                .disabled(value <= range.lowerBound)
                .opacity(value <= range.lowerBound ? 0.3 : 1.0)
                
                Text("\(value)")
                    .font(.poppinsBold(size: 24))
                    .foregroundStyle(.white)
                    .frame(minWidth: 32)
                
                // Plus button
                Button {
                    if value < range.upperBound { value += 1 }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                        )
                }
                .disabled(value >= range.upperBound)
                .opacity(value >= range.upperBound ? 0.3 : 1.0)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }
}

/// A small top-left back chevron used across the wizard screens.
struct BackButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.backward")
                .font(.title2.weight(.semibold))
                .padding(12)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .padding(8)
    }
}

#Preview {
    BattleSetupView(battle: BattleController())
}
