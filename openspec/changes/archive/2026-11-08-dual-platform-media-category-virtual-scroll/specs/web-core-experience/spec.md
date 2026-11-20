## ADDED Requirements

### Requirement: Interactive Web Photo Zoom and Pan Viewer
The web application SHALL provide an interactive image viewer supporting mouse-wheel zoom, drag-to-pan, and 1:1 pixel reset controls in the media preview dialog.

#### Scenario: User zooms in with mouse wheel
- **WHEN** a user hovers over the previewed photo and rotates the mouse scroll wheel
- **THEN** the image SHALL smoothly scale between 100% and 400% anchored at the mouse cursor position, with a floating control capsule providing zoom level indicator and one-click reset.

### Requirement: Custom Dopamine Audio and Video Player Components
The web application SHALL replace native `<audio>` and `<video>` tags with custom styled dopamine UI components featuring rounded squircle borders, progress scrubbing, and playback rate toggles.

#### Scenario: User plays audio with custom controls
- **WHEN** a user clicks the play button on an audio voice memo in the preview modal
- **THEN** the custom dopamine player SHALL play the AAC stream, render dynamic waveform indicator and scrubbable progress bar, and support switching between 1.0x and 1.5x speed without using browser native audio bars.

#### Scenario: User plays video guide without native browser controls
- **WHEN** a user previews a spatial video guide
- **THEN** the video container SHALL render with 20px squircle rounded borders, centered play overlay, custom seekbar, and zero unstyled native control bars.

### Requirement: Virtual Sliding Window Grid for Large-Scale Items
The web application SHALL implement a virtual sliding window grid for item browsing that mounts only the cards within the visible viewport plus top and bottom buffer lines.

#### Scenario: Maintaining bounded DOM nodes during vertical scroll
- **WHEN** a user navigates or scrolls vertically through hundreds or thousands of items
- **THEN** the total mounted item card DOM elements in the grid container SHALL remain bounded under 40 elements at all times, with dynamic top and bottom spacer paddings maintaining the natural scrollbar height and position.

