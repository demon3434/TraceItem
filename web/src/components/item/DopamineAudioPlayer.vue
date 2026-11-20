<template>
  <div class="p-3.5 bg-amber-50/90 border border-amber-200/80 rounded-2xl flex flex-col space-y-2 select-none shadow-sm">
    <!-- 顶栏：标题与倍速切换 -->
    <div class="flex items-center justify-between">
      <div class="flex items-center space-x-2">
        <span class="p-1.5 bg-amber-200/80 rounded-xl text-amber-800">
          <Mic class="w-4 h-4" />
        </span>
        <span class="text-sm font-bold text-amber-950">
          {{ title || "语音指引备忘录" }}
        </span>
      </div>

      <!-- 倍速胶囊 -->
      <button
        type="button"
        @click="toggleRate"
        class="px-2 py-0.5 rounded-lg text-xs font-bold text-amber-800 bg-amber-100 hover:bg-amber-200 transition-colors"
        title="点击切换播放速度"
      >
        {{ playbackRate }}x
      </button>
    </div>

    <!-- 中部：播放按钮、拟态声波与进度条 -->
    <div class="flex items-center space-x-3 pt-1">
      <button
        type="button"
        @click="togglePlay"
        class="w-10 h-10 rounded-full flex items-center justify-center text-white shadow-md transition-transform active:scale-95 flex-shrink-0"
        :style="{ backgroundColor: 'var(--theme-primary, #f97316)' }"
      >
        <Pause v-if="isPlaying" class="w-5 h-5" />
        <Play v-else class="w-5 h-5 ml-0.5" />
      </button>

      <!-- 动态拟态声波 -->
      <div class="flex items-center space-x-0.5 h-6 px-1 flex-shrink-0">
        <span
          v-for="i in 5"
          :key="i"
          class="w-1 bg-amber-500 rounded-full transition-all duration-300"
          :style="{
            height: isPlaying ? `${10 + ((i * 5) % 15)}px` : '4px',
            opacity: isPlaying ? 0.9 : 0.4,
          }"
        ></span>
      </div>

      <!-- 可拖拽进度条与时间显示 -->
      <div class="flex-1 flex flex-col justify-center space-y-1">
        <input
          type="range"
          min="0"
          :max="duration || 100"
          step="0.1"
          :value="currentTime"
          @input="handleSeek"
          class="w-full h-2 bg-amber-200/80 rounded-lg appearance-none cursor-pointer accent-orange-500"
        />
        <div class="flex justify-between text-xs font-mono text-amber-800/80 font-medium px-0.5">
          <span>{{ formatTime(currentTime) }}</span>
          <span>{{ formatTime(duration) }}</span>
        </div>
      </div>
    </div>

    <!-- 隐藏式音频核心 -->
    <audio
      ref="audioRef"
      :src="src"
      preload="metadata"
      @timeupdate="onTimeUpdate"
      @loadedmetadata="onLoadedMetadata"
      @ended="onEnded"
      class="hidden"
    ></audio>
  </div>
</template>

<script setup lang="ts">
import { ref, watch, onMounted } from "vue";
import { Mic, Play, Pause } from "lucide-vue-next";

const props = defineProps<{
  src: string;
  title?: string;
}>();

const audioRef = ref<HTMLAudioElement | null>(null);
const isPlaying = ref(false);
const currentTime = ref(0);
const duration = ref(0);
const playbackRate = ref(1.0);

function togglePlay() {
  if (!audioRef.value) return;
  if (isPlaying.value) {
    audioRef.value.pause();
    isPlaying.value = false;
  } else {
    audioRef.value.play().then(() => {
      isPlaying.value = true;
    }).catch(() => {
      isPlaying.value = false;
    });
  }
}

function toggleRate() {
  playbackRate.value = playbackRate.value === 1.0 ? 1.5 : 1.0;
  if (audioRef.value) {
    audioRef.value.playbackRate = playbackRate.value;
  }
}

function handleSeek(e: Event) {
  const target = e.target as HTMLInputElement;
  const val = parseFloat(target.value);
  if (audioRef.value) {
    audioRef.value.currentTime = val;
    currentTime.value = val;
  }
}

function onTimeUpdate() {
  if (audioRef.value) {
    currentTime.value = audioRef.value.currentTime;
  }
}

function onLoadedMetadata() {
  if (audioRef.value) {
    duration.value = audioRef.value.duration;
  }
}

function onEnded() {
  isPlaying.value = false;
  currentTime.value = 0;
}

function formatTime(sec: number) {
  if (!sec || isNaN(sec)) return "00:00";
  const m = Math.floor(sec / 60);
  const s = Math.floor(sec % 60);
  return `${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}`;
}

watch(
  () => props.src,
  () => {
    isPlaying.value = false;
    currentTime.value = 0;
  }
);
</script>

