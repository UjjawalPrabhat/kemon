//
//  SpaceScene.swift
//  Melodash
//
//  The outerspace visual scene: the layered starfield background, animated
//  planet/UFO/comet ornaments, the cockpit space-board console, and the curved
//  console base. Split out of Theme.swift.
//

import SwiftUI

// MARK: - Space Background View

struct SpaceBackgroundView: View {
    let showPlanet: Bool
    var showMoon: Bool = false
    let showCockpit: Bool
    var ufoStyle: UFOStyle = .purpleRed
    
    var body: some View {
        ZStack {
            // 1. Lowest Z-Index: Figma Gradient stops
            LinearGradient.melodashSpace
                .ignoresSafeArea()
            
            // 2. Parallax drifting stars background
            MovingStarsView()
            
            // 3. Periodic diagonal flying comet
            CometView()
            
            // 4. Floating Planet (Bottom-Left window quadrant)
            if showPlanet {
                VStack {
                    Spacer()
                    HStack {
                        FloatingPlanetView()
                            .offset(x: 40, y: -100)
                        Spacer()
                    }
                }
                .ignoresSafeArea()
            }
            
            // 5. Static Moon (Bottom centered curved surface)
            if showMoon {
                VStack {
                    Spacer()
                    Image("moon")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 180)
                }
                .ignoresSafeArea()
            }
            
            // 6. UFO overlays
            if ufoStyle == .purpleRed {
                // Floating UFO Purple (Top-Left window quadrant)
                VStack {
                    HStack {
                        FloatingUFOView(name: "ufo-purple", size: 160)
                            .offset(x: 50, y: 110)
                        Spacer()
                    }
                    Spacer()
                }
                .ignoresSafeArea()
                
                // Floating UFO Red (Bottom-Right window quadrant)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FloatingUFOView(name: "ufo-red", size: 220)
                            .offset(x: -60, y: -120)
                    }
                }
                .ignoresSafeArea()
            } else if ufoStyle == .greenYellow {
                // Floating UFO Green (Bottom-Left window quadrant)
                VStack {
                    Spacer()
                    HStack {
                        FloatingUFOView(name: "ufo-green", size: 220)
                            .rotationEffect(.degrees(15))
                            .offset(x: 100, y: -60)
                        Spacer()
                    }
                }
                .ignoresSafeArea()
                
                // Floating UFO Yellow (Bottom-Right near the moon)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FloatingUFOView(name: "ufo-yellow", size: 160)
                            .rotationEffect(.degrees(-15))
                            .offset(x: -100, y: -60)
                    }
                }
                .ignoresSafeArea()
            }
            
            // 7. Space Deck / Cockpit Frame Overlay
            if showCockpit {
                Image("space-deck")
                    .resizable()
                    .ignoresSafeArea()
            }
            
            // 8. Space Board / Center Bottom Panel with color-changing LEDs
            if showCockpit {
                VStack {
                    Spacer()
                    AnimatedSpaceBoardView()
                        .offset(y: 10)
                }
                .ignoresSafeArea()
            }
        }
    }
}

// MARK: - Animated Components

/// Parallax stars that rotate and scale slowly to feel like true 3D spatial drift
struct MovingStarsView: View {
    @State private var rotate1 = 0.0
    @State private var rotate2 = 0.0
    @State private var scale1 = 1.0
    @State private var scale2 = 1.1

    var body: some View {
        ZStack {
            Image("bg-stars")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .scaleEffect(scale1)
                .rotationEffect(.degrees(rotate1))
                .opacity(0.8)
                .onAppear {
                    withAnimation(.linear(duration: 120).repeatForever(autoreverses: false)) {
                        rotate1 = 360
                    }
                    withAnimation(.easeInOut(duration: 25).repeatForever(autoreverses: true)) {
                        scale1 = 1.15
                    }
                }
            
            Image("bg-stars")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .scaleEffect(scale2)
                .rotationEffect(.degrees(rotate2))
                .opacity(0.4)
                .blendMode(.screen)
                .onAppear {
                    withAnimation(.linear(duration: 180).repeatForever(autoreverses: false)) {
                        rotate2 = -360
                    }
                    withAnimation(.easeInOut(duration: 35).repeatForever(autoreverses: true)) {
                        scale2 = 0.95
                    }
                }
        }
        .ignoresSafeArea()
    }
}

