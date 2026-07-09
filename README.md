# Melodash

Melodash is a local, couch-multiplayer **singing battle** that scores **how you feel a song, not
just whether you hit the notes**. 2–5 players take turns singing; as each player performs, the app
listens to their voice *and* watches their expression, gives live feedback, and hands back a
per-turn score. A space-themed wizard runs the whole battle — setup, avatars, a "Mic Roulette"
turn order, per-turn results, and a final podium.

Everything runs **on-device** with Apple frameworks only — **Vision + Core ML** for expression,
**AVAudioEngine + Accelerate** for voice, **MusicKit** for Apple Music. One codebase runs on
**macOS and iOS**.

> **Deep dive:** [`TECH_REPORT.md`](TECH_REPORT.md) has the full system architecture, the scoring
> formulas, the audio-session choreography, and the design decisions (with diagrams).

## How it scores

Each performance blends **two independent signals**, computed live and entirely on-device:

- **Voice** — realtime pitch (FFT autocorrelation via Accelerate), scored on a *relative* model:
  in-tune-ness to the nearest note, pitch stability, onset timing vs. the lyric lines, and dynamic
  range. No reference melody needed.
- **Expression** — facial emotion (a Core ML classifier + a Vision-landmark smile score) compared
  against the target *"vibe"* of the song's genre via cosine similarity.

`overall = 0.4 · expression + 0.6 · voice`, and it **degrades gracefully** — no camera scores on
voice alone, no mic scores on expression alone. Live during the song: a pitch needle (note +
cents), an energy meter, lyric highlighting synced to the audio, and an emotion badge.

## Song sources

Every song plays through one seam (`PlaybackSource`) so the rest of the app is identical:

| Source | Playback | Vocal-suppress | Lyrics |
|---|---|---|---|
| **Bundled** (`.m4a` in the app) | `AVAudioEngine` | ✅ center-channel | bundled `.lrc` |
| **Imported** (user's own file) | `AVAudioEngine` | ✅ center-channel | — |
| **Apple Music** (MusicKit) | `ApplicationMusicPlayer` | ❌ (DRM — no sample access) | fetched at runtime |

For local songs the backing track and the mic share one `AVAudioEngine`, so voice-processing
**echo cancellation** keeps the captured voice clean on speaker. Apple Music plays the full mix
(no vocal dimming is possible on DRM audio) — **headphones recommended** so the mic hears only you.

## Architecture

SwiftUI + SwiftData. Two roots — a `BattleController` (the game state machine) and a
`MelodashEngine` (the per-turn scoring coordinator that drives lyric sync, scoring, and progress
off a **single audio clock**). Protocol seams keep the hardware/ML boundaries swappable:

- **`PlaybackSource`** — `LocalAudioEngine` (local files) vs. `MusicKitPlaybackSource` (Apple Music)
- **`VocalSuppressing`** — the vocal-dim capability, split out so only local sources conform
- **`VocalSeparating`** — `CenterChannelSuppressor` today; an on-device stem separator could drop in later
- **`EmotionAnalyzing`** — the Core ML classifier, with a geometry-based placeholder fallback

```
Melodash/
├─ App/           MelodashApp (@main, ModelContainer), ContentView (screen router)
├─ Models/        Song (+ genres), Emotion, VoiceReading, Player/Avatar, BattleTurn, SampleData, SongImporter
├─ Engine/        MelodashEngine, PlaybackSource + LocalAudioEngine + MusicKitPlaybackSource + VoiceSuppressor,
│                 MicController + PitchDetector, CameraController + EmotionAnalyzing + EmotionFusion,
│                 ScoringMatrix + VoiceScoringMatrix, LyricsLoader + LyricsService
├─ Flow/          BattleController + the battle screens (Home, Setup, AvatarPick, TurnOrder,
│                 RoundIntro, SongPick, Performance, Result, Winners, Lobby) + AppleMusicSearcher
├─ DesignSystem/  Tokens, Theme, SpaceScene, SharedComponents, CameraPreview
└─ Resources/     Info.plist, fonts (Orbitron, Poppins); Assets and the optional
                  MelodashEmotionClassifier.mlmodel live alongside
```

## Requirements

- **Xcode 26+**.
- Targets **macOS 26** and **iOS 26.5** (adjustable in build settings).
- Because the app uses the **camera and microphone**, run it on a **Mac** (native) or a **physical
  iOS device** — the iOS Simulator can't exercise the pitch/echo-cancellation and MusicKit paths.

## Build & run

```sh
open Melodash.xcodeproj
```

Select the **Melodash** scheme and run (My Mac, or a connected iOS device). On first launch the app
seeds a small bundled catalog; grant **camera** and **microphone** permission when prompted.

## The emotion model

The expression classifier is a Create ML image classifier bundled as
`Melodash/MelodashEmotionClassifier.mlmodel` (Xcode compiles it to `.mlmodelc`). It's loaded by
name at runtime; **if it's ever absent, the app falls back to a geometry-based placeholder** so the
whole pipeline still runs. Retraining is a drop-in replacement of that file.

## Apple Music setup

Apple Music playback needs one-time setup:

1. Enable **MusicKit** for the app's App ID in the [Apple Developer portal](https://developer.apple.com/account)
   → Identifiers → *(your bundle ID)* → **MusicKit** → Save. The App ID must match the project's
   bundle identifier exactly.
2. Run signed into an **active Apple Music subscription** (non-subscribers get 30-second previews).

Then use **Search** / the **＋** in the song list to add an Apple Music track. MusicKit works via
the App ID service plus the `NSAppleMusicUsageDescription` string (already set) — no entitlements
file needed.

> **Note on the bundle identifier:** the product is branded *Melodash*, but the bundle id is kept
> as `me.babonoo.kemon` because that is the App ID registered for MusicKit. Changing it requires
> registering a new App ID with MusicKit enabled.

## Content & licensing

The songs bundled in the repo are for **development and internal testing only** and are not licensed
for distribution. Shipping a public build with recognizable songs requires the full music-licensing
stack (mechanical + sync + master + performance + lyric-display rights). For a wider beta, swap to
royalty-free/owned content. Apple Music lyrics are fetched at runtime from public providers (LRCLIB
primary, with a fallback aggregator), disambiguated by track duration, since MusicKit exposes no
lyrics API.

## Privacy

Camera and microphone are processed **entirely on-device** and never uploaded or recorded. The only
data leaving the device is a song's title/artist/duration, sent to fetch public synced lyrics. The
app doesn't track users and runs in the App Sandbox with exactly three capabilities — camera,
microphone, and outbound network. See [`PrivacyInfo.xcprivacy`](Melodash/PrivacyInfo.xcprivacy).

## Status

Scoring engine, Apple Music search, and remote lyrics are implemented and building on macOS and iOS.
On-device validation of the end-to-end singing experience (pitch accuracy, echo cancellation,
MusicKit playback, multi-turn battles) is the ongoing pre-release checklist.
```
