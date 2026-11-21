export interface ApiResponse<T = any> {
  code: number;
  message: string;
  data: T;
}

export interface User {
  id: number;
  username: string;
  nickname: string;
  role: "admin" | "user";
  is_active: boolean;
  created_at: string;
}

export interface TokenOut {
  access_token: string;
  token_type: string;
  user: User;
}

export interface House {
  id: number;
  user_id: number;
  name: string;
  icon: string;
  sort_order: number;
  is_active: boolean;
  created_at: string;
}

export interface Room {
  id: number;
  user_id: number;
  house_id: number;
  name: string;
  icon: string;
  sort_order: number;
  is_active: boolean;
  created_at: string;
}

export interface Category {
  id: number;
  name: string;
  icon: string;
  sort_order: number;
  is_active?: boolean;
}

export interface CategoryTemplate {
  id: number;
  name: string;
  icon: string;
  color: string;
  sort_order: number;
  is_active: boolean;
  is_deleted: boolean;
  created_at: string;
}

export interface CategoryTemplatePayload {
  name: string;
  icon?: string;
  color?: string;
  sort_order?: number;
  is_active?: boolean;
}

export interface Tag {
  id: number;
  name: string;
}

export interface Attachment {
  id: number;
  item_id: number;
  media_type: "image" | "audio" | "video";
  scene?: "storage" | "in_use";
  file_path: string;
  url: string;
  thumbnail_path?: string;
  thumbnail_url?: string;
  file_size: number;
  duration_seconds: number;
  width: number;
  height: number;
  display_order: number;
  created_at: string;
}

export interface Item {
  id: number;
  user_id: number;
  house_id: number;
  room_id: number;
  category_id?: number | null;
  name: string;
  brand: string;
  quantity: number;
  location_detail: string;
  description: string;
  status?: "stored" | "in_use";
  storage_house_id?: number | null;
  storage_room_id?: number | null;
  storage_location_detail?: string;
  status_updated_at?: string | null;
  version?: number;
  created_at: string;
  updated_at: string;
  house?: House;
  room?: Room;
  category?: Category;
  tags: Tag[];
  attachments: Attachment[];
  storage_attachments?: Attachment[];
  path_display?: string;
  storage_path_display?: string;
}

export interface GodViewItem extends Item {
  owner_username: string;
  owner_nickname: string;
}

export interface PaginationMeta {
  page: number;
  page_size: number;
  total: number;
  total_pages: number;
}

export interface PaginatedData<T> {
  items: T[];
  pagination: PaginationMeta;
}

export interface BackupRecord {
  id: number;
  filename: string;
  file_size: number;
  file_size_display: string;
  sha256: string;
  item_count: number;
  attachment_count: number;
  created_at: string;
}

export interface AdminUser extends User {
  house_count: number;
  room_count: number;
  item_count: number;
}

export interface AdminSystemStats {
  total_users: number;
  total_items: number;
  total_houses: number;
  total_rooms: number;
  media_storage_bytes: number;
  media_storage_display: string;
  last_backup_time: string | null;
  total_backups: number;
}

export interface AuthConfig {
  allow_public_registration: boolean;
  server_instance_id?: string;
}

export interface AdminUserCreatePayload {
  username: string;
  password?: string;
  nickname?: string;
}

export interface AdminPasswordUpdatePayload {
  old_password: string;
  new_password: string;
}

export interface GodViewCascadingRoom {
  id: number;
  name: string;
  icon?: string;
}

export interface GodViewCascadingHouse {
  id: number;
  name: string;
  icon?: string;
  rooms: GodViewCascadingRoom[];
}

export interface GodViewCascadingUser {
  id: number;
  username: string;
  nickname: string;
  houses: GodViewCascadingHouse[];
}

export interface GodViewFilterCategory {
  id: number;
  name: string;
  icon?: string;
}

export interface GodViewFilterOptions {
  users: GodViewCascadingUser[];
  categories: GodViewFilterCategory[];
  tags: string[];
}

export interface GodViewAdvancedSearchParams {
  user_id?: number;
  house_id?: number;
  room_id?: number;
  category_id?: number;
  tag_name?: string;
  keyword?: string;
  start_date?: string;
  end_date?: string;
  page?: number;
  page_size?: number;
}

export interface OrphanMediaStats {
  orphan_count: number;
  orphan_size_bytes: number;
  orphan_size_display: string;
  orphan_files: string[];
}

export interface ImportedBackupRecord {
  filename: string;
  file_size: number;
  file_size_display: string;
  is_valid: boolean;
  backup_at?: string | null;
  item_count?: number | null;
  attachment_count?: number | null;
  error_message?: string | null;
}



