## Purpose

Defines the full lifecycle management of spatial hierarchy (Houses and Rooms) on the Web frontend, including creation, modification of names and Emoji totems, and cascade deletion with safe confirmation dialogs.

## ADDED Requirements

### Requirement: House and Room Renaming and Icon Update
The web application SHALL allow users to modify the name, Emoji totem icon, and sort order of any existing house or functional room.

#### Scenario: Editing an existing house
- **WHEN** a user triggers the edit action on a house node in the sidebar
- **THEN** the system SHALL display the house edit modal populated with current values, and upon saving, invoke `PUT /api/houses/{id}` and refresh the spatial sidebar

#### Scenario: Editing an existing room
- **WHEN** a user triggers the edit action on a room node under a house
- **THEN** the system SHALL display the room edit modal with pre-selected room functional totems, and upon saving, invoke `PUT /api/rooms/{id}` and refresh the spatial list

### Requirement: Spatial Cascade Deletion with Danger Confirmation
The web application SHALL protect against accidental destruction by requiring explicit confirmation through custom `ConfirmDialog` before deleting any house or room.

#### Scenario: Deleting a house invokes confirmation dialog
- **WHEN** a user clicks the delete button for a house
- **THEN** the system SHALL NOT use browser native `confirm()`, but SHALL open a styled `ConfirmDialog` warning that all rooms and stored items within the house will be permanently cleaned up, and call `DELETE /api/houses/{id}` only after confirmation

