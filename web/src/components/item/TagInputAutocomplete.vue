<template>
  <div class="space-y-2 relative select-none">
    <label class="block text-sm font-bold text-slate-700">
      特征标签 (回车确认，智能联想公共标签)
    </label>

    <!-- 已选标签胶囊栏 -->
    <div v-if="modelValue.length > 0" class="flex flex-wrap gap-1.5 mb-2">
      <span
        v-for="(tag, idx) in modelValue"
        :key="idx"
        class="inline-flex items-center px-2.5 py-1 rounded-xl text-xs font-bold bg-orange-50 text-orange-700 border border-orange-200/60 shadow-xs"
      >
        #{{ tag }}
        <button
          type="button"
          @click="removeTag(idx)"
          class="ml-1.5 text-orange-400 hover:text-orange-700 rounded-full p-0.5 hover:bg-orange-100 transition-colors"
        >
          <X class="w-3 h-3" />
        </button>
      </span>
    </div>

    <!-- 标签输入框 -->
    <div class="relative">
      <input
        ref="inputRef"
        v-model="inputValue"
        type="text"
        placeholder="打字如“办公”，回车或点击下方提示快速添加"
        class="w-full px-3.5 py-2.5 text-sm rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-orange-400 bg-white"
        @input="handleInput"
        @keydown.enter.prevent="handleEnter"
        @keydown.down.prevent="navigateSuggestions(1)"
        @keydown.up.prevent="navigateSuggestions(-1)"
        @blur="handleBlur"
        @focus="handleFocus"
      />

      <!-- 实时前缀联想下拉浮层 (温润大圆角与阴影) -->
      <div
        v-if="showSuggestions && suggestions.length > 0"
        class="absolute left-0 right-0 top-12 z-30 bg-white/95 backdrop-blur-md rounded-2xl p-2 shadow-xl border border-slate-100 space-y-1 max-h-48 overflow-y-auto"
        @mousedown.prevent
      >
        <div class="px-2 py-1 text-xs text-slate-400 font-bold flex items-center justify-between">
          <span>公共标签联想推荐 (直接复用不重名)</span>
          <span>按回车或轻触选取</span>
        </div>
        <button
          v-for="(sug, idx) in suggestions"
          :key="sug"
          type="button"
          class="w-full text-left px-3 py-2 rounded-xl text-sm font-medium flex items-center justify-between transition-colors"
          :class="highlightIdx === idx ? 'bg-orange-500 text-white font-bold' : 'text-slate-700 hover:bg-orange-50 hover:text-orange-700'"
          @click="selectSuggestion(sug)"
        >
          <span># {{ sug }}</span>
          <span class="text-xs opacity-70">复用</span>
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from "vue";
import { suggestTagsApi } from "@/api";
import { X } from "lucide-vue-next";

const props = defineProps<{
  modelValue: string[];
}>();

const emit = defineEmits(["update:modelValue"]);

const inputRef = ref<HTMLInputElement | null>(null);
const inputValue = ref("");
const suggestions = ref<string[]>([]);
const showSuggestions = ref(false);
const highlightIdx = ref(-1);

let debounceTimer: any = null;

function handleInput() {
  clearTimeout(debounceTimer);
  const q = inputValue.value.trim();
  if (!q) {
    suggestions.value = [];
    showSuggestions.value = false;
    return;
  }

  // 200ms 防抖联想请求
  debounceTimer = setTimeout(async () => {
    try {
      const res = await suggestTagsApi(q, 6);
      // 过滤已经选过的标签
      suggestions.value = res.filter((s) => !props.modelValue.includes(s));
      showSuggestions.value = suggestions.value.length > 0;
      highlightIdx.value = suggestions.value.length > 0 ? 0 : -1;
    } catch {
      suggestions.value = [];
      showSuggestions.value = false;
    }
  }, 200);
}

function handleFocus() {
  if (inputValue.value.trim()) {
    handleInput();
  }
}

function handleBlur() {
  setTimeout(() => {
    showSuggestions.value = false;
  }, 150);
}

function navigateSuggestions(step: number) {
  if (!showSuggestions.value || suggestions.value.length === 0) return;
  highlightIdx.value = (highlightIdx.value + step + suggestions.value.length) % suggestions.value.length;
}

function handleEnter() {
  if (showSuggestions.value && highlightIdx.value >= 0 && suggestions.value[highlightIdx.value]) {
    selectSuggestion(suggestions.value[highlightIdx.value]);
    return;
  }
  const clean = inputValue.value.trim().replace(/^#+/, "");
  if (clean && !props.modelValue.includes(clean)) {
    emit("update:modelValue", [...props.modelValue, clean]);
    inputValue.value = "";
    suggestions.value = [];
    showSuggestions.value = false;
  }
}

function selectSuggestion(sug: string) {
  const clean = sug.trim().replace(/^#+/, "");
  if (clean && !props.modelValue.includes(clean)) {
    emit("update:modelValue", [...props.modelValue, clean]);
  }
  inputValue.value = "";
  suggestions.value = [];
  showSuggestions.value = false;
  inputRef.value?.focus();
}

function removeTag(idx: number) {
  const next = [...props.modelValue];
  next.splice(idx, 1);
  emit("update:modelValue", next);
}
</script>

