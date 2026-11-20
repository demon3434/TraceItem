<template>
  <div class="space-y-6">
    <!-- 顶栏：分类模板控制卡片 -->
    <div class="bg-white p-5 rounded-3xl border border-slate-100 shadow-2xs flex flex-col md:flex-row md:items-center justify-between gap-4">
      <div class="flex items-center space-x-3">
        <div class="w-10 h-10 rounded-2xl bg-amber-100 text-amber-700 flex items-center justify-center font-bold">
          <Tags class="w-5 h-5" />
        </div>
        <div>
          <h3 class="text-lg font-black text-slate-800">物品分类管理</h3>
          <p class="text-xs text-slate-400 mt-0.5">管理系统全局分类模板，新用户注册或开户时将直接按此模板派生初始化分类</p>
        </div>
      </div>

      <div class="flex items-center space-x-2.5">
        <button
          type="button"
          @click="loadTemplates"
          :disabled="loading"
          class="px-3.5 py-2 text-xs font-bold text-slate-700 bg-slate-100 hover:bg-slate-200 rounded-xl transition-colors flex items-center space-x-1.5"
        >
          <RefreshCw class="w-3.5 h-3.5" :class="{ 'animate-spin': loading }" />
          <span>刷新</span>
        </button>

        <button
          type="button"
          @click="openCreateModal"
          class="px-4 py-2 text-xs font-bold text-white bg-gradient-to-r from-amber-500 to-orange-500 hover:from-amber-600 hover:to-orange-600 rounded-xl shadow-xs transition-all flex items-center space-x-1.5"
        >
          <Plus class="w-4 h-4" />
          <span>添加分类模板</span>
        </button>
      </div>
    </div>

    <!-- 统计概览胶囊栏 -->
    <div class="bg-amber-50/60 p-4 rounded-2xl border border-amber-200/50 flex flex-wrap items-center justify-between gap-3 text-xs">
      <div class="flex items-center space-x-2 text-amber-900 font-medium">
        <span>当前共维护 <strong>{{ templates.length }}</strong> 套分类模板</span>
        <span>·</span>
        <span class="text-emerald-700 font-bold">启用中: {{ activeCount }}</span>
        <span>·</span>
        <span class="text-slate-500">已停用: {{ templates.length - activeCount }}</span>
      </div>
      <div class="text-slate-400">
        💡 提示：支持直接拖拽卡片或点击卡片右上角箭头调整次序；后续新增用户将按此排序派生分类
      </div>
    </div>

    <!-- 加载中状态 -->
    <div v-if="loading && templates.length === 0" class="text-center py-20 text-slate-400 text-sm">
      正在加载分类模板...
    </div>

    <!-- 空状态 -->
    <div v-else-if="templates.length === 0" class="text-center py-24 bg-white rounded-3xl border border-slate-100">
      <div class="w-16 h-16 rounded-2xl bg-amber-50 text-amber-500 mx-auto flex items-center justify-center text-3xl mb-3">
        🏷️
      </div>
      <p class="text-base font-bold text-slate-700">暂无任何分类模板</p>
      <p class="text-xs text-slate-400 mt-1">点击右上角“添加分类模板”新增第一套系统分类吧！</p>
    </div>

    <!-- 分类模板紧凑响应式网格 (支持原生拖拽与上下箭头微调) -->
    <div v-else class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
      <div
        v-for="(tpl, index) in templates"
        :key="tpl.id"
        draggable="true"
        @dragstart="onDragStart(index, $event)"
        @dragover="onDragOver(index, $event)"
        @drop="onDrop(index, $event)"
        @dragend="onDragEnd"
        class="bg-white p-4 rounded-3xl border transition-all duration-200 flex flex-col justify-between cursor-move"
        :class="[
          tpl.is_active ? 'border-slate-100 hover:border-amber-200 shadow-2xs' : 'border-slate-200/60 bg-slate-50/50 opacity-80',
          draggedIndex === index ? 'opacity-40 border-dashed border-amber-400 scale-95' : ''
        ]"
      >
        <div>
          <!-- 头部：序号徽标与排序把柄 -->
          <div class="flex items-center justify-between pb-2 mb-2 border-b border-slate-100">
            <div class="flex items-center space-x-1.5">
              <span class="w-6 h-6 rounded-lg bg-amber-500 text-white font-black text-xs flex items-center justify-center shadow-2xs">
                {{ index + 1 }}
              </span>
              <span class="text-xs font-bold text-slate-500">序号</span>
            </div>

            <div class="flex items-center space-x-1" @click.stop>
              <button
                type="button"
                :disabled="index === 0 || isReordering"
                @click="moveItem(index, -1)"
                class="w-7 h-7 rounded-lg flex items-center justify-center text-slate-400 hover:text-amber-600 hover:bg-amber-50 disabled:opacity-20 disabled:hover:bg-transparent disabled:hover:text-slate-400 transition-colors"
                title="向上移动"
              >
                <ArrowUp class="w-3.5 h-3.5" />
              </button>
              <button
                type="button"
                :disabled="index === templates.length - 1 || isReordering"
                @click="moveItem(index, 1)"
                class="w-7 h-7 rounded-lg flex items-center justify-center text-slate-400 hover:text-amber-600 hover:bg-amber-50 disabled:opacity-20 disabled:hover:bg-transparent disabled:hover:text-slate-400 transition-colors"
                title="向下移动"
              >
                <ArrowDown class="w-3.5 h-3.5" />
              </button>
              <div class="text-slate-300 pl-0.5" title="可按住拖拽卡片调整次序">
                <GripVertical class="w-4 h-4 cursor-grab active:cursor-grabbing" />
              </div>
            </div>
          </div>

          <!-- 图标、名称与状态 -->
          <div class="flex items-center space-x-3">
            <div class="w-11 h-11 rounded-2xl bg-amber-50 border border-amber-100/80 flex items-center justify-center text-2xl flex-shrink-0">
              {{ tpl.icon || "📦" }}
            </div>
            <div class="min-w-0">
              <h4 class="font-bold text-slate-900 text-sm truncate">{{ tpl.name }}</h4>
              <span
                class="inline-block mt-0.5 px-2 py-0.5 rounded-full text-[11px] font-bold"
                :class="tpl.is_active ? 'bg-emerald-50 text-emerald-700' : 'bg-slate-100 text-slate-500'"
              >
                {{ tpl.is_active ? "● 启用中" : "○ 已停用" }}
              </span>
            </div>
          </div>
        </div>

        <!-- 底部操作按钮栏 -->
        <div class="mt-4 pt-3 border-t border-slate-100 flex items-center justify-end space-x-1.5">
          <button
            type="button"
            @click="openEditModal(tpl)"
            class="px-2.5 py-1 text-xs font-bold text-slate-600 hover:text-slate-900 bg-slate-50 hover:bg-slate-100 rounded-xl transition-colors flex items-center space-x-1"
          >
            <Pencil class="w-3 h-3 text-slate-400" />
            <span>编辑</span>
          </button>

          <button
            type="button"
            @click="toggleStatus(tpl)"
            class="px-2.5 py-1 text-xs font-bold rounded-xl transition-colors flex items-center space-x-1"
            :class="tpl.is_active ? 'text-amber-700 bg-amber-50 hover:bg-amber-100' : 'text-emerald-700 bg-emerald-50 hover:bg-emerald-100'"
          >
            <Power class="w-3 h-3" />
            <span>{{ tpl.is_active ? "停用" : "启用" }}</span>
          </button>

          <button
            type="button"
            @click="promptDelete(tpl)"
            class="px-2.5 py-1 text-xs font-bold text-rose-600 bg-rose-50 hover:bg-rose-100 rounded-xl transition-colors flex items-center space-x-1"
          >
            <Trash2 class="w-3 h-3" />
            <span>删除</span>
          </button>
        </div>
      </div>
    </div>

    <!-- 弹窗：新建 / 编辑分类模板 -->
    <div
      v-if="modalState.isOpen"
      class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40 backdrop-blur-xs"
      @click.self="modalState.isOpen = false"
    >
      <div class="bg-white w-full max-w-md rounded-squircle-lg p-6 shadow-2xl border border-slate-100 space-y-4">
        <div class="flex items-center justify-between pb-2 border-b border-slate-100">
          <h3 class="text-base font-black text-slate-800">
            {{ modalState.isEdit ? "编辑分类模板" : "添加新分类模板" }}
          </h3>
          <button
            type="button"
            @click="modalState.isOpen = false"
            class="w-7 h-7 rounded-xl text-slate-400 hover:text-slate-700 hover:bg-slate-100 flex items-center justify-center"
          >
            ✕
          </button>
        </div>

        <div class="space-y-3.5">
          <!-- 分类名称 -->
          <div>
            <label class="block text-xs font-bold text-slate-600 mb-1">分类名称 <span class="text-rose-500">*</span></label>
            <input
              v-model="modalForm.name"
              type="text"
              placeholder="例如：常备药品、五金工具"
              class="w-full px-3.5 py-2.5 text-sm rounded-xl border border-slate-200 focus:outline-hidden focus:border-amber-500 font-medium"
            />
          </div>

          <!-- 分类图标与快捷选择 -->
          <div>
            <label class="block text-xs font-bold text-slate-600 mb-1">分类图标 (Emoji) <span class="text-rose-500">*</span></label>
            <div class="flex items-center space-x-2">
              <input
                v-model="modalForm.icon"
                type="text"
                maxlength="8"
                class="w-16 text-center text-xl py-2 rounded-xl border border-slate-200 focus:outline-hidden focus:border-amber-500 font-bold"
              />
              <span class="text-xs text-slate-400">点击下方推荐 Emoji 快速填充：</span>
            </div>
            <!-- 快捷常用 Emoji -->
            <div class="flex flex-wrap gap-1.5 mt-2">
              <button
                v-for="em in quickEmojis"
                :key="em"
                type="button"
                @click="modalForm.icon = em"
                class="w-8 h-8 rounded-lg hover:bg-amber-100 text-lg flex items-center justify-center transition-colors"
                :class="modalForm.icon === em ? 'bg-amber-200 font-bold scale-110' : 'bg-slate-50'"
              >
                {{ em }}
              </button>
            </div>
          </div>

          <!-- 排序优先级 -->
          <div>
            <label class="block text-xs font-bold text-slate-600 mb-1">排序优先级 (数字越小越靠前)</label>
            <input
              v-model.number="modalForm.sort_order"
              type="number"
              min="0"
              class="w-full px-3.5 py-2.5 text-sm rounded-xl border border-slate-200 focus:outline-hidden focus:border-amber-500 font-medium"
            />
          </div>
        </div>

        <div class="pt-3 border-t border-slate-100 flex items-center justify-end space-x-2">
          <button
            type="button"
            @click="modalState.isOpen = false"
            class="px-4 py-2 text-xs font-bold text-slate-600 bg-slate-100 hover:bg-slate-200 rounded-xl transition-colors"
          >
            取消
          </button>
          <button
            type="button"
            @click="submitModalForm"
            :disabled="saving"
            class="px-5 py-2 text-xs font-bold text-white bg-amber-500 hover:bg-amber-600 rounded-xl shadow-xs transition-colors disabled:opacity-50"
          >
            {{ saving ? "保存中..." : "保存" }}
          </button>
        </div>
      </div>
    </div>

    <!-- 统一确认对话框 -->
    <ConfirmDialog
      :is-open="confirmState.isOpen"
      :title="confirmState.title"
      :message="confirmState.message"
      :confirm-text="confirmState.confirmText"
      :is-danger="confirmState.isDanger"
      @confirm="executeConfirm"
      @cancel="confirmState.isOpen = false"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from "vue";
