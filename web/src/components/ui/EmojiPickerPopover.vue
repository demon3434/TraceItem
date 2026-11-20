<template>
  <div
    v-if="isOpen"
    ref="popoverRef"
    class="absolute left-0 top-12 z-50 bg-white p-4 rounded-2xl shadow-2xl border border-slate-200 w-[468px] max-w-[calc(100vw-2rem)] select-none animate-in fade-in zoom-in-95 duration-150 overflow-hidden"
  >
    <!-- 头部：标题与关闭按钮 (纯实色背景，彻底消除半透明背景重叠瑕疵) -->
    <div class="flex items-center justify-between pb-2.5 border-b border-slate-100 mb-3">
      <div class="flex items-center space-x-1.5">
        <span class="text-base">✨</span>
        <span class="text-sm font-bold text-slate-800">挑选分类小图标</span>
        <span class="text-xs text-slate-400 font-medium">（共 {{ allCount }} 款精选图标）</span>
      </div>
      <button
        type="button"
        @click="emit('close')"
        class="p-1 text-slate-400 hover:text-slate-600 rounded-lg hover:bg-slate-100 transition-colors"
        title="关闭面板"
      >
        <X class="w-4 h-4" />
      </button>
    </div>

    <!-- 6 大趣味主题分类选择器 (2行3列平铺网格，100%全景展示，彻底杜绝末尾分类被截断无法点击的问题) -->
    <div class="grid grid-cols-3 gap-1.5 mb-3">
      <button
        v-for="cat in emojiCategories"
        :key="cat.name"
        type="button"
        @click="switchCategory(cat.name)"
        class="px-2.5 py-1.5 rounded-xl text-xs font-bold transition-all flex items-center justify-center space-x-1.5 border"
        :class="
          activeCategory === cat.name
            ? 'bg-orange-500 text-white border-orange-500 shadow-xs scale-[1.02]'
            : 'bg-slate-50 hover:bg-slate-100 text-slate-700 border-slate-200/80 hover:border-slate-300'
        "
      >
        <span class="text-sm flex-shrink-0">{{ cat.icon }}</span>
        <span>{{ cat.label }}</span>
      </button>
    </div>

    <!-- 8列 x 3行 精确固定尺寸网格 (定高 168px，无滚动条设计，悬停绝对不触发抖动与挤压) -->
    <div class="h-[168px] p-2 bg-slate-50/80 rounded-xl border border-slate-100 grid grid-cols-8 gap-2 content-start">
      <button
        v-for="emoji in pagedEmojis"
        :key="emoji"
        type="button"
        @click="selectEmoji(emoji)"
        class="relative z-0 w-11 h-11 rounded-xl bg-white hover:bg-orange-100 text-2xl flex items-center justify-center transition-transform hover:scale-125 hover:z-20 active:scale-95 cursor-pointer border border-slate-200/60 shadow-2xs"
        :class="modelValue === emoji ? 'ring-2 ring-orange-500 bg-orange-50 font-bold' : ''"
        :title="`选择图标: ${emoji}`"
      >
        {{ emoji }}
      </button>
    </div>

    <!-- 前端分页控制器 (多图标分页浏览，杜绝滚动条挤占矩阵宽度) -->
    <div class="mt-2.5 flex items-center justify-between px-1">
      <button
        type="button"
        :disabled="currentPage <= 1"
        @click="currentPage--"
        class="px-2.5 py-1 rounded-lg text-xs font-bold border border-slate-200 bg-white hover:bg-slate-50 disabled:opacity-30 disabled:cursor-not-allowed text-slate-700 flex items-center space-x-1 transition-all"
        title="查看上一页图标"
      >
        <ChevronLeft class="w-3.5 h-3.5" />
        <span>上一页</span>
      </button>

      <div class="flex items-center space-x-1 text-xs">
        <span class="font-bold text-slate-700">第 {{ currentPage }} / {{ totalPages }} 页</span>
        <span class="text-slate-400">（本类 {{ currentCategoryEmojis.length }} 款）</span>
      </div>

      <button
        type="button"
        :disabled="currentPage >= totalPages"
        @click="currentPage++"
        class="px-2.5 py-1 rounded-lg text-xs font-bold border border-slate-200 bg-white hover:bg-slate-50 disabled:opacity-30 disabled:cursor-not-allowed text-slate-700 flex items-center space-x-1 transition-all"
        title="查看下一页图标"
      >
        <span>下一页</span>
        <ChevronRight class="w-3.5 h-3.5" />
      </button>
    </div>

    <!-- 底部状态指示条 -->
    <div class="mt-2.5 pt-2 border-t border-slate-100 flex items-center justify-between text-xs text-slate-400">
      <div class="flex items-center space-x-1.5">
        <span>当前图标:</span>
        <span class="text-base text-slate-800">{{ modelValue || '📦' }}</span>
      </div>
      <span>点击任意小图标即可快速选定</span>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from "vue";
import { X, ChevronLeft, ChevronRight } from "lucide-vue-next";
import categoryEmojis from "@shared/category_emojis.json";

const props = defineProps<{
  isOpen: boolean;
  modelValue?: string;
}>();

const emit = defineEmits<{
  (e: "select", emoji: string): void;
  (e: "update:modelValue", emoji: string): void;
  (e: "close"): void;
}>();

const popoverRef = ref<HTMLElement | null>(null);
const activeCategory = ref("toys");

// 前端分页核心状态 (每页 8列 x 3行 = 24个)
const pageSize = 24;
const currentPage = ref(1);

const emojiCategories = categoryEmojis.groups;

const allCount = computed(() =>
  emojiCategories.reduce((acc, cat) => acc + cat.emojis.length, 0)
);

const currentCategoryEmojis = computed(() => {
  const current = emojiCategories.find((c) => c.name === activeCategory.value);
  return current ? current.emojis : emojiCategories[0].emojis;
});

const totalPages = computed(() =>
  Math.max(1, Math.ceil(currentCategoryEmojis.value.length / pageSize))
);

const pagedEmojis = computed(() => {
  const start = (currentPage.value - 1) * pageSize;
  return currentCategoryEmojis.value.slice(start, start + pageSize);
});

function switchCategory(catName: string) {
  activeCategory.value = catName;
  currentPage.value = 1;
}

function selectEmoji(emoji: string) {
  emit("update:modelValue", emoji);
  emit("select", emoji);
  emit("close");
}

function handleDocumentClick(e: MouseEvent) {
  if (!props.isOpen) return;
  const target = e.target as HTMLElement;
  if (popoverRef.value && !popoverRef.value.contains(target)) {
    if (!target.closest("[data-emoji-trigger]")) {
      emit("close");
    }
  }
}

onMounted(() => {
  document.addEventListener("click", handleDocumentClick);
});

onUnmounted(() => {
  document.removeEventListener("click", handleDocumentClick);
});
</script>
