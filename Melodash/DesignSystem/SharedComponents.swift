//
//  SharedComponents.swift
//  Melodash
//
//  Small view helpers shared across screens, factored out of the individual
//  views so artwork and avatar rendering live in one place.
//

import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

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

/// A square browse-genre tile image: the bundled `genre-<name>` asset when one
/// has been added, otherwise a deterministic gradient tile stamped with the
/// genre name so the Genre screen works before real artwork exists.
struct GenreTileArtwork: View {
    let genre: DisplayGenre
    let size: CGFloat
    var cornerRadius: CGFloat = 16

    var body: some View {
        ZStack {
            if imageExists {
                Image(genre.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var imageExists: Bool {
        #if canImport(AppKit)
        NSImage(named: genre.imageName) != nil
        #elseif canImport(UIKit)
        UIImage(named: genre.imageName) != nil
        #else
        false
        #endif
    }

    private var fallback: some View {
        let hue = Double(abs(genre.rawValue.hashValue) % 100) / 100.0
        return LinearGradient(
            colors: [
                Color(hue: hue, saturation: 0.55, brightness: 0.7),
                Color(hue: hue, saturation: 0.72, brightness: 0.4),
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .overlay {
            Text(genre.displayName.uppercased())
                .font(.orbitronBold(size: max(12, size * 0.12)))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(8)
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
