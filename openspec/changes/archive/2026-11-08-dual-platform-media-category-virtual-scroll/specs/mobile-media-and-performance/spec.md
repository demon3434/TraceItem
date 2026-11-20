## Purpose

Defines the Flutter mobile application's multimodal media preview layer with gesture zooming, audio and video playback, and high-performance windowed grid rendering for thousands of items.

## ADDED Requirements

### Requirement: Interactive Mobile Media Preview Layer
The mobile application SHALL provide a full-screen interactive media preview overlay using `shadcn_ui` dialog/sheet paradigms and `InteractiveViewer` gesture handling.

#### Scenario: User pinches to zoom photo
- **WHEN** a user taps an item card and views its primary photo in the preview overlay
- **THEN** the mobile app SHALL allow pinching to zoom between 1.0x and 4.0x magnification, double-tapping to toggle between 1.0x and 2.5x zoom, and panning across the magnified image.

#### Scenario: User plays audio guide or video guide
- **WHEN** an item has an audio attachment or a video guide in the preview overlay
- **THEN** the mobile app SHALL render unified styled playback controls allowing play, pause, progress scrubbing, and duration display, adhering to the dopamine theme.

### Requirement: Mobile Windowed Item Grid and Memory Bounds
The mobile application SHALL render items via lazy windowed layout (`GridView.builder`), fetching next batches upon reaching a scroll threshold and limiting image decoding memory.

#### Scenario: Seamless incremental pagination on scroll
- **WHEN** a user scrolls the item grid within 300 pixels of the current list bottom
- **THEN** the mobile app SHALL asynchronously fetch the next page of items and seamlessly append them to the list without stutter.

#### Scenario: Memory-bounded thumbnail decoding
- **WHEN** the item grid renders item cards
- **THEN** the mobile app SHALL load the backend's generated 320px `thumbnail_url` rather than the original 1600px image, with explicit `cacheWidth: 400` to prevent memory bloat and garbage collection pauses.

