//
//  HomeView.swift
//  kemon
//
//  The battle entry point: the app logo "logo-melodash",
//  framed inside the cockpit deck, with the Play button.
//

import SwiftUI

struct HomeView: View {
    var battle: BattleController
    @State private var logoScale = 0.97

    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // App Title Logo from assets catalog
            Image("logo-melodash")
                .resizable()
                .scaledToFit()
                .frame(width: 880, height: 210)
                .scaleEffect(logoScale)
                .shadow(color: Color(red: 0.4, green: 0.8, blue: 1.0).opacity(0.85), radius: 16)
                .onAppear {
                    withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                        logoScale = 1.03
                    }
                }
            
            Spacer().frame(height: 10)
            
            // Direct PLAY button (default, no Apple ID prompt required)
            KemonPrimaryButton(title: "PLAY", systemImage: "play.fill") {
                battle.beginSetup()
            }
            .transition(.scale.combined(with: .opacity))
            
            Spacer()
            Spacer().frame(height: 120) // Push content above the bottom cockpit dashboard
        }
        .foregroundStyle(Color.kemonInk)
        .kemonPage(showPlanet: true, showCockpit: true)
    }
}

#Preview {
    HomeView(battle: BattleController())
}
