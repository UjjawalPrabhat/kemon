//
//  PerformanceComponents.swift
//  Melodash
//
//  Self-contained subviews of the karaoke stage, split out of PerformanceView:
//  the lead-vocal volume panel and the "can't play this song" warning banner.
//

import SwiftUI

/// Pop-over panel for adjusting the backing track's lead-vocal level. Only the
/// on/off toggle is supported today, so the slider snaps between full and muted.
struct VolumePanel: View {
    let engine: MelodashEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Volumes")
                .font(.poppinsBold(size: 16))
                .foregroundStyle(.white)

            if engine.canSuppressVocals {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Lead Vocals")
                            .font(.poppinsMedium(size: 14))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(engine.vocalSuppressed ? "0%" : "100%")
                            .font(.poppinsBold(size: 14))
                            .foregroundStyle(Color.melodashBlue)
                    }
                    // The engine only toggles vocals on/off, so this slider snaps
                    // between full and muted rather than being continuous.
                    Slider(
                        value: Binding(
                            get: { engine.vocalSuppressed ? 0 : 100 },
                            set: { engine.vocalSuppressed = $0 < 50 }
                        ),
                        in: 0...100
                    )
                    .tint(Color.melodashBlue)
                }
            } else {
                Text("Vocal control isn't available for this track.")
                    .font(.poppinsMedium(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(width: 300)
        .background(
            LinearGradient(
                colors: [
                    Color.melodashSurfaceRaised.opacity(0.96),
                    Color(red: 0.18, green: 0.10, blue: 0.32).opacity(0.96)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.melodashBlue.opacity(0.6), lineWidth: 1.5)
        )
        .shadow(color: Color.melodashBlue.opacity(0.3), radius: 18)
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }
}

/// Amber banner shown when the active track can't play (e.g. an Apple Music
/// song with no active subscription).
struct PlaybackWarningBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 4) {
                Text("Can't play this song")
                    .font(.poppinsBold(size: 14))
                    .foregroundStyle(.white)
                Text(message)
                    .font(.poppinsMedium(size: 12))
                    .foregroundStyle(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.1), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: 560)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.16, green: 0.10, blue: 0.10).opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.yellow.opacity(0.5), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.4), radius: 16)
    }
}
