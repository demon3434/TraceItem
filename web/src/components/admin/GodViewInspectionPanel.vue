<template>
  <div class="space-y-5">
    <!-- 顶栏：搜索框与模式说明 -->
    <div class="bg-white p-5 rounded-3xl border border-slate-100 shadow-2xs flex flex-col md:flex-row md:items-center justify-between gap-4">
      <div class="flex items-center space-x-2.5">
        <div class="w-10 h-10 rounded-2xl bg-amber-100 text-amber-700 flex items-center justify-center font-bold">
          <Sparkles class="w-5 h-5" />
        </div>
        <div>
          <h3 class="text-lg font-black text-slate-800">全库资产全景巡检与上帝视角</h3>
          <p class="text-xs text-slate-400 mt-0.5">穿透所有家庭成员私有账本，按最新动态巡检或按关键词穿透检索</p>
        </div>
      </div>

      <!-- 搜索栏 -->
      <div class="flex items-center space-x-2 w-full md:w-auto">
        <div class="relative flex-1 md:w-80">
          <Search class="absolute left-3.5 top-3 w-4 h-4 text-slate-400" />
          <input
            v-model="searchQuery"
            type="text"
            placeholder="穿透搜索物品、品牌或细节备注..."
            class="w-full pl-10 pr-8 py-2.5 text-sm rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-amber-400 bg-slate-50"
            @keydown.enter="handleSearch"
          />
          <button
            v-if="searchQuery"
            @click="clearSearch"
            class="absolute right-2.5 top-2.5 text-slate-400 hover:text-slate-600 p-1"
          >
            <X class="w-3.5 h-3.5" />
          </button>
        </div>
        <button
          @click="handleSearch"
          :disabled="loading"
          class="px-4 py-2.5 text-sm font-bold text-white bg-amber-500 hover:bg-amber-600 rounded-xl shadow-xs transition-all flex items-center space-x-1"
        >
          <span>搜索</span>
        </button>
      </div>
    </div>

    <!-- 模式状态提示 -->
    <div v-if="isSearchMode" class="flex items-center justify-between px-3 text-xs text-slate-500">
      <span>正在展示全库穿透检索结果：“<strong>{{ activeQuery }}</strong>” (共 {{ searchResults.length }} 件)</span>
      <button @click="clearSearch" class="text-amber-600 hover:underline font-bold">
        返回全库最新全景巡检 →
      </button>
    </div>

    <!-- 物品巡检列表 -->
    <div v-if="loading" class="text-center py-20 text-slate-400 text-sm">
      正在穿透全库调阅收纳资产...
    </div>

    <div v-else-if="displayItems.length === 0" class="text-center py-20 text-slate-400 text-sm bg-white rounded-3xl border border-slate-100">
      <PackageOpen class="w-10 h-10 mx-auto text-slate-300 mb-2" />
      <p>暂无符合条件的收纳物品记录</p>
    </div>

    <div v-else class="space-y-3">
      <div
        v-for="item in displayItems"
        :key="item.id"
        @click="emit('inspectItem', item)"
        class="bg-white p-4 rounded-3xl border border-slate-100 hover:border-amber-200 hover:shadow-xs transition-all cursor-pointer flex flex-col sm:flex-row sm:items-center justify-between gap-3 group"
        title="点击调阅高分辨率现场照片与音视频寻路指引"
      >
        <div class="flex items-center space-x-3.5 min-w-0">
          <!-- 缩略图或分类图标 -->
          <div class="w-14 h-14 rounded-2xl bg-slate-50 border border-slate-100 overflow-hidden flex items-center justify-center flex-shrink-0">
            <img
              v-if="getThumb(item)"
              :src="getThumb(item)"
              class="w-full h-full object-cover transition-transform group-hover:scale-105"
            />
            <span v-else class="text-2xl">{{ item.category?.icon || "📦" }}</span>
          </div>

          <!-- 物品信息 -->
          <div class="min-w-0">
            <div class="flex items-center space-x-2 flex-wrap gap-y-1">
              <h4 class="text-base font-bold text-slate-800 truncate group-hover:text-amber-600 transition-colors">
                {{ item.name }}
              </h4>
              <span class="px-2.5 py-0.5 rounded-full text-xs font-bold bg-amber-100 text-amber-800 border border-amber-200">
                👑 归属: {{ item.owner_nickname || item.owner_username }}
              </span>
              <span v-if="item.brand" class="text-xs text-slate-400">
                · {{ item.brand }}
              </span>
            </div>

            <!-- 空间路径 -->
            <p class="text-sm text-slate-600 mt-1 flex items-center space-x-1.5 truncate">
              <MapPin class="w-4 h-4 text-amber-500 flex-shrink-0" />
              <span class="font-medium text-slate-700 truncate">{{ item.path_display || "未分配空间" }}</span>
              <span v-if="item.location_detail" class="text-slate-400 truncate">· {{ item.location_detail }}</span>
            </p>
          </div>
        </div>

        <!-- 数量与操作指示 -->
        <div class="flex items-center justify-between sm:justify-end space-x-4 flex-shrink-0 pt-2 sm:pt-0 border-t sm:border-t-0 border-slate-50">
          <div class="text-left sm:text-right">
            <span class="text-sm font-black text-slate-800">x{{ item.quantity }}</span>
            <p class="text-xs text-slate-400 mt-0.5">{{ formatTime(item.updated_at || item.created_at) }}</p>
          </div>

          <div class="flex items-center text-xs font-bold text-amber-600 group-hover:translate-x-0.5 transition-transform">
            <span>调阅现场指引</span>
            <ChevronRight class="w-4 h-4 ml-0.5" />
          </div>
        </div>
      </div>

      <!-- 分页工具栏 (全景巡检模式) -->
      <div v-if="!isSearchMode && totalPages > 1" class="pt-4 flex items-center justify-between text-xs text-slate-500 px-2">
        <span>共 {{ totalItems }} 件全库资产 · 当前第 {{ currentPage }} / {{ totalPages }} 页</span>
        <div class="flex items-center space-x-2">
          <button
            @click="changePage(currentPage - 1)"
            :disabled="currentPage <= 1 || loading"
            class="px-3 py-1.5 rounded-xl border bg-white hover:bg-slate-50 disabled:opacity-40 font-semibold"
          >
            上一页
          </button>
          <button
            @click="changePage(currentPage + 1)"
            :disabled="currentPage >= totalPages || loading"
            class="px-3 py-1.5 rounded-xl border bg-white hover:bg-slate-50 disabled:opacity-40 font-semibold"
          >
            下一页
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from "vue";
import type { GodViewItem } from "@/types";
import { resolveAttachmentThumb } from "@/utils/mediaUrl";
import { getGodViewItemsApi, godViewSearchApi } from "@/api";
import { useToastStore } from "@/stores/toast";
import { Sparkles, Search, X, MapPin, ChevronRight, PackageOpen } from "lucide-vue-next";