import categoryEmojis from "@shared/category_emojis.json";
import { Tags, Plus, RefreshCw, Pencil, Power, Trash2, ArrowUp, ArrowDown, GripVertical } from "lucide-vue-next";
import ConfirmDialog from "@/components/ui/ConfirmDialog.vue";
import {
  getCategoryTemplatesApi,
  createCategoryTemplateApi,
  updateCategoryTemplateApi,
  toggleCategoryTemplateStatusApi,
  deleteCategoryTemplateApi,
  reorderCategoryTemplatesApi,
} from "@/api";
import { useToastStore } from "@/stores/toast";
import type { CategoryTemplate } from "@/types";

const toastStore = useToastStore();

const loading = ref(false);
const saving = ref(false);
const isReordering = ref(false);
const draggedIndex = ref<number | null>(null);
const templates = ref<CategoryTemplate[]>([]);

function onDragStart(index: number, e: DragEvent) {
  draggedIndex.value = index;
  if (e.dataTransfer) {
    e.dataTransfer.effectAllowed = "move";
    e.dataTransfer.setData("text/plain", String(index));
  }
}

function onDragOver(index: number, e: DragEvent) {
  e.preventDefault();
  if (e.dataTransfer) {
    e.dataTransfer.dropEffect = "move";
  }
}

