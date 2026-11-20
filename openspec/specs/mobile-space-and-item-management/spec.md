# mobile-space-and-item-management Specification

## Purpose

Enables in-app space entity management (rooms and emoji totems), full item editing and updating workflows, network host configuration, and strict kid-friendly typography standards on mobile devices.

## Requirements

### Requirement: Mobile Space Entity Management Sheet
The mobile application SHALL provide a bottom sheet (`ShadSheet`) allowing users to create and edit room entities with customizable Emoji totems.

#### Scenario: User creates a new room
- **WHEN** a user opens the space management sheet, inputs a room name, selects an Emoji totem (e.g., 🧸, 🚀, 🛋️), and submits
- **THEN** the app SHALL persist the new room under the active house via `POST /api/rooms` and refresh the horizontal room chip selector.

### Requirement: Item Editing and Updating Workflow
The mobile application SHALL allow users to modify existing item attributes, update physical locations, and manage attachments.

#### Scenario: User enters edit mode for existing item
- **WHEN** a user taps "Edit" on an item details card or preview dialog
- **THEN** the app SHALL open `ItemEditScreen` populated with existing name, brand, quantity, location detail, tags, and attachments, submitting updates via `PUT /api/items/{id}` upon save.

### Requirement: Dynamic Server Connection Configuration
The mobile application SHALL allow users to configure and verify the backend API host without rebuilding the app package.

#### Scenario: User changes server base URL
- **WHEN** a user opens connection settings and enters a custom server host (e.g., LAN IP or DDNS domain)
- **THEN** the app SHALL perform a connectivity handshake test against `/api/health`, and persist the validated URL to local preferences upon success.

### Requirement: Mobile Typography and Readability Standards
The mobile application SHALL strictly enforce readable font sizes across all screens and widgets to ensure comfortable usage for children and elderly family members.

#### Scenario: Rendering text on mobile screens
- **WHEN** any text element is rendered in item cards, lists, dialogs, or inputs
- **THEN** font size SHALL NOT be smaller than 12px, with standard body and input text sized between 14px and 16px, completely eliminating sub-12px micro-text.
