<template>
  <div
    v-if="isOpen && item"
    class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-sm overflow-y-auto"
    @click.self="emit('close')"
  >
    <div class="w-full max-w-lg bg-white rounded-squircle-lg p-6 shadow-2xl border border-slate-100 my-8">
      <div class="flex items-center justify-between pb-4 border-b border-slate-100">
        <h2 class="text-lg font-bold text-slate-800 flex items-center space-x-2">
          <PackageOpen class="w-5 h-5 text-amber-500" />
          <span>取出使用登记</span>
        </h2>
        <button @click="emit('close')" class="text-slate-400 hover:text-slate-600 p-1 rounded-lg">
          <X class="w-5 h-5" />
        </button>
      </div>

      <form @submit.prevent="handleSubmit" class="mt-4 space-y-4">
        <!-- 只读基础属性展示 -->
        <div class="bg-slate-50 rounded-2xl p-3.5 text-sm space-y-1">
          <div class="font-bold text-slate-800 flex items-center justify-between">
            <span>{{ item.category?.icon || "📦" }} {{ item.name }}</span>
            <span class="px-2.5 py-0.5 rounded-full bg-white text-slate-700 text-xs font-bold">x{{ item.quantity }}</span>
          </div>
          <div v-if="item.brand" class="text-slate-500">品牌规格：{{ item.brand }}</div>
          <div class="text-slate-500">
            原收纳位置：{{ item.path_display || "未分配" }}{{ item.location_detail ? ` · ${item.location_detail}` : "" }}
          </div>
        </div>

        <!-- 允许修改当前使用房屋与房间 -->
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="block text-sm font-bold text-slate-700 mb-1.5">当前房屋 *</label>
            <select
              v-model="houseId"
              required
              class="w-full px-3.5 py-2.5 text-sm rounded-xl border border-slate-200 bg-slate-50 font-medium"
            >
              <option v-for="h in activeHouses" :key="h.id" :value="h.id">
                {{ h.icon }} {{ h.name }}
              </option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-bold text-slate-700 mb-1.5">当前房间 *</label>
            <select
              v-model="roomId"
              required
              class="w-full px-3.5 py-2.5 text-sm rounded-xl border border-slate-200 bg-slate-50 font-medium"
            >
              <option v-for="r in roomsForHouse" :key="r.id" :value="r.id">
                {{ r.icon }} {{ r.name }}
              </option>
            </select>
          </div>
        </div>

        <div>
          <label class="block text-sm font-bold text-slate-700 mb-1.5">当前摆放位置备注</label>
          <input
            v-model="locationDetail"
            type="text"
            placeholder="例如：客厅沙发旁、卧室门口"
            class="w-full px-3.5 py-2.5 text-sm rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-orange-400"
          />
        </div>

        <!-- 强制至少上传 1 张照片 -->
        <div>
          <div class="flex items-center justify-between mb-1.5">
            <label class="block text-sm font-bold text-slate-700">当前实拍照片 * (至少 1 张)</label>
            <span class="text-xs text-slate-400">已上传 {{ attachments.length }} 个</span>
          </div>
          <div class="flex flex-wrap items-center gap-3">
            <label
              class="cursor-pointer px-4 py-2.5 border-2 border-dashed border-orange-200 hover:border-orange-400 bg-orange-50/50 rounded-xl text-sm font-semibold text-orange-600 flex items-center space-x-2"
            >
              <Camera class="w-4 h-4" />
              <span>{{ uploading ? "压缩上传中..." : "+ 添加当前实拍照片" }}</span>
              <input
                type="file"
                accept="image/jpeg,image/png,image/webp"
                class="hidden"
                :disabled="uploading"
                @change="handleImageUpload"
              />
            </label>
            <div
              v-for="(att, idx) in attachments"
              :key="idx"
              class="relative w-16 h-16 rounded-xl overflow-hidden border border-slate-200"
            >
              <img :src="resolveAttachmentThumb(att)" class="w-full h-full object-cover" />
              <button
                type="button"
                @click="attachments.splice(idx, 1)"
                class="absolute top-0.5 right-0.5 bg-rose-500 text-white rounded-full p-0.5"
              >
                <X class="w-3 h-3" />
              </button>
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
            type="submit"
            :disabled="submitting || uploading"
            class="px-5 py-2 text-sm font-bold text-white rounded-xl bg-orange-500 hover:bg-orange-600 disabled:opacity-50"
          >
            {{ submitting ? "提交中..." : "确认取出" }}
          </button>
        </div>
      </form>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch } from "vue";
import { Camera, PackageOpen, X } from "lucide-vue-next";
import type { Item } from "@/types";
import { takeOutItemApi, uploadImageApi } from "@/api";
import { useSpaceStore } from "@/stores/space";
import { useToastStore } from "@/stores/toast";
import { compressImage } from "@/utils/imageCompressor";
import { resolveAttachmentThumb } from "@/utils/mediaUrl";

const props = defineProps<{ isOpen: boolean; item: Item | null }>();
const emit = defineEmits<{ (e: "close"): void; (e: "saved", item: Item): void }>();

const spaceStore = useSpaceStore();
const toastStore = useToastStore();

const houseId = ref<number>(0);
const roomId = ref<number>(0);
const locationDetail = ref("");
const attachments = ref<any[]>([]);
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
      houseId.value = props.item.house_id;
      roomId.value = props.item.room_id;
      locationDetail.value = "";
      attachments.value = [];
    }
  },
);

watch(houseId, () => {
  if (!roomsForHouse.value.some((r) => r.id === roomId.value)) {
    roomId.value = roomsForHouse.value[0]?.id || 0;
  }
});

async function handleImageUpload(e: Event) {
  const input = e.target as HTMLInputElement;
  const file = input.files?.[0];
  if (!file) return;
  uploading.value = true;
  try {
    const compressed = await compressImage(file, { maxDimension: 1600, quality: 0.82 });
    const res = await uploadImageApi(compressed);
    attachments.value.push({
      ...res,
      media_type: "image",
      scene: "in_use",
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
  if (!attachments.value.some((a) => a.media_type === "image")) {
    toastStore.error("请至少上传 1 张当前实拍照片");
    return;
  }
  submitting.value = true;
  try {
    const updated = await takeOutItemApi(props.item.id, {
      house_id: houseId.value,
      room_id: roomId.value,
      location_detail: locationDetail.value.trim(),
      attachments: attachments.value,
      expected_version: props.item.version,
    });
    toastStore.success("已标记为取出使用");
    emit("saved", updated);
    emit("close");
  } catch (err: any) {
    toastStore.error("取出登记失败", err.message);
  } finally {
    submitting.value = false;
  }
}
</script>
