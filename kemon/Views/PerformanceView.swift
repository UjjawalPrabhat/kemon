//
//  PerformanceView.swift
//  kemon
//
//  The karaoke stage for one singer's turn: live camera background, a scrolling
//  lyric box whose colour reflects how well the current expression matches the
//  song's vibe, a live emotion badge, pitch/energy HUD, and a running score.
//  Ends on a result card whose "Continue" hands the score back to the battle.
//

import SwiftUI

struct PerformanceView: View {
    let song: Song
    /// The singer taking this turn (shown in the header).
    var playerName: String = ""
    /// Called with the final 0–100 overall score when the singer taps Continue.
    var onFinish: (Int) -> Void = { _ in }

    @State private var engine = KemonEngine()
    @State private var showRomanized = false

    var body: some View {
        ZStack {
            CameraPreview(session: engine.camera.session)
                .ignoresSafeArea()

            // Legibility scrim over the camera feed.
            LinearGradient(
                colors: [.black.opacity(0.65), .clear, .black.opacity(0.75)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                header
                voiceHUD
                Spacer()
                lyricsBox
                Spacer()
                if engine.isPerforming {
                    vocalControls
                    startStopButton
                }
            }
            .padding()

            if let summary = engine.finalSummary {
                resultCard(summary)
            }
        }
        .onAppear { engine.start(song: song) }
        .onDisappear { engine.stop() }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top) {
                emotionBadge
                Spacer()
                
                if hasNonLatinLyrics {
                    Button {
                        showRomanized.toggle()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "character.bubble")
                            Text(showRomanized ? "Original" : "Romanize")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white.opacity(0.15)))
                        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(song.title)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .meloGlowText()
            if !playerName.isEmpty {
                Text(playerName.uppercased())
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.4, green: 0.8, blue: 1.0))
            }
        }
    }

    private var emotionBadge: some View {
        let reading = engine.currentReading
        return VStack(alignment: .leading, spacing: 4) {
            Label {
                Text(reading.faceDetected ? reading.dominant.displayName : "No face")
                    .font(.headline)
            } icon: {
                Image(systemName: reading.faceDetected ? reading.dominant.symbolName : "eye.slash")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .foregroundStyle(.white)

            if !engine.usingTrainedModel {
                Text("Placeholder model")
                    .font(.caption2)
                    .foregroundStyle(.yellow.opacity(0.9))
                    .padding(.leading, 4)
            }

            if Self.showsDebug {
                debugReadout
            }
        }
    }

    /// Raw model confidences + f0/smile readout for tuning against real faces.
    /// Debug builds only, so release/demo builds stay clean.
    #if DEBUG
    private static let showsDebug = true
    #else
    private static let showsDebug = false
    #endif

    private var debugReadout: some View {
        let v = engine.currentVoice
        return VStack(alignment: .leading, spacing: 1) {
            Text(String(format: "smile %.2f", engine.debugSmile))
                .foregroundStyle(.green)
            ForEach(Emotion.allCases) { e in
                Text(String(format: "%@ %.2f", e.rawValue, engine.debugConfidences[e] ?? 0))
            }
            Text(String(format: "f0 %.0f  %@ %+.0f¢  db %.0f  conf %.2f",
                        v.f0 ?? 0, v.noteName, v.centsOff ?? 0, v.db, v.confidence))
                .foregroundStyle(.cyan)
        }
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(.white.opacity(0.85))
        .padding(6)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
        .padding(.leading, 4)
    }

    // MARK: - Voice feedback

    /// Live pitch (note + cents needle) and energy meter.
    private var voiceHUD: some View {
        let voice = engine.currentVoice
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(voice.isVoiced ? voice.noteName : "listening…")
                    .font(.title3.weight(.bold).monospacedDigit())
                if let cents = voice.centsOff {
                    Text(String(format: "%+.0f cents", cents))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(width: 96, alignment: .leading)

            centsNeedle(cents: voice.centsOff)
            energyMeter(db: voice.db)
                .frame(width: 10)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .foregroundStyle(.white)
    }

    /// A −50…+50 cents scale with a marker that greens as it nears the center.
    private func centsNeedle(cents: Double?) -> some View {
        GeometryReader { geo in
            let width = geo.size.width
            let fraction = ((cents ?? 0) + 50) / 100  // 0…1
            let accuracy = 1 - min(1, abs(cents ?? 50) / 50)
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.18)).frame(height: 4)
                Rectangle().fill(.white.opacity(0.35))
                    .frame(width: 2, height: 14)
                    .position(x: width / 2, y: geo.size.height / 2) // center = in-tune
                if cents != nil {
                    Circle()
                        .fill(Color(hue: 0.0 + 0.33 * accuracy, saturation: 0.85, brightness: 1))
                        .frame(width: 14, height: 14)
                        .position(x: width * fraction, y: geo.size.height / 2)
                        .animation(.easeOut(duration: 0.08), value: fraction)
                }
            }
        }
        .frame(height: 18)
    }

    /// Vertical loudness bar, −60…0 dBFS mapped to 0…1.
    private func energyMeter(db: Double) -> some View {
        let level = min(1, max(0, (db + 60) / 60))
        return GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Capsule().fill(.white.opacity(0.18))
                Capsule().fill(.green.opacity(0.85))
                    .frame(height: geo.size.height * level)
                    .animation(.easeOut(duration: 0.08), value: level)
            }
        }
    }

    /// Vocal-suppress toggle for local songs; a headphones hint for MusicKit.
    @ViewBuilder
    private var vocalControls: some View {
        if engine.canSuppressVocals {
            Toggle(isOn: Binding(
                get: { engine.vocalSuppressed },
                set: { engine.vocalSuppressed = $0 }
            )) {
                Label("Dim vocals", systemImage: "music.mic")
            }
            .toggleStyle(.button)
            .tint(.white)
            .font(.subheadline)
            .padding(.bottom, 4)
        }
    }

    private var lyricsBox: some View {
        VStack(spacing: 12) {
            ForEach(visibleLyricWindow, id: \.offset) { item in
                Text(lyricText(for: item.line.text))
                    .font(item.isCurrent ? .title.bold() : .title3)
                    .foregroundStyle(item.isCurrent ? vibeColor : .white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut(duration: 0.2), value: vibeColor)
            }
            if engine.lyrics.isEmpty {
                Text("♪ Instrumental ♪")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private func lyricText(for text: String) -> String {
        guard showRomanized else { return text }
        return text.applyingTransform(.toLatin, reverse: false)?
            .applyingTransform(.stripDiacritics, reverse: false) ?? text
    }

    private var hasNonLatinLyrics: Bool {
        for line in engine.lyrics {
            if let transformed = line.text.applyingTransform(.toLatin, reverse: false),
               transformed != line.text {
                return true
            }
        }
        return false
    }

    private var startStopButton: some View {
        Button(role: .destructive) {
            engine.stop()
        } label: {
            Label("Finish", systemImage: "stop.fill")
                .font(.headline)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .tint(.red)
    }

    private func resultCard(_ summary: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)
                .meloGlowText(color: .yellow)
            Text(summary)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text("\(engine.overallScore)")
                .font(.system(size: 64, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .meloGlowText()
            scoreBreakdown
            KemonPrimaryButton(title: "Continue", systemImage: "arrow.right") {
                onFinish(engine.overallScore)
            }
        }
        .padding(32)
        .frame(maxWidth: 380)
        .kemonGlassCard(24)
        .padding()
    }

    /// Voice + vibe sub-scores under the overall percentage.
    private var scoreBreakdown: some View {
        HStack(spacing: 18) {
            metric("Vibe", engine.score.normalizedScore)
            if let voice = engine.voiceScore.normalizedScore {
                metric("Voice", voice)
                if let pitch = engine.voiceScore.inTuneness { metric("Pitch", pitch) }
                if let timing = engine.voiceScore.timing { metric("Timing", timing) }
            }
        }
    }

    private func metric(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.headline.monospacedDigit())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Derived UI state

    /// Colour of the current lyric, interpolated by how well the expression
    /// matches the target vibe (red → yellow → green).
    private var vibeColor: Color {
        let s = engine.score.lastSimilarity
        return Color(hue: 0.0 + 0.33 * s, saturation: 0.85, brightness: 1.0)
    }

    /// The current line plus one of context on each side, for the scrolling box.
    private var visibleLyricWindow: [(offset: Int, line: LyricLine, isCurrent: Bool)] {
        guard !engine.lyrics.isEmpty else { return [] }
        let current = engine.currentLyricIndex ?? -1
        let range = (current - 1)...(current + 1)
        return engine.lyrics.enumerated()
            .filter { range.contains($0.offset) }
            .map { (offset: $0.offset, line: $0.element, isCurrent: $0.offset == current) }
    }
}
