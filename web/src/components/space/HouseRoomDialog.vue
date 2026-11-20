<template>
  <Transition
    enter-active-class="ease-out duration-250 transition"
    enter-from-class="opacity-0"
    enter-to-class="opacity-100"
    leave-active-class="ease-in duration-200 transition"
    leave-from-class="opacity-100"
    leave-to-class="opacity-0"
  >
    <div
      v-if="isOpen"
      class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/40 backdrop-blur-sm"
      @click.self="emit('close')"
    >
      <div class="w-full max-w-sm bg-white rounded-squircle-lg p-6 shadow-2xl border border-slate-100">
        <h3 class="text-base font-bold text-slate-800 mb-4 flex items-center space-x-2">
          <span>{{ dialogTitle }}</span>
        </h3>

        <form @submit.prevent="handleSubmit" class="space-y-4">
          <!-- 若为房间，必须明确选择挂靠的所属房屋 -->
          <div v-if="type === 'room'">
            <label class="block text-sm font-bold text-slate-700 mb-1.5">所属挂靠房屋 *</label>
            <select
              v-model="selectedHouseId"
              required
              class="w-full px-3.5 py-2.5 text-sm rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-orange-400 bg-slate-50 font-medium"
            >
              <option v-for="h in spaceStore.houses" :key="h.id" :value="h.id">
                {{ h.icon }} {{ h.name }}
              </option>
            </select>
            <p class="text-xs text-slate-400 mt-1">每个功能房间都必须归属于指定的房屋空间之下</p>
          </div>

          <!-- 精准专属 Emoji 图标选择 (房屋与房间严格物理分离) -->
          <div>
            <div class="flex items-center justify-between mb-2">
              <label class="text-sm font-bold text-slate-700">
                {{ type === 'house' ? '选择房屋建筑图标' : '选择房间功能图标' }}
              </label>
              <span class="text-xs text-orange-600 font-bold">
                {{ currentPresetLabel }}
              </span>
            </div>

            <div class="grid grid-cols-5 gap-2 p-2.5 bg-slate-50 rounded-2xl border border-slate-100">
              <button
                type="button"
                v-for="item in activeEmojiList"
                :key="item.icon"
                @click="selectedIcon = item.icon"
                :title="item.label"
                class="w-10 h-10 rounded-xl text-xl flex items-center justify-center transition-all relative group"
                :class="
                  selectedIcon === item.icon
                    ? 'shadow-md scale-105'
                    : 'hover:bg-white hover:shadow-sm text-slate-700'
                "
                :style="
                  selectedIcon === item.icon
                    ? { backgroundColor: 'var(--theme-primary)', color: '#ffffff' }
                    : {}
                "
              >
                <span>{{ item.icon }}</span>
              </button>
            </div>
          </div>

          <!-- 空间名称 -->
          <div>
            <label class="block text-sm font-bold text-slate-700 mb-1.5">
              {{ type === 'house' ? '房屋名称 *' : '房间名称 *' }}
            </label>
            <input
              v-model="name"
              type="text"
              required
              :placeholder="type === 'house' ? '例如：老家自建房 / 湖畔度假屋' : '例如：儿童玩具角 / 主卧衣帽间'"
              class="w-full px-3.5 py-2.5 text-sm rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-orange-400"
            />
          </div>

          <div class="flex justify-end space-x-2.5 pt-3">
            <button
              type="button"
              @click="emit('close')"
              class="px-4 py-2 text-sm font-semibold text-slate-600 bg-slate-100 hover:bg-slate-200 rounded-xl transition-colors"
            >
              取消
            </button>
            <button
              type="submit"
              class="btn-theme-primary px-5 py-2 text-sm font-bold rounded-xl shadow-sm transition-all hover:scale-105"
            >
              {{ isEditMode ? "保存修改" : "立即创建" }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </Transition>
</template>

<script setup lang="ts">
import { ref, computed, watch } from "vue";
import spaceEmojis from "@shared/space_emojis.json";
import type { House, Room } from "@/types";
import { createHouseApi, createRoomApi, updateHouseApi, updateRoomApi } from "@/api";
import { useSpaceStore } from "@/stores/space";
import { useToastStore } from "@/stores/toast";

const props = withDefaults(
  defineProps<{
    isOpen: boolean;
    type: "house" | "room";
    mode?: "create" | "edit";
    houseId?: number | null;
    target?: House | Room | null;
  }>(),
  {
    mode: "create",
  }
);

const emit = defineEmits(["close", "created", "saved"]);
const spaceStore = useSpaceStore();
const toastStore = useToastStore();

const isEditMode = computed(() => props.mode === "edit");

const dialogTitle = computed(() => {
  if (isEditMode.value) {
    return props.type === "house" ? "🏠 修改房屋名称与图标" : "🛋️ 修改功能房间与图标";
  }
  return props.type === "house" ? "🏠 添加新房屋" : "🛋️ 添加功能房间";
});

// 1. 房屋与房间专属图标：源自 shared/space_emojis.json 单一数据源
const houseEmojiList = spaceEmojis.houses;
const roomEmojiList = spaceEmojis.rooms;

const activeEmojiList = computed(() =>
  props.type === "house" ? houseEmojiList : roomEmojiList
);

const selectedIcon = ref("🏠");
const selectedHouseId = ref<number | null>(null);
const name = ref("");

const currentPresetLabel = computed(() => {
  const match = activeEmojiList.value.find((e) => e.icon === selectedIcon.value);
  return match ? match.label : "";
});

function cleanName(n?: string, icon?: string): string {
  if (!n) return "";
  let res = n.trim();
  if (icon && res.startsWith(icon)) {
    res = res.slice(icon.length).trim();
  }
  return res || n;
}

watch(
  () => props.isOpen,
  (open) => {
    if (open) {
      if (isEditMode.value && props.target) {
        selectedIcon.value = props.target.icon || (props.type === "house" ? "🏠" : "🛋️");
        name.value = cleanName(props.target.name, props.target.icon);
        if (props.type === "room") {
          selectedHouseId.value = (props.target as Room).house_id;
        }
      } else {
        selectedIcon.value = props.type === "house" ? "🏠" : "🛋️";
        name.value = "";
        if (props.type === "room") {
          selectedHouseId.value =
            props.houseId || spaceStore.activeHouseId || spaceStore.houses[0]?.id || null;
        }
      }
    }
  }
);

async function handleSubmit() {
  const cleanStr = name.value.trim();
  if (!cleanStr) return;

  try {
    if (isEditMode.value && props.target) {
      if (props.type === "house") {
        await updateHouseApi(props.target.id, { name: cleanStr, icon: selectedIcon.value });
        toastStore.success("房屋信息已更新", `修改为 ${selectedIcon.value} ${cleanStr}`);
      } else {
        await updateRoomApi(props.target.id, {
          house_id: selectedHouseId.value || undefined,
          name: cleanStr,
          icon: selectedIcon.value,
        });
        toastStore.success("房间信息已更新", `修改为 ${selectedIcon.value} ${cleanStr}`);
      }
      emit("saved");
    } else {
      if (props.type === "house") {
        await createHouseApi({ name: cleanStr, icon: selectedIcon.value });
        toastStore.success("房屋创建成功", `已添加 ${selectedIcon.value} ${cleanStr}`);
      } else {
        if (!selectedHouseId.value) {
          toastStore.error("必须选择挂靠的所属房屋");
          return;
        }
        await createRoomApi({
          house_id: selectedHouseId.value,
          name: cleanStr,
          icon: selectedIcon.value,
        });
        toastStore.success("功能房间创建成功", `已在房屋下添加 ${selectedIcon.value} ${cleanStr}`);
      }
      emit("created");
    }
    emit("close");
  } catch (err: any) {
    toastStore.error(isEditMode.value ? "修改失败" : "创建失败", err.message);
  }
}
</script>