/// A comet that flies diagonally across the sky every 9 seconds
struct CometView: View {
    @State private var positionX: CGFloat = 0
    @State private var positionY: CGFloat = 0
    @State private var isAnimating = false
    @State private var timer: Timer?

    var body: some View {
        GeometryReader { geo in
            Image("comet")
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 70)
                .position(x: positionX, y: positionY)
                .opacity(isAnimating ? 1 : 0)
                .onAppear {
                    resetPosition(in: geo.size)
                    startTimer(in: geo.size)
                }
                .onDisappear {
                    timer?.invalidate()
                    timer = nil
                }
        }
        .ignoresSafeArea()
    }

    private func resetPosition(in size: CGSize) {
        positionX = size.width + 100
        positionY = -50
    }

    private func startTimer(in size: CGSize) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 14.0, repeats: true) { _ in
            guard !isAnimating else { return }

            resetPosition(in: size)
            isAnimating = true

            withAnimation(.linear(duration: 3.5)) {
                positionX = -100
                positionY = size.height * 0.5
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                isAnimating = false
                resetPosition(in: size)
            }
        }
    }
}

/// Floating and rotating planet
struct FloatingPlanetView: View {
    @State private var floatOffset: CGFloat = 0
    @State private var rotation: Double = 0
    
    var body: some View {
        Image("planet")
            .resizable()
            .scaledToFit()
            .frame(width: 220, height: 220)
            .rotationEffect(.degrees(rotation))
            .offset(y: floatOffset)
            .onAppear {
                withAnimation(.easeInOut(duration: 5.5).repeatForever(autoreverses: true)) {
                    floatOffset = -12
                }
                withAnimation(.linear(duration: 45.0).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

/// Floating UFO with beams
struct FloatingUFOView: View {
    let name: String
    let size: CGFloat
    
    @State private var floatOffset: CGFloat = 0
    @State private var rotation: Double = 0
    
    var body: some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotation))
            .offset(x: floatOffset)
            .onAppear {
                withAnimation(.easeInOut(duration: 4.8).repeatForever(autoreverses: true)) {
                    floatOffset = 18
                }
                withAnimation(.easeInOut(duration: 6.5).repeatForever(autoreverses: true)) {
                    rotation = 6
                }
            }
    }
}

/// Animated cockpit dashboard with pulsing LED ring shapes and color-changing sequences
struct AnimatedSpaceBoardView: View {
    @State private var dialRotation1 = 0.0
    @State private var dialRotation2 = -70.0

    var body: some View {
        ZStack {
            Image("space-board-blank")
                .resizable()
                .scaledToFit()
                .frame(width: 480, height: 180)
            
            // Left Red Dial widget (Radar/Compass Style)
            ZStack {
                // Outer glow border
                Circle()
                    .stroke(Color.red.opacity(0.8), lineWidth: 3)
                    .shadow(color: .red.opacity(0.6), radius: 6)
                
                // Outer ring ticks
                Circle()
                    .stroke(Color.red.opacity(0.3), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [4, 8]))
                
                // Rotating needle
                Rectangle()
                    .fill(LinearGradient(colors: [.red, .clear], startPoint: .top, endPoint: .bottom))
                    .frame(width: 3, height: 26)
                    .offset(y: -13)
                    .rotationEffect(.degrees(dialRotation1))
                
                // Central hub
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .shadow(color: .red, radius: 4)
            }
            .frame(width: 60, height: 60)
            .offset(x: -122, y: -16)
            .onAppear {
                withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                    dialRotation1 = 360
                }
            }
            
