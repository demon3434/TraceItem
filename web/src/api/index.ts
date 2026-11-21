import { api } from "./client";
import type {
  AdminPasswordUpdatePayload,
  AdminSystemStats,
  AdminUser,
  AdminUserCreatePayload,
  ApiResponse,
  AuthConfig,
  BackupRecord,
  Category,
  CategoryTemplate,
  CategoryTemplatePayload,
  GodViewAdvancedSearchParams,
  GodViewFilterOptions,
  GodViewItem,
  House,
  ImportedBackupRecord,
  Item,
  OrphanMediaStats,
  PaginatedData,
  Room,
  Tag,
  TokenOut,
  User,
} from "../types";

// Auth
export async function loginApi(params: { username: string; password: string }): Promise<TokenOut> {
  const res = await api.post<ApiResponse<TokenOut>>("/auth/login", params);
  return res.data.data;
}

export async function registerApi(data: {
  username: string;
  password: string;
  nickname: string;
}): Promise<User> {
  const res = await api.post<ApiResponse<User>>("/auth/register", data);
  return res.data.data;
}

export async function getMeApi(): Promise<User> {
  const res = await api.get<ApiResponse<User>>("/auth/me");
  return res.data.data;
}

export async function updateMeApi(data: {
  nickname?: string;
  password?: string;
}): Promise<User> {
  const res = await api.put<ApiResponse<User>>("/auth/me", data);
  return res.data.data;
}

export async function getUsersApi(): Promise<User[]> {
  const res = await api.get<ApiResponse<User[]>>("/auth/users");
  return res.data.data;
}

// Spaces: Houses & Rooms
export async function getHousesApi(): Promise<House[]> {
  const res = await api.get<ApiResponse<House[]>>("/houses");
  return res.data.data;
}

export async function createHouseApi(data: { name: string; icon?: string; sort_order?: number }): Promise<House> {
  const res = await api.post<ApiResponse<House>>("/houses", data);
  return res.data.data;
}

export async function updateHouseApi(id: number, data: { name?: string; icon?: string; sort_order?: number; is_active?: boolean }): Promise<House> {
  const res = await api.put<ApiResponse<House>>(`/houses/${id}`, data);
  return res.data.data;
}

export async function toggleHouseStatusApi(id: number, is_active: boolean): Promise<House> {
  const res = await api.patch<ApiResponse<House>>(`/houses/${id}/status`, null, {
    params: { is_active },
  });
  return res.data.data;
}

export async function deleteHouseApi(id: number): Promise<void> {
  await api.delete(`/houses/${id}`);
}

export async function reorderHousesApi(orderedIds: number[]): Promise<House[]> {
  const res = await api.put<ApiResponse<House[]>>("/houses/reorder", {
    ordered_ids: orderedIds,
  });
  return res.data.data;
}

export async function getRoomsApi(houseId?: number): Promise<Room[]> {
  const res = await api.get<ApiResponse<Room[]>>("/rooms", { params: { house_id: houseId } });
  return res.data.data;
}

export async function createRoomApi(data: { house_id: number; name: string; icon?: string; sort_order?: number }): Promise<Room> {
  const res = await api.post<ApiResponse<Room>>("/rooms", data);
  return res.data.data;
}

export async function updateRoomApi(id: number, data: { house_id?: number; name?: string; icon?: string; sort_order?: number; is_active?: boolean }): Promise<Room> {
  const res = await api.put<ApiResponse<Room>>(`/rooms/${id}`, data);
  return res.data.data;
}

export async function toggleRoomStatusApi(id: number, is_active: boolean): Promise<Room> {
  const res = await api.patch<ApiResponse<Room>>(`/rooms/${id}/status`, null, {
    params: { is_active },
  });
  return res.data.data;
}

export async function deleteRoomApi(id: number): Promise<void> {
  await api.delete(`/rooms/${id}`);
}

export async function reorderRoomsApi(houseId: number, orderedIds: number[]): Promise<Room[]> {
  const res = await api.put<ApiResponse<Room[]>>("/rooms/reorder", {
    house_id: houseId,
    ordered_ids: orderedIds,
  });
  return res.data.data;
}

// Items & Categories
export async function getItemsApi(params: {
  house_id?: number;
  room_id?: number;
  category_id?: number;
  status?: "stored" | "in_use";
  page?: number;
  page_size?: number;
}): Promise<PaginatedData<Item>> {
  const res = await api.get<ApiResponse<PaginatedData<Item>>>("/items", { params });
  return res.data.data;
}

export async function getItemDetailApi(id: number): Promise<Item> {
  const res = await api.get<ApiResponse<Item>>(`/items/${id}`);
  return res.data.data;
}

export async function createItemApi(data: Partial<Item> & { tag_names?: string[]; attachments?: any[] }): Promise<Item> {
  const res = await api.post<ApiResponse<Item>>("/items", data);
  return res.data.data;
}

export async function updateItemApi(id: number, data: Partial<Item> & { tag_names?: string[]; attachments?: any[] }): Promise<Item> {
  const res = await api.put<ApiResponse<Item>>(`/items/${id}`, data);
  return res.data.data;
}

