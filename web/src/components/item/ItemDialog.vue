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
      class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/40 backdrop-blur-sm overflow-y-auto"
      @click.self="emit('close')"
    >
      <div
        class="w-full max-w-xl bg-white rounded-squircle-lg p-6 shadow-2xl border border-slate-100 my-8 overflow-hidden"
      >
        <div class="flex items-center justify-between pb-4 border-b border-slate-100">
          <h2 class="text-lg font-bold text-slate-800 flex items-center space-x-2">
            <span>{{ isEditing ? "✏️ 修改物品信息" : "📦 登记收纳新物品" }}</span>
          </h2>
          <button @click="emit('close')" class="text-slate-400 hover:text-slate-600 p-1 rounded-lg">
            <X class="w-5 h-5" />
          </button>
        </div>

        <form @submit.prevent="handleSubmit" class="mt-4 space-y-4">
          <!-- 空间位置归属 (若空间锚定生效则显示锁闭提示) -->
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="block text-sm font-bold text-slate-700 mb-1.5">所属房屋 *</label>
              <select
                v-model="form.house_id"
                required
                class="w-full px-3.5 py-2.5 text-sm rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-orange-400 bg-slate-50 font-medium"
              >
                <option v-for="h in selectableHouses" :key="h.id" :value="h.id">
                  {{ h.icon }} {{ h.name }}{{ h.is_active === false ? " (已停用)" : "" }}
                </option>
              </select>
            </div>
            <div>
              <label class="block text-sm font-bold text-slate-700 mb-1.5">所在房间 *</label>
              <select
                v-model="form.room_id"
                required
                class="w-full px-3.5 py-2.5 text-sm rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-orange-400 bg-slate-50 font-medium"
              >
                <option v-for="r in filteredRooms" :key="r.id" :value="r.id">
                  {{ r.icon }} {{ cleanName(r.name, r.icon) }}{{ !spaceStore.isRoomEffectivelyActive(r) ? " (已停用)" : "" }}
                </option>
              </select>
            </div>
          </div>

          <!-- 物品核心信息 -->
          <div class="grid grid-cols-3 gap-3">
            <div class="col-span-2">
              <label class="block text-sm font-bold text-slate-700 mb-1.5">物品名称 *</label>
              <input
                v-model="form.name"
                type="text"
                required
                placeholder="例如：布洛芬缓释胶囊"
                class="w-full px-3.5 py-2.5 text-sm rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-orange-400"
              />
            </div>
            <div>
              <label class="block text-sm font-bold text-slate-700 mb-1.5">数量</label>
              <input
                v-model.number="form.quantity"
                type="number"
                min="0"
                class="w-full px-3.5 py-2.5 text-sm rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-orange-400"
              />
            </div>
          </div>

          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="block text-sm font-bold text-slate-700 mb-1.5">品牌 / 规格型号</label>
              <input
                v-model="form.brand"
                type="text"
                placeholder="例如：中美史克芬必得"
                class="w-full px-3.5 py-2.5 text-sm rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-orange-400"
              />
            </div>
            <div>
              <label class="block text-sm font-bold text-slate-700 mb-1.5">物品品类</label>
              <select
                v-model="form.category_id"
                class="w-full px-3.5 py-2.5 text-sm rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-orange-400 bg-slate-50 font-medium"
              >
                <option :value="null">📦 未分类</option>
                <option v-for="c in activeCategories" :key="c.id" :value="c.id">
                  {{ c.icon }} {{ c.name }}
                </option>
              </select>
            </div>
          </div>

          <!-- 具体摆放细节 (橱柜免配置原则) -->
          <div>
            <label class="block text-sm font-bold text-slate-700 mb-1.5">存放具体位置细节 (免建复杂橱柜表)</label>
            <input
              v-model="form.location_detail"
              type="text"
              placeholder="例如：电视柜左侧第2个抽屉深处"
              class="w-full px-3.5 py-2.5 text-sm rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-orange-400"
            />
          </div>

          <!-- 自由特征标签与智能前缀联想 -->
          <TagInputAutocomplete v-model="selectedTags" />

          <!-- 实景照片上传与多附件管理 -->
          <div>
            <div class="flex items-center justify-between mb-1.5">
              <label class="block text-sm font-bold text-slate-700">现场照片与多模态附件凭证</label>
              <span class="text-xs text-slate-400 font-medium">已添加 {{ attachmentsList.length }} 个附件</span>
            </div>
            <div class="flex flex-wrap items-center gap-3">
              <label
                class="cursor-pointer px-4 py-2.5 border-2 border-dashed border-orange-200 hover:border-orange-400 bg-orange-50/50 rounded-xl text-sm font-semibold text-orange-600 flex items-center space-x-2 transition-colors"
              >
                <Camera class="w-4 h-4" />
                <span>{{ uploadingImage ? "端侧压缩上传中..." : "+ 添加现场照片" }}</span>
                <input
                  type="file"
                  accept="image/jpeg,image/png,image/webp"
                  class="hidden"
                  :disabled="uploadingImage"
                  @change="handleImageUpload"
                />
              </label>

              <!-- 已上传/已有附件缩略图预览列表 -->
              <div v-if="attachmentsList.length > 0" class="flex flex-wrap gap-2">
                <div
                  v-for="(att, idx) in attachmentsList"
                  :key="idx"
                  class="relative w-12 h-12 rounded-xl overflow-hidden border border-slate-200 group bg-slate-100 flex items-center justify-center shadow-xs"
                >
                  <img
                    v-if="getAttachmentThumb(att)"
                    :src="getAttachmentThumb(att)"
                    class="w-full h-full object-cover"
                  />
                  <span v-else class="text-xs text-slate-500 font-bold">
                    {{ att.media_type === 'video' ? '🎬' : att.media_type === 'audio' ? '🎵' : '🖼️' }}
                  </span>
                  <button
                    type="button"
                    @click="removeAttachment(idx)"
                    class="absolute top-0.5 right-0.5 w-4 h-4 rounded-full bg-rose-500 text-white flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity shadow-sm"
                    title="移除该附件"
                  >
                    <X class="w-2.5 h-2.5" />
                  </button>
                </div>
              </div>
            </div>
          </div>

          <!-- 备忘说明 -->
          <div>
            <label class="block text-sm font-bold text-slate-700 mb-1.5">备忘与寻物指引</label>
            <textarea
              v-model="form.description"
              rows="2"
              placeholder="例如：保质期至2027年，全家应急发烧时取用"
              class="w-full px-3.5 py-2.5 text-sm rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-orange-400"
            ></textarea>
          </div>

          <!-- 底部操作按钮 -->
          <div class="flex items-center justify-end space-x-3 pt-4 border-t border-slate-100">
            <button
              type="button"
              @click="emit('close')"
              class="px-5 py-2.5 text-sm font-semibold text-slate-600 bg-slate-100 hover:bg-slate-200 rounded-xl transition-colors"
            >
              取消
            </button>
            <button
              type="submit"
              :disabled="submitting || uploadingImage"
              class="btn-theme-primary px-6 py-2.5 text-sm font-bold rounded-xl shadow-sm transition-all hover:scale-105 disabled:opacity-50"
            >
              {{ submitting ? "保存中..." : isEditing ? "确认修改" : "完成登记" }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </Transition>
</template>

<script setup lang="ts">
import { ref, computed, watch } from "vue";
import type { Item, Category } from "@/types";
import { useSpaceStore } from "@/stores/space";
import { useToastStore } from "@/stores/toast";
import { uploadImageApi, createItemApi, updateItemApi } from "@/api";
import { compressImage } from "@/utils/imageCompressor";
import { resolveAttachmentThumb } from "@/utils/mediaUrl";
import { X, Camera } from "lucide-vue-next";
import TagInputAutocomplete from "./TagInputAutocomplete.vue";

const props = defineProps<{
  isOpen: boolean;
  itemToEdit?: Item | null;
  categories: Category[];
}>();

const emit = defineEmits(["close", "saved"]);

const spaceStore = useSpaceStore();
const toastStore = useToastStore();

const isEditing = computed(() => !!props.itemToEdit);
const submitting = ref(false);
const uploadingImage = ref(false);
const selectedTags = ref<string[]>([]);
const attachmentsList = ref<any[]>([]);

const activeCategories = computed(() =>
  props.categories.filter((c) => c.is_active !== false || c.id === form.value.category_id)
);

const form = ref({
  house_id: spaceStore.activeHouseId || 0,
  room_id: spaceStore.activeRoomId || 0,
  category_id: null as number | null,
  name: "",
  brand: "",
  quantity: 1,
  location_detail: "",
  description: "",
});

const selectableHouses = computed(() => {
  return spaceStore.houses.filter(
    (h) => h.is_active !== false || (props.itemToEdit && h.id === props.itemToEdit.house_id)
  );
});

const filteredRooms = computed(() => {
  return spaceStore.rooms.filter(
    (r) =>
      r.house_id === form.value.house_id &&
      (spaceStore.isRoomEffectivelyActive(r) || (props.itemToEdit && r.id === props.itemToEdit.room_id))
  );
});

function cleanName(name?: string, icon?: string): string {
  if (!name) return "";
  let res = name.trim();
  if (icon && res.startsWith(icon)) {
    res = res.slice(icon.length).trim();
  }
  return res || name;
}

function getAttachmentThumb(att: any): string {
  return resolveAttachmentThumb(att);
}

function removeAttachment(idx: number) {
  attachmentsList.value.splice(idx, 1);
}

watch(
  () => props.isOpen,
  (open) => {
    if (open) {
      if (props.itemToEdit) {
        form.value = {
          house_id: props.itemToEdit.house_id,
          room_id: props.itemToEdit.room_id,
          category_id: props.itemToEdit.category_id || null,
          name: props.itemToEdit.name,
          brand: props.itemToEdit.brand || "",
          quantity: props.itemToEdit.quantity || 1,
          location_detail: props.itemToEdit.location_detail || "",
          description: props.itemToEdit.description || "",
        };
        tagsInput.value = props.itemToEdit.tags?.map((t) => t.name).join(" ") || "";
        selectedTags.value = props.itemToEdit.tags?.map((t) => t.name) || [];
        attachmentsList.value = props.itemToEdit.attachments ? [...props.itemToEdit.attachments] : [];
      } else {
        // 新增模式：若空间锚定处于锁定状态且锚定空间有效启用，则自动预填锚定空间
        const activeHouses = spaceStore.houses.filter((h) => h.is_active !== false);
        const anchorValid =
          spaceStore.isAnchorLocked &&
          spaceStore.anchorHouseId &&
          spaceStore.anchorRoomId &&
          activeHouses.some((h) => h.id === spaceStore.anchorHouseId) &&
          spaceStore.rooms.some(
            (r) => r.id === spaceStore.anchorRoomId && spaceStore.isRoomEffectivelyActive(r)
          );
        const activeHouseValid = activeHouses.some((h) => h.id === spaceStore.activeHouseId);
        const houseId = anchorValid
          ? (spaceStore.anchorHouseId as number)
          : activeHouseValid
            ? (spaceStore.activeHouseId as number)
            : (activeHouses[0]?.id ?? 0);
        const activeRoomsInHouse = spaceStore.rooms.filter(
          (r) => r.house_id === houseId && spaceStore.isRoomEffectivelyActive(r)
        );
        const activeRoomValid = activeRoomsInHouse.some((r) => r.id === spaceStore.activeRoomId);
        const roomId = anchorValid
          ? (spaceStore.anchorRoomId as number)
          : activeRoomValid
            ? (spaceStore.activeRoomId as number)
            : (activeRoomsInHouse[0]?.id ?? 0);

        form.value = {
          house_id: houseId,
          room_id: roomId,
          category_id: null,
          name: "",
          brand: "",
          quantity: 1,
          location_detail: "",
          description: "",
        };
        selectedTags.value = [];
        attachmentsList.value = [];
      }
    }
  }
);

async function handleImageUpload(e: Event) {
  const target = e.target as HTMLInputElement;
  if (!target.files || target.files.length === 0) return;
  const file = target.files[0];

  uploadingImage.value = true;
  try {
    // 客户端智能等比压缩：长边限制1600px，JPEG 82% 质量 (ADR 0003)
    const compressedFile = await compressImage(file, { maxDimension: 1600, quality: 0.82 });
    const res = await uploadImageApi(compressedFile);
    attachmentsList.value.push(res);
    toastStore.success("照片上传完成！", "已通过长边1600px等比Canvas压缩与工业年月分片");
  } catch (err: any) {
    toastStore.error("图片上传失败", err.message);
  } finally {
    uploadingImage.value = false;
    target.value = "";
  }
}

async function handleSubmit() {
  if (!form.value.name.trim()) {
    toastStore.warning("请输入物品名称");
    return;
  }
  if (!form.value.house_id || !form.value.room_id) {
    toastStore.warning("请选择所属房屋与房间");
    return;
  }

  const tags = selectedTags.value.length > 0
    ? selectedTags.value
    : tagsInput.value
        .split(/\s+/)
        .map((t) => t.trim().replace(/^#/, ""))
        .filter(Boolean);

  const attachments = attachmentsList.value.length > 0 ? attachmentsList.value : undefined;

  submitting.value = true;
  try {
    if (isEditing.value && props.itemToEdit) {
      await updateItemApi(props.itemToEdit.id, {
        ...form.value,
        tag_names: tags,
        attachments,
        ...(props.itemToEdit.version != null ? { expected_version: props.itemToEdit.version } : {}),
      });
      toastStore.success("物品修改成功");
    } else {
      await createItemApi({
        ...form.value,
        tag_names: tags,
        attachments,
      });
      toastStore.success("物品登记成功！");
    }
    emit("saved");
    emit("close");
  } catch (err: any) {
    if (err?.response?.status === 409) {
      toastStore.error("检测到跨端编辑冲突", "该物品已在其他设备上被修改，请关闭弹窗刷新列表后再编辑。");
    } else {
      toastStore.error("保存失败", err.message);
    }
  } finally {
    submitting.value = false;
  }
}
</script>

