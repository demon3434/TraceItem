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
      v-if="isOpen && item"
      class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-md"
      @click.self="emit('close')"
    >
      <div
        class="w-full max-w-5xl h-[640px] max-h-[90vh] flex flex-col bg-white rounded-squircle-lg p-6 shadow-2xl border border-slate-100 overflow-hidden"
      >
        <!-- 弹窗顶栏 -->
        <div class="flex items-center justify-between pb-3 border-b border-slate-100 flex-shrink-0">
          <div class="flex items-center space-x-2.5">
            <span class="text-3xl">{{ item.category?.icon || "📦" }}</span>
            <div>
              <div class="flex items-center space-x-2">
                <h2 class="text-xl font-bold text-slate-800 leading-tight">{{ item.name }}</h2>
                <span
                  v-if="(item as any).owner_nickname || (item as any).owner_username"
                  class="px-2.5 py-0.5 rounded-full bg-amber-100 text-amber-800 text-xs font-bold border border-amber-200 shadow-2xs"
                >
                  👑 归属: {{ (item as any).owner_nickname || (item as any).owner_username }}
                </span>
              </div>
              <p class="text-sm text-slate-500 mt-0.5">
                {{ item.brand || "无品牌" }} · {{ item.category?.name || "未分类" }} · 数量: {{ item.quantity }}
              </p>
            </div>
          </div>
          <button @click="emit('close')" class="text-slate-400 hover:text-slate-600 p-1.5 rounded-xl hover:bg-slate-50">
            <X class="w-5 h-5" />
          </button>
        </div>

        <!-- 左右分栏主体 -->
        <div class="mt-4 grid grid-cols-1 md:grid-cols-12 gap-6 flex-1 min-h-0 overflow-hidden">
          <!-- 左栏：文本字段信息 (独立滚动，不受右栏切换影响) -->
          <div class="md:col-span-5 overflow-y-auto pr-1 space-y-4">
            <div class="bg-slate-50 p-4 rounded-2xl space-y-3 text-sm text-slate-700">
              <div class="flex items-center space-x-2.5">
                <PackageOpen
                  v-if="item.status === 'in_use'"
                  class="w-4 h-4 text-amber-500 flex-shrink-0"
                />
                <PackageCheck
                  v-else
                  class="w-4 h-4 text-emerald-500 flex-shrink-0"
                />
                <span class="font-bold text-slate-800">当前状态:</span>
                <span
                  class="px-2.5 py-0.5 rounded-full text-xs font-bold"
                  :class="
                    item.status === 'in_use'
                      ? 'bg-amber-100 text-amber-800'
                      : 'bg-emerald-100 text-emerald-800'
                  "
                >
                  {{ item.status === "in_use" ? "已取出使用" : "已收纳" }}
                </span>
              </div>

              <div class="flex items-center space-x-2.5">
                <MapPin class="w-4 h-4 text-orange-500 flex-shrink-0" />
                <span class="font-bold text-slate-800">{{ item.status === "in_use" ? "当前位置:" : "所在位置:" }}</span>
                <span class="font-medium">{{ item.path_display || "未分配空间" }}</span>
              </div>

              <div v-if="item.status === 'in_use' && item.storage_path_display" class="flex items-center space-x-2.5">
                <MapPin class="w-4 h-4 text-slate-400 flex-shrink-0" />
                <span class="font-bold text-slate-800">原收纳位置:</span>
                <span class="text-slate-600">
                  {{ item.storage_path_display }}{{ item.storage_location_detail ? ` · ${item.storage_location_detail}` : "" }}
                </span>
              </div>

              <div class="flex items-start space-x-2.5">
                <Compass class="w-4 h-4 text-slate-400 flex-shrink-0 mt-0.5" />
                <span class="font-bold text-slate-800">细节备注:</span>
                <span :class="item.location_detail ? 'text-slate-600' : 'text-slate-400'">
                  {{ item.location_detail || "未填写" }}
                </span>
              </div>

              <div class="flex items-start space-x-2.5">
                <FileText class="w-4 h-4 text-slate-400 flex-shrink-0 mt-0.5" />
                <span class="font-bold text-slate-800">说明备忘:</span>
                <span class="leading-relaxed" :class="item.description ? 'text-slate-600' : 'text-slate-400'">
                  {{ item.description || "未填写" }}
                </span>
              </div>
            </div>

            <!-- 标签展示 -->
            <div v-if="item.tags && item.tags.length > 0" class="flex flex-wrap gap-2">
              <span
                v-for="t in item.tags"
                :key="t.id"
                class="px-3 py-1 rounded-xl bg-orange-50 border border-orange-100 text-sm font-semibold text-orange-700"
              >
                # {{ t.name }}
              </span>
            </div>
          </div>

          <!-- 右栏：顶部标签页切换 (无垂直滚动条) -->
          <div class="md:col-span-7 flex flex-col min-h-0">
            <!-- 标签页头：图片(x/9) | 视频(x/3) | 音频(x/3) -->
            <div class="flex items-center space-x-2 bg-slate-100 p-1.5 rounded-2xl flex-shrink-0 mb-3">
              <button
                type="button"
                @click="activeTab = 'image'"
                class="flex-1 py-2 px-3 rounded-xl text-sm font-bold transition-all flex items-center justify-center space-x-1.5"
                :class="
                  activeTab === 'image'
                    ? 'bg-white text-slate-800 shadow-sm'
                    : 'text-slate-500 hover:text-slate-700'
                "
              >
                <ImageIcon class="w-4 h-4 text-orange-500" />
                <span>图片({{ imageAttachments.length }}/{{ mediaLimits.maxImageAttachments }})</span>
              </button>
              <button
                type="button"
                @click="activeTab = 'video'"
                class="flex-1 py-2 px-3 rounded-xl text-sm font-bold transition-all flex items-center justify-center space-x-1.5"
                :class="
                  activeTab === 'video'
                    ? 'bg-white text-slate-800 shadow-sm'
                    : 'text-slate-500 hover:text-slate-700'
                "
              >
                <Video class="w-4 h-4 text-sky-500" />
                <span>视频({{ videoAttachments.length }}/{{ mediaLimits.maxVideoAttachments }})</span>
              </button>
              <button
                type="button"
                @click="activeTab = 'audio'"
                class="flex-1 py-2 px-3 rounded-xl text-sm font-bold transition-all flex items-center justify-center space-x-1.5"
                :class="
                  activeTab === 'audio'
                    ? 'bg-white text-slate-800 shadow-sm'
                    : 'text-slate-500 hover:text-slate-700'
                "
              >
                <Mic class="w-4 h-4 text-amber-500" />
                <span>音频({{ audioAttachments.length }}/{{ mediaLimits.maxAudioAttachments }})</span>
              </button>
            </div>

            <!-- 图片标签页：点击图片全屏放大弹出 -->
            <div v-if="activeTab === 'image'" class="space-y-2.5">
              <div
                v-if="currentImage"
                @click="showFullscreenImage = true"
                class="group relative w-full h-[340px] rounded-2xl overflow-hidden bg-slate-950 flex items-center justify-center cursor-zoom-in border border-slate-200"
              >
                <img
                  :src="resolveUrl(currentImage)"
                  :alt="item.name"
                  class="max-w-full max-h-full object-contain transition-transform duration-300 group-hover:scale-[1.02]"
                />
                <div
                  class="absolute bottom-3 right-3 px-3 py-1.5 rounded-full bg-slate-900/75 backdrop-blur-sm text-white text-xs font-bold flex items-center space-x-1.5 opacity-85 group-hover:opacity-100 transition-opacity"
                >
                  <Maximize2 class="w-3.5 h-3.5" />
                  <span>点击全屏放大</span>
                </div>
              </div>
              <div
                v-else
                class="h-[340px] rounded-2xl bg-slate-50 border border-dashed border-slate-200 flex items-center justify-center text-sm text-slate-400"
              >
                暂无图片附件
              </div>
              <div v-if="imageAttachments.length > 1" class="flex items-center space-x-2 overflow-x-auto py-1">
                <button
                  v-for="(img, idx) in imageAttachments"
                  :key="img.id || idx"
                  type="button"
                  @click="selectedImgIdx = idx"
                  class="w-14 h-14 rounded-xl overflow-hidden border-2 transition-all flex-shrink-0"
                  :class="selectedImgIdx === idx ? 'border-orange-500 shadow-md scale-105' : 'border-transparent opacity-70 hover:opacity-100'"
                >
                  <img :src="resolveThumb(img)" class="w-full h-full object-cover" />
                </button>
              </div>
            </div>

            <!-- 视频标签页 -->
            <div v-else-if="activeTab === 'video'" class="space-y-2.5">
              <div
                v-if="currentVideo"
                class="rounded-2xl overflow-hidden bg-slate-950 border border-slate-800 shadow-sm"
              >
                <video
                  :key="currentVideo.file_path"
                  controls
                  class="w-full h-[340px] bg-black"
                  :src="resolveUrl(currentVideo)"
                  :poster="resolveThumb(currentVideo) || undefined"
                ></video>
              </div>
              <div
                v-else
                class="h-[340px] rounded-2xl bg-slate-50 border border-dashed border-slate-200 flex items-center justify-center text-sm text-slate-400"
              >
                暂无视频附件
              </div>
              <div v-if="videoAttachments.length > 1" class="flex items-center space-x-2 overflow-x-auto py-1">
                <button
                  v-for="(vid, vIdx) in videoAttachments"
                  :key="vid.id || vIdx"
                  type="button"
                  @click="selectedVideoIdx = vIdx"
                  class="relative w-20 h-14 rounded-xl overflow-hidden border-2 transition-all flex-shrink-0 bg-slate-900 flex items-center justify-center"
                  :class="selectedVideoIdx === vIdx ? 'border-sky-500 shadow-md scale-105' : 'border-transparent opacity-75 hover:opacity-100'"
                >
                  <img v-if="resolveThumb(vid)" :src="resolveThumb(vid)" class="w-full h-full object-cover" />
                  <span class="absolute bottom-1 right-1 px-1.5 py-0.5 rounded bg-slate-900/80 text-white text-xs font-bold">
                    #{{ vIdx + 1 }}
                  </span>
                </button>
              </div>
            </div>

            <!-- 音频标签页 -->
            <div v-else class="space-y-3">
              <div v-if="currentAudio" class="space-y-3">
                <DopamineAudioPlayer
                  :key="currentAudio.file_path"
                  :src="resolveUrl(currentAudio)"
                  :title="`语音指引与收纳备忘${audioAttachments.length > 1 ? ` #${selectedAudioIdx + 1}` : ''}`"
                />
                <div v-if="audioAttachments.length > 1" class="flex items-center space-x-2 overflow-x-auto py-1">
                  <button
                    v-for="(aud, aIdx) in audioAttachments"
                    :key="aud.id || aIdx"
                    type="button"
                    @click="selectedAudioIdx = aIdx"
                    class="px-3.5 py-2 rounded-xl text-xs font-bold border-2 transition-all flex items-center space-x-1.5 flex-shrink-0"
                    :class="
                      selectedAudioIdx === aIdx
                        ? 'border-amber-500 bg-amber-50 text-amber-800 shadow-sm'
                        : 'border-slate-200 bg-slate-50 text-slate-600 hover:border-amber-300'
                    "
                  >
                    <Mic class="w-3.5 h-3.5" />
                    <span>语音 #{{ aIdx + 1 }}</span>
                  </button>
                </div>
              </div>
              <div
                v-else
                class="h-[340px] rounded-2xl bg-slate-50 border border-dashed border-slate-200 flex items-center justify-center text-sm text-slate-400"
              >
                暂无音频附件
              </div>
            </div>
          </div>
        </div>

        <div class="mt-4 pt-3 border-t border-slate-100 flex justify-end flex-shrink-0">
          <button
            type="button"
            @click="emit('close')"
            class="px-5 py-2.5 text-sm font-bold text-slate-600 bg-slate-100 hover:bg-slate-200 rounded-xl transition-colors"
          >
            关闭详情
          </button>
        </div>
      </div>
    </div>
  </Transition>

  <!-- 独立全屏图片放大弹出层 -->
  <div
    v-if="showFullscreenImage && currentImage"
    class="fixed inset-0 z-[60] bg-slate-950/92 backdrop-blur-md p-4 flex flex-col"
    @click.self="showFullscreenImage = false"
  >
    <div class="flex items-center justify-between text-white pb-3 px-2 flex-shrink-0">
      <span class="text-sm font-bold">
        {{ item?.name }} · 图片 {{ selectedImgIdx + 1 }} / {{ imageAttachments.length }}
      </span>
      <button
        type="button"
        @click="showFullscreenImage = false"
        class="p-2 rounded-full bg-white/10 hover:bg-white/20 text-white transition-colors"
      >
        <X class="w-5 h-5" />
      </button>
    </div>
    <div class="flex-1 min-h-0 flex items-center justify-center">
      <InteractiveImageViewer
        :src="resolveUrl(currentImage)"
        :alt="item?.name || '预览大图'"
        class="w-full h-full max-w-6xl"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch } from "vue";
