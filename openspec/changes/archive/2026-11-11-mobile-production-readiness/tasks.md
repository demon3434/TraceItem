## 1. Android Platform Manifest & Dependencies Setup

- [x] 1.1 Add required Flutter packages to `mobile/pubspec.yaml` (`image_picker`, `record`, `audioplayers`, `video_player`, `speech_to_text`, `cached_network_image`) and verify with `flutter pub get`
- [x] 1.2 Update `mobile/android/app/src/main/AndroidManifest.xml` with permissions (`INTERNET`, `CAMERA`, `RECORD_AUDIO`, `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO`), enable `android:usesCleartextTraffic="true"`, and verify XML syntax

## 2. Hardware Multimodal Acquisition Pipeline

- [x] 2.1 Refactor `mobile/lib/core/media_pipeline.dart` to support reading raw bytes directly from `XFile` and verify JPEG compression to <= 1600px long edge with 300px thumbnail generation
- [x] 2.2 Replace mock capture in `mobile/lib/screens/item_edit_screen.dart` with real camera and album picking via `image_picker` and verify photo attachment preview
- [x] 2.3 Implement audio recording controller in `mobile/lib/widgets/audio_record_sheet.dart` using `record` library with 60s countdown and preview playback

## 3. Multimodal Media Playback Components

- [x] 3.1 Create `mobile/lib/widgets/dopamine_audio_player.dart` using `audioplayers` with play/pause toggle, position scrubbing, and total duration display
- [x] 3.2 Create `mobile/lib/widgets/dopamine_video_player.dart` using `video_player` with faststart HTTP streaming, aspect ratio container, and play/pause controls
- [x] 3.3 Embed active audio and video players into `mobile/lib/widgets/media_preview_dialog.dart`, replacing static placeholder cards

## 4. Elderly & Kid Friendly Voice Search

- [x] 4.1 Create `mobile/lib/widgets/voice_search_overlay.dart` using `speech_to_text` with dopamine ripple animations, listening to Chinese (`zh_CN`)
- [x] 4.2 Integrate the voice search trigger button into `mobile/lib/screens/home_screen.dart` search bar and verify speech transcription populates search and triggers FTS5 query

## 5. Space Entity & Item Management Workflows

- [x] 5.1 Implement `mobile/lib/widgets/space_manage_sheet.dart` for adding and editing rooms with Emoji totem selection (🧸, 🚀, 🛋️) via `POST /api/rooms` and `PUT /api/rooms/{id}`
- [x] 5.2 Expand `mobile/lib/screens/item_edit_screen.dart` to support edit mode for existing items, pre-filling data and persisting changes via `PUT /api/items/{id}`
- [x] 5.3 Add server host configuration dialog in `mobile/lib/widgets/server_config_dialog.dart` with health-check handshake verification and SharedPreferences persistence

## 6. Typography, Aesthetics & Verification

- [x] 6.1 Audit all mobile screens and widgets to ensure all text sizes are >= 12px with readable body/input text (14-16px), strictly eliminating sub-12px micro-text
- [x] 6.2 Verify end-to-end mobile flow with `flutter analyze` and static inspection

