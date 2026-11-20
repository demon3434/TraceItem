<template>
  <div
    class="ml-5 mt-1.5 pl-3 border-l-2 space-y-1.5 py-1"
    :style="{ borderColor: 'var(--theme-primary-border)' }"
  >
    <div
      v-for="(room, rIdx) in displayedRooms"
      :key="room.id"
      :draggable="isSortMode"
      @dragstart="onRoomDragStart(room, $event)"
      @dragover="onRoomDragOver(room, $event)"
      @dragleave="clearDragOver(room.id)"
      @drop="onRoomDrop(room, $event)"
      @dragend="onDragEnd"
      class="relative w-full group/room flex items-center justify-between px-3 py-2 rounded-xl text-sm transition-all"
      :class="[
        isSortMode ? 'cursor-grab active:cursor-grabbing bg-white border border-slate-200/80 text-slate-800 font-medium' : 'cursor-pointer',
        !isSortMode && isActiveRoom(room.id)
          ? 'font-bold shadow-sm'
          : !isSortMode
            ? 'text-slate-700 hover:bg-white hover:text-slate-900 font-medium'
            : '',
        dragOverRoomId === room.id ? 'ring-2 ring-offset-1' : '',
        draggingRoomId === room.id ? 'opacity-45 scale-[0.98]' : '',
      ]"
      :style="
        !isSortMode && isActiveRoom(room.id)
          ? { backgroundColor: 'var(--theme-primary)', color: '#ffffff' }
          : dragOverRoomId === room.id
            ? { '--tw-ring-color': 'var(--theme-primary)' }
            : {}
      "
      @click="!isSortMode && emit('selectRoom', houseId, room.id)"
    >
      <span class="flex items-center space-x-2 min-w-0 flex-1">
        <GripVertical
          v-if="isSortMode"
          class="w-3.5 h-3.5 text-slate-400 flex-shrink-0"
        />
        <span class="text-base flex-shrink-0">{{ room.icon }}</span>
        <span class="truncate" :title="room.name">{{ cleanName(room.name, room.icon) }}</span>
        <span
          v-if="room.is_active === false"
          class="px-1.5 py-0.5 text-xs font-semibold rounded-md bg-slate-200/80 text-slate-600 flex-shrink-0"
        >
          已停用
        </span>
      </span>

      <!-- 排序态：房间上下微调 -->
      <div v-if="isSortMode" class="flex items-center space-x-0.5 flex-shrink-0 ml-1" @click.stop>
        <button
          type="button"
          :disabled="rIdx === 0 || isSavingOrder"
          @click="moveRoom(rIdx, -1)"
          class="p-1 rounded-lg text-slate-500 hover:bg-slate-100 disabled:opacity-25"
          title="上移房间"
        >
          <ArrowUp class="w-3.5 h-3.5" />
        </button>
        <button
          type="button"
          :disabled="rIdx === rooms.length - 1 || isSavingOrder"
          @click="moveRoom(rIdx, 1)"
          class="p-1 rounded-lg text-slate-500 hover:bg-slate-100 disabled:opacity-25"
          title="下移房间"
        >
          <ArrowDown class="w-3.5 h-3.5" />
        </button>
      </div>

      <!-- 普通态：房间快捷操作按钮 -->
      <div
        v-else
        class="absolute right-2 top-1/2 -translate-y-1/2 hidden group-hover/room:flex items-center space-x-0.5 px-1 py-0.5 rounded-lg bg-white/95 backdrop-blur-sm shadow-sm border border-slate-200/80 text-slate-600"
      >
        <button
          type="button"
          @click.stop="toggleRoomActive(room)"
          class="p-1 rounded-lg hover:bg-slate-100 transition-colors"
          :class="room.is_active !== false ? 'hover:text-amber-600' : 'text-emerald-600 hover:bg-emerald-50'"
          :title="room.is_active !== false ? '停用房间（不再录入新物品）' : '重新启用房间'"
        >
          <EyeOff v-if="room.is_active !== false" class="w-3 h-3" />
          <Eye v-else class="w-3 h-3" />
        </button>
        <button
          type="button"
          @click.stop="emit('openEditRoom', room)"
          class="p-1 rounded-lg hover:bg-slate-100 transition-colors"
          title="修改房间"
        >
          <Edit3 class="w-3 h-3" />
        </button>
        <button
          type="button"
          @click.stop="emit('deleteRoomConfirm', room)"
          class="p-1 rounded-lg hover:bg-rose-500 hover:text-white transition-colors"
          title="删除房间"
        >
          <Trash2 class="w-3 h-3" />
        </button>
      </div>
    </div>

    <!-- 快捷在此房屋下添加房间按钮 -->
    <button
      v-if="!isSortMode && houseIsActive"
      @click="emit('openCreateRoom', houseId)"
      class="w-full flex items-center space-x-2 px-3 py-1.5 rounded-xl text-xs font-semibold text-slate-400 hover:opacity-100 transition-colors"
      :style="{ color: 'var(--theme-primary)' }"
    >
      <Plus class="w-3.5 h-3.5" />
      <span>在此添加功能房间...</span>
    </button>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from "vue";
