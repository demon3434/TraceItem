<template>
  <!-- 顶层：全部空间物品 -->
  <button
    @click="selectAllSpaces"
    class="w-full flex items-center justify-between px-3.5 py-2.5 rounded-xl text-sm font-bold transition-all"
    :class="spaceStore.activeHouseId === null ? 'shadow-sm' : 'text-slate-700 hover:bg-slate-50'"
    :style="
      spaceStore.activeHouseId === null
        ? { backgroundColor: 'var(--theme-primary)', color: '#ffffff' }
        : {}
    "
  >
    <span class="flex items-center space-x-2.5">
      <span class="text-base">🌟</span>
      <span>全部空间收纳物品</span>
    </span>
  </button>

  <!-- 房屋与房间树形层级 -->
  <div class="pt-2">
    <div class="flex items-center justify-between px-2 mb-2.5 gap-1">
      <span class="text-xs font-bold text-slate-400 uppercase tracking-wider">我的空间层级</span>
      <div class="flex items-center space-x-1">
        <button
          v-if="spaceStore.houses.length > 0"
          type="button"
          @click="toggleSortMode"
          class="flex items-center space-x-1 px-2.5 py-1 text-xs font-bold rounded-lg transition-colors"
          :class="isSortMode ? 'shadow-xs' : 'text-slate-600 hover:bg-slate-100'"
          :style="
            isSortMode
              ? { backgroundColor: 'var(--theme-primary)', color: '#ffffff' }
              : {}
          "
          :title="isSortMode ? '完成排序' : '调整房屋与房间顺序'"
        >
          <Check v-if="isSortMode" class="w-3.5 h-3.5" />
          <ArrowUpDown v-else class="w-3.5 h-3.5" />
          <span>{{ isSortMode ? "完成" : "排序" }}</span>
        </button>

        <button
          v-if="!isSortMode"
          type="button"
          @click="emit('openCreateHouse')"
          class="flex items-center space-x-1 px-2.5 py-1 text-xs font-bold rounded-lg transition-colors hover:opacity-80"
          :style="{ color: 'var(--theme-primary)' }"
          title="添加新房屋"
        >
          <Plus class="w-4 h-4" />
          <span>新建房屋</span>
        </button>
      </div>
    </div>

    <!-- 排序模式提示条 -->
    <div
      v-if="isSortMode"
      class="mx-1 mb-2.5 px-3 py-2 rounded-xl text-xs font-medium leading-relaxed border"
      :style="{
        backgroundColor: 'var(--theme-primary-light)',
        borderColor: 'var(--theme-primary-border)',
        color: 'var(--theme-primary-text)',
      }"
    >
      拖拽或点 ↑↓ 调整顺序；房间仅限在所属房屋内部排序
    </div>

      <!-- 房屋节点列表 -->
    <div class="space-y-2">
      <div
        v-for="(house, hIdx) in displayedHouses"
        :key="house.id"
        class="rounded-2xl transition-all"
        :class="[
          isExpanded(house.id) ? 'bg-slate-50/70 p-1.5' : '',
          house.is_active === false ? 'opacity-70' : '',
        ]"
      >
        <div
          :draggable="isSortMode"
          @dragstart="onHouseDragStart(house, $event)"
          @dragover="onHouseDragOver(house, $event)"
          @dragleave="clearDragOver(house.id)"
          @drop="onHouseDrop(house, $event)"
          @dragend="onDragEnd"
          class="relative w-full flex items-center justify-between px-3 py-2.5 rounded-xl text-sm font-bold transition-all group"
          :class="[
            isSortMode ? 'cursor-grab active:cursor-grabbing bg-white border border-slate-200/80' : 'cursor-pointer',
            !isSortMode && spaceStore.activeHouseId === house.id && spaceStore.activeRoomId === null
              ? 'font-extrabold'
              : 'text-slate-800 hover:bg-white',
            dragOverHouseId === house.id ? 'ring-2 ring-offset-1' : '',
            draggingHouseId === house.id ? 'opacity-45 scale-[0.98]' : '',
          ]"
          :style="
            !isSortMode && spaceStore.activeHouseId === house.id && spaceStore.activeRoomId === null
              ? {
                  backgroundColor: 'var(--theme-primary-light)',
                  color: 'var(--theme-primary-text)',
                }
              : dragOverHouseId === house.id
                ? { '--tw-ring-color': 'var(--theme-primary)' }
                : {}
          "
          @click="isSortMode ? toggleExpand(house.id) : selectHouse(house.id)"
        >
          <div class="flex items-center space-x-2 min-w-0 flex-1">
            <GripVertical
              v-if="isSortMode"
              class="w-4 h-4 text-slate-400 flex-shrink-0"
            />
            <button
              type="button"
              @click.stop="toggleExpand(house.id)"
              class="p-0.5 text-slate-400 hover:text-slate-700 rounded transition-transform flex-shrink-0"
            >
              <ChevronDown v-if="isExpanded(house.id)" class="w-4 h-4" />
              <ChevronRight v-else class="w-4 h-4" />
            </button>
            <span class="text-base flex-shrink-0">{{ house.icon }}</span>
            <span class="truncate" :title="house.name">{{ cleanName(house.name, house.icon) }}</span>
            <span
              v-if="house.is_active === false"
              class="px-1.5 py-0.5 text-xs font-semibold rounded-md bg-slate-200/80 text-slate-600 flex-shrink-0"
            >
              已停用
            </span>
          </div>

          <div v-if="isSortMode" class="flex items-center space-x-0.5 flex-shrink-0 ml-1" @click.stop>
            <button
              type="button"
              :disabled="hIdx === 0 || isSavingOrder"
              @click="moveHouse(hIdx, -1)"
              class="p-1 rounded-lg text-slate-500 hover:bg-slate-100 disabled:opacity-25"
              title="上移房屋"
            >
              <ArrowUp class="w-3.5 h-3.5" />
            </button>
            <button
              type="button"
              :disabled="hIdx === spaceStore.houses.length - 1 || isSavingOrder"
              @click="moveHouse(hIdx, 1)"
              class="p-1 rounded-lg text-slate-500 hover:bg-slate-100 disabled:opacity-25"
              title="下移房屋"
            >
              <ArrowDown class="w-3.5 h-3.5" />
            </button>
          </div>

          <div
            v-else
            class="absolute right-2 top-1/2 -translate-y-1/2 hidden group-hover:flex items-center space-x-0.5 px-1 py-0.5 rounded-lg bg-white/95 backdrop-blur-sm shadow-sm border border-slate-200/80"
          >
            <button
              v-if="house.is_active !== false"
              type="button"
              @click.stop="emit('openCreateRoom', house.id)"
              class="p-1 text-slate-400 hover:text-orange-500 rounded-lg hover:bg-slate-100"
              title="在此房屋下添加房间"
            >
              <Plus class="w-3.5 h-3.5" />
            </button>
            <button
              type="button"
              @click.stop="toggleHouseActive(house)"
              class="p-1 rounded-lg hover:bg-slate-100 transition-colors"
              :class="house.is_active !== false ? 'text-slate-400 hover:text-amber-600' : 'text-emerald-600 hover:bg-emerald-50'"
              :title="house.is_active !== false ? '停用房屋（不再录入新物品）' : '重新启用房屋'"
            >
              <EyeOff v-if="house.is_active !== false" class="w-3.5 h-3.5" />
              <Eye v-else class="w-3.5 h-3.5" />
            </button>
            <button
              type="button"
              @click.stop="emit('openEditHouse', house)"
              class="p-1 text-slate-400 hover:text-blue-500 rounded-lg hover:bg-slate-100"
              title="修改房屋信息"
            >
              <Edit3 class="w-3.5 h-3.5" />
            </button>
            <button
              type="button"
              @click.stop="emit('deleteHouseConfirm', house)"
              class="p-1 text-slate-400 hover:text-rose-500 rounded-lg hover:bg-slate-100"
              title="删除房屋"
            >
              <Trash2 class="w-3.5 h-3.5" />
            </button>
          </div>
        </div>

        <SpaceTreeRoomList
          v-if="isExpanded(house.id)"
          :house-id="house.id"
          :house-is-active="house.is_active !== false"
          :rooms="getRoomsForHouse(house.id)"
          :is-sort-mode="isSortMode"
          :is-saving-order="isSavingOrder"
          @select-room="selectRoom"
          @open-create-room="emit('openCreateRoom', $event)"
          @open-edit-room="emit('openEditRoom', $event)"
          @delete-room-confirm="emit('deleteRoomConfirm', $event)"
          @saving-change="isSavingOrder = $event"
        />
      </div>
    </div>

    <!-- 显示已停用空间切换开关 -->
    <button
      v-if="spaceStore.hasInactiveSpaces && !isSortMode"
      type="button"
      @click="spaceStore.showInactiveSpaces = !spaceStore.showInactiveSpaces"
      class="mt-3 w-full flex items-center justify-between px-3 py-2 rounded-xl text-xs font-semibold border transition-colors"
      :class="
        spaceStore.showInactiveSpaces
          ? 'bg-slate-100 border-slate-300 text-slate-800'
          : 'bg-slate-50/70 border-slate-200/70 text-slate-500 hover:bg-slate-100'
      "
    >
      <span class="flex items-center space-x-1.5">
        <Eye v-if="spaceStore.showInactiveSpaces" class="w-3.5 h-3.5" />
        <EyeOff v-else class="w-3.5 h-3.5" />
        <span>显示已停用空间</span>
      </span>
      <span class="text-xs font-bold">{{ spaceStore.showInactiveSpaces ? "已开启" : "已隐藏" }}</span>
    </button>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch } from "vue";
