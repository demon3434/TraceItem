<template>
  <div class="flex h-screen overflow-hidden" :style="{ backgroundColor: 'var(--theme-bg)' }">
    <!-- 左侧空间层级侧边栏 -->
    <HouseRoomSidebar
      :current-admin-tab="adminTab"
      @select-admin-tab="(tab) => adminTab = tab"
      @open-admin-god-view="openGodViewFromSidebar"
      @open-create-house="openCreateSpace('house')"
      @open-edit-house="handleEditHouse"
      @delete-house-confirm="handleDeleteHouseConfirm"
      @open-create-room="(hId) => openCreateSpace('room', hId)"
      @open-edit-room="handleEditRoom"
      @delete-room-confirm="handleDeleteRoomConfirm"
      @open-backup-panel="showBackupPanel = true"
    />

    <!-- 右侧主体内容区 -->
    <main class="flex-1 flex flex-col h-full overflow-hidden">
      <!-- 空间锚定条与操作顶栏 (右上角集成醒目退出按钮) -->
      <SpaceAnchorBar
        :current-admin-tab="adminTab"
        :stats="adminStats"
        @open-create-item="openCreateItem"
        @logout-confirm="showLogoutConfirm = true"
        @open-admin-god-view="showGodView = true"
        @open-edit-nickname="showEditNicknameDialog = true"
        @open-change-password="handleOpenChangePassword"
      />

      <!-- A. 系统管理员专属工作台 (admin 不产生任何私有数据) -->
      <AdminDashboard
        v-if="authStore.isAdmin"
        :active-tab="adminTab"
        :stats="adminStats"
        @update-tab="(tab) => adminTab = tab"
        @open-backup-panel="showBackupPanel = true"
        @inspect-item="handleInspectGodViewItem"
      />

      <!-- B. 普通家庭成员空间视图 (搜索栏与分类过滤胶囊 + 物品网格) -->
      <template v-else>
        <!-- 搜索栏与分类过滤胶囊 (字号全面升级至舒适 text-sm) -->
        <div class="relative z-10 px-8 py-4 bg-white/40 backdrop-blur-sm border-b border-slate-100 flex items-center justify-between gap-4">
          <div class="relative flex-1 max-w-md">
            <Search class="absolute left-3.5 top-3 w-4 h-4 text-slate-400" />
            <input
              v-model="searchQuery"
              type="text"
              placeholder="搜索当前私有物品、品牌、存放细节..."
              class="w-full pl-10 pr-4 py-2.5 text-sm rounded-xl border border-slate-200/80 focus:outline-none focus:ring-2 focus:ring-orange-400 bg-white"
              @input="handleSearchInput"
            />
          </div>

          <!-- 重构后的高颜值品类筛选器 (下拉全景气泡网格，彻底消除横向截断) -->
          <div class="flex items-center gap-2.5">
            <CategoryFilterSelect
              :categories="activeCategories"
              :selected-category-id="selectedCategory"
              @select="(id) => selectedCategory = id"
              @open-manage="showCategoryManage = true"
            />
            <button
              type="button"
              :disabled="loading"
              class="inline-flex items-center gap-1.5 px-3 py-2.5 rounded-xl border border-slate-200/80 bg-white text-sm font-semibold text-slate-600 hover:bg-slate-50 transition-colors disabled:opacity-50"
              title="刷新物品清单"
              @click="loadItems"
            >
              <RefreshCw class="w-4 h-4" :class="{ 'animate-spin': loading }" />
              <span class="hidden sm:inline">刷新</span>
            </button>
          </div>
        </div>

        <!-- 物品卡片虚拟滑动窗口网格 (支持千件物品 60fps 丝滑滚动) -->
        <div class="flex-1 overflow-y-auto p-8">
          <div v-if="loading" class="text-center py-20 text-slate-400 text-sm">
            正在载入空间物品...
          </div>

          <div v-else-if="items.length === 0" class="text-center py-24">
            <div class="w-16 h-16 rounded-3xl bg-orange-50 text-orange-400 mx-auto flex items-center justify-center text-2xl mb-3">
              📦
            </div>
            <p class="text-base font-bold text-slate-700">当前空间暂无收纳物品</p>
            <p class="text-sm text-slate-400 mt-1">点击右上角“登记新物品”或拍照归档吧！</p>
          </div>

          <VirtualItemGrid
            v-else
            :items="items"
            :loading-more="loadingMore"
            :load-more-error="loadMoreError"
            :has-more="hasMore"
            :total="total"
            @preview="handlePreview"
            @edit="handleEdit"
            @delete="handleDeleteConfirm"
            @load-more="handleLoadMore"
            @retry-load-more="handleLoadMore"
            @refresh="loadItems"
          />
        </div>
      </template>
    </main>

    <!-- 弹窗集群 (统一温润大圆角规范，严禁原生 alert/confirm) -->
    <ItemDialog
      :is-open="showItemDialog"
      :item-to-edit="editingItem"
      :categories="categories"
      @close="showItemDialog = false"
      @saved="loadItems"
    />

    <MediaPreviewDialog
      :is-open="showPreviewDialog"
      :item="previewingItem"
      @close="showPreviewDialog = false"
    />

    <CategoryManageDialog
      :is-open="showCategoryManage"
      @close="showCategoryManage = false"
      @updated="onCategoriesUpdated"
    />

    <GodViewDialog
      :is-open="showGodView"
      @close="showGodView = false"
      @inspect-item="handleInspectGodViewItem"
    />

    <BackupPanel
      :is-open="showBackupPanel"
      @close="showBackupPanel = false"
    />

    <AdminPasswordDialog
      :is-open="showAdminPasswordDialog"
      @close="showAdminPasswordDialog = false"
      @success="authStore.logout"
    />

    <EditNicknameDialog
      :is-open="showEditNicknameDialog"
      @close="showEditNicknameDialog = false"
    />

    <ChangePasswordDialog
      :is-open="showChangePasswordDialog"
      @close="showChangePasswordDialog = false"
    />

    <HouseRoomDialog
      :is-open="showSpaceDialog"
      :type="spaceDialogType"
      :mode="spaceDialogMode"
      :target="selectedSpaceTarget"
      :house-id="selectedHouseForRoom"
      @close="showSpaceDialog = false"
      @created="onSpaceUpdated"
      @saved="onSpaceUpdated"
    />

    <!-- 物品删除确认 -->
    <ConfirmDialog
      :is-open="showDeleteConfirm"
      title="确认删除该物品？"
      message="删除后将永久清理该物品及其关联的所有物理现场照片与音视频附件！"
      :is-danger="true"
      confirm-text="彻底删除"
      @confirm="executeDeleteItem"
      @cancel="showDeleteConfirm = false"
    />

    <!-- 房屋删除确认 -->
    <ConfirmDialog
      :is-open="showDeleteHouseConfirm"
      title="确认删除此房屋空间？"
      :message="`将删除空房屋【${deletingHouse?.name}】及其名下空房间；若房屋内仍有物品，系统将拦截删除并建议改为停用。`"
      :is-danger="true"
      confirm-text="确认删除房屋"
      @confirm="executeDeleteHouse"
      @cancel="showDeleteHouseConfirm = false"
    />

    <!-- 房间删除确认 -->
    <ConfirmDialog
      :is-open="showDeleteRoomConfirm"
      title="确认删除此功能房间？"
      :message="`将删除空房间【${deletingRoom?.name}】；若房间内仍有物品，系统将拦截删除并建议改为停用。`"
      :is-danger="true"
      confirm-text="确认删除房间"
      @confirm="executeDeleteRoom"
      @cancel="showDeleteRoomConfirm = false"
    />

    <!-- 退出登录确认 -->
    <ConfirmDialog
      :is-open="showLogoutConfirm"
      title="退出登录确认"
      message="您确定要退出当前家庭账本账号吗？"
      confirm-text="退出"
      @confirm="authStore.logout"
      @cancel="showLogoutConfirm = false"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from "vue";
