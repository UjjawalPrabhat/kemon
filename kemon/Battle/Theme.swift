//
//  Theme.swift
//  kemon
//
//  The visual identity for Melodash: Outerspace-themed visuals,
//  featuring Figma gradient stops, moving/animated stars, floating planet
//  and UFOs, flying comets, and an interactive space-board cockpit console.
//

import SwiftUI

// MARK: - Palette

extension Color {
    static let kemonCream = Color(red: 0.05, green: 0.05, blue: 0.15)
    static let kemonInk = Color.white
    static let kemonBlue = Color(red: 0.4, green: 0.8, blue: 1.0)
    static let spaceDark = Color(red: 0.01, green: 0.01, blue: 0.05)
}

// MARK: - Page scaffold

enum UFOStyle {
    case purpleRed
    case greenYellow
    case none
}

extension View {
    /// Overlays a view onto the custom starry space background.
    func kemonPage(showPlanet: Bool = true, showMoon: Bool = false, showCockpit: Bool = false, ufoStyle: UFOStyle = .purpleRed) -> some View {
        ZStack {
            SpaceBackgroundView(showPlanet: showPlanet, showMoon: showMoon, showCockpit: showCockpit, ufoStyle: ufoStyle)
            self
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// Neon glow text effect
    func meloGlowText(color: Color = Color(red: 0.4, green: 0.8, blue: 1.0)) -> some View {
        self
            .shadow(color: color, radius: 4)
            .shadow(color: color, radius: 8)
    }
}

// MARK: - Space Background View

struct SpaceBackgroundView: View {
    let showPlanet: Bool
    var showMoon: Bool = false
    let showCockpit: Bool
    var ufoStyle: UFOStyle = .purpleRed
    
    var body: some View {
        ZStack {
            // 1. Lowest Z-Index: Figma Gradient stops
            LinearGradient(
                stops: [
                    .init(color: Color(red: 4.0/255.0, green: 7.0/255.0, blue: 26.0/255.0), location: 0.0),
                    .init(color: Color(red: 8.0/255.0, green: 13.0/255.0, blue: 42.0/255.0), location: 0.4),
                    .init(color: Color(red: 10.0/255.0, green: 5.0/255.0, blue: 32.0/255.0), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
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

struct MoonCrater: Identifiable {
    let id = UUID()
    let size: CGFloat
    let y: CGFloat
    let speed: Double
    let initialX: CGFloat
}

struct SpinningMoonView: View {
    // A list of crater shapes distributed horizontally and vertically
    private let craters = [
        MoonCrater(size: 38, y: 35, speed: 35, initialX: -400),
        MoonCrater(size: 55, y: 70, speed: 40, initialX: -200),
        MoonCrater(size: 30, y: 10, speed: 30, initialX: -100),
        MoonCrater(size: 45, y: 60, speed: 38, initialX: 0),
        MoonCrater(size: 65, y: 20, speed: 42, initialX: 150),
        MoonCrater(size: 35, y: 80, speed: 34, initialX: 300),
        MoonCrater(size: 50, y: -5, speed: 37, initialX: 450),
        MoonCrater(size: 26, y: 50, speed: 32, initialX: -300),
        MoonCrater(size: 60, y: 25, speed: 41, initialX: -50),
        MoonCrater(size: 42, y: 65, speed: 36, initialX: 220),
        MoonCrater(size: 34, y: 15, speed: 33, initialX: 380),
        MoonCrater(size: 48, y: 75, speed: 39, initialX: -150)
    ]

    var body: some View {
        TimelineView(.animation) { timelineContext in
            let time = timelineContext.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let width = geo.size.width
                ZStack {
                    // The base blank moon surface
                    Image("moon-blank")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: width, height: 180)
                        
                    // Masked sliding craters
                    ZStack {
                        ForEach(craters) { crater in
                            let totalDistance = width + 200
                            let currentOffset = crater.initialX - CGFloat(time * crater.speed)
                            
                            // Modulo wrapping math:
                            let rawWrappedX = currentOffset.truncatingRemainder(dividingBy: totalDistance)
                            let wrappedX = rawWrappedX + (currentOffset < 0 ? totalDistance : 0) - 100
                            
                            // 3D sphere projection mapping (craters contract near horizons)
                            let distanceFromCenter = wrappedX - (width / 2)
                            let ratio = distanceFromCenter / (width / 2)
                            let scaleFactor = max(0.1, sqrt(max(0.0, 1.0 - ratio * ratio)))
                            
                            Circle()
                                .fill(Color(red: 0.08, green: 0.05, blue: 0.25).opacity(0.85)) // Dark crater shade
                                .frame(width: crater.size * scaleFactor, height: crater.size * scaleFactor)
                                .offset(x: wrappedX - (width / 2), y: crater.y)
                        }
                    }
                    .mask {
                        Image("moon-blank")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: width, height: 180)
                    }
                }
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
        }
        .ignoresSafeArea()
    }
    
    private func resetPosition(in size: CGSize) {
        positionX = size.width + 100
        positionY = -50
    }
    
    private func startTimer(in size: CGSize) {
        Timer.scheduledTimer(withTimeInterval: 14.0, repeats: true) { _ in
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
            .fill(Color(red: 0.184, green: 0.282, blue: 0.647)) // #2F48A5
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
            Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isGlowing.toggle()
                    }
                }
            }
        }
    }
}

// MARK: - Legacy vector structures (Preserved for compatibility)

struct ArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

struct CratersView: View {
    let height: CGFloat
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Circle()
                    .fill(Color(red: 0.05, green: 0.03, blue: 0.15).opacity(0.6))
                    .frame(width: 44, height: 26)
                    .position(x: geo.size.width * 0.22, y: geo.size.height - height * 0.7)
                
                Circle()
                    .fill(Color(red: 0.05, green: 0.03, blue: 0.15).opacity(0.6))
                    .frame(width: 60, height: 35)
                    .position(x: geo.size.width * 0.38, y: geo.size.height - height * 0.4)
                
                Circle()
                    .fill(Color(red: 0.05, green: 0.03, blue: 0.15).opacity(0.6))
                    .frame(width: 70, height: 40)
                    .position(x: geo.size.width * 0.65, y: geo.size.height - height * 0.6)
                
                Circle()
                    .fill(Color(red: 0.05, green: 0.03, blue: 0.15).opacity(0.6))
                    .frame(width: 50, height: 30)
                    .position(x: geo.size.width * 0.85, y: geo.size.height - height * 0.3)
            }
        }
    }
}

