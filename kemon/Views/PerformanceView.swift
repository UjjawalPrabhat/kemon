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
    /// Called when the singer backs out to pick a different song (no scoring).
    var onCancel: () -> Void = {}
    /// Called with the final score breakdown when the singer taps Continue.
    var onFinish: (TurnResult) -> Void = { _ in }

    @State private var engine = KemonEngine()
    @State private var showRomanized = false
    @State private var showVolumePanel = false
    /// Set once the user dismisses the Apple Music subscription warning.
    @State private var dismissedWarning = false
    /// While the user is dragging the progress bar, the previewed 0...1 position.
    /// Nil when not scrubbing, so the bar follows the live clock.
    @State private var scrubProgress: Double?
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

    // MARK: - Change Song button

    /// Backs out of this performance to reselect a song. Sets `didFinish` so the
    /// engine's teardown (via `onDisappear`) can't fire `onFinish` and score the
    /// abandoned track.
    private var changeSongButton: some View {
        Button {
            didFinish = true
            engine.stop()
            onCancel()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .bold))
                Text("CHANGE SONG")
                    .font(.orbitronBold(size: 11))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.white.opacity(0.12)))
            .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        VStack(spacing: 28) {
            Spacer()

            // Song album artwork (large)
            SongArtworkView(song: song, size: 180, cornerRadius: 20)
                .shadow(color: Color.kemonBlue.opacity(0.3), radius: 20)

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
                        .foregroundStyle(Color.kemonBlue)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .stroke(Color.kemonBlue.opacity(0.5), lineWidth: 1.5)
                )
            }

            Spacer()

            // Loading indicator
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.regular)
                    .tint(Color.kemonBlue)

                Text("PREPARING YOUR STAGE...")
                    .font(.orbitronBold(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .kemonPage(showPlanet: false, showCockpit: false, ufoStyle: .none)
        .overlay(alignment: .topLeading) {
            changeSongButton
                .padding(.top, 16)
                .padding(.leading, 24)
        }
    }

    // MARK: - Live Karaoke Stage

    // Softer pastel cyan — the player card's fill (lighter than the Color.kemonCyan border).
    private static let playerCyan = Color(red: 0.53, green: 0.83, blue: 0.93)
    // Deep indigo fill behind the song card (matches the design, not pure black).
    private static let songNavy = Color(red: 0.09, green: 0.10, blue: 0.28)

    private var karaokeStage: some View {
        ZStack {
            // Space background (planet + moon + drifting UFO, matching the design)
            Color.clear
                .kemonPage(showPlanet: true, showMoon: true, showCockpit: false, ufoStyle: .purpleRed)

            // Center lyrics + bottom playback bar. Sized off the live window so
            // the stage scales from small windows up to large displays.
            GeometryReader { geo in
                VStack(spacing: 0) {
                    Spacer(minLength: geo.size.height * 0.12)

                    // Fixed-height slot: lines entering/leaving the window no
                    // longer reflow the whole page (that shift read as a "buffer").
                    lyricsView(width: geo.size.width)
                        .frame(height: geo.size.height * 0.46)
                        .padding(.horizontal, 40)

                    Spacer(minLength: 24)

                    playbackBar
                        .frame(maxWidth: min(geo.size.width * 0.62, 980))
                        .padding(.horizontal, 24)
                        .padding(.bottom, 28)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        // Top-left: change song
        .overlay(alignment: .topLeading) {
            changeSongButton
                .padding(.top, 16)
                .padding(.leading, 24)
        }
        // Top-center: player card + song card
        .overlay(alignment: .top) {
            playerSongCard
                .padding(.top, 16)
                .padding(.horizontal, 220) // clear the corner controls
        }
        // Top-right: mirrored camera preview
        .overlay(alignment: .topTrailing) {
            cameraPip
                .padding(.top, 16)
                .padding(.trailing, 24)
        }
        // Bottom-left: live score
        .overlay(alignment: .bottomLeading) {
            if engine.isPerforming {
                liveScoreChip
                    .padding(.leading, 28)
                    .padding(.bottom, 34)
            }
        }
        // Bottom-right: finish
        .overlay(alignment: .bottomTrailing) {
            if engine.isPerforming {
                finishButton
                    .padding(.trailing, 28)
                    .padding(.bottom, 34)
            }
        }
        // Bottom-right: volumes panel pops over when opened
        .overlay(alignment: .bottomTrailing) {
            if showVolumePanel {
                VolumePanel(engine: engine)
                    .padding(.trailing, 24)
                    .padding(.bottom, 120)
            }
        }
        // Apple Music subscription / playback warning banner
        .overlay(alignment: .top) {
            if let warning = engine.playbackWarning, !dismissedWarning {
                PlaybackWarningBanner(message: warning) {
                    withAnimation(.spring(duration: 0.3)) { dismissedWarning = true }
                }
                .padding(.top, 128)
                .padding(.horizontal, 40)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.4), value: engine.playbackWarning)
    }

    // MARK: - Top: Player + Song card (centered)

    /// Both top cards share this height; the player card is a square of it.
    private static let topCardHeight: CGFloat = 100

    private var playerSongCard: some View {
        HStack(spacing: 14) {
            // Player card — square, soft pastel cyan with a bright cyan glow border
            VStack(spacing: 7) {
                Text(playerName.isEmpty ? "Singer" : playerName)
                    .font(.poppinsBold(size: 13))
                    .foregroundStyle(Color.kemonInkBlue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.55)))
                    .overlay(Capsule().stroke(Color.kemonInkBlue, lineWidth: 1.5))

                avatarSquare(size: 46)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(width: Self.topCardHeight, height: Self.topCardHeight)
            .background(RoundedRectangle(cornerRadius: 18).fill(Self.playerCyan))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.kemonCyan, lineWidth: 2))
            .shadow(color: Color.kemonCyan.opacity(0.5), radius: 10)

            // Song card — wider rectangle, matches the player card's height
            HStack(spacing: 14) {
                SongArtworkView(song: song, size: 56, cornerRadius: 10)
                    .grayscale(1.0)

                VStack(alignment: .leading, spacing: 4) {
                    Text(song.title)
                        .font(.poppinsBold(size: 22))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(song.artist)
                        .font(.poppinsMedium(size: 14))
                        .foregroundStyle(Color.kemonCyan)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(width: 380, height: Self.topCardHeight, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18).fill(Self.songNavy))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.kemonCyan, lineWidth: 2))
            .shadow(color: Color.kemonCyan.opacity(0.5), radius: 10)
        }
        .fixedSize()
    }

    // MARK: - Top-right: Camera PiP (mirrored, avatar + emotion overlaid)

    private var cameraPip: some View {
        VStack(alignment: .trailing, spacing: 8) {
            CameraPreview(session: engine.camera.session)
                .frame(width: 200, height: 150)
                .scaleEffect(x: -1, y: 1)  // mirror like a selfie
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.kemonBlue.opacity(0.4), lineWidth: 1.5)
                )
                // Player avatar, on the preview (top-left)
                .overlay(alignment: .topLeading) {
                    avatarCircle(size: 36)
                        .padding(8)
                }
                // Emotion badge (bottom-right)
                .overlay(alignment: .bottomTrailing) {
                    emotionBadgeCompact
                        .padding(8)
                }
                .shadow(color: Color.kemonBlue.opacity(0.2), radius: 8)

            // Live pitch HUD, tucked under the camera (moved out of the bar).
            if engine.isPerforming {
                compactVoiceHUD
            }

            if engine.hasNonLatinLyrics {
                romanizeButton
            }

            #if DEBUG
            if Self.showsDebug {
                debugReadout
            }
            #endif
        }
    }

    private var romanizeButton: some View {
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

    // MARK: - Avatar helpers

    @ViewBuilder
    private func avatarSquare(size: CGFloat) -> some View {
        if !avatarImageName.isEmpty {
            Image(avatarImageName).resizable().scaledToFit().frame(width: size, height: size)
        } else {
            Image("avatar-placeholder").resizable().scaledToFit()
                .frame(width: size * 0.7, height: size * 0.7).opacity(0.4)
        }
    }

    private func avatarCircle(size: CGFloat) -> some View {
        avatarSquare(size: size * 0.8)
            .frame(width: size, height: size)
            .background(Circle().fill(Color.black.opacity(0.5)))
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.kemonBlue.opacity(0.7), lineWidth: 1.5))
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

    // MARK: - Lyrics (Dominant Center)

    private func lyricsView(width: CGFloat) -> some View {
        // Type scales with the window width, clamped so it stays readable on a
        // small window and doesn't get absurd on a large external display.
        let currentSize = min(76, max(34, width * 0.037))
        let contextSize = currentSize * 0.60
        let lineSpacing = currentSize * 0.55

        return VStack(spacing: lineSpacing) {
            if engine.lyrics.isEmpty {
                Text("♪ Instrumental ♪")
                    .font(.poppinsBold(size: contextSize))
                    .foregroundStyle(.white.opacity(0.4))
            } else {
                ForEach(visibleLyricWindow, id: \.offset) { item in
                    Text(lyricText(for: item.line.text))
                        .font(item.isCurrent ? .poppinsBold(size: currentSize)
                                             : .poppinsMedium(size: contextSize))
                        .foregroundStyle(item.isCurrent ? .white : .white.opacity(0.22))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        // Stable id + fade transition → smooth swap, no snap.
                        .id(item.offset)
                        .transition(.opacity)
                }
            }
        }
        .frame(maxWidth: min(width * 0.82, 1200))
        .frame(maxWidth: .infinity)
        // One animation on the container drives the whole window change.
        .animation(.easeInOut(duration: 0.35), value: engine.currentLyricIndex)
    }

    // MARK: - Bottom Playback Bar (centered)

    private var playbackBar: some View {
        // The glowing control pill: play · progress · volumes. Score and Finish
        // live in the bottom corners (see karaokeStage overlays).
        HStack(spacing: 18) {
            playPauseButton

            progressBar

            volumesToggleButton
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.13, green: 0.16, blue: 0.42),
                            Color(red: 0.10, green: 0.12, blue: 0.32)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.kemonCyan, lineWidth: 2)
        )
        .shadow(color: Color.kemonCyan.opacity(0.45), radius: 14)
    }

    private var liveScoreChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
                .font(.system(size: 15))
                .foregroundStyle(.yellow)
            Text("\(engine.overallScore)")
                .font(.orbitronBold(size: 20))
                .foregroundStyle(.white)
                .meloGlowText()
        }
        .padding(.horizontal, 4)
    }

    private var playPauseButton: some View {
        Button {
            engine.togglePause()
        } label: {
            Image(systemName: engine.isPaused ? "play.fill" : "pause.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(engine.isPaused ? "Play" : "Pause")
    }

    private var volumesToggleButton: some View {
        Button {
            withAnimation(.spring(duration: 0.3)) { showVolumePanel.toggle() }
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(showVolumePanel ? Color.kemonBlue : .white)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var finishButton: some View {
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
            .background(Capsule().fill(Color.red.opacity(0.7)))
            .overlay(Capsule().stroke(Color.red.opacity(0.5), lineWidth: 1))
            .shadow(color: .red.opacity(0.3), radius: 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            let duration = engine.estimatedDuration
            let liveProgress = min(1, engine.elapsed / max(1, duration))
            // While dragging, follow the finger; otherwise follow the clock.
            let progress = scrubProgress ?? liveProgress
            let isScrubbing = scrubProgress != nil

            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 4)

                // Fill
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.kemonBlue, Color(red: 0.6, green: 0.4, blue: 1.0)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * progress, height: 4)
                    .animation(isScrubbing ? nil : .linear(duration: 0.1), value: progress)

                // Knob — a white pill that grows while scrubbing for feedback
                Capsule()
                    .fill(.white)
                    .frame(width: isScrubbing ? 30 : 26, height: isScrubbing ? 18 : 15)
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                    .offset(x: geo.size.width * progress - (isScrubbing ? 15 : 13))
                    .animation(isScrubbing ? nil : .linear(duration: 0.1), value: progress)
                    .animation(.spring(duration: 0.2), value: isScrubbing)
            }
            // Full-height hit area so the thin bar is easy to grab.
            .frame(height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        scrubProgress = max(0, min(1, value.location.x / geo.size.width))
                    }
                    .onEnded { value in
                        let p = max(0, min(1, value.location.x / geo.size.width))
                        engine.seek(to: p * duration)
                        scrubProgress = nil
                    }
            )
        }
        .frame(height: 20)
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

    // MARK: - Lyric Helpers

    private func lyricText(for text: String) -> String {
        showRomanized ? text.romanizedLatin : text
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
