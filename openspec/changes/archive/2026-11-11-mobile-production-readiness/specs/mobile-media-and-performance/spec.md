## MODIFIED Requirements

### Requirement: Interactive Mobile Media Preview Layer
The mobile application SHALL provide a full-screen interactive media preview overlay using `shadcn_ui` dialog/sheet paradigms and `InteractiveViewer` gesture handling.

#### Scenario: User pinches to zoom photo
- **WHEN** a user taps an item card and views its primary photo in the preview overlay
- **THEN** the mobile app SHALL allow pinching to zoom between 1.0x and 4.0x magnification, double-tapping to toggle between 1.0x and 2.5x zoom, and panning across the magnified image.

#### Scenario: User plays audio guide or video guide
- **WHEN** an item has an audio attachment or a video guide in the preview overlay
- **THEN** the mobile app SHALL render active audio and video player components with interactive controls (play, pause, progress scrubbing bar, and elapsed/total duration display) instead of static placeholders, streaming media over HTTP with moov-faststart and dopamine styling.

## ADDED Requirements

### Requirement: Real Hardware Multimodal Capture and Compression Pipeline
The mobile application SHALL provide direct acquisition channels from physical device cameras, system photo galleries, and microphones, executing client-side compression before uploading to the server.

#### Scenario: User captures physical item photo via camera or album
- **WHEN** a user selects "Take Photo" or "Choose from Album" in the item editing interface
- **THEN** the mobile app SHALL invoke the system camera or gallery picker, correct EXIF rotation, downscale the image to long edge <= 1600px, compress to JPEG at 82% quality, generate a 300px thumbnail, and upload both to `/api/media/upload/image`.

#### Scenario: User records voice memo guide
- **WHEN** a user taps and records a voice memo guide for an item
- **THEN** the mobile app SHALL record up to 60 seconds of AAC/M4A audio at 48kbps, display real-time elapsed recording seconds, and allow previewing before submission.

### Requirement: Android Platform Network and Runtime Permissions
The Android build configuration SHALL grant essential network and hardware runtime permissions to ensure uninterrupted local network communication and multimodal hardware usage.

#### Scenario: App communicates with local HTTP server
- **WHEN** the app runs on Android 9+ (API 28+) and connects to a LAN IP address over HTTP
- **THEN** network requests SHALL succeed without being blocked by cleartext restrictions, backed by `android:usesCleartextTraffic="true"` and `android.permission.INTERNET`.

#### Scenario: User launches camera or microphone
- **WHEN** the user triggers photo capture or voice recording
- **THEN** the system SHALL properly prompt for `CAMERA` or `RECORD_AUDIO` permissions without runtime crash.