import mediaLimits from "@shared/media_limits.json";
import type { Item } from "@/types";
import { resolveAttachmentUrl, resolveAttachmentThumb } from "@/utils/mediaUrl";
import {
  X,
  MapPin,
  Compass,
  FileText,
  Video,
  Mic,
  Image as ImageIcon,
  Maximize2,
  PackageOpen,
  PackageCheck,
} from "lucide-vue-next";
import InteractiveImageViewer from "./InteractiveImageViewer.vue";
import DopamineAudioPlayer from "./DopamineAudioPlayer.vue";

const props = defineProps<{
  isOpen: boolean;
  item: Item | null;
}>();

const emit = defineEmits(["close"]);

const activeTab = ref<"image" | "video" | "audio">("image");
const selectedImgIdx = ref(0);
const selectedVideoIdx = ref(0);
const selectedAudioIdx = ref(0);
const showFullscreenImage = ref(false);

const imageAttachments = computed(() =>
  props.item?.attachments?.filter((a) => a.media_type === "image" || (a as any).file_type === "image") || [],
);
const currentImage = computed(() => imageAttachments.value[selectedImgIdx.value] || imageAttachments.value[0] || null);

const videoAttachments = computed(() =>
  props.item?.attachments?.filter((a) => a.media_type === "video" || (a as any).file_type === "video") || [],
);
const currentVideo = computed(() => videoAttachments.value[selectedVideoIdx.value] || videoAttachments.value[0] || null);

const audioAttachments = computed(() =>
  props.item?.attachments?.filter((a) => a.media_type === "audio" || (a as any).file_type === "audio") || [],
);
const currentAudio = computed(() => audioAttachments.value[selectedAudioIdx.value] || audioAttachments.value[0] || null);

watch(
  () => props.item,
  () => {
    selectedImgIdx.value = 0;
    selectedVideoIdx.value = 0;
    selectedAudioIdx.value = 0;
    showFullscreenImage.value = false;
    if (imageAttachments.value.length > 0) activeTab.value = "image";
    else if (videoAttachments.value.length > 0) activeTab.value = "video";
    else if (audioAttachments.value.length > 0) activeTab.value = "audio";
    else activeTab.value = "image";
  },
);

function resolveUrl(att: any): string {
  return resolveAttachmentUrl(att);
}

function resolveThumb(att: any): string {
  return resolveAttachmentThumb(att);
}
</script>