async function onDrop(targetIndex: number, e: DragEvent) {
  e.preventDefault();
  if (draggedIndex.value === null || draggedIndex.value === targetIndex) return;
  const item = templates.value.splice(draggedIndex.value, 1)[0];
  templates.value.splice(targetIndex, 0, item);
  draggedIndex.value = null;
  await persistReorder();
}

function onDragEnd() {
  draggedIndex.value = null;
}

async function moveItem(index: number, delta: number) {
  const newIndex = index + delta;
  if (newIndex < 0 || newIndex >= templates.value.length) return;
  const item = templates.value.splice(index, 1)[0];
  templates.value.splice(newIndex, 0, item);
  await persistReorder();
}

async function persistReorder() {
  isReordering.value = true;
  try {
    const orderedIds = templates.value.map((t) => t.id);
    const updated = await reorderCategoryTemplatesApi(orderedIds);
    templates.value = updated;
    toastStore.success("分类模板排序已保存");
  } catch (err: any) {
    toastStore.error("保存排序失败", err.message);
    await loadTemplates();
  } finally {
    isReordering.value = false;
  }
}

const quickEmojis: string[] = categoryEmojis.quickEmojis;

const activeCount = computed(() => templates.value.filter((t) => t.is_active).length);

const modalState = ref({
  isOpen: false,
  isEdit: false,
  editId: 0,
});