import { toggleHouseStatusApi } from "@/api";
import { useSpaceStore } from "@/stores/space";
import { useToastStore } from "@/stores/toast";
import SpaceTreeRoomList from "@/components/space/SpaceTreeRoomList.vue";
import type { House } from "@/types";
import {
  Plus,
  Edit3,
  Trash2,
  ChevronDown,
  ChevronRight,
  ArrowUpDown,
  Check,
  GripVertical,
  ArrowUp,
  ArrowDown,
  Eye,
  EyeOff,
} from "lucide-vue-next";

const spaceStore = useSpaceStore();
const toastStore = useToastStore();

const emit = defineEmits([
  "openCreateHouse",
  "openEditHouse",
  "deleteHouseConfirm",
  "openCreateRoom",
  "openEditRoom",
  "deleteRoomConfirm",
]);

const isSortMode = ref(false);
const isSavingOrder = ref(false);
const expandedHouseId = ref<number | null>(spaceStore.activeHouseId || null);
const draggingHouseId = ref<number | null>(null);
const dragOverHouseId = ref<number | null>(null);

const displayedHouses = computed(() => {
  if (isSortMode.value || spaceStore.showInactiveSpaces) {
    return spaceStore.houses;
  }
  return spaceStore.houses.filter((h) => h.is_active !== false);
});