struct UFOView: View {
    let color: Color
    var size: CGFloat = 80
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                Path { path in
                    path.addArc(
                        center: CGPoint(x: size/2, y: size * 0.4),
                        radius: size * 0.22,
                        startAngle: .degrees(180),
                        endAngle: .degrees(360),
                        clockwise: false
                    )
                }
                .fill(color.opacity(0.4))
                .overlay(
                    Path { path in
                        path.addArc(
                            center: CGPoint(x: size/2, y: size * 0.4),
                            radius: size * 0.22,
                            startAngle: .degrees(180),
                            endAngle: .degrees(360),
                            clockwise: false
                        )
                    }
                    .stroke(color, lineWidth: 1.5)
                )
                
                Ellipse()
                    .fill(color.opacity(0.8))
                    .frame(width: size, height: size * 0.24)
                    .overlay(
                        Ellipse()
                            .stroke(color, lineWidth: 1.5)
                    )
                
                HStack(spacing: size * 0.08) {
                    ForEach(0..<4) { _ in
                        Circle()
                            .fill(Color.white)
                            .frame(width: size * 0.06, height: size * 0.06)
                            .shadow(color: .white, radius: 2)
                    }
                }
                .padding(.bottom, size * 0.06)
            }
            .frame(width: size, height: size * 0.5)
            
            BeamShape()
                .fill(LinearGradient(
                    colors: [color.opacity(0.25), color.opacity(0.0)],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(width: size * 1.5, height: size * 1.5)
                .offset(y: -size * 0.05)
        }
        .frame(width: size * 1.5)
    }
}