import type { Item, Category, House, Room, AdminSystemStats } from "@/types";
import { useAuthStore } from "@/stores/auth";
import { useSpaceStore } from "@/stores/space";
import { useToastStore } from "@/stores/toast";
import {
  getCategoriesApi,
  deleteItemApi,
  deleteHouseApi,
  deleteRoomApi,
  getAdminStatsApi,
} from "@/api";
import { useItemPagination } from "@/composables/useItemPagination";

import HouseRoomSidebar from "@/components/space/HouseRoomSidebar.vue";
import SpaceAnchorBar from "@/components/space/SpaceAnchorBar.vue";
import ItemCard from "@/components/item/ItemCard.vue";
import ItemDialog from "@/components/item/ItemDialog.vue";
import MediaPreviewDialog from "@/components/item/MediaPreviewDialog.vue";
import VirtualItemGrid from "@/components/item/VirtualItemGrid.vue";
import CategoryFilterSelect from "@/components/item/CategoryFilterSelect.vue";
import CategoryManageDialog from "@/components/item/CategoryManageDialog.vue";
import AdminDashboard from "@/components/admin/AdminDashboard.vue";
import AdminPasswordDialog from "@/components/admin/AdminPasswordDialog.vue";
import EditNicknameDialog from "@/components/auth/EditNicknameDialog.vue";
import ChangePasswordDialog from "@/components/auth/ChangePasswordDialog.vue";
import GodViewDialog from "@/components/admin/GodViewDialog.vue";
import BackupPanel from "@/components/admin/BackupPanel.vue";
import HouseRoomDialog from "@/components/space/HouseRoomDialog.vue";
import ConfirmDialog from "@/components/ui/ConfirmDialog.vue";
import { Search, FolderCog, ChevronRight, RefreshCw } from "lucide-vue-next";

