//
//  Components.swift
//  Melodash
//
//  Small shared UI atoms used across the wizard screens — extracted so the
//  same chip / label / affordance is defined once and styled consistently.
//

import SwiftUI

// MARK: - "… SELECTING" chip

/// The neon capsule that names whose turn it is to pick (e.g. "• P1 SELECTING").
struct SelectingChip: View {
    /// The subject shown before "SELECTING" — a player tag or name, uppercased.
    let subject: String

    var body: some View {
        Text("• \(subject) SELECTING")
            .font(.poppinsBold(size: 12))
            .foregroundStyle(Color.melodashBlue)
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(Capsule().stroke(Color.melodashBlue, lineWidth: Stroke.thin))
            .meloGlowText()
    }
}

// MARK: - Section label

/// An uppercase Orbitron micro-header (sidebar groups, screen sub-headers).
struct SectionLabel: View {
    let text: String
    var size: CGFloat = 11
    var opacity: Double = 0.4

    var body: some View {
        Text(text)
            .font(.orbitronBold(size: size))
            .foregroundStyle(.white.opacity(opacity))
    }
}

// MARK: - Back affordance

/// A small top-left back chevron used across the wizard screens.
struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.backward")
                .font(.title2.weight(.semibold))
                .padding(12)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .padding(8)
    }
}