struct BeamShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.35, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.width * 0.65, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct CockpitFrameShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        
        let insetTop = rect.height * 0.12
        let insetLeftRight = rect.width * 0.22
        let bottomConsoleHeight = rect.height * 0.2
        
        var windowPath = Path()
        windowPath.move(to: CGPoint(x: insetLeftRight, y: insetTop))
        windowPath.addLine(to: CGPoint(x: rect.width - insetLeftRight, y: insetTop))
        windowPath.addLine(to: CGPoint(x: rect.width - insetLeftRight * 0.7, y: rect.height - bottomConsoleHeight))
        windowPath.addLine(to: CGPoint(x: insetLeftRight * 0.7, y: rect.height - bottomConsoleHeight))
        windowPath.closeSubpath()
        path.addPath(windowPath)
        return path
    }
}

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

struct ConsolePanelShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.1, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.width * 0.9, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.width * 0.95, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.width * 0.05, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Cards

extension View {
    func kemonGlassCard(_ cornerRadius: CGFloat = 22) -> some View {
        self
            .background(Color.black.opacity(0.35))
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
            )
    }
}

// MARK: - Primary Button

struct KemonPrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var tint: Color = .kemonBlue
    let action: () -> Void
    
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
                    .font(.poppinsBlack(size: 22))
            }
            .foregroundStyle(Color(red: 0.184, green: 0.282, blue: 0.647)) // #2F48A5
            .padding(.horizontal, 48)
            .padding(.vertical, 20)
            .background {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(red: 0.851, green: 0.886, blue: 1.0)) // #D9E2FF
            }
            // Inner Shadow 1: White 25%, X: 0, Y: 12, Blur: 4
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.25), lineWidth: 8)
                    .offset(y: 12)
                    .blur(radius: 4)
                    .mask(RoundedRectangle(cornerRadius: 24))
            }
            // Inner Shadow 2: #A1B7FF, X: -8, Y: 0, Blur: 4
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color(red: 0.631, green: 0.718, blue: 1.0), lineWidth: 8) // #A1B7FF
                    .offset(x: -8)
                    .blur(radius: 4)
                    .mask(RoundedRectangle(cornerRadius: 24))
            }
            // Inner Shadow 3: #A1B7FF, X: 0, Y: -8, Blur: 4
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color(red: 0.631, green: 0.718, blue: 1.0), lineWidth: 8) // #A1B7FF
                    .offset(y: -8)
                    .blur(radius: 4)
                    .mask(RoundedRectangle(cornerRadius: 24))
            }
            // Drop Shadow: #6AD6EB, X: 0, Y: 4, Blur: 14 (grows on hover)
            .shadow(
                color: Color(red: 0.416, green: 0.839, blue: 0.922).opacity(isHovered ? 1.0 : 0.7),
                radius: isHovered ? 20 : 14,
                x: 0,
                y: isHovered ? 6 : 4
            )
            .scaleEffect(isHovered ? 1.06 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Secondary Button

struct KemonGlassButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
                    .font(.headline.weight(.heavy))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.35))
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Avatar Bubble

struct AvatarBubble: View {
    let avatar: Avatar
    var size: CGFloat = 96
    var isSelected: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.45))
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            
            Text(avatar.emoji)
                .font(.system(size: size * 0.55))
        }
        .frame(width: size, height: size)
        .overlay {
            Circle()
                .strokeBorder(Color(red: 0.4, green: 0.8, blue: 1.0), lineWidth: isSelected ? 3 : 0)
                .shadow(color: Color(red: 0.4, green: 0.8, blue: 1.0), radius: isSelected ? 8 : 0)
                .padding(-4)
        }
        .animation(.snappy(duration: 0.15), value: isSelected)
    }
}

// MARK: - Custom Font Extensions

extension Font {
    static func orbitronRegular(size: CGFloat) -> Font {
        .custom("Orbitron-Regular", size: size)
    }
    static func orbitronBlack(size: CGFloat) -> Font {
        .custom("Orbitron-Black", size: size)
    }
    static func poppinsBlack(size: CGFloat) -> Font {
        .custom("Poppins-Black", size: size)
    }
    static func poppinsBold(size: CGFloat) -> Font {
        .custom("Poppins-Bold", size: size)
    }
    static func poppinsMedium(size: CGFloat) -> Font {
        .custom("Poppins-Medium", size: size)
    }
    static func orbitronBold(size: CGFloat) -> Font {
        .custom("Orbitron-Bold", size: size)
    }
}