const authStore = useAuthStore();
const spaceStore = useSpaceStore();
const toastStore = useToastStore();

const {
  items,
  loading,
  loadingMore,
  loadMoreError,
  hasMore,
  total,
  loadFirstPage,
  loadNextPage,
} = useItemPagination(60);
const categories = ref<Category[]>([]);
const searchQuery = ref("");
const selectedCategory = ref<number | null>(null);

const activeCategories = computed(() =>
  categories.value.filter((c) => c.is_active !== false)
);

// 弹窗状态
const adminTab = ref<string>("users");
const adminStats = ref<AdminSystemStats | null>(null);
const showAdminPasswordDialog = ref(false);
const showEditNicknameDialog = ref(false);
const showChangePasswordDialog = ref(false);

function handleOpenChangePassword() {
  if (authStore.isAdmin) {
    showAdminPasswordDialog.value = true;
  } else {
    showChangePasswordDialog.value = true;
  }
}

const showCategoryManage = ref(false);
const showItemDialog = ref(false);
const editingItem = ref<Item | null>(null);
const showPreviewDialog = ref(false);
const previewingItem = ref<Item | null>(null);
const showGodView = ref(false);
const showBackupPanel = ref(false);
const showSpaceDialog = ref(false);
const spaceDialogType = ref<"house" | "room">("house");
const spaceDialogMode = ref<"create" | "edit">("create");
const selectedSpaceTarget = ref<House | Room | null>(null);
const showDeleteConfirm = ref(false);
const deletingItemId = ref<number | null>(null);
const showDeleteHouseConfirm = ref(false);
const deletingHouse = ref<House | null>(null);
const showDeleteRoomConfirm = ref(false);
const deletingRoom = ref<Room | null>(null);
const showLogoutConfirm = ref(false);

function getFilterParams() {
  return {
    houseId: spaceStore.activeHouseId,
    roomId: spaceStore.activeRoomId,
    categoryId: selectedCategory.value,
    searchQuery: searchQuery.value,
  };
}

onMounted(async () => {
  if (authStore.isAuthenticated) {
    await authStore.fetchCurrentUser();
  }
  // 系统管理员不产生私有房屋、空间或物品数据，阻断普通账本请求，加载管理看板指标
  if (authStore.isAdmin) {
    await loadAdminStats();
    return;
  }
  await spaceStore.loadSpaces();
  await loadCategories();
  await loadItems();
});

async function loadAdminStats() {
  try {
    adminStats.value = await getAdminStatsApi();
  } catch (err: any) {
    console.error("加载管理指标失败", err);
  }
}

