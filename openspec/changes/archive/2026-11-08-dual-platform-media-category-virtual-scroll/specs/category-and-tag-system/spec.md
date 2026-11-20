## Purpose

Defines the comprehensive 14-preset daily category system, user-level category lifecycle management (CRUD and deactivation), and global shared tag autocomplete and idempotent deduplication in TraceItem.

## ADDED Requirements

### Requirement: Preset Category Template Seeding on User Creation
The system SHALL provide 14 daily preset categories with Emoji totems, and automatically clone a private copy of this preset template for every newly registered user.

#### Scenario: New user registers and receives default categories
- **WHEN** a new user account is successfully created via the registration API
- **THEN** the system SHALL immediately clone the 14 system preset categories (常备药品 💊, 证件票据 📑, 数码配件 🔌, 五金工具 🧰, 儿童玩具 🧸, 办公文具 ✏️, 厨房用品 🍳, 食品干货 🍵, 日用清洁 🧼, 服饰鞋帽 👔, 美妆个护 💄, 运动户外 ⛺, 家家居家 🛋️, 闲置收藏 📦) into the user's private category records with `is_active=True`.

### Requirement: User Category Lifecycle Management
The system SHALL allow authenticated users to create, update, reorder, and deactivate/activate their private categories, while preventing destructive cascading deletion of items.

#### Scenario: User deactivates a category
- **WHEN** a user sets a category's `is_active` to `False`
- **THEN** existing items associated with this category SHALL continue displaying the category normally, but the deactivated category SHALL be hidden from item creation dropdowns and home screen quick filter tabs.

#### Scenario: User safely deletes a category with items
- **WHEN** a user requests deletion of a category that currently has items attached
- **THEN** the UI SHALL prompt with a custom confirmation dialog (no native confirm) asking whether to unbind associated items (setting `category_id=NULL`) before removing the category, and SHALL NOT delete the items themselves.

### Requirement: Cross-User Tag Sharing and Autocomplete
The system SHALL maintain a global pool of unique tag names without user isolation, enabling cross-user prefix suggestion and autocompletion.

#### Scenario: Autocomplete suggestions for tag input
- **WHEN** a user types a prefix into the tag input field (e.g., "办公")
- **THEN** the frontend SHALL query `GET /api/tags/suggest?q=办公` and display matching existing global tags (e.g., "办公用品") in a custom popover overlay.

### Requirement: Idempotent Tag Resolution on Item Save
The backend SHALL resolve tag names atomically by trimmed case-sensitive exact match, reusing existing tag IDs rather than creating duplicate tag records.

#### Scenario: Saving item with existing tag name avoids duplicates
- **WHEN** an item is submitted with tag name "办公用品" where a tag with that exact trimmed name already exists in the global `tags` table
- **THEN** the backend SHALL link the item to the existing tag record's ID without creating any new row in `tags`.

