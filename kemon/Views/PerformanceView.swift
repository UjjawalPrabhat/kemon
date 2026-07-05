//
//  PerformanceView.swift
//  kemon
//
//  The karaoke stage for one singer's turn. Features a small PiP camera
//  preview in the top-left corner, dominant centered lyrics with
//  Poppins Bold/Medium styling, song album art, and a loading overlay
//  that displays while the engine prepares audio/camera.
//

import SwiftUI

struct PerformanceView: View {
    let song: Song
    /// The singer taking this turn (shown in the header).
    var playerName: String = ""
    /// Avatar image name for the current player.
    var avatarImageName: String = ""
    /// Called with the final score breakdown when the singer taps Continue.
    var onFinish: (TurnResult) -> Void = { _ in }

    @State private var engine = KemonEngine()
    @State private var showRomanized = false
    @State private var showVolumePanel = false
    /// Guards against firing `onFinish` more than once as the engine finalizes.
    @State private var didFinish = false

    /// True while the engine is still preparing (camera, mic, audio).
    private var isLoading: Bool {
        !engine.isPerforming && engine.finalSummary == nil
    }

    var body: some View {
        ZStack {
            // Live karaoke stage
            karaokeStage
                .opacity(isLoading ? 0 : 1)

            // Loading overlay
            if isLoading {
                loadingOverlay
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.6), value: isLoading)
        .onAppear { engine.start(song: song) }
        .onDisappear { engine.stop() }
        // Finishing hands off to the fullscreen results screen — no in-place modal.
        .onChange(of: engine.finalSummary) { _, summary in
            guard summary != nil, !didFinish else { return }
            didFinish = true
            onFinish(TurnResult(
                overall: engine.overallScore,
                pitch: engine.voiceScore.inTuneness ?? 0,
                facialExpression: engine.score.normalizedScore
            ))
        }
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        VStack(spacing: 28) {
            Spacer()

            // Song album artwork (large)
            songArtwork(size: 180)
                .shadow(color: Color(red: 0.4, green: 0.8, blue: 1.0).opacity(0.3), radius: 20)

            // Song info
            VStack(spacing: 8) {
                Text(song.title)
                    .font(.orbitronBold(size: 28))
                    .foregroundStyle(.white)
                    .meloGlowText()
                    .multilineTextAlignment(.center)

                Text(song.artist)
                    .font(.poppinsMedium(size: 16))
                    .foregroundStyle(.white.opacity(0.6))
            }

            // Player badge
            if !playerName.isEmpty {
                HStack(spacing: 8) {
                    if !avatarImageName.isEmpty {
                        Image(avatarImageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 28, height: 28)
                            .clipShape(Circle())
                    }
                    Text(playerName.uppercased())
                        .font(.poppinsBold(size: 13))
                        .foregroundStyle(Color(red: 0.4, green: 0.8, blue: 1.0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .stroke(Color(red: 0.4, green: 0.8, blue: 1.0).opacity(0.5), lineWidth: 1.5)
                )
            }

            Spacer()

            // Loading indicator
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.regular)
                    .tint(Color(red: 0.4, green: 0.8, blue: 1.0))

                Text("PREPARING YOUR STAGE...")
                    .font(.orbitronBold(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .kemonPage(showPlanet: false, showCockpit: false, ufoStyle: .none)
    }

    // MARK: - Live Karaoke Stage

    private var karaokeStage: some View {
        ZStack(alignment: .topLeading) {
            // Space background
            Color.clear
                .kemonPage(showPlanet: false, showCockpit: false, ufoStyle: .none)

            VStack(spacing: 0) {
                // Top bar: PiP camera + song info + controls
                topBar
                    .padding(.top, 16)
                    .padding(.horizontal, 24)

                Spacer()

                // Dominant centered lyrics
                lyricsBox
                    .padding(.horizontal, 40)

                Spacer()

                // Bottom controls
                bottomControls
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(alignment: .top, spacing: 16) {
            // PiP Camera Preview
            ZStack(alignment: .bottomTrailing) {
                CameraPreview(session: engine.camera.session)
                    .frame(width: 180, height: 135)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(red: 0.4, green: 0.8, blue: 1.0).opacity(0.4), lineWidth: 1.5)
                    )
                    .shadow(color: Color(red: 0.4, green: 0.8, blue: 1.0).opacity(0.2), radius: 8)

                // Emotion badge overlay on camera
                emotionBadgeCompact
                    .offset(x: -6, y: -6)
            }

            // Song info + player badge
            VStack(alignment: .leading, spacing: 8) {
                // Player name badge
                if !playerName.isEmpty {
                    HStack(spacing: 6) {
                        if !avatarImageName.isEmpty {
                            Image(avatarImageName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 24, height: 24)
                                .clipShape(Circle())
                        }
                        Text(playerName.uppercased())
                            .font(.poppinsBold(size: 11))
                            .foregroundStyle(Color(red: 0.4, green: 0.8, blue: 1.0))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.4, green: 0.8, blue: 1.0).opacity(0.1))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color(red: 0.4, green: 0.8, blue: 1.0).opacity(0.3), lineWidth: 1)
                    )
                }

                // Song details with artwork
                HStack(spacing: 12) {
                    songArtwork(size: 48)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.title)
                            .font(.poppinsBold(size: 15))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(song.artist)
                            .font(.poppinsMedium(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            }

            Spacer()

            // Right controls: Romanize + Volume
            VStack(alignment: .trailing, spacing: 8) {
                if hasNonLatinLyrics {
                    Button {
                        showRomanized.toggle()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "character.bubble")
                            Text(showRomanized ? "Original" : "Romanize")
                                .font(.poppinsBold(size: 11))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                // Volume panel toggle
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        showVolumePanel.toggle()
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)

                if showVolumePanel {
                    volumePanel
                }

                #if DEBUG
                if Self.showsDebug {
                    debugReadout
                }
                #endif
            }
        }
    }

    // MARK: - Compact Emotion Badge

    private var emotionBadgeCompact: some View {
        let reading = engine.currentReading
        return HStack(spacing: 4) {
            Image(systemName: reading.faceDetected ? reading.dominant.symbolName : "eye.slash")
                .font(.system(size: 10, weight: .bold))
            Text(reading.faceDetected ? reading.dominant.displayName : "No face")
                .font(.poppinsBold(size: 9))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.6), in: Capsule())
    }

    // MARK: - Volume Panel

    private var volumePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Volumes")
                .font(.poppinsBold(size: 13))
                .foregroundStyle(.white)

            if engine.canSuppressVocals {
                Toggle(isOn: Binding(
                    get: { engine.vocalSuppressed },
                    set: { engine.vocalSuppressed = $0 }
                )) {
                    Label("Dim Vocals", systemImage: "music.mic")
                        .font(.poppinsMedium(size: 12))
                }
                .toggleStyle(.switch)
                .tint(Color(red: 0.4, green: 0.8, blue: 1.0))
            }
        }
        .foregroundStyle(.white)
        .padding(14)
        .frame(width: 200)
        .background(Color.black.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(red: 0.4, green: 0.8, blue: 1.0).opacity(0.3), lineWidth: 1)
        )
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    // MARK: - Lyrics (Dominant Center)

