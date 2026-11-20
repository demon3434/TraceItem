<template>
  <div class="relative flex items-center space-x-2 select-none" ref="rootRef">
    <!-- 1. 全部品类快速重置胶囊 -->
    <button
      type="button"
      @click="selectCategory(null)"
      class="px-3.5 py-1.5 rounded-xl text-sm font-bold transition-all whitespace-nowrap flex items-center space-x-1.5"
      :class="selectedCategoryId === null ? 'shadow-sm' : 'bg-white text-slate-700 hover:bg-slate-50 border border-slate-200/80'"
      :style="selectedCategoryId === null ? { backgroundColor: 'var(--theme-primary)', color: '#ffffff' } : {}"
    >
      <span>🌟</span>
      <span>全部品类</span>
    </button>

    <!-- 2. 分类筛选下拉选择器触发按钮 (高颜值多巴胺风格，自适应当前选中状态) -->
    <div class="relative">
      <button
        type="button"
        @click="isOpen = !isOpen"
        class="px-3.5 py-1.5 rounded-xl text-sm font-semibold transition-all whitespace-nowrap flex items-center space-x-2 border"
        :class="
          selectedCategory
            ? 'shadow-xs font-bold'
            : 'bg-white text-slate-700 hover:bg-slate-50 border-slate-200/80'
        "
        :style="
          selectedCategory
            ? {
                backgroundColor: 'var(--theme-primary-light)',
                borderColor: 'var(--theme-primary-border)',
                color: 'var(--theme-primary-text)',
              }
            : {}
        "
      >
        <span class="text-base flex-shrink-0">{{ selectedCategory ? selectedCategory.icon : "🏷️" }}</span>
        <span class="max-w-[120px] truncate">
          {{ selectedCategory ? selectedCategory.name : `选择分类 (${categories.length})` }}
        </span>

        <!-- 清空已选分类按钮 -->
        <span
          v-if="selectedCategory"
          @click.stop="selectCategory(null)"
          class="p-0.5 rounded-full hover:bg-black/10 transition-colors ml-0.5 text-slate-500 hover:text-slate-800"
          title="清除此分类筛选"
        >
          <X class="w-3.5 h-3.5" />
        </span>

        <!-- 下拉小箭头 -->
        <ChevronDown
          class="w-4 h-4 text-slate-400 transition-transform duration-200 flex-shrink-0"
          :class="isOpen ? 'rotate-180' : ''"
        />
      </button>

      <!-- 3. 下拉分类全景浮层面板 (双列气泡网格，清晰美观，彻底解决横向溢出) -->
      <Transition
        enter-active-class="ease-out duration-150 transition"
        enter-from-class="opacity-0 translate-y-1 scale-95"
        enter-to-class="opacity-100 translate-y-0 scale-100"
        leave-active-class="ease-in duration-100 transition"
        leave-from-class="opacity-100 translate-y-0 scale-100"
        leave-to-class="opacity-0 translate-y-1 scale-95"
      >
        <div
          v-if="isOpen"
          class="absolute right-0 mt-2 w-80 bg-white/95 backdrop-blur-md rounded-2xl p-3.5 shadow-2xl border border-slate-100 z-50 text-slate-800"
        >
          <!-- 浮层头部：标题与快速搜索 -->
          <div class="mb-2.5">
            <div class="flex items-center justify-between px-1 mb-2">
              <span class="text-xs font-bold text-slate-400 uppercase tracking-wider">
                选择分类 (共 {{ categories.length }} 套)
              </span>
              <button
                type="button"
                @click="isOpen = false"
                class="text-slate-400 hover:text-slate-600 p-0.5 rounded-lg"
              >
                <X class="w-3.5 h-3.5" />
              </button>
            </div>
            <div class="relative">
              <Search class="absolute left-2.5 top-2.5 w-3.5 h-3.5 text-slate-400" />
              <input
                v-model="filterKeyword"
                type="text"
                placeholder="快速检索分类..."
                class="w-full pl-8 pr-3 py-1.5 text-xs bg-slate-50 border border-slate-200/80 rounded-xl focus:outline-none focus:ring-1 focus:ring-orange-400"
              />
            </div>
          </div>

          <!-- 双列分类列表 (支持滚动) -->
          <div class="max-h-56 overflow-y-auto pr-1 grid grid-cols-2 gap-1.5">
            <!-- 全部品类选项 -->
            <button
              type="button"
              @click="selectCategory(null)"
              class="col-span-2 flex items-center justify-between px-2.5 py-2 rounded-xl text-xs font-bold transition-all"
              :class="
                selectedCategoryId === null
                  ? 'bg-orange-50 text-orange-600 border border-orange-200'
                  : 'hover:bg-slate-50 text-slate-700'
              "
            >
              <span class="flex items-center space-x-1.5">
                <span>🌟</span>
                <span>全部品类收纳</span>
              </span>
              <Check v-if="selectedCategoryId === null" class="w-3.5 h-3.5 text-orange-600" />
            </button>

            <!-- 各个具体分类 -->
            <button
              v-for="cat in filteredCategories"
              :key="cat.id"
              type="button"
              @click="selectCategory(cat.id)"
              class="flex items-center justify-between px-2.5 py-2 rounded-xl text-xs font-semibold transition-all border text-left"
              :class="
                selectedCategoryId === cat.id
                  ? 'border-orange-200 bg-orange-50 text-orange-700 font-bold'
                  : 'border-slate-100 hover:border-slate-200 bg-white hover:bg-slate-50 text-slate-700'
              "
            >
              <span class="flex items-center space-x-1.5 truncate">
                <span class="text-sm flex-shrink-0">{{ cat.icon }}</span>
                <span class="truncate">{{ cat.name }}</span>
              </span>
              <Check v-if="selectedCategoryId === cat.id" class="w-3.5 h-3.5 text-orange-600 flex-shrink-0" />
            </button>
          </div>

          <!-- 浮层底部：分类管理入口 -->
          <div class="mt-2.5 pt-2 border-t border-slate-100 flex items-center justify-between px-1">
            <button
              type="button"
              @click="selectCategory(null)"
              class="text-xs text-slate-400 hover:text-slate-600 transition-colors"
            >
              清除筛选
            </button>
            <button
              type="button"
              @click="openManageModal"
              class="text-xs font-bold text-orange-600 hover:text-orange-700 flex items-center space-x-1 transition-colors"
            >
              <FolderCog class="w-3.5 h-3.5" />
              <span>管理分类...</span>
            </button>
          </div>
        </div>
      </Transition>
    </div>

    <!-- 3. 独立直达管理分类按钮 (统一 14px text-sm 高度与字号排版规范) -->
    <button
      type="button"
      @click="emit('openManage')"
      class="px-3.5 py-1.5 rounded-xl text-sm font-bold text-slate-700 hover:text-orange-600 bg-white hover:bg-orange-50 border border-slate-200/80 transition-all flex items-center space-x-1.5 shadow-xs"
      title="增、删、改或停用分类"
    >
      <FolderCog class="w-4 h-4 text-slate-500" />
      <span>管理分类</span>
    </button>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from "vue";