function openGodViewFromSidebar() {
  adminTab.value = "inspection";
}

watch(
  () => [spaceStore.activeHouseId, spaceStore.activeRoomId, selectedCategory.value],
  () => {
    if (!authStore.isAdmin) {
      loadItems();
    }
  }
);

async function loadCategories() {
  try {
    categories.value = await getCategoriesApi(true);
  } catch (err: any) {
    console.error("加载分类失败:", err);
  }
}

async function onCategoriesUpdated() {
  await loadCategories();
  await loadItems();
}

async function loadItems() {
  if (authStore.isAdmin) return;
  await loadFirstPage(getFilterParams(), (msg) => {
    toastStore.error("加载物品失败", msg);
  });
}

async function handleLoadMore() {
  if (authStore.isAdmin) return;
  await loadNextPage(getFilterParams(), (msg) => {
    toastStore.error("加载更多失败", msg);
  });
}

let searchTimer: any = null;
function handleSearchInput() {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(() => {
    loadItems();
  }, 300);
}

function openCreateItem() {
  editingItem.value = null;
  showItemDialog.value = true;
}

function handlePreview(item: Item) {
  previewingItem.value = item;
  showPreviewDialog.value = true;
}

function handleEdit(item: Item) {
  editingItem.value = item;
  showItemDialog.value = true;
}

function handleDeleteConfirm(item: Item) {
  deletingItemId.value = item.id;
  showDeleteConfirm.value = true;
}

async function executeDeleteItem() {
  if (!deletingItemId.value) return;
  try {
    await deleteItemApi(deletingItemId.value);
    toastStore.success("物品已彻底清理并释放磁盘附件空间");
    showDeleteConfirm.value = false;
    await loadItems();
  } catch (err: any) {
    toastStore.error("删除失败", err.message);
  }
}

const selectedHouseForRoom = ref<number | null>(null);

function openCreateSpace(type: "house" | "room", houseId?: number) {
  spaceDialogType.value = type;
  spaceDialogMode.value = "create";
  selectedSpaceTarget.value = null;
  selectedHouseForRoom.value = houseId || spaceStore.activeHouseId || null;
  showSpaceDialog.value = true;
}

function handleEditHouse(house: House) {
  spaceDialogType.value = "house";
  spaceDialogMode.value = "edit";
  selectedSpaceTarget.value = house;
  showSpaceDialog.value = true;
}

function handleDeleteHouseConfirm(house: House) {
  deletingHouse.value = house;
  showDeleteHouseConfirm.value = true;
}

async function executeDeleteHouse() {
  if (!deletingHouse.value) return;
  try {
    await deleteHouseApi(deletingHouse.value.id);
    toastStore.success("空房屋已删除");
    showDeleteHouseConfirm.value = false;
    if (spaceStore.activeHouseId === deletingHouse.value.id) {
      spaceStore.activeHouseId = null;
      spaceStore.activeRoomId = null;
    }
    await onSpaceUpdated();
  } catch (err: any) {
    showDeleteHouseConfirm.value = false;
    toastStore.error("无法删除房屋", err.message);
  }
}

function handleEditRoom(room: Room) {
  spaceDialogType.value = "room";
  spaceDialogMode.value = "edit";
  selectedSpaceTarget.value = room;
  showSpaceDialog.value = true;
}

function handleDeleteRoomConfirm(room: Room) {
  deletingRoom.value = room;
  showDeleteRoomConfirm.value = true;
}

async function executeDeleteRoom() {
  if (!deletingRoom.value) return;
  try {
    await deleteRoomApi(deletingRoom.value.id);
    toastStore.success("空房间已删除");
    showDeleteRoomConfirm.value = false;
    if (spaceStore.activeRoomId === deletingRoom.value.id) {
      spaceStore.activeRoomId = null;
    }
    await onSpaceUpdated();
  } catch (err: any) {
    showDeleteRoomConfirm.value = false;
    toastStore.error("无法删除房间", err.message);
  }
}

async function onSpaceUpdated() {
  await spaceStore.loadSpaces();
  await loadItems();
}

function handleInspectGodViewItem(item: any) {
  previewingItem.value = item;
  showPreviewDialog.value = true;
}
</script>