            // Right Yellow Dial widget (Tachometer/Oscillating Style)
            ZStack {
                // Outer glow border
                Circle()
                    .stroke(Color.yellow.opacity(0.8), lineWidth: 3)
                    .shadow(color: .yellow.opacity(0.6), radius: 6)
                
                // Arc scale indicator
                Circle()
                    .trim(from: 0.15, to: 0.85)
                    .stroke(Color.yellow.opacity(0.4), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(90))
                
                // Oscillating needle
                Rectangle()
                    .fill(Color.yellow)
                    .frame(width: 3, height: 26)
                    .offset(y: -13)
                    .rotationEffect(.degrees(dialRotation2))
                
                // Central hub
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 8, height: 8)
                    .shadow(color: .yellow, radius: 4)
            }
            .frame(width: 60, height: 60)
            .offset(x: -50, y: -16)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    dialRotation2 = 70.0
                }
            }
            
            // Right Pane HUD Container (Aligns inside the gray console box)
            ZStack {
                // A. White Monitor Screen (oscillates sound waves)
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(red: 0.91, green: 0.94, blue: 1.0)) // #E8EFFF
                        .frame(width: 80, height: 36)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.8), lineWidth: 1.2)
                        )
                        .shadow(color: .white.opacity(0.3), radius: 3)
                    
                    // Pulses of green frequency lines
                    HStack(alignment: .bottom, spacing: 2) {
                        SoundwaveBarView(duration: 0.45)
                        SoundwaveBarView(duration: 0.6)
                        SoundwaveBarView(duration: 0.35)
                        SoundwaveBarView(duration: 0.5)
                        SoundwaveBarView(duration: 0.4)
                        SoundwaveBarView(duration: 0.55)
                        SoundwaveBarView(duration: 0.3)
                    }
                    .frame(height: 28)
                }
                .offset(x: -26, y: -20)
                
                // B. Additional 2x2 grid of small square buttons
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        SpaceBoardLEDButton(color: .orange, delay: 0.15, size: 12)
                        SpaceBoardLEDButton(color: .purple, delay: 0.35, size: 12)
                    }
                    HStack(spacing: 4) {
                        SpaceBoardLEDButton(color: .white, delay: 0.55, size: 12)
                        SpaceBoardLEDButton(color: .pink, delay: 0.75, size: 12)
                    }
                }
                .offset(x: 40, y: -20)
                
                // C. Main bottom LED row (4 standard size buttons)
                HStack(spacing: 12) {
                    SpaceBoardLEDButton(color: .red, delay: 0.0, size: 18)
                    SpaceBoardLEDButton(color: .yellow, delay: 0.2, size: 18)
                    SpaceBoardLEDButton(color: .blue, delay: 0.4, size: 18)
                    SpaceBoardLEDButton(color: .green, delay: 0.6, size: 18)
                }
                .offset(x: 6, y: 18)
            }
            .offset(x: 80, y: -8)
        }
    }
}

/// Bouncing bars representing cockpit instrumentation frequencies
struct SoundwaveBarView: View {
    @State private var height: CGFloat = 6
    let duration: Double
    
    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(Color.melodashInkBlue)
            .frame(width: 3.5, height: height)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    height = 28
                }
            }
    }
}

struct SpaceBoardLEDButton: View {
    let color: Color
    let delay: Double
    var size: CGFloat = 22
    
    @State private var isGlowing = false
    
    var body: some View {
        ZStack {
            // Dark button socket
            Circle()
                .fill(Color.black.opacity(0.75))
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                )
            
            // Pulsing color core
            Circle()
                .fill(color)
                .frame(width: size * 0.58, height: size * 0.58)
                .opacity(isGlowing ? 1.0 : 0.25)
                .shadow(color: color, radius: isGlowing ? 8 : 0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).delay(delay).repeatForever(autoreverses: true)) {
                isGlowing = true
            }
        }
    }
}

// MARK: - Console shape (used by TurnOrderView)

struct ConsoleBaseShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.height * 0.4))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.height * 0.4),
            control: CGPoint(x: rect.midX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
