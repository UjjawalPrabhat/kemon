//
//  BattleSetupView.swift
//  Melodash
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
                .font(.orbitronBlack(size: 48))
                .foregroundStyle(.white)
                .meloGlowText()
            
            // Stepper controls laid out directly on the page background matching the mockup
            VStack(spacing: 32) {
                SpaceCounterRow(title: "Number of Singers", value: $battle.playerCount, range: 2...5)
                SpaceCounterRow(title: "How many rounds", value: $battle.roundCount, range: 1...5)
            }
            .frame(maxWidth: 580)
            .padding(.horizontal, 40)

            MelodashPrimaryButton(title: "NEXT") {
                battle.confirmSetup()
            }
        }
        .foregroundStyle(Color.melodashInk)
        .melodashPage(showPlanet: false, showMoon: true, showCockpit: false, ufoStyle: .greenYellow)
        .overlay(alignment: .topLeading) {
            BackButton { battle.goHome() }
        }
    }
}

/// A stepper row: a title with framed −/+ buttons around the current value.
private struct SpaceCounterRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    
    var body: some View {
        HStack {
            Text(title)
                .font(.orbitronRegular(size: 24))
                .foregroundStyle(.white)
            
            Spacer()
            
            HStack(spacing: 14) {
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
                        .contentShape(Rectangle())
                }
                .disabled(value <= range.lowerBound)
                .opacity(value <= range.lowerBound ? 0.3 : 1.0)

                Text("\(value)")
                    .font(.orbitronRegular(size: 26))
                    .foregroundStyle(.white)
                    .frame(minWidth: 32)

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
                        .contentShape(Rectangle())
                }
                .disabled(value >= range.upperBound)
                .opacity(value >= range.upperBound ? 0.3 : 1.0)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
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
