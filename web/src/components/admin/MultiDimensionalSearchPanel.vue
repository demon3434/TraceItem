<template>
  <div class="space-y-5">
    <!-- 顶栏：多维组合托底寻物检索工作台 -->
    <div class="bg-white p-5 rounded-3xl border border-slate-100 shadow-2xs space-y-4">
      <div class="flex items-center justify-between pb-2 border-b border-slate-100">
        <div class="flex items-center space-x-2.5">
          <div class="w-10 h-10 rounded-2xl bg-amber-100 text-amber-700 flex items-center justify-center font-bold">
            <Search class="w-5 h-5" />
          </div>
          <div>
            <h3 class="text-lg font-black text-slate-800">多维托底寻物</h3>
            <p class="text-xs text-slate-400 mt-0.5">跨用户与空间级联筛选、关键词及时间范围定位物品（严格只读）</p>
          </div>
        </div>

        <div class="flex items-center space-x-2.5">
          <button
            type="button"
            @click="handleReset"
            class="px-4 py-2 text-sm font-bold text-slate-600 bg-slate-100 hover:bg-slate-200 rounded-xl transition-colors flex items-center space-x-1.5"
          >
            <RotateCcw class="w-4 h-4 text-slate-500" />
            <span>重置条件</span>
          </button>
          <button
            type="button"
            @click="handleSearch"
            :disabled="loading"
            class="px-5 py-2 text-sm font-bold text-white bg-gradient-to-r from-amber-500 to-orange-500 hover:from-amber-600 hover:to-orange-600 rounded-xl shadow-xs transition-all flex items-center space-x-1.5"
          >
            <Search class="w-4 h-4" />
            <span>开始检索</span>
          </button>
        </div>
      </div>

      <!-- 级联下拉与组合过滤器 -->
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
        <!-- 1. 属主用户下拉 -->
        <div>
          <label class="block text-xs font-bold text-slate-600 mb-1">所属用户</label>
          <select
            v-model="filters.user_id"
            @change="onUserChange"
            class="w-full px-3 py-2 text-sm rounded-xl border border-slate-200 bg-slate-50 focus:outline-none focus:ring-2 focus:ring-amber-400"
          >
            <option :value="undefined">全部用户</option>
            <option v-for="u in filterOptions.users" :key="u.id" :value="u.id">
              {{ u.nickname }} (@{{ u.username }})
            </option>
          </select>
        </div>

        <!-- 2. 所属房屋下拉 (级联) -->
        <div>
          <label class="block text-xs font-bold text-slate-600 mb-1">存放房屋</label>
          <select
            v-model="filters.house_id"
            @change="onHouseChange"
            class="w-full px-3 py-2 text-sm rounded-xl border border-slate-200 bg-slate-50 focus:outline-none focus:ring-2 focus:ring-amber-400"
          >
            <option :value="undefined">全部房屋</option>
            <option v-for="h in availableHouses" :key="h.id" :value="h.id">
              {{ h.icon || '🏠' }} {{ h.name }}
            </option>
          </select>
        </div>

        <!-- 3. 所属房间下拉 (级联) -->
        <div>
          <label class="block text-xs font-bold text-slate-600 mb-1">具体房间</label>
          <select
            v-model="filters.room_id"
            class="w-full px-3 py-2 text-sm rounded-xl border border-slate-200 bg-slate-50 focus:outline-none focus:ring-2 focus:ring-amber-400"
          >
            <option :value="undefined">全部房间</option>
            <option v-for="r in availableRooms" :key="r.id" :value="r.id">
              {{ r.icon || '🚪' }} {{ r.name }}
            </option>
          </select>
        </div>

        <!-- 4. 物品分类下拉 -->
        <div>
          <label class="block text-xs font-bold text-slate-600 mb-1">物品品类</label>
          <select
            v-model="filters.category_id"
            class="w-full px-3 py-2 text-sm rounded-xl border border-slate-200 bg-slate-50 focus:outline-none focus:ring-2 focus:ring-amber-400"
          >
            <option :value="undefined">全部分类</option>
            <option v-for="c in filterOptions.categories" :key="c.id" :value="c.id">
              {{ c.icon || '📦' }} {{ c.name }}
            </option>
          </select>
        </div>
      </div>

      <!-- 第二排过滤器：标签、关键词、录入日期范围 -->
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 pt-1">
        <!-- 5. 关键词 (名称/品牌/存放细节) -->
        <div>
          <label class="block text-xs font-bold text-slate-600 mb-1">关键词搜索</label>
          <input
            v-model="filters.keyword"
            type="text"
            placeholder="搜索物品名、品牌、位置细节..."
            @keyup.enter="handleSearch"
            class="w-full px-3 py-2 text-sm rounded-xl border border-slate-200 bg-slate-50 focus:outline-none focus:ring-2 focus:ring-amber-400"
          />
        </div>

        <!-- 6. 标签过滤 -->
        <div>
          <label class="block text-xs font-bold text-slate-600 mb-1">标签筛选</label>
          <select
            v-model="filters.tag_name"
            class="w-full px-3 py-2 text-sm rounded-xl border border-slate-200 bg-slate-50 focus:outline-none focus:ring-2 focus:ring-amber-400"
          >
            <option value="">全部标签</option>
            <option v-for="t in filterOptions.tags" :key="t" :value="t">
              🏷️ {{ t }}
            </option>
          </select>
        </div>

        <!-- 7. 起始日期 -->
        <div>
          <label class="block text-xs font-bold text-slate-600 mb-1">录入起始日期</label>
          <input
            v-model="filters.start_date"
            type="date"
            class="w-full px-3 py-2 text-sm rounded-xl border border-slate-200 bg-slate-50 focus:outline-none focus:ring-2 focus:ring-amber-400"
          />
        </div>

        <!-- 8. 截止日期 -->
        <div>
          <label class="block text-xs font-bold text-slate-600 mb-1">录入截止日期</label>
          <input
            v-model="filters.end_date"
            type="date"
            class="w-full px-3 py-2 text-sm rounded-xl border border-slate-200 bg-slate-50 focus:outline-none focus:ring-2 focus:ring-amber-400"
          />
        </div>
      </div>
    </div>

    <!-- 结果列表区 -->
    <div class="bg-white rounded-3xl border border-slate-100 shadow-2xs overflow-hidden">
      <div class="px-5 py-3.5 border-b border-slate-100 flex items-center justify-between text-xs font-bold text-slate-500">
        <span>检索结果：共找到 <strong class="text-amber-600">{{ totalItems }}</strong> 件物品</span>
        <span>提示：点击任意条目即可查看图片与收纳详情</span>
      </div>

      <!-- 加载状态 -->
      <div v-if="loading" class="text-center py-20 text-slate-400 text-sm">
        正在穿透多维索引查找中...
      </div>

      <!-- 空结果 -->
      <div v-else-if="items.length === 0" class="text-center py-24">
        <div class="w-14 h-14 rounded-2xl bg-amber-50 text-amber-500 mx-auto flex items-center justify-center text-2xl mb-2">
          🔍
        </div>
        <p class="text-sm font-bold text-slate-700">未找到符合条件的收纳物品</p>
        <p class="text-xs text-slate-400 mt-1">请尝试放宽检索关键词、空间或日期范围</p>
      </div>

      <!-- 物品表格 -->
      <div v-else class="overflow-x-auto">
        <table class="w-full text-left text-sm border-collapse">
          <thead>
            <tr class="bg-slate-50/70 text-slate-500 text-xs font-bold border-b border-slate-100">
              <th class="py-3 px-4">物品名称</th>
              <th class="py-3 px-4">归属用户</th>
              <th class="py-3 px-4">空间路径</th>
              <th class="py-3 px-4">分类 / 品牌</th>
              <th class="py-3 px-4">数量</th>
              <th class="py-3 px-4">录入时间</th>
              <th class="py-3 px-4 text-right">操作</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr
              v-for="it in items"
              :key="it.id"
              @click="emit('inspectItem', it)"
              class="hover:bg-amber-50/40 transition-colors cursor-pointer group"
            >
              <td class="py-3.5 px-4 font-bold text-slate-800">
                <div class="flex items-center space-x-2.5">
                  <span class="w-2 h-2 rounded-full bg-amber-400"></span>
                  <span class="group-hover:text-amber-700 transition-colors">{{ it.name }}</span>
                  <span v-if="it.attachments?.length" class="text-xs text-slate-400">
                    📷 {{ it.attachments.length }}
                  </span>
                </div>
              </td>
              <td class="py-3.5 px-4">
                <span class="px-2.5 py-1 rounded-xl text-xs font-bold bg-amber-50 text-amber-800 border border-amber-200/80">
                  {{ it.owner_nickname }} (@{{ it.owner_username }})
                </span>
              </td>
              <td class="py-3.5 px-4 text-xs text-slate-600">
                {{ it.house?.icon || '🏠' }} {{ it.house?.name }} ➔ {{ it.room?.icon || '🚪' }} {{ it.room?.name }}
              </td>
              <td class="py-3.5 px-4 text-xs text-slate-600">
                <span>{{ it.category?.icon || '📦' }} {{ it.category?.name || '未分类' }}</span>
                <span v-if="it.brand" class="ml-2 text-slate-400">({{ it.brand }})</span>
              </td>
              <td class="py-3.5 px-4 font-bold text-slate-700">
                {{ it.quantity }}
              </td>
              <td class="py-3.5 px-4 text-xs text-slate-400">
                {{ formatDate(it.created_at) }}
              </td>
              <td class="py-3.5 px-4 text-right">
                <button
                  type="button"
                  @click.stop="emit('inspectItem', it)"
                  class="px-3 py-1.5 text-xs font-bold text-amber-700 bg-amber-100 hover:bg-amber-200 rounded-xl transition-colors"
                >
                  详情
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- 分页控制 -->
      <div v-if="totalPages > 1" class="px-5 py-3.5 bg-slate-50/50 border-t border-slate-100 flex items-center justify-between text-xs">
        <span class="text-slate-500">第 {{ currentPage }} / {{ totalPages }} 页</span>
        <div class="flex items-center space-x-2">
          <button
            @click="changePage(currentPage - 1)"
            :disabled="currentPage <= 1"
            class="px-3 py-1.5 rounded-xl border border-slate-200 bg-white hover:bg-slate-50 disabled:opacity-40"
          >
            上一页
          </button>
          <button
            @click="changePage(currentPage + 1)"
            :disabled="currentPage >= totalPages"
            class="px-3 py-1.5 rounded-xl border border-slate-200 bg-white hover:bg-slate-50 disabled:opacity-40"
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
import { Search, RotateCcw } from "lucide-vue-next";
import { getGodViewFilterOptionsApi, godViewAdvancedSearchApi } from "@/api";
import type {
  GodViewFilterOptions,
  GodViewItem,
  GodViewAdvancedSearchParams,
  GodViewCascadingHouse,
  GodViewCascadingRoom,
} from "@/types";

