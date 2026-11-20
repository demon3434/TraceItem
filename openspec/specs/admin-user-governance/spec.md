# admin-user-governance Specification

## Purpose

Provides comprehensive family member user lifecycle management, credential administration, and soft-delete safeguards for system administrators in TraceItem.

## Requirements

### Requirement: Global Soft-Delete for User Accounts
The system SHALL NOT physically delete any user account record. Deletion of user accounts SHALL be executed by setting `is_deleted = true` while preserving all related historical houses, rooms, and items in an archived state.

#### Scenario: Admin soft-deletes an account
- **WHEN** the administrator requests account deletion
- **THEN** the system SHALL mark `is_deleted = true` on the user record without executing SQL `DELETE`, preventing physical data destruction

### Requirement: Admin Household Member List and Asset Statistics
The system SHALL provide an administrative endpoint and web interface to retrieve all active non-deleted user accounts with their active status and owned asset counts, displaying no redundant family member role tags and using a balanced, compact multi-column grid layout without excessive horizontal whitespace.

#### Scenario: Admin views member list
- **WHEN** an authenticated administrator accesses the user management panel
- **THEN** the system SHALL return all registered non-deleted users along with their username, nickname, role, active status, creation time, house count, room count, and item count, omitting redundant generic member badges and rendering cards in a balanced responsive grid (3 to 4 columns on large screens)

### Requirement: Admin Managed User Creation with Default Password
The system SHALL permit administrators to directly create new user accounts with a nickname, auto-generating default password `123456` if left empty, and automatically provisioning the 14 standard category templates.

#### Scenario: Admin provisions a new account without password
- **WHEN** the administrator submits a username and nickname with empty password through `POST /api/admin/users`
- **THEN** the system SHALL set the initial password to `123456`, create the user, seed 14 default scene categories, and return the created user metadata

### Requirement: Admin User Account Status Toggle
The system SHALL enable administrators to freeze or activate user accounts with custom confirmation dialogs, immediately blocking frozen accounts from logging in.

#### Scenario: Admin deactivates an account
- **WHEN** the administrator confirms the deactivation of a user via `PATCH /api/admin/users/{user_id}/status` with `is_active=false`
- **THEN** the user's `is_active` field SHALL be set to false, and subsequent login attempts for that user SHALL be rejected with HTTP 403 Forbidden

### Requirement: Admin User Password Reset and One-Click Initialization
The system SHALL allow administrators to reset passwords or one-click restore the default `123456` password for any non-admin account.

#### Scenario: Admin one-click initializes a member's password
- **WHEN** the administrator confirms password initialization via `POST /api/admin/users/{user_id}/init-password`
- **THEN** the system SHALL update the user's hashed password to `123456` and confirm with a success toast notification

### Requirement: Admin Self Password Modification
The system SHALL permit the authenticated administrator to update their own login password through a dedicated administrative endpoint and modal.

#### Scenario: Administrator modifies own password
- **WHEN** the administrator submits a valid new password to `PUT /api/admin/password`
- **THEN** the system SHALL update the administrator's password hash and require future logins to use the new credentials

### Requirement: Initial Administrator Default Password Specification
Upon fresh system initialization and seed provisioning, the system SHALL set the built-in administrator account (`admin`) password to `admin123`.

#### Scenario: Fresh database initialization
- **WHEN** `init_db` or `seed_data` runs on a fresh database
- **THEN** the built-in administrator account `admin` SHALL be initialized with password `admin123`

### Requirement: Category Template Administration (CRUD and Status Toggle)
The system SHALL provide administrative endpoints and a dedicated web panel for administrators to manage global category templates with creation, updating, soft-deletion, and active/inactive toggling.

#### Scenario: Admin creates or toggles category template
- **WHEN** the administrator creates, modifies, or toggles active status of a category template via `/api/admin/category-templates`
- **THEN** the system SHALL persist the changes with name, icon, sort order, and active flag, preserving soft-delete contracts

### Requirement: Dynamic Category Seeding for New Users from Active Templates
When any new user is registered or provisioned, the system SHALL dynamically replicate categories from currently active, non-deleted `CategoryTemplate` records rather than hardcoded code lists.

#### Scenario: New user account initialization
- **WHEN** a new user account is created
- **THEN** the system SHALL query active category templates (`is_active=true` and `is_deleted=false`) and populate the new user's personal categories from that template set

### Requirement: Category Template Sequence Index and Reordering (Drag-and-Drop & Arrow Controls)
The system SHALL display an explicit sequence index (e.g. `#1`, `#2`) on each category template card in the admin governance panel, and permit administrators to reorder templates via drag-and-drop or up/down arrow buttons, persisting new ordering via `PUT /api/admin/category-templates/reorder`.

#### Scenario: Admin reorders category templates
- **WHEN** the administrator drags a template card to a new position or clicks the up/down arrow button
- **THEN** the system SHALL recalculate sequential `sort_order` values and persist the new order to the backend, updating the template display immediately

### Requirement: User Personal Category Sequence Index and Reordering (Drag-and-Drop & Arrow Controls)
The system SHALL display sequence indices on each personal category card in the user's category management interface, and enable ordinary users to reorder their categories via drag-and-drop or up/down arrow buttons, persisting new ordering via `PUT /api/items/categories/reorder`.

#### Scenario: User reorders personal categories
- **WHEN** an authenticated user adjusts the order of personal categories using drag-and-drop or arrow buttons
- **THEN** the system SHALL persist the updated `sort_order` values for that user's categories and update the home page category filter pills in real time

