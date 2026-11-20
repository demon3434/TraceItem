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
      v-if="isOpen"
      class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-md overflow-y-auto"
      @click.self="emit('close')"
    >
      <div
        class="w-full max-w-3xl bg-white rounded-squircle-lg p-6 shadow-2xl border border-slate-100 my-8 overflow-hidden"
      >
        <!-- 头部 -->
        <div class="flex items-center justify-between pb-4 border-b border-slate-100">
          <div class="flex items-center space-x-2.5">
            <div class="w-9 h-9 rounded-xl bg-orange-100 text-orange-600 flex items-center justify-center">
              <Sparkles class="w-5 h-5" />
            </div>
            <div>
              <h2 class="text-lg font-bold text-slate-800">Admin 上帝视角 · 紧急寻物中枢</h2>
              <p class="text-xs text-slate-400">穿透全库所有家庭成员独立账本，检索公用应急物品与位置</p>
            </div>
          </div>
          <button @click="emit('close')" class="text-slate-400 hover:text-slate-600 p-1 rounded-lg">
            <X class="w-5 h-5" />
          </button>
        </div>

        <!-- 检索框 -->
        <div class="mt-4">
          <div class="relative">
            <Search class="absolute left-3.5 top-3 w-4 h-4 text-slate-400" />
            <input
              v-model="query"
              type="text"
              placeholder="输入物品名称、备忘或品牌（如：布洛芬、冲击钻、户口簿）..."
              class="w-full pl-10 pr-4 py-2.5 text-sm rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-orange-400 bg-slate-50"
              @keydown.enter="handleSearch"
            />
          </div>
        </div>

        <!-- 结果列表 -->
        <div class="mt-4 max-h-[420px] overflow-y-auto space-y-2.5 pr-1">
          <div v-if="loading" class="text-center py-10 text-sm text-slate-400">
            正在穿透全库全文检索中...
          </div>
          <div v-else-if="searched && results.length === 0" class="text-center py-10 text-sm text-slate-400">
            全库未查找到与 “{{ query }}” 匹配的物品
          </div>
          <div
            v-for="item in results"
            :key="item.id"
            @click="emit('inspectItem', item)"
            class="p-3.5 bg-slate-50 hover:bg-orange-50/60 rounded-2xl border border-slate-100 transition-all flex items-center justify-between cursor-pointer group hover:shadow-sm hover:border-orange-200"
            title="点击调阅该物品全景现场照片与音视频指引"
          >
            <div class="flex items-center space-x-3.5 min-w-0">
              <div class="w-12 h-12 rounded-xl bg-white border border-slate-100 overflow-hidden flex items-center justify-center flex-shrink-0">
                <img
                  v-if="getThumb(item)"
                  :src="getThumb(item)"
                  class="w-full h-full object-cover transition-transform group-hover:scale-105"
                />
                <span v-else class="text-2xl">{{ item.category?.icon || "📦" }}</span>
              </div>
              <div class="min-w-0">
                <div class="flex items-center space-x-2">
                  <h4 class="text-base font-bold text-slate-800 truncate group-hover:text-orange-600 transition-colors">
                    {{ item.name }}
                  </h4>
                  <span class="px-2 py-0.5 rounded-full bg-orange-100 text-xs font-bold text-orange-700">
                    归属: {{ item.owner_nickname || item.owner_username }}
                  </span>
                </div>
                <p class="text-sm text-slate-600 mt-1 flex items-center space-x-1.5 truncate">
                  <MapPin class="w-4 h-4 text-orange-400 flex-shrink-0" />
                  <span class="truncate font-medium">{{ item.path_display || "空间未标注" }}</span>
                  <span v-if="item.location_detail" class="text-slate-500"> · {{ item.location_detail }}</span>
                </p>
              </div>
            </div>

            <div class="text-right flex-shrink-0 pl-3 flex items-center space-x-3">
              <span class="text-sm font-bold text-slate-700">x{{ item.quantity }}</span>
              <span class="text-xs text-orange-600 font-semibold opacity-0 group-hover:opacity-100 transition-opacity">
                调阅详情 →
              </span>
            </div>
          </div>
        </div>

        <div class="mt-4 pt-3 border-t border-slate-100 flex justify-end">
          <button
            type="button"
            @click="emit('close')"
            class="px-4 py-2 text-sm font-semibold text-slate-600 bg-slate-100 hover:bg-slate-200 rounded-xl transition-colors"
          >
            关闭
          </button>
        </div>
      </div>
    </div>
  </Transition>
</template>

<script setup lang="ts">
import { ref } from "vue";
import type { GodViewItem } from "@/types";
import { resolveAttachmentThumb } from "@/utils/mediaUrl";
import { godViewSearchApi } from "@/api";
import { useToastStore } from "@/stores/toast";
import { Sparkles, X, Search, MapPin } from "lucide-vue-next";

defineProps<{
  isOpen: boolean;
}>();

const emit = defineEmits(["close", "inspectItem"]);
const toastStore = useToastStore();

const query = ref("");
const loading = ref(false);
const searched = ref(false);
const results = ref<GodViewItem[]>([]);

function getThumb(item: any): string {
  return resolveAttachmentThumb(item.attachments?.[0]);
}

async function handleSearch() {
  if (!query.value.trim()) return;
  loading.value = true;
  searched.value = true;
  try {
    results.value = await godViewSearchApi(query.value.trim());
  } catch (err: any) {
    toastStore.error("上帝视角检索失败", err.message);
  } finally {
    loading.value = false;
  }
}
</script>