const emit = defineEmits(["inspectItem"]);

const loading = ref(false);
const filterOptions = ref<GodViewFilterOptions>({ users: [], categories: [], tags: [] });
const items = ref<GodViewItem[]>([]);
const totalItems = ref(0);
const totalPages = ref(1);
const currentPage = ref(1);
const pageSize = ref(20);

const filters = ref<{
  user_id?: number;
  house_id?: number;
  room_id?: number;
  category_id?: number;
  tag_name?: string;
  keyword?: string;
  start_date?: string;
  end_date?: string;
}>({
  user_id: undefined,
  house_id: undefined,
  room_id: undefined,
  category_id: undefined,
  tag_name: "",
  keyword: "",
  start_date: "",
  end_date: "",
});

const availableHouses = computed<GodViewCascadingHouse[]>(() => {
  if (filters.value.user_id) {
    const u = filterOptions.value.users.find((x) => x.id === filters.value.user_id);
    return u?.houses || [];
  }
  // 全部用户的房屋集合
  return filterOptions.value.users.flatMap((u) => u.houses);
});

const availableRooms = computed<GodViewCascadingRoom[]>(() => {
  if (filters.value.house_id) {
    const h = availableHouses.value.find((x) => x.id === filters.value.house_id);
    return h?.rooms || [];
  }
  // 当前可选房屋的所有房间
  return availableHouses.value.flatMap((h) => h.rooms);
});

