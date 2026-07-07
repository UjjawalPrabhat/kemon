//
//  SharedComponents.swift
//  kemon
//
//  Small view helpers shared across screens, factored out of the individual
//  views so artwork and avatar rendering live in one place.
//

import SwiftUI

/// Album art for a song: the remote artwork when available, otherwise a
/// deterministic hue-from-title gradient with a music-note glyph. `cornerRadius`
/// is explicit so each call site keeps its own rounding.
struct SongArtworkView: View {
    let song: Song
    let size: CGFloat
    var cornerRadius: CGFloat

    var body: some View {
        Group {
            if let urlString = song.artworkURLString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var fallback: some View {
        let hue = Double(abs(song.title.hashValue) % 100) / 100.0
        return RoundedRectangle(cornerRadius: cornerRadius)
            .fill(LinearGradient(
                colors: [
                    Color(hue: hue, saturation: 0.5, brightness: 0.72),
                    Color(hue: hue, saturation: 0.62, brightness: 0.43),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ))
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.3))
                    .foregroundStyle(.white.opacity(0.85))
            }
    }
}

/// A player's Memoji-style avatar image, or the dimmed placeholder when none
/// has been chosen yet. Resizable; callers apply their own frame and clip shape.
struct AvatarImage: View {
    let imageName: String?

    var body: some View {
        if let imageName, !imageName.isEmpty {
            Image(imageName).resizable()
        } else {
            Image("avatar-placeholder").resizable().opacity(0.4)
        }
    }
}
