# Melodash

Melodash is an iOS karaoke app that scores **how you feel the song, not just whether you hit the notes**. As you sing, it listens to your voice *and* watches your expression, then gives live feedback and a post-song breakdown — so you can perform a song the way it was meant to be felt.

Everything runs **on-device** (Apple frameworks only): Vision + Core ML + ARKit for expression, Accelerate + AVAudioEngine for voice, MusicKit for Apple Music playback.

## What it scores

Each performance blends two independent signals into one score:

- **Voice** — real-time pitch (FFT autocorrelation), scored on a relative model: in-tune-ness to the nearest note, pitch stability, onset timing vs the lyric lines, and dynamic range.
- **Expression** — facial emotion (Core ML classifier + Vision-landmark smile, or ARKit blendshapes) compared against the target "vibe" of the song's genre.

Live feedback during the song: a pitch needle (note + cents), an energy meter, lyric highlighting synced to the audio, and an emotion badge. A summary card at the end shows the overall score with a voice/vibe/pitch/timing breakdown.

## Song sources

Songs flow through one karaoke session behind a `PlaybackSource` seam:

| Source | Playback | Vocal-suppress toggle | Lyrics |
|---|---|---|---|
| **Bundled** (`.m4a` in the app) | `AVAudioEngine` | ✅ center-channel | bundled `.lrc` |
| **Imported** (user's own file) | `AVAudioEngine` | ✅ center-channel | — |
| **Apple Music** (MusicKit) | `ApplicationMusicPlayer` | ❌ (DRM — no sample access) | fetched from the network |

For local songs, the backing track and the mic share one `AVAudioEngine` so voice-processing **echo cancellation** keeps the captured voice clean on speaker. Apple Music plays the full mix (no vocal dimming is possible on DRM audio) — **headphones are recommended** so the mic hears only you.

## Architecture

SwiftUI + SwiftData, with an `@Observable` `MelodashEngine` coordinator wiring audio, camera/ARKit, and scoring off a single audio clock. Protocol seams keep it swappable:

- `PlaybackSource` — `LocalAudioEngine` (files) vs `MusicKitPlaybackSource` (Apple Music)
- `VoiceSource` — `MicController` (mic capture → `PitchDetector` → `VoiceReading`)
- `FaceSource` — `CameraController` (Core ML + Vision) vs `ARFaceController` (blendshapes)
- `VocalSeparating` — `CenterChannelSuppressor` today; an on-device Demucs model can drop in later
- `EmotionAnalyzing` — the Core ML classifier, with a geometry-based placeholder fallback

```
Melodash/
├─ App/           MelodashApp, ContentView (the root screen router)
├─ Models/        Song (+ genres), Emotion, VoiceReading, Player/Avatar, TurnResult, SampleData, SongImporter
├─ Engine/        MelodashEngine, PlaybackSource + LocalAudioEngine + MusicKitPlaybackSource,
│                 MicController + PitchDetector, VoiceSuppressor, ScoringMatrix + VoiceScoringMatrix,
│                 CameraController + EmotionAnalyzing + EmotionFusion, LyricsLoader + LyricsService
├─ Flow/          BattleController + the battle screens (Home, Setup, AvatarPick, TurnOrder,
│                 RoundIntro, SongPick, Performance, Result, Winners, Lobby)
├─ DesignSystem/  Theme, SpaceScene, shared components, camera preview
└─ Resources/     Info.plist, fonts (Orbitron, Poppins); Assets and the optional
                  MelodashEmotionClassifier.mlmodel live alongside
```

## Requirements

- **Xcode 26+**, Swift 5+.
- Deployment target is currently **iOS 26.5** (adjustable in build settings; the real API floor is ~iOS 17).
- A **physical device** for the voice/pitch/echo-cancellation and MusicKit features — the Simulator can't exercise them.

## Build & run

```sh
open Melodash.xcodeproj
```

Select the `Melodash` scheme and run on a device. On first launch the app seeds a small bundled catalog; grant **camera** and **microphone** permission when prompted.

## Apple Music setup

Apple Music playback needs one-time setup:

1. Enable **MusicKit** for the app's App ID in the [Apple Developer portal](https://developer.apple.com/account) → Certificates, Identifiers & Profiles → Identifiers → *(your bundle ID)* → **MusicKit** → Save. The App ID must match the project's bundle identifier exactly.
2. Run on a device signed into an **active Apple Music subscription** (non-subscribers get 30-second previews only).

Then tap **＋** in the song list to search Apple Music and add a track. There is no in-Xcode capability or entitlements file to add — MusicKit works via the App ID service plus the `NSAppleMusicUsageDescription` string (already set).

## Content & licensing

The songs bundled in the repo are for **development and internal testing only** and are not licensed for distribution. Shipping a public build with recognizable songs requires the full music-licensing stack (mechanical + sync + master/re-recording + performance + lyric-display rights) — see the karaoke-industry model (KaraFun/Smule/Singa) for what that entails. For a wider beta, swap to royalty-free/owned content.

Lyrics for Apple Music tracks are fetched at runtime from public providers (LRCLIB primary, with a fallback aggregator) since MusicKit exposes no lyrics API.

## Privacy

Camera and microphone are processed **entirely on-device** and never uploaded or recorded to a server. The only data leaving the device is a song's title/artist, sent to fetch public synced lyrics. The app does not track users. See [`PrivacyInfo.xcprivacy`](Melodash/PrivacyInfo.xcprivacy).

## Status

The scoring engine, Apple Music search, and remote lyrics are implemented and building. On-device validation of the end-to-end singing experience (pitch accuracy, echo cancellation, MusicKit playback) is the remaining pre-release checklist item.
