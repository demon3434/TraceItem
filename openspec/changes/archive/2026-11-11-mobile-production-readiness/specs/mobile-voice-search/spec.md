## Purpose

Provides native client-side speech-to-text transcription and a single-touch press-and-hold voice search interaction tailored for elderly and child family members.

## ADDED Requirements

### Requirement: Press-and-Hold Voice Search Overlay
The mobile application SHALL provide a prominent voice search trigger on the home screen that enables one-touch press-and-hold speech recognition without typing.

#### Scenario: User presses and holds voice search button
- **WHEN** a user presses and holds the voice search button on the home search bar
- **THEN** the app SHALL present a dopamine-themed recording overlay with animated ripple waves, activate the native system speech-to-text listener for Chinese (`zh_CN`), and display recognized text in real time.

#### Scenario: User releases voice search button to trigger query
- **WHEN** the user finishes speaking and releases the button
- **THEN** the app SHALL stop recording, populate the transcribed text into the search input, dismiss the overlay, and immediately trigger the SQLite FTS5 full-text item search.

#### Scenario: User slides finger up to cancel voice recognition
- **WHEN** the user slides their finger upwards past the cancellation threshold before releasing
- **THEN** the app SHALL abort speech recognition without executing search and dismiss the overlay cleanly.

