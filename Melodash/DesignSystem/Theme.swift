//
//  Theme.swift
//  Melodash
//
//  The visual identity for Melodash: Outerspace-themed visuals,
//  featuring Figma gradient stops, moving/animated stars, floating planet
//  and UFOs, flying comets, and an interactive space-board cockpit console.
//

import SwiftUI

// MARK: - Page scaffold

enum UFOStyle {
    case purpleRed
    case greenYellow
    case none
}

extension View {
    /// Overlays a view onto the custom starry space background.
    func melodashPage(showPlanet: Bool = true, showMoon: Bool = false, showCockpit: Bool = false, ufoStyle: UFOStyle = .purpleRed) -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                SpaceBackgroundView(showPlanet: showPlanet, showMoon: showMoon, showCockpit: showCockpit, ufoStyle: ufoStyle)
                    .ignoresSafeArea()
            )
    }
    
    /// Neon glow text effect
    func meloGlowText(color: Color = Color.melodashBlue) -> some View {
        self
            .shadow(color: color, radius: 4)
            .shadow(color: color, radius: 8)
    }
}

// MARK: - Cards

extension View {
    /// The frosted, hairline-stroked card used throughout the app. Parameters
    /// let one definition cover the handful of fill/stroke variations screens need.
    func melodashGlassCard(_ cornerRadius: CGFloat = Radius.lg,
                           fill: Color = Color.black.opacity(0.35),
                           stroke: Color = Color.white.opacity(0.2),
                           lineWidth: CGFloat = Stroke.thin) -> some View {
        self
            .background(fill)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(stroke, lineWidth: lineWidth)
            )
    }
}

// MARK: - Hover scale

/// Springy grow-on-hover, extracted from the ~6 places that hand-rolled it.
private struct HoverScale: ViewModifier {
    var scale: CGFloat = 1.05
    @State private var hovering = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(hovering ? scale : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hovering)
            .onHover { hovering = $0 }
    }
}

extension View {
    /// Grows the view on hover (macOS / iPad pointer). Replaces ad-hoc
    /// `@State isHovered` + `scaleEffect` + `onHover` triples.
    func melodashHoverScale(_ scale: CGFloat = 1.05) -> some View {
        modifier(HoverScale(scale: scale))
    }
}

// MARK: - Primary Button

struct MelodashPrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var tint: Color = Color.melodashBlue
    var isEnabled: Bool = true
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button {
            SoundManager.shared.play(.buzz)
            action()
        } label: {
            HStack(spacing: 10) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
                    .font(.poppinsBlack(size: 22))
            }
            .foregroundStyle(Color.melodashInkBlue)
            .padding(.horizontal, 48)
            .padding(.vertical, 20)
            .background {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.melodashButtonFill)
            }
            // Figma inner shadows: a white top highlight and two periwinkle edges.
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.25), lineWidth: 8)
                    .offset(y: 12)
                    .blur(radius: 4)
                    .mask(RoundedRectangle(cornerRadius: 24))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.melodashHighlight, lineWidth: 8)
                    .offset(x: -8)
                    .blur(radius: 4)
                    .mask(RoundedRectangle(cornerRadius: 24))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.melodashHighlight, lineWidth: 8)
                    .offset(y: -8)
                    .blur(radius: 4)
                    .mask(RoundedRectangle(cornerRadius: 24))
            }
            // Cyan drop-shadow glow, growing on hover.
            .shadow(
                color: Color.melodashGlow.opacity(isHovered ? 1.0 : 0.7),
                radius: isHovered ? 20 : 14,
                x: 0,
                y: isHovered ? 6 : 4
            )
            .scaleEffect(isHovered && isEnabled ? 1.06 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: isHovered)
            .opacity(isEnabled ? 1.0 : 0.4)
            .onHover { hovering in
                isHovered = hovering
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

// MARK: - Secondary Button

struct MelodashGlassButton: View {
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
    let avatar: Avatar?
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
            
            if let avatar {
                Image(avatar.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.72, height: size * 0.72)
            } else {
                Image("avatar-placeholder")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.72, height: size * 0.72)
                    .opacity(0.4)
            }
        }
        .frame(width: size, height: size)
        .overlay {
            Circle()
                .strokeBorder(Color.melodashBlue, lineWidth: isSelected ? 3 : 0)
                .shadow(color: Color.melodashBlue, radius: isSelected ? 8 : 0)
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
