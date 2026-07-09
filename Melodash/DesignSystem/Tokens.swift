//
//  Tokens.swift
//  Melodash
//
//  The single source of truth for the Melodash visual language: the colour
//  palette, the deep-space gradient, and the spacing / radius / stroke / type
//  scales. Everything visual should reference a token here rather than a raw
//  literal, so the look stays consistent and is tunable in one place.
//

import SwiftUI

// MARK: - Colour palette

extension Color {

    // Surfaces — the deep-space navies, darkest (page) to lightest (active).
    /// The page background base.
    static let melodashSurface       = Color(red: 0.05, green: 0.05, blue: 0.15)
    /// Cards, tiles, and panels raised above the page.
    static let melodashSurfaceRaised = Color(red: 0.10, green: 0.12, blue: 0.30)
    /// Selected rows, position badges, and other active-state fills.
    static let melodashSurfaceActive = Color(red: 0.12, green: 0.20, blue: 0.42)

    // Accents.
    /// Primary neon blue — glows, highlights, most accented text.
    static let melodashBlue    = Color(red: 0.40, green: 0.80, blue: 1.00)
    /// Brighter, more saturated cyan for glowing card borders.
    static let melodashCyan    = Color(red: 0.24, green: 0.85, blue: 1.00)
    /// Deep indigo for dark-on-light text and outlines.
    static let melodashInkBlue = Color(red: 0.184, green: 0.282, blue: 0.647)
    /// White — primary foreground on the dark theme.
    static let melodashInk     = Color.white
    /// Cyan drop-shadow glow under the primary button (#6AD6EB).
    static let melodashGlow      = Color(red: 0.416, green: 0.839, blue: 0.922)
    /// Pale periwinkle inner-highlight on the primary button (#A1B7FF).
    static let melodashHighlight = Color(red: 0.631, green: 0.718, blue: 1.00)
    /// Violet used at the far end of accent gradients.
    static let melodashViolet    = Color(red: 0.60, green: 0.40, blue: 1.00)

    /// Pale lavender fill of the primary button (#D9E2FF).
    static let melodashButtonFill = Color(red: 0.851, green: 0.886, blue: 1.00)

    // Podium / status.
    /// 1st-place gold.
    static let melodashGold    = Color(red: 0.96, green: 0.77, blue: 0.09)
    /// 3rd-place orange (also the comet trail).
    static let melodashOrange  = Color(red: 0.96, green: 0.46, blue: 0.12)
    /// Soft red for warnings / playback errors.
    static let melodashWarning = Color(red: 1.00, green: 0.55, blue: 0.55)
}

extension LinearGradient {
    /// The app's base deep-space vertical gradient (Figma stops), shared by the
    /// main background and the bespoke result/finale backdrops.
    static let melodashSpace = LinearGradient(
        stops: [
            .init(color: Color(red:  4.0/255, green:  7.0/255, blue: 26.0/255), location: 0.0),
            .init(color: Color(red:  8.0/255, green: 13.0/255, blue: 42.0/255), location: 0.4),
            .init(color: Color(red: 10.0/255, green:  5.0/255, blue: 32.0/255), location: 1.0)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Metric scales

/// Corner-radius steps (points). `lg` is the standard card radius.
enum Radius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 22
    static let xl: CGFloat = 28
}

/// Stroke widths (points).
enum Stroke {
    static let hair: CGFloat = 1
    static let thin: CGFloat = 1.5
    static let thick: CGFloat = 2
}
