## Purpose

Defines web security boundaries, credentials protection, authenticated backup streaming, and admin God View emergency item inspection in TraceItem.

## ADDED Requirements

### Requirement: Removal of Production Hardcoded Credentials
The web application SHALL NOT expose plaintext administrator or user passwords in production JavaScript bundles or public login interfaces.

#### Scenario: Quick-fill buttons restricted to development mode
- **WHEN** the web application is built for production (`import.meta.env.PROD`)
- **THEN** quick-fill credentials buttons containing `admin123456` or default user passwords SHALL NOT be rendered in the login view

### Requirement: Authenticated TAR Backup Stream Download
The web application SHALL download TAR backup archives using authenticated HTTP requests that supply the administrator Bearer token.

#### Scenario: Admin downloads a TAR backup archive
- **WHEN** an authenticated administrator clicks the download button in the backup panel
- **THEN** the client SHALL send an authorized GET request with `Authorization: Bearer <token>`, receive the file as a Blob with MIME type `application/x-tar`, and trigger a local file save dialog without receiving a 401 Unauthorized response

### Requirement: Backup Deletion Safety Confirmation
The web application SHALL mandate custom confirmation overlay verification before permanently deleting historical TAR backup snapshots.

#### Scenario: Deleting a backup requires confirmation
- **WHEN** the administrator clicks the delete button on any backup record
- **THEN** the system SHALL display a styled danger `ConfirmDialog` and execute `DELETE /api/admin/backups/{id}` only when explicitly confirmed

### Requirement: God View Emergency Inspection Interactive Preview
The web application SHALL enable administrators to interactively inspect full item details and media assets returned by the cross-user God View search.

#### Scenario: Inspecting item detail from God View search
- **WHEN** the administrator clicks on a search result card in the God View dialog
- **THEN** the system SHALL open a detailed preview modal displaying the item's owning family member, room path, high-resolution photos, and audio/video navigation aids

