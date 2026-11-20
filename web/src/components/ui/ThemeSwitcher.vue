<template>
  <div class="relative" ref="containerRef">
    <!-- 主题触发按钮 (纯图标按钮，与改密、退出按钮保持统一尺寸) -->
    <button
      @click="isOpen = !isOpen"
      class="relative flex items-center justify-center w-10 h-10 rounded-xl bg-white hover:bg-slate-50 text-slate-700 shadow-2xs border border-slate-200/90 transition-all hover:scale-105 active:scale-95"
      :title="`切换色彩主题 (当前: ${themeStore.currentTheme.name})`"
    >
      <Palette class="w-5 h-5" :style="{ color: 'var(--theme-primary)' }" />
      <span
        class="absolute -top-1 -right-1 w-3 h-3 rounded-full border-2 border-white shadow-xs"
        :style="{ backgroundColor: 'var(--theme-primary)' }"
      />
    </button>

    <!-- 主题切换气泡面板 (纯白实底 100% 不透明，杜绝透底混淆) -->
    <Transition
      enter-active-class="ease-out duration-150 transition"
      enter-from-class="opacity-0 translate-y-2 scale-95"
      enter-to-class="opacity-100 translate-y-0 scale-100"
      leave-active-class="ease-in duration-100 transition"
      leave-from-class="opacity-100 translate-y-0 scale-100"
      leave-to-class="opacity-0 translate-y-2 scale-95"
    >
      <div
        v-if="isOpen"
        class="fixed sm:absolute right-4 sm:right-0 mt-2 w-80 max-h-[460px] overflow-y-auto bg-white rounded-2xl shadow-2xl border border-slate-200 p-3.5 z-50 space-y-3"
        style="background-color: #ffffff !important;"
      >
        <!-- 头部说明 -->
        <div class="flex items-center justify-between pb-2 border-b border-slate-100">
          <div>
            <h4 class="text-sm font-black text-slate-800">色彩主题中枢</h4>
            <p class="text-xs text-slate-400">共预设 18 套多巴胺与 shadcn 官方色系</p>
          </div>
          <span class="text-xs px-2 py-0.5 rounded-full bg-orange-100 text-orange-700 font-bold">
            {{ themeStore.currentTheme.name.split(' ')[0] }}
          </span>
        </div>

        <!-- 分类 1：🌟 活力多巴胺系列 -->
        <div>
          <div class="px-2 py-1 text-xs font-black text-orange-600 uppercase tracking-wider flex items-center space-x-1">
            <span>🌟 活力多巴胺色板</span>
          </div>
          <div class="grid grid-cols-1 gap-1 mt-1">
            <button
              v-for="t in dopamineThemes"
              :key="t.id"
              @click="selectTheme(t.id)"
              class="w-full flex items-center justify-between px-3 py-2 rounded-xl text-xs font-bold transition-all text-left"
              :class="
                themeStore.currentThemeId === t.id
                  ? 'bg-orange-50 text-orange-900 border border-orange-200 shadow-sm'
                  : 'text-slate-700 hover:bg-slate-50'
              "
            >
              <div class="flex items-center space-x-2.5 min-w-0">
                <span class="text-base">{{ t.icon }}</span>
                <div class="min-w-0">
                  <p class="truncate leading-none">{{ t.name }}</p>
                  <p class="text-xs text-slate-400 font-normal truncate mt-0.5">{{ t.desc }}</p>
                </div>
              </div>
              <span
                class="w-4 h-4 rounded-full border-2 border-white shadow-sm flex-shrink-0 ml-2"
                :style="{ backgroundColor: t.primaryColor }"
              />
            </button>
          </div>
        </div>

        <!-- 分类 2：🏛️ shadcn 官方 12 色系 -->
        <div class="pt-2 border-t border-slate-100">
          <div class="px-2 py-1 text-xs font-black text-slate-600 uppercase tracking-wider flex items-center space-x-1">
            <span>🏛️ shadcn 官方 12 经典色系</span>
          </div>
          <div class="grid grid-cols-1 gap-1 mt-1">
            <button
              v-for="t in shadcnThemes"
              :key="t.id"
              @click="selectTheme(t.id)"
              class="w-full flex items-center justify-between px-3 py-1.5 rounded-xl text-xs font-semibold transition-all text-left"
              :class="
                themeStore.currentThemeId === t.id
                  ? 'bg-slate-100 text-slate-900 font-bold border border-slate-300 shadow-sm'
                  : 'text-slate-600 hover:bg-slate-50'
              "
            >
              <div class="flex items-center space-x-2 min-w-0">
                <span class="text-sm">{{ t.icon }}</span>
                <span class="truncate">{{ t.name }}</span>
              </div>
              <span
                class="w-3.5 h-3.5 rounded-full border-2 border-white shadow-sm flex-shrink-0 ml-2"
                :style="{ backgroundColor: t.primaryColor }"
              />
            </button>
          </div>
        </div>
      </div>
    </Transition>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from "vue";
import { useThemeStore } from "@/stores/theme";
import { Palette } from "lucide-vue-next";

const themeStore = useThemeStore();
const isOpen = ref(false);
const containerRef = ref<HTMLElement | null>(null);

const dopamineThemes = computed(() =>
  themeStore.themes.filter((t) => t.category === "dopamine")
);

const shadcnThemes = computed(() =>
  themeStore.themes.filter((t) => t.category === "shadcn")
);

function selectTheme(themeId: string) {
  themeStore.applyTheme(themeId);
  isOpen.value = false;
}

function handleClickOutside(e: MouseEvent) {
  if (containerRef.value && !containerRef.value.contains(e.target as Node)) {
    isOpen.value = false;
  }
}

onMounted(() => {
  document.addEventListener("click", handleClickOutside);
});

onUnmounted(() => {
  document.removeEventListener("click", handleClickOutside);
});
</script>
