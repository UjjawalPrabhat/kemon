//
//  PerformanceView.swift
//  kemon
//
//  The karaoke stage: live front-camera background, a scrolling lyric box whose
//  colour reflects how well the current expression matches the song's vibe, a
//  live emotion badge, and the running score. Ends on a summary card.
//

import SwiftUI

struct PerformanceView: View {
    let song: Song

    @State private var engine = KemonEngine()

    var body: some View {
        ZStack {
            cameraPreview
                .ignoresSafeArea()

            // Legibility scrim over the camera feed.
            LinearGradient(
                colors: [.black.opacity(0.65), .clear, .black.opacity(0.75)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                header
                Spacer()
                lyricsBox
                Spacer()
                if engine.isPerforming {
                    startStopButton
                }
            }
            .padding()

            if let summary = engine.finalSummary {
                summaryCard(summary)
            }
        }
        .navigationTitle(song.title)
        .navigationBarTitleDisplayModeInlineIfAvailable()
        .onAppear { engine.start(song: song) }
        .onDisappear { engine.stop() }
    }

    // MARK: - Pieces

    @ViewBuilder
    private var cameraPreview: some View {
        #if os(iOS) && canImport(ARKit)
        if engine.mode == .arkit, let arFace = engine.arFace {
            ARFaceCameraView(session: arFace.session)
        } else {
            CameraPreview(session: engine.camera.session)
        }
        #else
        CameraPreview(session: engine.camera.session)
        #endif
    }

    private var header: some View {
        HStack(alignment: .top) {
            emotionBadge
            Spacer()
            if engine.arKitAvailable {
                modePicker
            }
        }
    }

    /// A/B switch between the Core ML+Vision pipeline and ARKit blendshapes.
    private var modePicker: some View {
        Picker("Mode", selection: Binding(
            get: { engine.mode },
            set: { engine.setMode($0) }
        )) {
            ForEach(AnalysisMode.allCases) { m in
                Text(m.rawValue).tag(m)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 160)
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

    /// Flip to `false` before the demo. Shows raw model confidences + the Vision
    /// smile score so the fusion weights can be tuned against real faces.
    private static let showsDebug = true

    private var debugReadout: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(String(format: "smile %.2f", engine.debugSmile))
                .foregroundStyle(.green)
            ForEach(Emotion.allCases) { e in
                Text(String(format: "%@ %.2f", e.rawValue, engine.debugConfidences[e] ?? 0))
            }
        }
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(.white.opacity(0.85))
        .padding(6)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
        .padding(.leading, 4)
    }

    private var lyricsBox: some View {
        VStack(spacing: 12) {
            ForEach(visibleLyricWindow, id: \.offset) { item in
                Text(item.line.text)
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
        .tint(.red)
    }

    private func summaryCard(_ summary: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)
            Text(summary)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
            Text("\(engine.score.normalizedScore)%")
                .font(.system(size: 64, weight: .heavy, design: .rounded))
            Button("Sing Again") { engine.start(song: song) }
                .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: 340)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .padding()
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

private extension View {
    /// Inline title on iOS; no-op elsewhere so the file compiles for Mac.
    @ViewBuilder
    func navigationBarTitleDisplayModeInlineIfAvailable() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
