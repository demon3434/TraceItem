## MODIFIED Requirements

### Requirement: God View Emergency Inspection Interactive Preview
The web application SHALL enable administrators to interactively inspect full item details and media assets returned by the cross-user God View search, displaying the owner identity prominently in all preview modals in a strictly read-only mode without mutating user data.

#### Scenario: Inspecting item detail from God View search
- **WHEN** the administrator clicks on a search result card in the God View dialog
- **THEN** the system SHALL open a detailed preview modal displaying the item's owning family member (nickname and username), room path, high-resolution photos, and audio/video navigation aids without offering edit or mutation controls

## ADDED Requirements

### Requirement: Global Soft-Delete Enforcement
The system SHALL NOT physically delete items, houses, rooms, categories, or attachments during any delete operation; all deletions SHALL set an `is_deleted = true` status flag.

#### Scenario: User or admin initiates deletion
- **WHEN** a delete request is sent for an item or space
- **THEN** the system SHALL update `is_deleted = true` in SQLite and filter it out of standard user listings, retaining data integrity and auditability

### Requirement: Admin Multi-Dimensional Fallback Search Hub
The web application SHALL provide an advanced fallback item search interface allowing administrators to locate items using cascading filters (user, user's houses, house's rooms, category, tags, keywords, and creation/update time range).

#### Scenario: Admin locates an item for a specific user
- **WHEN** the administrator selects a target user in the fallback search panel
- **THEN** the interface SHALL dynamically load that user's houses and rooms, allowing combined multi-criteria querying across categories, tags, keywords, and date ranges

### Requirement: Orphan Media Audit and Physical Cleanup
The system SHALL provide an administrative tool to detect and physically delete orphaned media files on disk that have no active attachment records in the database.

#### Scenario: Admin scans and purges orphan files
- **WHEN** the administrator initiates an orphan media scan
- **THEN** the system SHALL inspect `/data/media/` against active attachments, return the count and reclaimable disk space, and physically remove orphaned files only upon explicit confirmation

### Requirement: Three-Mode TAR Disaster Recovery
The system SHALL support restoring database snapshots and media archives from existing backups, direct web file upload, or by scanning a designated server import directory (`/data/media/backups/import/`) populated via SCP.

#### Scenario: Restoring from server import directory
- **WHEN** a large archive is transferred to `/data/media/backups/import/` and scanned by the administrator
- **THEN** the system SHALL validate the archive structure (ensuring valid SQLite snapshot and media shards), present it in the recoverable archives list, and execute restoration upon confirmation

### Requirement: Database Decoupling, Retention Pruning and Archive Compatibility
The system SHALL decouple the SQLite database file name from software brand names, adopting generic functional name `items.db`. TAR backups SHALL package `items.db` and backward-compatibly restore archives containing legacy `antusuoji.db`. The system SHALL provide one-click historical backup pruning retaining only the latest 3 archives.

#### Scenario: Admin creates or prunes backup archives
- **WHEN** a TAR archive is generated or pruned
- **THEN** the snapshot file inside SHALL be named `items.db`, and automatic/manual pruning SHALL retain the most recent 3 snapshots, preventing disk bloat

### Requirement: Backup Concurrency Lock, Modal Confirmation and Table Pagination
The system SHALL require modal confirmation before triggering TAR backup creation, disable the trigger button with an in-progress indicator while packing, enforce a server-side mutual exclusion lock to reject concurrent requests, and present the historical backup list with pagination (default 10 items per page).

#### Scenario: Admin triggers backup creation
- **WHEN** the administrator clicks the backup creation button
- **THEN** a confirmation modal SHALL prompt for approval; once approved, the button SHALL disable with packing status, the backend SHALL reject any concurrent backup request with HTTP 409, and the resulting archive SHALL appear in a paginated list

### Requirement: Grounded Plain Wording and Typography Alignment
The system SHALL eliminate grandiose or hyperbolic phrasing across all interfaces (removing terms like "全景收纳", "三模恢复"), adopting grounded functional phrasing (e.g., "数据备份与恢复"). In the search panel, the "重置条件" button SHALL match the primary button font size (`text-sm font-bold`) and feature an eraser/brush icon.

#### Scenario: Admin views navigation and filter controls
- **WHEN** the administrator opens any management panel
- **THEN** all titles and descriptions SHALL use concise, plain language without marketing hyperbole, and the reset button SHALL match the search button typography with an accompanying icon

### Requirement: Panel-Level Metric Embedding and Clutter-Free Layout
The web application SHALL relocate metric statistics into each panel's own sub-header rather than displaying them permanently in the global top bar, completely eliminating obsolete welcome banners and duplicate tab bars, and rendering user cards in a compact, balanced multi-column grid.

#### Scenario: Admin navigates administrative functions
- **WHEN** the administrator selects a navigation item on the left sidebar
- **THEN** the content canvas SHALL render the selected module with its own embedded metric overview without global header clutter
