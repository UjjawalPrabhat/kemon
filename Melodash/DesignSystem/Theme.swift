//
//  Theme.swift
//  Melodash
//
//  The visual identity for Melodash: Outerspace-themed visuals,
//  featuring Figma gradient stops, moving/animated stars, floating planet
//  and UFOs, flying comets, and an interactive space-board cockpit console.
//

import SwiftUI

// MARK: - Palette

extension Color {
    static let melodashCream = Color(red: 0.05, green: 0.05, blue: 0.15)
    static let melodashInk = Color.white
    static let melodashBlue = Color(red: 0.4, green: 0.8, blue: 1.0)
    /// Brighter, more saturated cyan used for glowing card borders.
    static let melodashCyan = Color(red: 0.24, green: 0.85, blue: 1.0)
    /// Deep indigo used for dark-on-cyan text and outlines.
    static let melodashInkBlue = Color(red: 0.184, green: 0.282, blue: 0.647)
}

extension LinearGradient {
    /// The app's base deep-space vertical gradient (Figma stops), shared by the
    /// main background and the bespoke result/finale backdrops.
    static let melodashSpace = LinearGradient(
        stops: [
            .init(color: Color(red: 4.0/255.0, green: 7.0/255.0, blue: 26.0/255.0), location: 0.0),
            .init(color: Color(red: 8.0/255.0, green: 13.0/255.0, blue: 42.0/255.0), location: 0.4),
            .init(color: Color(red: 10.0/255.0, green: 5.0/255.0, blue: 32.0/255.0), location: 1.0)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

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
    func melodashGlassCard(_ cornerRadius: CGFloat = 22) -> some View {
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

struct MelodashPrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var tint: Color = Color.melodashBlue
    var isEnabled: Bool = true
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
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