    private var lyricsBox: some View {
        VStack(spacing: 16) {
            if engine.lyrics.isEmpty {
                Text("♪ Instrumental ♪")
                    .font(.poppinsBold(size: 28))
                    .foregroundStyle(.white.opacity(0.4))
            } else {
                ForEach(visibleLyricWindow, id: \.offset) { item in
                    Text(lyricText(for: item.line.text))
                        .font(item.isCurrent ? .poppinsBold(size: 36) : .poppinsMedium(size: 24))
                        .foregroundStyle(item.isCurrent ? .white : .white.opacity(0.2))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .animation(.easeInOut(duration: 0.3), value: engine.currentLyricIndex)
                }
            }
        }
        .frame(maxWidth: 700)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 12) {
            // Progress bar
            progressBar

            // Controls row
            HStack(spacing: 20) {
                // Voice HUD (compact)
                compactVoiceHUD

                Spacer()

                // Score display
                if engine.isPerforming {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.yellow)
                        Text("\(engine.overallScore)")
                            .font(.orbitronBold(size: 18))
                            .foregroundStyle(.white)
                            .meloGlowText()
                    }
                }

                Spacer()

                // Finish button
                if engine.isPerforming {
                    Button {
                        engine.stop()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 12))
                            Text("FINISH")
                                .font(.orbitronBold(size: 12))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.red.opacity(0.7))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.red.opacity(0.5), lineWidth: 1)
                        )
                        .shadow(color: .red.opacity(0.3), radius: 8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            // Estimate duration from the last lyric timestamp + a buffer, or a fallback
            let estimatedDuration: TimeInterval = {
                if let lastLine = engine.lyrics.last {
                    return lastLine.time + 15 // add ~15s buffer after last lyric
                }
                return max(180, engine.elapsed + 30) // fallback: 3 min or current + 30s
            }()
            let progress = min(1, engine.elapsed / max(1, estimatedDuration))

            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 4)

                // Fill
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.4, green: 0.8, blue: 1.0), Color(red: 0.6, green: 0.4, blue: 1.0)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * progress, height: 4)
                    .animation(.linear(duration: 0.1), value: progress)

                // Knob
                Circle()
                    .fill(Color(red: 0.4, green: 0.8, blue: 1.0))
                    .frame(width: 10, height: 10)
                    .offset(x: geo.size.width * progress - 5)
                    .animation(.linear(duration: 0.1), value: progress)
            }
        }
        .frame(height: 10)
    }

    // MARK: - Compact Voice HUD

    private var compactVoiceHUD: some View {
        let voice = engine.currentVoice
        return HStack(spacing: 12) {
            // Note name
            Text(voice.isVoiced ? voice.noteName : "—")
                .font(.orbitronBold(size: 14))
                .foregroundStyle(voice.isVoiced ? .white : .white.opacity(0.3))
                .frame(width: 40)

            // Cents indicator (compact)
            centsNeedle(cents: voice.centsOff)
                .frame(width: 80, height: 14)

            // Energy bar (compact)
            energyMeter(db: voice.db)
                .frame(width: 6, height: 24)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Song Artwork Helper

    @ViewBuilder
    private func songArtwork(size: CGFloat) -> some View {
        if let urlString = song.artworkURLString, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    defaultSongArtwork(size: size)
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size > 80 ? 20 : 10))
        } else {
            defaultSongArtwork(size: size)
                .frame(width: size, height: size)
        }
    }

    private func defaultSongArtwork(size: CGFloat) -> some View {
        let hue = Double(abs(song.title.hashValue) % 100) / 100.0
        return RoundedRectangle(cornerRadius: size > 80 ? 20 : 10)
            .fill(LinearGradient(
                colors: [
                    Color(hue: hue, saturation: 0.5, brightness: 0.7),
                    Color(hue: hue, saturation: 0.65, brightness: 0.4),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.3))
                    .foregroundStyle(.white.opacity(0.8))
            }
    }

    // MARK: - Lyric Helpers

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

    /// The current line plus two of context on each side for the scrolling lyric display.
    private var visibleLyricWindow: [(offset: Int, line: LyricLine, isCurrent: Bool)] {
        guard !engine.lyrics.isEmpty else { return [] }
        let current = engine.currentLyricIndex ?? -1
        let range = (current - 2)...(current + 2)
        return engine.lyrics.enumerated()
            .filter { range.contains($0.offset) }
            .map { (offset: $0.offset, line: $0.element, isCurrent: $0.offset == current) }
    }

    // MARK: - Voice Visualization Helpers

    private func centsNeedle(cents: Double?) -> some View {
        GeometryReader { geo in
            let width = geo.size.width
            let fraction = ((cents ?? 0) + 50) / 100
            let accuracy = 1 - min(1, abs(cents ?? 50) / 50)
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.18)).frame(height: 3)
                Rectangle().fill(.white.opacity(0.35))
                    .frame(width: 1.5, height: 10)
                    .position(x: width / 2, y: geo.size.height / 2)
                if cents != nil {
                    Circle()
                        .fill(Color(hue: 0.0 + 0.33 * accuracy, saturation: 0.85, brightness: 1))
                        .frame(width: 10, height: 10)
                        .position(x: width * fraction, y: geo.size.height / 2)
                        .animation(.easeOut(duration: 0.08), value: fraction)
                }
            }
        }
    }

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

    // MARK: - Debug

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
        .font(.system(size: 9, design: .monospaced))
        .foregroundStyle(.white.opacity(0.85))
        .padding(4)
        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 4))
    }
}
