<template>
  <div
    class="squircle-card group relative p-4 flex flex-col justify-between cursor-pointer border border-slate-100/60 overflow-hidden"
    @click="emit('preview', item)"
  >
    <!-- 卡片上部：实景照片缩略图与数量胶囊 -->
    <div class="relative w-full aspect-[4/3] rounded-2xl overflow-hidden bg-slate-100 mb-3.5 flex items-center justify-center">
      <img
        v-if="primaryThumbnail"
        :src="primaryThumbnail"
        :alt="item.name"
        class="w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
        loading="lazy"
      />
      <div v-else class="text-4xl select-none">
        {{ item.category?.icon || "📦" }}
      </div>

      <!-- 数量徽章 (悬停卡片时平滑展开 -1 / +1 快捷步进) -->
      <div
        class="absolute top-2.5 right-2.5 flex items-center rounded-full bg-white/90 backdrop-blur-md text-xs font-bold text-slate-800 shadow-sm transition-all"
        @click.stop
      >
        <button
          type="button"
          :disabled="item.quantity <= 0"
          @click="emit('step-quantity', { item, delta: -1 })"
          class="w-0 opacity-0 overflow-hidden group-hover:w-6 group-hover:opacity-100 h-6 flex items-center justify-center text-slate-500 hover:text-orange-600 disabled:opacity-30 transition-all"
          title="减少 1"
        >
          <Minus class="w-3.5 h-3.5" />
        </button>
        <span class="px-2.5 py-1 select-none">x{{ item.quantity }}</span>
        <button
          type="button"
          @click="emit('step-quantity', { item, delta: 1 })"
          class="w-0 opacity-0 overflow-hidden group-hover:w-6 group-hover:opacity-100 h-6 flex items-center justify-center text-slate-500 hover:text-orange-600 transition-all"
          title="增加 1"
        >
          <Plus class="w-3.5 h-3.5" />
        </button>
      </div>

      <!-- 极简无字「已取出」图标角标（仅 Lucide 图标 + 微光点） -->
      <div
        v-if="item.status === 'in_use'"
        class="absolute bottom-2.5 right-2.5 px-2 py-1 rounded-full bg-slate-900/75 backdrop-blur-sm text-white flex items-center space-x-1.5 shadow-sm"
        title="已取出使用"
      >
        <span class="w-1.5 h-1.5 rounded-full bg-amber-400"></span>
        <PackageOpen class="w-3.5 h-3.5" />
      </div>

      <!-- 多模态附件图标指示器 -->
      <div class="absolute bottom-2.5 left-2.5 flex items-center space-x-1.5">
        <span
          v-if="hasAudio"
          class="p-1.5 rounded-lg bg-amber-500/90 backdrop-blur-sm text-white text-xs font-bold flex items-center space-x-1"
          title="包含语音指引"
        >
          <Mic class="w-3.5 h-3.5" />
        </span>
        <span
          v-if="hasVideo"
          class="p-1.5 rounded-lg bg-sky-500/90 backdrop-blur-sm text-white text-xs font-bold flex items-center space-x-1"
          title="包含寻路短视频"
        >
          <Video class="w-3.5 h-3.5" />
        </span>
      </div>
    </div>

    <!-- 卡片中部：物品名称与品牌规格 (清晰大字号) -->
    <div>
      <div class="flex items-start justify-between">
        <h3 class="text-base font-bold text-slate-800 line-clamp-1 group-hover:text-orange-600 transition-colors leading-snug">
          {{ item.name }}
        </h3>
      </div>
      <p v-if="item.brand" class="text-sm text-slate-500 mt-0.5 line-clamp-1 font-medium">
        {{ item.brand }}
      </p>

      <!-- 空间存放细节与路径 (14px text-sm) -->
      <div class="flex items-center space-x-2 mt-3 text-sm text-slate-600 bg-slate-50 px-2.5 py-2 rounded-xl">
        <MapPin class="w-4 h-4 flex-shrink-0" :style="{ color: 'var(--theme-primary)' }" />
        <span class="truncate font-medium">
          {{ item.path_display || "未分配空间" }}
          <span v-if="item.location_detail" class="text-slate-500 font-normal"> · {{ item.location_detail }}</span>
        </span>
      </div>

      <!-- 标签气泡 (动态绑定当前主题浅色底与深色字) -->
      <div v-if="item.tags && item.tags.length > 0" class="flex flex-wrap gap-1.5 mt-3">
        <span
          v-for="t in item.tags.slice(0, 3)"
          :key="t.id"
          class="px-2.5 py-1 rounded-lg text-xs font-bold transition-colors"
          :style="{
            backgroundColor: 'var(--theme-primary-light)',
            color: 'var(--theme-primary-text)',
          }"
        >
          #{{ t.name }}
        </span>
        <span v-if="item.tags.length > 3" class="text-xs text-slate-400 font-semibold self-center">
          +{{ item.tags.length - 3 }}
        </span>
      </div>
    </div>

    <!-- 悬浮操作胶囊 -->
    <div
      class="absolute top-3 left-3 opacity-0 group-hover:opacity-100 transition-opacity flex items-center space-x-1.5 bg-white/95 backdrop-blur-sm rounded-xl p-1 shadow-md border border-slate-100"
      @click.stop
    >
      <button
        @click="emit('edit', item)"
        class="p-1.5 text-slate-600 hover:text-orange-600 hover:bg-orange-50 rounded-lg transition-colors"
        title="编辑物品"
      >
        <Edit3 class="w-4 h-4" />
      </button>
      <button
        @click="emit('lifecycle', item)"
        class="p-1.5 rounded-lg transition-colors"
        :class="
          item.status === 'in_use'
            ? 'text-emerald-600 hover:bg-emerald-50'
            : 'text-amber-600 hover:bg-amber-50'
        "
        :title="item.status === 'in_use' ? '归还收纳' : '取出使用'"
      >
        <svg
          v-if="item.status === 'in_use'"
          class="w-4 h-4"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <path d="M3.5 10v9a2 2 0 0 0 2 2h11a2 2 0 0 0 2-2v-7.5" />
          <path d="M2.5 10h9" />
          <path d="M8.5 14.5h4.5" />
          <path d="M20.5 3.5 13.5 10.5" />
          <path d="M13.5 5.5v5h5" />
        </svg>
        <svg
          v-else
          class="w-4 h-4"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <path d="M3.5 10v9a2 2 0 0 0 2 2h11a2 2 0 0 0 2-2v-7.5" />
          <path d="M2.5 10h9" />
          <path d="M8.5 14.5h4.5" />
          <path d="M13.5 10.5 20.5 3.5" />
          <path d="M15.5 3.5h5v5" />
        </svg>
      </button>
      <button
        @click="emit('delete', item)"
        class="p-1.5 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-lg transition-colors"
        title="删除物品"
      >
        <Trash2 class="w-4 h-4" />
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from "vue";
import type { Item } from "@/types";
import { MapPin, Edit3, Trash2, Mic, Video, PackageOpen, Minus, Plus } from "lucide-vue-next";
import { resolveAttachmentThumb } from "@/utils/mediaUrl";

const props = defineProps<{
  item: Item;
}>();

const emit = defineEmits(["preview", "edit", "delete", "lifecycle", "step-quantity"]);

const primaryThumbnail = computed(() => {
  if (!props.item.attachments || props.item.attachments.length === 0) return null;
  const imgAtt = props.item.attachments.find(
    (a) => a.media_type === "image" || (a as any).file_type === "image"
  );
  return resolveAttachmentThumb(imgAtt) || null;
});

const hasAudio = computed(() =>
  props.item.attachments?.some(
    (a) => a.media_type === "audio" || (a as any).file_type === "audio"
  )
);

const hasVideo = computed(() =>
  props.item.attachments?.some(
    (a) => a.media_type === "video" || (a as any).file_type === "video"
  )
);
</script>