const emit = defineEmits(["inspectItem"]);
const toastStore = useToastStore();

const searchQuery = ref("");
const activeQuery = ref("");
const isSearchMode = ref(false);

const loading = ref(false);
const paginatedItems = ref<GodViewItem[]>([]);
const searchResults = ref<GodViewItem[]>([]);

const currentPage = ref(1);
const pageSize = ref(15);
const totalItems = ref(0);
const totalPages = ref(1);

const displayItems = computed(() => {
  return isSearchMode.value ? searchResults.value : paginatedItems.value;
});

onMounted(() => {
  loadPanoramics();
});

async function loadPanoramics() {
  loading.value = true;
  try {
    const res = await getGodViewItemsApi(currentPage.value, pageSize.value);
    paginatedItems.value = res.items;
    totalItems.value = res.pagination.total;
    totalPages.value = res.pagination.total_pages;
  } catch (err: any) {
    toastStore.error("调阅全景资产失败", err.message);
  } finally {
    loading.value = false;
  }
}

async function handleSearch() {
  const q = searchQuery.value.trim();
  if (!q) {
    clearSearch();
    return;
  }
  loading.value = true;
  isSearchMode.value = true;
  activeQuery.value = q;
  try {
    searchResults.value = await godViewSearchApi(q);
  } catch (err: any) {
    toastStore.error("穿透检索失败", err.message);
  } finally {
    loading.value = false;
  }
}

function clearSearch() {
  searchQuery.value = "";
  activeQuery.value = "";
  isSearchMode.value = false;
  loadPanoramics();
}

function changePage(p: number) {
  if (p < 1 || p > totalPages.value) return;
  currentPage.value = p;
  loadPanoramics();
}

function getThumb(item: any): string {
  return resolveAttachmentThumb(item.attachments?.[0]);
}

function formatTime(isoStr?: string): string {
  if (!isoStr) return "";
  const d = new Date(isoStr);
  return `${d.getMonth() + 1}/${d.getDate()} ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}
</script>