function onUserChange() {
  filters.value.house_id = undefined;
  filters.value.room_id = undefined;
}

function onHouseChange() {
  filters.value.room_id = undefined;
}

async function loadFilterOptions() {
  try {
    filterOptions.value = await getGodViewFilterOptionsApi();
  } catch (err) {
    console.error("加载多维筛选选项失败", err);
  }
}

async function handleSearch() {
  loading.value = true;
  try {
    const params: GodViewAdvancedSearchParams = {
      page: currentPage.value,
      page_size: pageSize.value,
      user_id: filters.value.user_id,
      house_id: filters.value.house_id,
      room_id: filters.value.room_id,
      category_id: filters.value.category_id,
      tag_name: filters.value.tag_name || undefined,
      keyword: filters.value.keyword?.trim() || undefined,
      start_date: filters.value.start_date || undefined,
      end_date: filters.value.end_date || undefined,
    };
    const res = await godViewAdvancedSearchApi(params);
    items.value = res.items;
    totalItems.value = res.pagination.total;
    totalPages.value = res.pagination.total_pages;
  } catch (err) {
    console.error("多维寻物检索失败", err);
  } finally {
    loading.value = false;
  }
}

function handleReset() {
  filters.value = {
    user_id: undefined,
    house_id: undefined,
    room_id: undefined,
    category_id: undefined,
    tag_name: "",
    keyword: "",
    start_date: "",
    end_date: "",
  };
  currentPage.value = 1;
  handleSearch();
}

function changePage(p: number) {
  if (p < 1 || p > totalPages.value) return;
  currentPage.value = p;
  handleSearch();
}

function formatDate(iso: string) {
  if (!iso) return "-";
  return new Date(iso).toLocaleDateString("zh-CN", {
    year: "numeric",
    month: "numeric",
    day: "numeric",
  });
}

onMounted(async () => {
  await loadFilterOptions();
  await handleSearch();
});
</script>