export async function takeOutItemApi(
  id: number,
  data: {
    house_id: number;
    room_id: number;
    location_detail: string;
    attachments: any[];
    expected_version?: number;
  },
): Promise<Item> {
  const res = await api.post<ApiResponse<Item>>(`/items/${id}/take-out`, data);
  return res.data.data;
}

export async function putBackItemApi(
  id: number,
  data: {
    restore_original: boolean;
    house_id?: number;
    room_id?: number;
    location_detail?: string;
    added_storage_attachments?: any[];
    removed_attachment_paths?: string[];
    expected_version?: number;
  },
): Promise<Item> {
  const res = await api.post<ApiResponse<Item>>(`/items/${id}/put-back`, data);
  return res.data.data;
}

export async function deleteItemApi(id: number): Promise<void> {
  await api.delete(`/items/${id}`);
}

export async function getCategoriesApi(include_inactive = false): Promise<Category[]> {
  const res = await api.get<ApiResponse<Category[]>>("/items/categories", {
    params: { include_inactive },
  });
  return res.data.data;
}

export async function getCategoriesPaginatedApi(
  page = 1,
  pageSize = 6,
  includeInactive = true
): Promise<PaginatedData<Category>> {
  const res = await api.get<ApiResponse<PaginatedData<Category>>>("/items/categories/paginated", {
    params: {
      page,
      page_size: pageSize,
      include_inactive: includeInactive,
    },
  });
  return res.data.data;
}

export async function createCategoryApi(data: { name: string; icon?: string; sort_order?: number; is_active?: boolean }): Promise<Category> {
  const res = await api.post<ApiResponse<Category>>("/items/categories", data);
  return res.data.data;
}

export async function updateCategoryApi(id: number, data: { name?: string; icon?: string; sort_order?: number; is_active?: boolean }): Promise<Category> {
  const res = await api.put<ApiResponse<Category>>(`/items/categories/${id}`, data);
  return res.data.data;
}

export async function toggleCategoryStatusApi(id: number, is_active: boolean): Promise<Category> {
  const res = await api.patch<ApiResponse<Category>>(`/items/categories/${id}/status`, null, {
    params: { is_active },
  });
  return res.data.data;
}

export async function deleteCategoryApi(id: number): Promise<void> {
  await api.delete(`/items/categories/${id}`);
}

export async function suggestTagsApi(q: string, limit = 8): Promise<string[]> {
  const res = await api.get<ApiResponse<string[]>>("/items/tags/suggest", {
    params: { q, limit },
  });
  return res.data.data;
}

export async function getTagsApi(): Promise<Tag[]> {
  const res = await api.get<ApiResponse<Tag[]>>("/items/tags");
  return res.data.data;
}

// Search
export async function searchItemsApi(q: string, limit = 50): Promise<Item[]> {
  const res = await api.get<ApiResponse<Item[]>>("/search", { params: { q, limit } });
  return res.data.data;
}

// Media
export async function uploadImageApi(file: File): Promise<any> {
  const formData = new FormData();
  formData.append("file", file);
  const res = await api.post<ApiResponse<any>>("/media/upload/image", formData, {
    headers: { "Content-Type": "multipart/form-data" },
  });
  return res.data.data;
}

// Admin: God View & TAR Backups
export async function godViewSearchApi(q: string, limit = 50): Promise<GodViewItem[]> {
  const res = await api.get<ApiResponse<GodViewItem[]>>("/admin/god-view/search", { params: { q, limit } });
  return res.data.data;
}

export async function getBackupsApi(): Promise<BackupRecord[]> {
  const res = await api.get<ApiResponse<BackupRecord[]>>("/admin/backups");
  return res.data.data;
}

export async function createBackupApi(): Promise<BackupRecord> {
  const res = await api.post<ApiResponse<BackupRecord>>("/admin/backups");
  return res.data.data;
}

export async function deleteBackupApi(id: number): Promise<void> {
  await api.delete(`/admin/backups/${id}`);
}

export async function pruneBackupsApi(keep_latest: number): Promise<number> {
  const res = await api.post<ApiResponse<number>>("/admin/backups/prune", { keep_latest });
  return res.data.data;
}

export async function downloadBackupApi(id: number, filename: string): Promise<void> {
  const res = await api.get(`/admin/backups/${id}/download`, {
    responseType: "blob",
  });
  const blob = new Blob([res.data], { type: "application/x-tar" });
  const url = window.URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  window.URL.revokeObjectURL(url);
}

// Admin: User Governance & System Stats
export async function getAuthConfigApi(): Promise<AuthConfig> {
  const res = await api.get<ApiResponse<AuthConfig>>("/auth/config");
  return res.data.data;
}

export async function getAdminUsersApi(): Promise<AdminUser[]> {
  const res = await api.get<ApiResponse<AdminUser[]>>("/admin/users");
  return res.data.data;
}

export async function createAdminUserApi(data: AdminUserCreatePayload): Promise<AdminUser> {
  const res = await api.post<ApiResponse<AdminUser>>("/admin/users", data);
  return res.data.data;
}

