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
      class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-md overflow-y-auto"
      @click.self="emit('close')"
    >
      <div
        class="w-full max-w-2xl bg-white rounded-squircle-lg p-6 shadow-2xl border border-slate-100 my-8 overflow-hidden"
      >
        <!-- 弹窗顶栏 -->
        <div class="flex items-center justify-between pb-3 border-b border-slate-100">
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
                {{ item.brand || "无品牌" }} · 数量: {{ item.quantity }}
              </p>
            </div>
          </div>
          <button @click="emit('close')" class="text-slate-400 hover:text-slate-600 p-1.5 rounded-xl hover:bg-slate-50">
            <X class="w-5 h-5" />
          </button>
        </div>

        <!-- 媒体展示区 (优先照片/视频) -->
        <div class="mt-4 space-y-4">
          <!-- 图片主展示 (支持鼠标滚轮与拖拽放大) 与多图选择 -->
          <div v-if="currentImage" class="space-y-2">
            <InteractiveImageViewer
              :src="resolveUrl(currentImage)"
              :alt="item.name"
            />

            <!-- 多图缩略图切换栏 -->
            <div v-if="imageAttachments.length > 1" class="flex items-center space-x-2 overflow-x-auto py-1">
              <button
                v-for="(img, idx) in imageAttachments"
                :key="idx"
                @click="selectedImgIdx = idx"
                class="w-14 h-14 rounded-xl overflow-hidden border-2 transition-all flex-shrink-0"
                :class="selectedImgIdx === idx ? 'border-orange-500 shadow-md scale-105' : 'border-transparent opacity-70 hover:opacity-100'"
              >
                <img :src="resolveThumb(img)" class="w-full h-full object-cover" />
              </button>
            </div>
          </div>

          <!-- 视频播放 (若有，20px圆角沉浸播放器) -->
          <div v-if="mainVideo" class="rounded-2xl overflow-hidden bg-slate-950 border border-slate-800 shadow-sm">
            <div class="px-3.5 py-2 bg-slate-900/90 flex items-center space-x-2 text-slate-300 text-xs font-bold border-b border-slate-800">
              <Video class="w-4 h-4 text-sky-400" />
              <span>现场寻路短视频 (MOOV 前置即开即播)</span>
            </div>
            <video
              controls
              class="w-full max-h-[320px] bg-black"
              :src="resolveUrl(mainVideo)"
              :poster="resolveThumb(mainVideo) || undefined"
            ></video>
          </div>

          <!-- 语音备忘录播放条 (多巴胺拟态控件) -->
          <DopamineAudioPlayer
            v-if="mainAudio"
            :src="resolveUrl(mainAudio)"
            title="语音指引与收纳备忘"
          />

          <!-- 位置与指引信息卡 (字号升级至 14px text-sm 舒适标准) -->
          <div class="bg-slate-50 p-4 rounded-2xl space-y-3 text-sm text-slate-700">
            <div class="flex items-center space-x-2.5">
              <MapPin class="w-4 h-4 text-orange-500 flex-shrink-0" />
              <span class="font-bold text-slate-800">所在位置:</span>
              <span class="font-medium">{{ item.path_display || "未分配空间" }}</span>
            </div>

            <div v-if="item.location_detail" class="flex items-start space-x-2.5">
              <Compass class="w-4 h-4 text-slate-400 flex-shrink-0 mt-0.5" />
              <span class="font-bold text-slate-800">细节备注:</span>
              <span class="text-slate-600">{{ item.location_detail }}</span>
            </div>

            <div v-if="item.description" class="flex items-start space-x-2.5">
              <FileText class="w-4 h-4 text-slate-400 flex-shrink-0 mt-0.5" />
              <span class="font-bold text-slate-800">说明备忘:</span>
              <span class="text-slate-600 leading-relaxed">{{ item.description }}</span>
            </div>
          </div>

          <!-- 标签展示 -->
          <div v-if="item.tags && item.tags.length > 0" class="flex flex-wrap gap-2 pt-1">
            <span
              v-for="t in item.tags"
              :key="t.id"
              class="px-3 py-1 rounded-xl bg-orange-50 border border-orange-100 text-sm font-semibold text-orange-700"
            >
              # {{ t.name }}
            </span>
          </div>
        </div>

        <div class="mt-6 flex justify-end">
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
</template>

<script setup lang="ts">
import { ref, computed, watch } from "vue";
import type { Item } from "@/types";
import { resolveAttachmentUrl, resolveAttachmentThumb } from "@/utils/mediaUrl";
import { X, MapPin, Compass, FileText, Video } from "lucide-vue-next";
import InteractiveImageViewer from "./InteractiveImageViewer.vue";
import DopamineAudioPlayer from "./DopamineAudioPlayer.vue";

const props = defineProps<{
  isOpen: boolean;
  item: Item | null;
}>();

const emit = defineEmits(["close"]);

const selectedImgIdx = ref(0);

watch(
  () => props.item,
  () => {
    selectedImgIdx.value = 0;
  }
);

const imageAttachments = computed(() =>
  props.item?.attachments?.filter((a) => a.media_type === "image" || (a as any).file_type === "image") || []
);

const currentImage = computed(() => {
  if (imageAttachments.value.length === 0) return null;
  return imageAttachments.value[selectedImgIdx.value] || imageAttachments.value[0];
});

const mainAudio = computed(() =>
  props.item?.attachments?.find((a) => a.media_type === "audio" || (a as any).file_type === "audio")
);

const mainVideo = computed(() =>
  props.item?.attachments?.find((a) => a.media_type === "video" || (a as any).file_type === "video")
);

function resolveUrl(att: any): string {
  return resolveAttachmentUrl(att);
}

function resolveThumb(att: any): string {
  return resolveAttachmentThumb(att);
}
</script>
