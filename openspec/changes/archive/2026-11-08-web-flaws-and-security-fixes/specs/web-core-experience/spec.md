## Purpose

Defines the web frontend item card rendering, client-side visual image compression pipeline, multimodal media attachments management, and item browsing capabilities in TraceItem.

## ADDED Requirements

### Requirement: Item Card Media and Thumbnail Rendering
The web application SHALL render item cards with actual thumbnail images and multimodal status badges derived from the attachment `media_type` field and industrial backend storage paths.

#### Scenario: Item with image attachment displays thumbnail
- **WHEN** an item contains attachments where `media_type` is "image"
- **THEN** the item card SHALL display the image via `thumbnail_url` or `/api/media/file/{thumbnail_path}` with squircle rounded borders and hover zoom animation

#### Scenario: Item with audio and video displays multimodal indicators
- **WHEN** an item has attachments where `media_type` is "audio" or "video"
- **THEN** the item card SHALL display distinct Lucide Mic and Video indicator badges at the bottom of the card

### Requirement: Client-Side Image Compression Pipeline
The web application SHALL perform smart proportional client-side downscaling and compression using HTML5 Canvas before uploading images to the backend.

#### Scenario: Large photo compressed before upload
- **WHEN** a user selects a high-resolution photo exceeding 1600px on its longest side
- **THEN** the client SHALL downscale the image proportionally to a maximum dimension of 1600px and encode it as JPEG with 80% to 85% quality before transmitting it via HTTP multipart form-data

### Requirement: Multimodal Attachment Management in Item Dialog
The web application SHALL support uploading, previewing, and managing multiple images, audio voice memos, and spatial guide videos when creating or editing an item.

#### Scenario: Editing an item preserves and allows updating attachments
- **WHEN** a user opens an existing item in the edit dialog
- **THEN** existing attachments SHALL be rendered with preview thumbnails, and the user SHALL be permitted to remove existing attachments or append new photos and media files without data loss

### Requirement: Kid-Friendly Typography Standard Compliance
All web typography across item cards, dialogs, forms, and preview modals SHALL adhere to readable font sizes without any sub-12px elements.

#### Scenario: Strict absence of sub-12px typography
- **WHEN** any web component is rendered
- **THEN** no element SHALL have font size classes of `text-[10px]` or `text-[11px]`, and body descriptions and form labels SHALL use at least 14px (`text-sm`)

