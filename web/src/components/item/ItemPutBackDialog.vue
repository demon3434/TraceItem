<template>
  <div
    v-if="isOpen && item"
    class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-sm overflow-y-auto"
    @click.self="emit('close')"
  >
    <div class="w-full max-w-lg bg-white rounded-squircle-lg p-6 shadow-2xl border border-slate-100 my-8">
      <div class="flex items-center justify-between pb-4 border-b border-slate-100">
        <h2 class="text-lg font-bold text-slate-800 flex items-center space-x-2">
          <PackageCheck class="w-5 h-5 text-emerald-500" />
          <span>归还收纳</span>
        </h2>
        <button @click="emit('close')" class="text-slate-400 hover:text-slate-600 p-1 rounded-lg">
          <X class="w-5 h-5" />
        </button>
      </div>

      <div class="mt-4 space-y-4">
        <p class="text-sm text-slate-500">归还后将自动清理使用中的临时实拍附件。</p>

        <div class="grid grid-cols-2 gap-3">
          <button
            type="button"
            @click="restoreOriginal = true"
            class="py-2.5 rounded-xl text-sm font-bold border-2 transition-all"
            :class="restoreOriginal ? 'border-orange-500 bg-orange-50 text-orange-600' : 'border-slate-200 text-slate-600'"
          >
            原位放回
          </button>
          <button
            type="button"
            @click="restoreOriginal = false"
            class="py-2.5 rounded-xl text-sm font-bold border-2 transition-all"
            :class="!restoreOriginal ? 'border-orange-500 bg-orange-50 text-orange-600' : 'border-slate-200 text-slate-600'"
          >
            更换位置 / 替换照片
          </button>
        </div>

        <div v-if="restoreOriginal" class="bg-slate-50 rounded-2xl p-4 text-sm text-slate-700">
          将恢复至：<span class="font-bold">{{ item.storage_path_display || item.path_display || "原位置" }}</span>
          <span v-if="item.storage_location_detail"> · {{ item.storage_location_detail }}</span>
        </div>

        <div v-else class="space-y-3">
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="block text-sm font-bold text-slate-700 mb-1.5">新收纳房屋 *</label>
              <select v-model="houseId" class="w-full px-3.5 py-2.5 text-sm rounded-xl border border-slate-200 bg-slate-50">
                <option v-for="h in activeHouses" :key="h.id" :value="h.id">{{ h.icon }} {{ h.name }}</option>
              </select>
            </div>
            <div>
              <label class="block text-sm font-bold text-slate-700 mb-1.5">新收纳房间 *</label>
              <select v-model="roomId" class="w-full px-3.5 py-2.5 text-sm rounded-xl border border-slate-200 bg-slate-50">
                <option v-for="r in roomsForHouse" :key="r.id" :value="r.id">{{ r.icon }} {{ r.name }}</option>
              </select>
            </div>
          </div>
          <div>
            <label class="block text-sm font-bold text-slate-700 mb-1.5">新收纳位置备注</label>
            <input
              v-model="locationDetail"
              type="text"
              placeholder="例如：换到白色收纳箱"
              class="w-full px-3.5 py-2.5 text-sm rounded-xl border border-slate-200"
            />
          </div>
          <div>
            <label class="block text-sm font-bold text-slate-700 mb-1.5">收纳照片 (可删减旧图或追加新图)</label>
            <div class="flex flex-wrap items-center gap-2">
              <label class="cursor-pointer px-3 py-2 border-2 border-dashed border-orange-200 rounded-xl text-sm font-semibold text-orange-600 flex items-center space-x-1.5">
                <Camera class="w-4 h-4" />
                <span>{{ uploading ? "上传中..." : "+ 新拍" }}</span>
                <input type="file" accept="image/jpeg,image/png,image/webp" class="hidden" :disabled="uploading" @change="handleImageUpload" />
              </label>
              <div
                v-for="(att, idx) in storageAttachments"
                :key="att.file_path"
                class="relative w-14 h-14 rounded-xl overflow-hidden border border-slate-200"
              >
                <img :src="resolveAttachmentThumb(att)" class="w-full h-full object-cover" />
                <button
                  type="button"
                  @click="storageAttachments.splice(idx, 1)"
                  class="absolute top-0.5 right-0.5 bg-rose-500 text-white rounded-full p-0.5"
                >
                  <X class="w-3 h-3" />
                </button>
              </div>
            </div>
          </div>
        </div>

        <div class="flex justify-end space-x-3 pt-2">
          <button
            type="button"
            @click="emit('close')"
            class="px-4 py-2 text-sm font-medium text-slate-600 bg-slate-100 hover:bg-slate-200 rounded-xl"
          >
            取消
          </button>
          <button
            type="button"
            :disabled="submitting || uploading"
            @click="handleSubmit"
            class="px-5 py-2 text-sm font-bold text-white rounded-xl bg-emerald-500 hover:bg-emerald-600 disabled:opacity-50"
          >
            {{ submitting ? "处理中..." : "确认归还" }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from "vue";
import { Camera, PackageCheck, X } from "lucide-vue-next";
import type { Item } from "@/types";
import { putBackItemApi, uploadImageApi } from "@/api";
import { useSpaceStore } from "@/stores/space";
import { useToastStore } from "@/stores/toast";
import { compressImage } from "@/utils/imageCompressor";
import { resolveAttachmentThumb } from "@/utils/mediaUrl";

const props = defineProps<{ isOpen: boolean; item: Item | null }>();
const emit = defineEmits<{ (e: "close"): void; (e: "saved", item: Item): void }>();

const spaceStore = useSpaceStore();
const toastStore = useToastStore();

const restoreOriginal = ref(true);
const houseId = ref<number>(0);
const roomId = ref<number>(0);
const locationDetail = ref("");
const storageAttachments = ref<any[]>([]);
const initialPaths = ref<Set<string>>(new Set());
const uploading = ref(false);
const submitting = ref(false);

const activeHouses = computed(() => spaceStore.houses.filter((h) => h.is_active !== false));
const roomsForHouse = computed(() =>
  spaceStore.rooms.filter((r) => r.house_id === houseId.value && spaceStore.isRoomEffectivelyActive(r)),
);

watch(
  () => props.isOpen,
  (open) => {
    if (open && props.item) {
      restoreOriginal.value = true;
      houseId.value = props.item.storage_house_id || props.item.house_id;
      roomId.value = props.item.storage_room_id || props.item.room_id;
      locationDetail.value = props.item.storage_location_detail || "";
      const list = (props.item.storage_attachments || []).map((a) => ({ ...a }));
      storageAttachments.value = list;
      initialPaths.value = new Set(list.map((a) => a.file_path));
    }
  },
);

async function handleImageUpload(e: Event) {
  const input = e.target as HTMLInputElement;
  const file = input.files?.[0];
  if (!file) return;
  uploading.value = true;
  try {
    const compressed = await compressImage(file, { maxDimension: 1600, quality: 0.82 });
    const res = await uploadImageApi(compressed);
    storageAttachments.value.push({
      ...res,
      media_type: "image",
      scene: "storage",
    });
  } catch (err: any) {
    toastStore.error("图片上传失败", err.message);
  } finally {
    uploading.value = false;
    input.value = "";
  }
}

async function handleSubmit() {
  if (!props.item) return;
  submitting.value = true;
  try {
    const currentSet = new Set(storageAttachments.value.map((a) => a.file_path));
    const removed = Array.from(initialPaths.value).filter((p) => !currentSet.has(p));
    const added = storageAttachments.value.filter((a) => !initialPaths.value.has(a.file_path));
    const updated = await putBackItemApi(props.item.id, {
      restore_original: restoreOriginal.value,
      ...(restoreOriginal.value
        ? {}
        : {
            house_id: houseId.value,
            room_id: roomId.value,
            location_detail: locationDetail.value.trim(),
            added_storage_attachments: added,
            removed_attachment_paths: removed,
          }),
      expected_version: props.item.version,
    });
    toastStore.success("物品已归还收纳");
    emit("saved", updated);
    emit("close");
  } catch (err: any) {
    toastStore.error("归还失败", err.message);
  } finally {
    submitting.value = false;
  }
}
</script>
