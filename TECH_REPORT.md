# Kemon — Tech Report

> Kemon (a.k.a. *Melodash*) is a local, couch-multiplayer **singing battle**: 2–5 players
> take turns singing, and each performance is scored on-device by **how they sound**
> (pitch, timing, dynamics) *and* **how they look** (facial expression vs. the song's vibe).
> A space-themed wizard runs the whole battle end to end — setup, avatars, turn order,
> per-turn results, and a final leaderboard.

---

## 1. Present your team

| Name  | Role (self-assigned, overlapping — it was a jam) |
|-------|--------------------------------------------------|
| **Shinta** | Product & game-flow design, playtesting |
| **Tami**   | UI / visual design, space theme, mockups |
| **Cio**    | UX, screen states, copy |
| **Bono**   | Engine + app architecture, MusicKit/audio, SwiftUI build |
| **Uj**     | ML (emotion classifier), scoring, docs |

We built Kemon as a small team where everyone touched code and design at some point,
but the split above is where each person spent most of their time.

---

## 2. Starting Assumption

**We think we'll end up using:**
On-device **ARKit face tracking** for expression + **AVAudioEngine/Accelerate** for pitch,
shipping as an **iOS** app.

**Because:**
ARKit's blendshapes (`browInnerUp`, `mouthSmileLeft`, etc.) are the "obvious" Apple way to
read a face in real time — they're high quality, already smoothed, and come with a TrueDepth
camera on every modern iPhone. It sounded like the shortest path from "phone points at your
face" to "I know if you're smiling." For audio we assumed a straight FFT pitch detector would
be enough. Honestly, the ARKit call was mostly *"it's the branded solution, it must be the fit."*

---

## 3. The Exploration Log

*(Written as we went, not cleaned up into a conclusion.)*

**What we browsed, and what surprised us:**
- ARKit `ARFaceAnchor.blendShapes` looked perfect on paper. The surprise was **how much it
  locks you in**: it needs `ARSession` + a TrueDepth device, and it does *not* exist on macOS
  at all. The moment we imagined this on a laptop for a party game, the whole assumption wobbled.
- Vision (`VNDetectFaceLandmarksRequest`) + a **Core ML image classifier** turned out to be a
  much more portable way to get "what emotion is this face" — it runs off a plain camera frame,
  no depth sensor, and works on both iOS *and* macOS.
- MusicKit's `ApplicationMusicPlayer` gives you real Apple Music playback, but the catalog audio
  is **DRM-protected** — you get playback, not samples.

**What we actually built or tested in code (not just read about):**
- A **Core ML emotion classifier** (`KemonEmotionClassifier`, trained in a Create ML
  `.mlproj` that's checked into `mlproject/`), fed by `CameraController` via Vision landmarks.
- A real **pitch pipeline**: `MicController` → `PitchDetector` (FFT/autocorrelation via
  **Accelerate**) → `VoiceScoringMatrix` (in-tune-ness, stability, onset timing, dynamics).
- A shared `AVAudioEngine` where the **backing track and mic live on the same engine** so
  voice-processing echo cancellation keeps the captured voice clean on speaker.
- Protocol seams — `FaceSource`, `VoiceSource`, `PlaybackSource` — so the concrete
  camera/mic/playback implementations are swappable behind `KemonEngine`.
- The full **battle state machine** (`BattleController`): home → setup → avatars → turn order →
  round intro → song pick → performing → result → winners.

**What we discovered that we didn't expect:**
- The single most valuable design decision was **driving everything off one audio clock**
  (`KemonEngine.elapsed`) — lyric sync, scoring windows, and progress all read the same time,
  which killed a whole class of drift bugs.
- The app was *more fun as a shared-screen battle* (pass-the-mic, big TV/laptop) than as a
  solo iPhone karaoke app. That reframed the entire product.

---

## 4. What We Tried and Dropped

**We considered:** the **ARKit blendshape expression pipeline** (our Section-1 assumption), and
also **MusicKit vocal-suppression** (dimming the lead vocal so the singer carries the melody).

**We dropped ARKit because:**
- It's **iOS/TrueDepth-only**. Once we pivoted the experience to a laptop-friendly *battle*
  (see §6), ARKit simply doesn't exist on macOS — it couldn't come with us.
- It made the "face" input a hard dependency on specific hardware, which fought our goal of a
  game a group could just start on whatever screen was in the room.
- We replaced it with **Vision + a Core ML classifier**, which reads emotion from an ordinary
  camera frame and runs on both platforms. We kept the `FaceSource` protocol so an ARKit source
  *could* be re-added on iOS later without touching the engine.

**We dropped MusicKit vocal-suppression because:**
- Apple Music catalog audio is DRM'd — there's **no sample-level access**, so you can't do
  center-channel vocal removal on it. We kept vocal-suppress only for **bundled/imported local
  files** (where we own the samples) and recommend **headphones** for Apple Music songs instead.

---

## 5. Real Limitations Hit

**ARKit → macOS wall.**
When we moved to a multiplatform (macOS) target, everything under `import ARKit` failed to
compile because the framework isn't available there. AI could scaffold *around* it but couldn't
"port" ARKit — the API genuinely doesn't exist on the Mac.
*How we worked around it:* removed the ARKit source entirely, made **Vision + Core ML** the
single expression path, and hid it behind `FaceSource` so it stays swappable per platform.

**`AVAudioSession` is iOS-only.**
Audio session configuration code compiled fine on iOS but is **absent on macOS**. This is the
kind of platform gap docs mention in passing but that only bites at build time.
*How we worked around it:* guarded all `AVAudioSession` usage so the macOS build skips it and
configures the `AVAudioEngine` directly.

**DRM on Apple Music.**
No sample access means no vocal dimming and no offline analysis of catalog tracks — a hard
platform boundary, not a bug we could code past.
*How we worked around it:* two-tier playback via `PlaybackSource` (full DSP for local files,
plain playback for Apple Music) and a UX nudge to use headphones.

**Where AI genuinely couldn't help:**
- **Emotion-classifier quality** — labeling/training data and judging "does this *feel* right"
  is human work; the model is only as good as the faces we trained it on.
- **Tuning what a score should *feel* like** — mapping raw pitch/expression signals to a number
  that feels fair and fun was pure playtesting, not something a model could tell us.

---

## 6. The Revised Decision

**Final decision:**
A **multiplatform (macOS-first) singing *battle*** built on **SwiftUI + SwiftData**, with an
`@Observable` `KemonEngine` wiring:
- **Expression:** Vision landmarks + a custom **Core ML** emotion classifier (no ARKit).
- **Voice:** **AVAudioEngine** capture + **Accelerate** FFT pitch → voice scoring matrix.
- **Music:** **MusicKit** for Apple Music, plus bundled/imported local files with vocal-suppress.
- Everything **on-device**, coordinated off a single audio clock.

**What changed since Section 1, and why:**
- **ARKit → Vision + Core ML.** Our first instinct (ARKit, because it's the branded option)
  did *not* hold up. The instant the product became a shared-screen party battle, ARKit's
  iOS/TrueDepth lock-in disqualified it. Portability beat "the official face API."
- **iOS → macOS-first multiplatform.** The game is better on a big shared screen with players
  taking turns than as a solo phone app, so we moved the target and reworked the flow into a
  turn-based battle with a results screen and a final leaderboard.
- **What *did* hold up:** the **on-device, Apple-frameworks-only** stance and the
  **audio-driven** design — those were right from day one and everything else reorganized around
  them.

---

## App Track Addendum

### About the Frameworks

Kemon genuinely uses several frameworks *together*, and the combination is the point rather than
decoration:
- **Vision + Core ML** produce the expression signal; **AVFoundation (AVAudioEngine) +
  Accelerate** produce the voice signal. The core mechanic — *scoring how you feel a song, not
  just whether you hit the notes* — **requires both** the camera pipeline and the audio pipeline
  running at once. Drop either and it's just a pitch game or just a face game.
- **MusicKit** is the one framework that's arguably optional: the app works fully on bundled/
  imported local files. MusicKit exists to widen the song catalog, and it's cleanly isolated
  behind `PlaybackSource` so a build without it still runs.

### About Accessibility and Localization

- **We did not localize** the UI (English only). Reason: it's a jam-scope party game and the
  on-screen text is minimal and mostly playful ("Your Score…", "Next Up in 05…"); translation
  wasn't where limited time bought the most player value. The strings are plain SwiftUI `Text`,
  so localization is a mechanical add later.
- **Accessibility we support:** system-font Dynamic-Type-friendly SwiftUI controls, and the
  game is fundamentally **multi-modal** (you can play to the visuals *or* the audio).
- **Accessibility we consciously did *not* fully solve:** the expression-scoring mechanic
  assumes a visible face to the camera, which isn't equally accessible to every player. We treat
  expression as one *blended* signal (not a gate), so a player who can't/doesn't face the camera
  still gets a voice-driven score — but this is a known limitation we'd want to make explicit and
  configurable in a real release.

### About Privacy

- **What the app actually needs:** the **camera** (front/FaceTime) to read expressions, the
  **microphone** to score singing, and **outbound network** only for Apple Music (MusicKit) and
  remote lyric lookup. It runs in the **App Sandbox** with exactly those entitlements and nothing
  else. All scoring happens **on-device** — camera frames and audio are analyzed live and not
  uploaded or persisted.
- **Usage strings** are declared honestly (camera: *"read your expressions and score how well
  they match the song's vibe"*; mic: *"score your pitch, timing, and dynamics"*; Apple Music:
  *"plays songs you choose as karaoke backing tracks"*).
- **When the user says no to a permission:** the app **degrades, it doesn't crash or block.**
  - No **camera** → expression scoring is unavailable; the score falls back to the **voice**
    signal alone.
  - No **microphone** → voice scoring is unavailable; the app leans on the **expression** signal.
  - No **Apple Music** → the player uses **bundled or imported local songs**; the rest of the
    battle is unaffected.