import { toggleRoomStatusApi } from "@/api";
import { useSpaceStore } from "@/stores/space";
import { useToastStore } from "@/stores/toast";
import type { Room } from "@/types";
import { Plus, Edit3, Trash2, GripVertical, ArrowUp, ArrowDown, Eye, EyeOff } from "lucide-vue-next";

const props = defineProps<{
  houseId: number;
  houseIsActive: boolean;
  rooms: Room[];
  isSortMode: boolean;
  isSavingOrder: boolean;
}>();

const displayedRooms = computed(() => {
  if (props.isSortMode || spaceStore.showInactiveSpaces) {
    return props.rooms;
  }
  return props.rooms.filter((r) => r.is_active !== false);
});

async function toggleRoomActive(room: Room) {
  const nextActive = room.is_active === false;
  try {
    await toggleRoomStatusApi(room.id, nextActive);
    await spaceStore.loadSpaces();
    toastStore.success(
      nextActive ? "房间已重新启用" : "房间已停用",
      nextActive ? "现在可以继续向该房间录入新物品" : "已有物品完好保留，可在开启「显示已停用空间」后查看"
    );
  } catch (err: any) {
    toastStore.error("操作失败", err.message);
  }
}

const emit = defineEmits([
  "selectRoom",
  "openCreateRoom",
  "openEditRoom",
  "deleteRoomConfirm",
  "savingChange",
]);

const spaceStore = useSpaceStore();
const toastStore = useToastStore();

const draggingRoomId = ref<number | null>(null);
const dragOverRoomId = ref<number | null>(null);

function isActiveRoom(roomId: number): boolean {
  return spaceStore.activeHouseId === props.houseId && spaceStore.activeRoomId === roomId;
}

function clearDragOver(roomId: number) {
  if (dragOverRoomId.value === roomId) {
    dragOverRoomId.value = null;
  }
}

function onDragEnd() {
  draggingRoomId.value = null;
  dragOverRoomId.value = null;
}

function onRoomDragStart(room: Room, e: DragEvent) {
  if (!props.isSortMode) return;
  draggingRoomId.value = room.id;
  if (e.dataTransfer) {
    e.dataTransfer.effectAllowed = "move";
    e.dataTransfer.setData("text/plain", `room:${props.houseId}:${room.id}`);
  }
}

function onRoomDragOver(targetRoom: Room, e: DragEvent) {
  if (!props.isSortMode || draggingRoomId.value === null) return;
  e.preventDefault();
  dragOverRoomId.value = targetRoom.id;
}

async function onRoomDrop(targetRoom: Room, e: DragEvent) {
  e.preventDefault();
  const sourceId = draggingRoomId.value;
  onDragEnd();
  if (!props.isSortMode || sourceId === null || sourceId === targetRoom.id) {
    return;
  }
  const ids = props.rooms.map((r) => r.id);
  const fromIdx = ids.indexOf(sourceId);
  const toIdx = ids.indexOf(targetRoom.id);
  if (fromIdx < 0 || toIdx < 0) return;
  const [moved] = ids.splice(fromIdx, 1);
  ids.splice(toIdx, 0, moved);
  await persistRoomOrder(ids);
}

async function moveRoom(index: number, delta: number) {
  const target = index + delta;
  if (target < 0 || target >= props.rooms.length || props.isSavingOrder) return;
  const ids = props.rooms.map((r) => r.id);
  const [moved] = ids.splice(index, 1);
  ids.splice(target, 0, moved);
  await persistRoomOrder(ids);
}

async function persistRoomOrder(orderedIds: number[]) {
  emit("savingChange", true);
  try {
    await spaceStore.reorderRooms(props.houseId, orderedIds);
    toastStore.success("房间顺序已更新");
  } catch (err: any) {
    toastStore.error("保存房间顺序失败", err?.message || "请稍后重试");
  } finally {
    emit("savingChange", false);
  }
}

function cleanName(name: string, icon?: string): string {
  if (!name) return "";
  let res = name.trim();
  if (icon && res.startsWith(icon)) {
    res = res.slice(icon.length).trim();
  }
  return res || name;
}
</script>

