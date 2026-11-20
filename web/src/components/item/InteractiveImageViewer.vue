<template>
  <div
    ref="containerRef"
    class="relative w-full h-[380px] rounded-2xl overflow-hidden bg-slate-950 flex items-center justify-center select-none"
    :class="scale > 1 ? (isDragging ? 'cursor-grabbing' : 'cursor-grab') : 'cursor-zoom-in'"
    @wheel.prevent="handleWheel"
    @mousedown="handleMouseDown"
    @dblclick="handleDoubleClick"
  >
    <!-- 图片层 -->
    <div
      class="w-full h-full flex items-center justify-center"
      :style="{
        transform: `translate(${translateX}px, ${translateY}px) scale(${scale})`,
        transition: isDragging ? 'none' : 'transform 0.2s cubic-bezier(0.2, 0, 0, 1)',
      }"
    >
      <img
        :src="src"
        :alt="alt"
        class="max-h-full max-w-full object-contain pointer-events-none"
        draggable="false"
      />
    </div>

    <!-- 底部悬浮控制胶囊 (高斯模糊半透多巴胺设计) -->
    <div
      class="absolute bottom-3 left-1/2 -translate-x-1/2 flex items-center space-x-1 bg-slate-900/80 backdrop-blur-md px-3 py-1.5 rounded-full border border-slate-700/60 shadow-lg text-white"
      @mousedown.stop
      @dblclick.stop
    >
      <button
        type="button"
        @click="zoomOut"
        :disabled="scale <= 1"
        class="p-1.5 text-slate-300 hover:text-white disabled:opacity-40 hover:bg-slate-800 rounded-lg transition-colors"
        title="缩小"
      >
        <ZoomOut class="w-4 h-4" />
      </button>

      <span class="text-xs font-mono font-bold px-2 min-w-[50px] text-center text-orange-300">
        {{ Math.round(scale * 100) }}%
      </span>

      <button
        type="button"
        @click="zoomIn"
        :disabled="scale >= 4"
        class="p-1.5 text-slate-300 hover:text-white disabled:opacity-40 hover:bg-slate-800 rounded-lg transition-colors"
        title="放大"
      >
        <ZoomIn class="w-4 h-4" />
      </button>

      <div class="w-px h-3.5 bg-slate-700 mx-1"></div>

      <button
        type="button"
        @click="resetZoom"
        class="p-1.5 text-slate-300 hover:text-white hover:bg-slate-800 rounded-lg transition-colors"
        title="复位 1:1"
      >
        <RotateCcw class="w-4 h-4" />
      </button>
    </div>

    <!-- 提示小徽章 (初次缩放引导) -->
    <div
      v-if="scale > 1"
      class="absolute top-3 right-3 text-xs text-slate-300 bg-slate-900/70 backdrop-blur-sm px-2.5 py-1 rounded-lg flex items-center space-x-1 pointer-events-none"
    >
      <Move class="w-3.5 h-3.5 text-orange-400" />
      <span>按住可拖拽移动</span>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, watch, onMounted, onUnmounted } from "vue";
import { ZoomIn, ZoomOut, RotateCcw, Move } from "lucide-vue-next";

const props = defineProps<{
  src: string;
  alt?: string;
}>();

const containerRef = ref<HTMLElement | null>(null);
const scale = ref(1.0);
const translateX = ref(0);
const translateY = ref(0);
const isDragging = ref(false);

let startMouseX = 0;
let startMouseY = 0;
let initialTranslateX = 0;
let initialTranslateY = 0;

function zoomIn() {
  scale.value = Math.min(4.0, +(scale.value + 0.35).toFixed(2));
}

function zoomOut() {
  const next = Math.max(1.0, +(scale.value - 0.35).toFixed(2));
  scale.value = next;
  if (next <= 1.0) {
    translateX.value = 0;
    translateY.value = 0;
  }
}

function resetZoom() {
  scale.value = 1.0;
  translateX.value = 0;
  translateY.value = 0;
}

function handleDoubleClick() {
  if (scale.value > 1.2) {
    resetZoom();
  } else {
    scale.value = 2.5;
  }
}

function handleWheel(e: WheelEvent) {
  if (e.deltaY < 0) {
    zoomIn();
  } else {
    zoomOut();
  }
}

function handleMouseDown(e: MouseEvent) {
  if (scale.value <= 1.0) return;
  isDragging.value = true;
  startMouseX = e.clientX;
  startMouseY = e.clientY;
  initialTranslateX = translateX.value;
  initialTranslateY = translateY.value;

  window.addEventListener("mousemove", onMouseMove);
  window.addEventListener("mouseup", onMouseUp);
}

function onMouseMove(e: MouseEvent) {
  if (!isDragging.value) return;
  const dx = e.clientX - startMouseX;
  const dy = e.clientY - startMouseY;
  // 限制最大平移范围
  const maxPan = 300 * (scale.value - 1);
  translateX.value = Math.max(-maxPan, Math.min(maxPan, initialTranslateX + dx));
  translateY.value = Math.max(-maxPan, Math.min(maxPan, initialTranslateY + dy));
}

function onMouseUp() {
  isDragging.value = false;
  window.removeEventListener("mousemove", onMouseMove);
  window.removeEventListener("mouseup", onMouseUp);
}

watch(
  () => props.src,
  () => {
    resetZoom();
  }
);

onUnmounted(() => {
  window.removeEventListener("mousemove", onMouseMove);
  window.removeEventListener("mouseup", onMouseUp);
});
</script>