async function toggleHouseActive(house: House) {
  const nextActive = house.is_active === false;
  try {
    await toggleHouseStatusApi(house.id, nextActive);
    await spaceStore.loadSpaces();
    toastStore.success(
      nextActive ? "房屋已重新启用" : "房屋已停用",
      nextActive ? "现在可以继续向该房屋录入新物品" : "已有物品完好保留，可在开启「显示已停用空间」后查看"
    );
  } catch (err: any) {
    toastStore.error("操作失败", err.message);
  }
}

function toggleSortMode() {
  isSortMode.value = !isSortMode.value;
  onDragEnd();
}

function isExpanded(houseId: number): boolean {
  return expandedHouseId.value === houseId;
}

function toggleExpand(houseId: number) {
  expandedHouseId.value = expandedHouseId.value === houseId ? null : houseId;
}

function getRoomsForHouse(houseId: number) {
  return spaceStore.rooms.filter((r) => r.house_id === houseId);
}

function selectAllSpaces() {
  spaceStore.activeHouseId = null;
  spaceStore.activeRoomId = null;
}

function selectHouse(houseId: number) {
  if (
    spaceStore.activeHouseId === houseId &&
    spaceStore.activeRoomId === null &&
    expandedHouseId.value === houseId
  ) {
    expandedHouseId.value = null;
  } else {
    expandedHouseId.value = houseId;
    spaceStore.activeHouseId = houseId;
    spaceStore.activeRoomId = null;
  }
}

function selectRoom(houseId: number, roomId: number) {
  expandedHouseId.value = houseId;
  spaceStore.activeHouseId = houseId;
  spaceStore.activeRoomId = roomId;
}

function clearDragOver(houseId: number) {
  if (dragOverHouseId.value === houseId) {
    dragOverHouseId.value = null;
  }
}

function onDragEnd() {
  draggingHouseId.value = null;
  dragOverHouseId.value = null;
}

function onHouseDragStart(house: House, e: DragEvent) {
  if (!isSortMode.value) return;
  draggingHouseId.value = house.id;
  if (e.dataTransfer) {
    e.dataTransfer.effectAllowed = "move";
    e.dataTransfer.setData("text/plain", `house:${house.id}`);
  }
}

function onHouseDragOver(house: House, e: DragEvent) {
  if (!isSortMode.value || draggingHouseId.value === null) return;
  e.preventDefault();
  dragOverHouseId.value = house.id;
}

async function onHouseDrop(targetHouse: House, e: DragEvent) {
  e.preventDefault();
  const sourceId = draggingHouseId.value;
  onDragEnd();
  if (!isSortMode.value || sourceId === null || sourceId === targetHouse.id) {
    return;
  }
  const ids = spaceStore.houses.map((h) => h.id);
  const fromIdx = ids.indexOf(sourceId);
  const toIdx = ids.indexOf(targetHouse.id);
  if (fromIdx < 0 || toIdx < 0) return;
  const [moved] = ids.splice(fromIdx, 1);
  ids.splice(toIdx, 0, moved);
  await persistHouseOrder(ids);
}

async function moveHouse(index: number, delta: number) {
  const target = index + delta;
  if (target < 0 || target >= spaceStore.houses.length || isSavingOrder.value) return;
  const ids = spaceStore.houses.map((h) => h.id);
  const [moved] = ids.splice(index, 1);
  ids.splice(target, 0, moved);
  await persistHouseOrder(ids);
}

async function persistHouseOrder(orderedIds: number[]) {
  isSavingOrder.value = true;
  try {
    await spaceStore.reorderHouses(orderedIds);
    toastStore.success("房屋顺序已更新");
  } catch (err: any) {
    toastStore.error("保存房屋顺序失败", err?.message || "请稍后重试");
  } finally {
    isSavingOrder.value = false;
  }
}

watch(
  () => spaceStore.activeHouseId,
  (newId) => {
    if (newId !== null) {
      expandedHouseId.value = newId;
    }
  },
  { immediate: true }
);

function cleanName(name: string, icon?: string): string {
  if (!name) return "";
  let res = name.trim();
  if (icon && res.startsWith(icon)) {
    res = res.slice(icon.length).trim();
  }
  return res || name;
}
</script>