export async function updateAdminUserStatusApi(userId: number, is_active: boolean): Promise<AdminUser> {
  const res = await api.patch<ApiResponse<AdminUser>>(`/admin/users/${userId}/status`, { is_active });
  return res.data.data;
}

export async function resetAdminUserPasswordApi(userId: number, new_password: string): Promise<void> {
  await api.post(`/admin/users/${userId}/reset-password`, { new_password });
}

export async function initAdminUserPasswordApi(userId: number): Promise<void> {
  await api.post(`/admin/users/${userId}/init-password`);
}

export async function getAdminStatsApi(): Promise<AdminSystemStats> {
  const res = await api.get<ApiResponse<AdminSystemStats>>("/admin/stats");
  return res.data.data;
}

export async function getGodViewItemsApi(
  page = 1,
  pageSize = 20
): Promise<PaginatedData<GodViewItem>> {
  const res = await api.get<ApiResponse<PaginatedData<GodViewItem>>>("/admin/god-view/items", {
    params: { page, page_size: pageSize },
  });
  return res.data.data;
}

// Admin: Self Password Update
export async function adminUpdatePasswordApi(payload: AdminPasswordUpdatePayload): Promise<void> {
  await api.put("/admin/password", payload);
}

// Admin: God-View Multi-Dimensional Search
export async function getGodViewFilterOptionsApi(): Promise<GodViewFilterOptions> {
  const res = await api.get<ApiResponse<GodViewFilterOptions>>("/admin/god-view/filter-options");
  return res.data.data;
}

export async function godViewAdvancedSearchApi(
  params: GodViewAdvancedSearchParams
): Promise<PaginatedData<GodViewItem>> {
  const res = await api.get<ApiResponse<PaginatedData<GodViewItem>>>("/admin/god-view/advanced-search", {
    params,
  });
  return res.data.data;
}

// Admin: Orphan Media Audit & Clean
export async function scanOrphanMediaApi(): Promise<OrphanMediaStats> {
  const res = await api.get<ApiResponse<OrphanMediaStats>>("/admin/media/orphans");
  return res.data.data;
}

export async function cleanOrphanMediaApi(): Promise<{ cleaned_count: number; reclaimed_bytes: number }> {
  const res = await api.post<ApiResponse<{ cleaned_count: number; reclaimed_bytes: number }>>("/admin/media/orphans/clean");
  return res.data.data;
}

// Admin: Three-mode TAR Restore Engine
export async function restoreBackupApi(recordId: number): Promise<any> {
  const res = await api.post<ApiResponse<any>>(`/admin/backups/${recordId}/restore`);
  return res.data.data;
}

export async function restoreFromUploadApi(file: File): Promise<any> {
  const formData = new FormData();
  formData.append("file", file);
  const res = await api.post<ApiResponse<any>>("/admin/backups/restore-upload", formData, {
    headers: { "Content-Type": "multipart/form-data" },
  });
  return res.data.data;
}

export async function scanImportBackupsApi(): Promise<ImportedBackupRecord[]> {
  const res = await api.get<ApiResponse<ImportedBackupRecord[]>>("/admin/backups/import-scan");
  return res.data.data;
}

export async function restoreFromImportApi(filename: string): Promise<any> {
  const res = await api.post<ApiResponse<any>>("/admin/backups/import-restore", { filename });
  return res.data.data;
}

// Admin: Category Template Governance (增删改停)
export async function getCategoryTemplatesApi(includeInactive = true): Promise<CategoryTemplate[]> {
  const res = await api.get<ApiResponse<CategoryTemplate[]>>("/admin/category-templates", {
    params: { include_inactive: includeInactive },
  });
  return res.data.data;
}

export async function createCategoryTemplateApi(payload: CategoryTemplatePayload): Promise<CategoryTemplate> {
  const res = await api.post<ApiResponse<CategoryTemplate>>("/admin/category-templates", payload);
  return res.data.data;
}

export async function updateCategoryTemplateApi(
  id: number,
  payload: Partial<CategoryTemplatePayload>
): Promise<CategoryTemplate> {
  const res = await api.put<ApiResponse<CategoryTemplate>>(`/admin/category-templates/${id}`, payload);
  return res.data.data;
}

export async function toggleCategoryTemplateStatusApi(id: number, is_active: boolean): Promise<CategoryTemplate> {
  const res = await api.patch<ApiResponse<CategoryTemplate>>(`/admin/category-templates/${id}/status`, { is_active });
  return res.data.data;
}

export async function deleteCategoryTemplateApi(id: number): Promise<void> {
  await api.delete(`/admin/category-templates/${id}`);
}

export async function reorderCategoryTemplatesApi(orderedIds: number[]): Promise<CategoryTemplate[]> {
  const res = await api.put<ApiResponse<CategoryTemplate[]>>("/admin/category-templates/reorder", {
    ordered_ids: orderedIds,
  });
  return res.data.data;
}

export async function reorderUserCategoriesApi(orderedIds: number[]): Promise<Category[]> {
  const res = await api.put<ApiResponse<Category[]>>("/items/categories/reorder", {
    ordered_ids: orderedIds,
  });
  return res.data.data;
}