import type { Category } from "@/types";
import { ChevronDown, X, Check, Search, FolderCog } from "lucide-vue-next";

const props = defineProps<{
  categories: Category[];
  selectedCategoryId: number | null;
}>();

const emit = defineEmits<{
  (e: "select", id: number | null): void;
  (e: "openManage"): void;
}>();

const rootRef = ref<HTMLElement | null>(null);
const isOpen = ref(false);
const filterKeyword = ref("");

const selectedCategory = computed(() => {
  if (props.selectedCategoryId === null) return null;
  return props.categories.find((c) => c.id === props.selectedCategoryId) || null;
});

const filteredCategories = computed(() => {
  const kw = filterKeyword.value.trim().toLowerCase();
  if (!kw) return props.categories;
  return props.categories.filter((c) => c.name.toLowerCase().includes(kw));
});

function selectCategory(id: number | null) {
  emit("select", id);
  isOpen.value = false;
  filterKeyword.value = "";
}

function openManageModal() {
  isOpen.value = false;
  emit("openManage");
}

function handleDocumentClick(e: MouseEvent) {
  if (rootRef.value && !rootRef.value.contains(e.target as Node)) {
    isOpen.value = false;
  }
}

onMounted(() => {
  document.addEventListener("click", handleDocumentClick);
});

onUnmounted(() => {
  document.removeEventListener("click", handleDocumentClick);
});
</script>