const modalForm = ref({
  name: "",
  icon: "📦",
  sort_order: 10,
});

const confirmState = ref({
  isOpen: false,
  title: "",
  message: "",
  confirmText: "确认",
  isDanger: false,
  action: async () => {},
});

async function loadTemplates() {
  loading.value = true;
  try {
    templates.value = await getCategoryTemplatesApi(true);
  } catch (err: any) {
    toastStore.error("加载分类模板失败", err.message);
  } finally {
    loading.value = false;
  }
}

function openCreateModal() {
  modalState.value = { isOpen: true, isEdit: false, editId: 0 };
  modalForm.value = {
    name: "",
    icon: "📦",
    sort_order: (templates.value.length + 1) * 5,
  };
}

function openEditModal(tpl: CategoryTemplate) {
  modalState.value = { isOpen: true, isEdit: true, editId: tpl.id };
  modalForm.value = {
    name: tpl.name,
    icon: tpl.icon,
    sort_order: tpl.sort_order,
  };
}

async function submitModalForm() {
  if (!modalForm.value.name.trim()) {
    toastStore.warning("分类名称不能为空");
    return;
  }
  saving.value = true;
  try {
    if (modalState.value.isEdit) {
      await updateCategoryTemplateApi(modalState.value.editId, {
        name: modalForm.value.name.trim(),
        icon: modalForm.value.icon.trim() || "📦",
        sort_order: modalForm.value.sort_order,
      });
      toastStore.success("分类模板更新成功");
    } else {
      await createCategoryTemplateApi({
        name: modalForm.value.name.trim(),
        icon: modalForm.value.icon.trim() || "📦",
        sort_order: modalForm.value.sort_order,
      });
      toastStore.success("新分类模板已创建");
    }
    modalState.value.isOpen = false;
    await loadTemplates();
  } catch (err: any) {
    toastStore.error("操作失败", err.message);
  } finally {
    saving.value = false;
  }
}

async function toggleStatus(tpl: CategoryTemplate) {
  const newStatus = !tpl.is_active;
  try {
    await toggleCategoryTemplateStatusApi(tpl.id, newStatus);
    toastStore.success(`分类模板已${newStatus ? "启用" : "停用"}`);
    await loadTemplates();
  } catch (err: any) {
    toastStore.error("状态切换失败", err.message);
  }
}

function promptDelete(tpl: CategoryTemplate) {
  confirmState.value = {
    isOpen: true,
    title: "确认删除该分类模板？",
    message: `确定要删除分类模板【${tpl.name}】吗？删除后新用户将不再派生该分类，已存在的用户私有数据不受影响。`,
    confirmText: "确认删除",
    isDanger: true,
    action: async () => {
      try {
        await deleteCategoryTemplateApi(tpl.id);
        toastStore.success("分类模板已删除");
        await loadTemplates();
      } catch (err: any) {
        toastStore.error("删除失败", err.message);
      }
    },
  };
}

async function executeConfirm() {
  confirmState.value.isOpen = false;
  await confirmState.value.action();
}

onMounted(async () => {
  await loadTemplates();
});
</script>

