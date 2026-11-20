# Technical Design: Mobile Production Readiness

## Context

See [proposal.md](file:///E:/code/TraceItem/openspec/changes/mobile-production-readiness/proposal.md) for background and motivation. The Flutter mobile app has the core structural UI in place, but its media acquisition pipeline uses a mock byte generator, audio/video attachments have no playback controls, Android permissions and cleartext configurations are absent, and voice search is not yet integrated.

## Goals / Non-Goals

**Goals:**
- Replace mock image capture with real `image_picker` camera/album input, integrated directly with the client-side `MediaPipeline` (1600px JPEG 82% compression).
- Implement audio memo recording via `record` (AAC 48kbps, <=60s) and media playback via `audioplayers` and `video_player`.
- Implement client-side `speech_to_text` press-and-hold voice search overlay for one-touch item lookup targeting elderly and child users.
- Add room entity management sheet (`SpaceManageSheet`), item editing support, and dynamic server BaseURL configuration.
- Update `AndroidManifest.xml` with cleartext network permissions and camera/mic hardware permissions.
- Enforce kid-friendly typography standards (strictly no fonts below 12px).

**Non-Goals:**
- Implementing server-side transcoding daemons or server-side ASR models (explicitly rejected by ADR 0003 and ADR 0004).
- Over-complicating cabinet/drawer database tables (explicitly forbidden by ADR 0008; cabinets remain visual-only).

## Decisions

### 1. Media Acquisition: `image_picker` + Dart-native `MediaPipeline`
- **Choice**: Use Flutter official `image_picker` for camera and gallery picking, then feed bytes into existing `MediaPipeline.processImageBytes()`.
- **Rationale**: `image_picker` is rock-solid across Android versions, avoids heavy third-party UI dependencies, and seamlessly hands over bytes/files to our existing in-memory EXIF auto-orient and JPEG 82% compression pipeline.
- **Alternatives considered**:
  - `camera` package directly: Overkill, requires writing custom viewfinder UI and managing hardware focus lifecycles manually.

### 2. Audio Recording & Playback: `record` + `audioplayers`
- **Choice**: `record` (^5.1.2) for AAC/M4A capture, `audioplayers` (^6.0.0) for in-dialog audio playback.
- **Rationale**: `record` produces standard `.m4a` / AAC files at 48kbps matching ADR 0003 specifications without external C++ toolchains. `audioplayers` provides lightweight event streams for duration and position, perfectly matching our custom dopamine progress bars.
- **Alternatives considered**:
  - `flutter_sound`: Highly complex, historically prone to build issues with Kotlin Gradle DSL.

### 3. Video Streaming: `video_player` with HTTP Controller
- **Choice**: Use Flutter official `video_player` embedded in `MediaPreviewDialog`.
- **Rationale**: Because our backend enforces MOOV atom faststart (`+faststart`) and 1-second keyframe intervals (ADR 0003), native ExoPlayer under `video_player` can stream and seek immediately without downloading the full video file.

### 4. Client Speech-to-Text: `speech_to_text`
- **Choice**: `speech_to_text` (^7.0.0) configured with `localeId: "zh_CN"`.
- **Rationale**: Direct wrapper over Android's `SpeechRecognizer`. Offloads all neural computation to the device's native or offline voice engine, generating instant text for FTS5 queries without any server CPU burden.

### 5. Dynamic Base URL & Network Permissiveness
- **Choice**: Add `setBaseUrl(String url)` in `ApiService`, store in `SharedPreferences`, and enable `android:usesCleartextTraffic="true"` in `AndroidManifest.xml`.
- **Rationale**: Home NAS instances commonly run without HTTPS certificates on local IP addresses (e.g. `192.168.x.x`). Android 9+ blocks cleartext HTTP by default unless explicitly allowed.

## Risks / Trade-offs

- **[Risk] Camera / Mic permissions denied by user**:
  - *Mitigation*: Gracefully handle permission denials with `CustomDialogs.showConfirm` explaining why camera/mic is needed, offering to guide the user to system settings instead of crashing.
- **[Risk] Device memory pressure during multi-image capture**:
  - *Mitigation*: Continue leveraging `MediaPipeline` to compress and downscale each image sequentially before uploading, avoiding holding multiple raw 4K bitmaps in RAM.
- **[Risk] Android system voice recognizer unavailable on bare AOSP / custom ROMs**:
  - *Mitigation*: Check `speech.hasPermission && speech.isAvailable` on startup. If unavailable, hide or disable the voice button and fallback gracefully to keyboard text input.

