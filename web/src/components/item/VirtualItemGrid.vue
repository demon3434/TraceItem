<template>
  <div ref="rootRef" class="w-full relative">
    <!-- 顶部与底部弹性占位垫片，完美维持容器真实物理滚动条 -->
    <div
      :style="{
        paddingTop: `${paddingTop}px`,
        paddingBottom: `${paddingBottom}px`,
      }"
    >
      <div
        class="grid gap-5"
        :class="gridColsClass"
      >
        <ItemCard
          v-for="item in visibleItems"
          :key="item.id"
          :item="item"
          @preview="emit('preview', $event)"
          @edit="emit('edit', $event)"
          @delete="emit('delete', $event)"
        />
      </div>
    </div>

    <!-- 触底增量加载哨兵与底部状态提示 -->
    <div ref="sentinelRef" class="w-full py-6 flex items-center justify-center">
      <div
        v-if="loadingMore"
        class="flex items-center gap-2 text-sm text-slate-500 font-medium"
      >
        <Loader2 class="w-4 h-4 animate-spin" :style="{ color: 'var(--theme-primary)' }" />
        <span>正在加载更多物品...</span>
      </div>
      <button
        v-else-if="loadMoreError"
        type="button"
        class="inline-flex items-center gap-1.5 px-4 py-2 rounded-full text-sm font-semibold transition-colors border"
        :style="{
          backgroundColor: 'var(--theme-primary-light)',
          color: 'var(--theme-primary-text)',
          borderColor: 'var(--theme-primary)',
        }"
        @click="emit('retry-load-more')"
      >
        <RefreshCw class="w-4 h-4" />
        <span>加载失败，点击重试</span>
      </button>
      <span
        v-else-if="!hasMore && items.length > 0"
        class="text-xs text-slate-400 font-medium"
      >
        已加载全部 {{ total && total > items.length ? total : items.length }} 件物品
      </span>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from "vue";
import type { Item } from "@/types";
import { Loader2, RefreshCw } from "lucide-vue-next";
import ItemCard from "./ItemCard.vue";

const props = withDefaults(
  defineProps<{
    items: Item[];
    rowHeight?: number;
    loadingMore?: boolean;
    loadMoreError?: boolean;
    hasMore?: boolean;
    total?: number;
  }>(),
  {
    rowHeight: 345, // 单张卡片高度 + 网格间距 (gap-5 = 20px)
    loadingMore: false,
    loadMoreError: false,
    hasMore: false,
    total: 0,
  }
);

const emit = defineEmits<{
  (e: "preview", item: Item): void;
  (e: "edit", item: Item): void;
  (e: "delete", item: Item): void;
  (e: "load-more"): void;
  (e: "retry-load-more"): void;
}>();

const rootRef = ref<HTMLElement | null>(null);
const sentinelRef = ref<HTMLElement | null>(null);
const containerWidth = ref(1200);
const scrollTop = ref(0);
const viewportHeight = ref(800);

let scrollParent: HTMLElement | Window | null = null;
let resizeObserver: ResizeObserver | null = null;
let intersectionObserver: IntersectionObserver | null = null;
let rafId: number | null = null;

// 响应式列数推算 (严格对齐 Tailwind 断点)
const columnCount = computed(() => {
  const w = containerWidth.value;
  if (w < 640) return 1;
  if (w < 768) return 2;
  if (w < 1024) return 3;
  if (w < 1280) return 4;
  return 5;
});

const gridColsClass = computed(() => {
  return "grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5";
});

const totalRows = computed(() => {
  if (props.items.length === 0) return 0;
  return Math.ceil(props.items.length / columnCount.value);
});

// 计算可视窗口与前后各 1~2 行缓冲区的行范围
const startRow = computed(() => {
  if (totalRows.value === 0) return 0;
  const raw = Math.floor(scrollTop.value / props.rowHeight) - 1;
  return Math.max(0, raw);
});

const visibleRowCount = computed(() => {
  return Math.ceil(viewportHeight.value / props.rowHeight) + 3; // +3 行缓冲
});

const endRow = computed(() => {
  return Math.min(totalRows.value, startRow.value + visibleRowCount.value);
});

// 动态计算顶部与底部占位填充
const paddingTop = computed(() => {
  return startRow.value * props.rowHeight;
});

const paddingBottom = computed(() => {
  const remainingRows = totalRows.value - endRow.value;
  return Math.max(0, remainingRows * props.rowHeight);
});

// 视口切片渲染数据 (DOM 节点恒定在 20~30 个以内)
const visibleItems = computed(() => {
  if (props.items.length === 0) return [];
  const startIdx = startRow.value * columnCount.value;
  const endIdx = Math.min(props.items.length, endRow.value * columnCount.value);
  return props.items.slice(startIdx, endIdx);
});

function findScrollParent(el: HTMLElement | null): HTMLElement | Window {
  let parent = el?.parentElement;
  while (parent) {
    const overflowY = window.getComputedStyle(parent).overflowY;
    if (overflowY === "auto" || overflowY === "scroll") {
      return parent;
    }
    parent = parent.parentElement;
  }
  return window;
}

function handleScroll() {
  if (rafId) return;
  rafId = requestAnimationFrame(() => {
    rafId = null;
    if (!scrollParent) return;
    if (scrollParent instanceof Window) {
      scrollTop.value = window.scrollY;
      viewportHeight.value = window.innerHeight;
    } else {
      scrollTop.value = scrollParent.scrollTop;
      viewportHeight.value = scrollParent.clientHeight;
    }
  });
}

function updateContainerWidth() {
  if (rootRef.value) {
    containerWidth.value = rootRef.value.clientWidth;
  }
}

onMounted(() => {
  updateContainerWidth();
  if (rootRef.value) {
    scrollParent = findScrollParent(rootRef.value);
    scrollParent.addEventListener("scroll", handleScroll, { passive: true });

    if (scrollParent instanceof HTMLElement) {
      viewportHeight.value = scrollParent.clientHeight;
      scrollTop.value = scrollParent.scrollTop;
    } else {
      viewportHeight.value = window.innerHeight;
      scrollTop.value = window.scrollY;
    }

    resizeObserver = new ResizeObserver(() => {
      updateContainerWidth();
      handleScroll();
    });
    resizeObserver.observe(rootRef.value);

    if (sentinelRef.value) {
      intersectionObserver = new IntersectionObserver(
        (entries) => {
          const hit = entries.some((entry) => entry.isIntersecting);
          if (hit && props.hasMore && !props.loadingMore && !props.loadMoreError) {
            emit("load-more");
          }
        },
        {
          root: scrollParent instanceof HTMLElement ? scrollParent : null,
          rootMargin: "240px 0px",
          threshold: 0,
        }
      );
      intersectionObserver.observe(sentinelRef.value);
    }
  }
});

onUnmounted(() => {
  if (scrollParent) {
    scrollParent.removeEventListener("scroll", handleScroll);
  }
  if (resizeObserver) {
    resizeObserver.disconnect();
  }
  if (intersectionObserver) {
    intersectionObserver.disconnect();
  }
  if (rafId) {
    cancelAnimationFrame(rafId);
  }
});
</script>

