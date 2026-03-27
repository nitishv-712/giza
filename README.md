# Giza 🎵

Underground music streaming — Audius discovery + YouTube IFrame audio.

## Architecture

| Layer | Tech |
|---|---|
| **Discovery / Search** | [Audius REST API](https://audius.co) — free, no API key |
| **Audio playback** | YouTube IFrame via `youtube_player_flutter` — hidden 1×1 widget |
| **YouTube search** | `youtube_explode_dart` — finds video ID from title+artist, no API key |
| **Local storage** | Hive (favourites, play history) |
| **Images** | `cached_network_image` |

## Project structure

```
lib/
├── main.dart
├── db/
│   └── hive_helper.dart          # Hive box wrapper (songs, history, settings)
├── models/
│   ├── song.dart                 # Song model + Hive annotations
│   └── song.g.dart               # Generated Hive adapter (DO NOT EDIT)
├── services/
│   ├── audio_service.dart        # YouTube IFrame player + stream controllers
│   └── audius_service.dart       # Audius REST API wrapper
└── screens/
    ├── home_screen.dart           # Browse, search, trending, mini player
    └── play_screen.dart          # Full-screen now playing
```

## Setup

### 1. Install dependencies

```bash
flutter pub get
```

### 2. Android — ensure minSdkVersion ≥ 17

In `android/app/build.gradle`:
```gradle
defaultConfig {
    minSdkVersion 17
}
```

### 3. Run

```bash
flutter run
```

## How playback works

1. User taps a track (metadata from Audius).
2. `AudioService.play(song)` calls `youtube_explode_dart` to search YouTube for `"Title Artist audio"` and picks the best result.
3. A `YoutubePlayerController` is created with `hideControls: true`.
4. A `YoutubePlayer` widget is mounted at **1×1 px off-screen** in both `HomeScreen` and `PlayScreen` — this is the actual audio source.
5. The controller's listener feeds position/duration/state into `StreamController`s so the custom Giza UI (slider, play button, artwork animation) reacts reactively.

> **Note:** There is a ~1–2 second delay on first play while the YouTube video ID is resolved. The loading spinner on the play button covers this.

## Removed features

- ❌ Download / offline playback (was `download_service.dart`) — fully removed
- ❌ `just_audio` dependency — replaced by `youtube_player_flutter`
- ❌ `path_provider`, `path` — no longer needed

## Dependencies

```yaml
hive: ^2.2.3
hive_flutter: ^1.1.0
youtube_player_flutter: ^9.1.1
youtube_explode_dart: ^2.3.3
http: ^1.2.0
cached_network_image: ^3.3.1
```
