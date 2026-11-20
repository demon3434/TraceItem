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
      class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-sm"
      @click.self="emit('close')"
    >
      <div
        class="w-full max-w-xl bg-white rounded-squircle-lg p-6 shadow-2xl border border-slate-100 flex flex-col max-h-[85vh] overflow-hidden"
      >
        <!-- 弹窗顶栏 -->
        <div class="flex items-center justify-between pb-3 border-b border-slate-100">
          <div class="flex items-center space-x-2.5">
            <div class="p-2 bg-orange-50 text-orange-600 rounded-xl">
              <FolderCog class="w-5 h-5" />
            </div>
            <div>
              <h2 class="text-lg font-bold text-slate-800">分类生命周期管理</h2>
              <p class="text-xs text-slate-500 mt-0.5">增、删、改私有分类或停用展示，停用不影响归档历史</p>
            </div>
          </div>
          <button
            type="button"
            @click="emit('close')"
            class="text-slate-400 hover:text-slate-600 p-1.5 rounded-xl hover:bg-slate-50"
          >
            <X class="w-5 h-5" />
          </button>
        </div>

        <!-- 快速添加新分类栏 -->
        <div class="p-3 bg-slate-50/80 rounded-2xl border border-slate-100 my-3 flex items-center space-x-2">
          <!-- Emoji 图标快选 (扩充至 144 款精选儿童趣味多巴胺图标) -->
          <div class="relative">
            <button
              type="button"
              data-emoji-trigger="new"
              @click="showNewEmojiPopover = !showNewEmojiPopover"
              class="w-10 h-10 rounded-xl bg-white border border-slate-200 shadow-sm flex items-center justify-center text-xl hover:border-orange-400 transition-colors"
              title="选择分类图标 Emoji"
            >
              {{ newIcon }}
            </button>
            <EmojiPickerPopover
              :is-open="showNewEmojiPopover"
              :model-value="newIcon"
              @select="(e) => newIcon = e"
              @close="showNewEmojiPopover = false"
            />
          </div>

          <input
            v-model="newName"
            type="text"
            maxlength="20"
            placeholder="新增自定义分类名称 (如：烘焙器具)"
            class="flex-1 px-3.5 py-2 text-sm bg-white rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-orange-500/20 focus:border-orange-500"
            @keyup.enter="handleCreateCategory"
          />

          <button
            type="button"
            @click="handleCreateCategory"
            :disabled="!newName.trim() || submitting"
            class="px-4 py-2 text-sm font-bold text-white bg-orange-500 hover:bg-orange-600 disabled:opacity-50 rounded-xl transition-all shadow-sm"
          >
            添加分类
          </button>
        </div>

        <!-- 分类列表 (滚动区，支持拖拽与上下移动排序) -->
        <div class="flex-1 overflow-y-auto pr-1 space-y-1.5 divide-y divide-slate-100">
          <div
            v-for="(cat, index) in categories"
            :key="cat.id"
            draggable="true"
            @dragstart="onDragStart(index, $event)"
            @dragover="onDragOver(index, $event)"
            @drop="onDrop(index, $event)"
            @dragend="onDragEnd"
            class="pt-1.5 first:pt-0 flex items-center justify-between p-2.5 rounded-2xl hover:bg-slate-50/80 transition-all border border-transparent hover:border-slate-100 cursor-move"
            :class="draggedIndex === index ? 'opacity-40 border-dashed border-orange-400 bg-orange-50/50' : ''"
          >
            <!-- 正常展示或行内编辑模式 -->
            <div v-if="editingId === cat.id" class="flex-1 flex items-center space-x-2 mr-2">
              <span class="w-6 h-6 rounded-lg bg-orange-500 text-white font-black text-xs flex items-center justify-center shadow-2xs flex-shrink-0">
                {{ index + 1 }}
              </span>
              <div class="relative">
                <button
                  type="button"
                  data-emoji-trigger="edit"
                  @click="showEditEmojiPopover = !showEditEmojiPopover"
                  class="w-9 h-9 rounded-lg bg-white border border-orange-400 shadow-sm flex items-center justify-center text-lg hover:border-orange-500 transition-colors"
                  title="点击更改分类图标"
                >
                  {{ editIcon }}
                </button>
                <EmojiPickerPopover
                  :is-open="showEditEmojiPopover"
                  :model-value="editIcon"
                  @select="(e) => editIcon = e"
                  @close="showEditEmojiPopover = false"
                />
              </div>
              <input
                v-model="editName"
                type="text"
                maxlength="20"
                class="flex-1 px-2.5 py-1.5 text-sm bg-white rounded-lg border border-orange-400 focus:outline-none"
                @keyup.enter="handleSaveEdit(cat.id)"
              />
              <button
                type="button"
                @click="handleSaveEdit(cat.id)"
                class="p-1.5 text-emerald-600 hover:bg-emerald-50 rounded-lg"
                title="保存修改"
              >
                <Check class="w-4 h-4" />
              </button>
              <button
                type="button"
                @click="editingId = null"
                class="p-1.5 text-slate-400 hover:bg-slate-100 rounded-lg"
                title="取消修改"
              >
                <X class="w-4 h-4" />
              </button>
            </div>

            <div v-else class="flex items-center space-x-2.5 min-w-0">
              <!-- 序号徽章 -->
              <span class="w-6 h-6 rounded-lg bg-orange-500 text-white font-black text-xs flex items-center justify-center shadow-2xs flex-shrink-0">
                {{ index + 1 }}
              </span>

              <!-- 排序上下箭头与拖拽把手 -->
              <div class="flex items-center space-x-0.5 mr-1" @click.stop>
                <button
                  type="button"
                  :disabled="index === 0 || isReordering"
                  @click="moveItem(index, -1)"
                  class="w-6 h-6 rounded-md flex items-center justify-center text-slate-400 hover:text-orange-600 hover:bg-orange-50 disabled:opacity-20 transition-colors"
                  title="向上移动"
                >
                  <ArrowUp class="w-3.5 h-3.5" />
                </button>
                <button
                  type="button"
                  :disabled="index === categories.length - 1 || isReordering"
                  @click="moveItem(index, 1)"
                  class="w-6 h-6 rounded-md flex items-center justify-center text-slate-400 hover:text-orange-600 hover:bg-orange-50 disabled:opacity-20 transition-colors"
                  title="向下移动"
                >
                  <ArrowDown class="w-3.5 h-3.5" />
                </button>
                <GripVertical class="w-3.5 h-3.5 text-slate-300 cursor-grab active:cursor-grabbing ml-0.5" title="按住可拖拽调整顺序" />
              </div>

              <span class="text-xl flex-shrink-0">{{ cat.icon }}</span>
              <div class="min-w-0">
                <div class="flex items-center space-x-2">
                  <span
                    class="text-sm font-bold truncate"
                    :class="cat.is_active !== false ? 'text-slate-800' : 'text-slate-400 line-through'"
                  >
                    {{ cat.name }}
                  </span>
                  <span
                    v-if="cat.is_active === false"
                    class="px-2 py-0.5 rounded-full text-xs font-semibold bg-slate-100 text-slate-400 flex-shrink-0"
                  >
                    已停用
                  </span>
                </div>
              </div>
            </div>

            <!-- 操作胶囊群 -->
            <div v-if="editingId !== cat.id" class="flex items-center space-x-1 flex-shrink-0">
              <!-- 停用/启用切换按钮 -->
              <button
                type="button"
                @click="handleToggleStatus(cat)"
                class="px-2.5 py-1 text-xs font-bold rounded-lg transition-colors"
                :class="
                  cat.is_active !== false
                    ? 'text-amber-700 bg-amber-50 hover:bg-amber-100'
                    : 'text-emerald-700 bg-emerald-50 hover:bg-emerald-100'
                "
                :title="cat.is_active !== false ? '停用后在录入和主页快捷栏隐藏' : '重新启用该分类'"
              >
                {{ cat.is_active !== false ? "停用" : "启用" }}
              </button>

              <!-- 编辑 -->
              <button
                type="button"
                @click="startEdit(cat)"
                class="p-1.5 text-slate-400 hover:text-slate-700 hover:bg-slate-100 rounded-lg transition-colors"
                title="编辑名称与图标"
              >
                <Edit3 class="w-4 h-4" />
              </button>

              <!-- 删除 -->
              <button
                type="button"
                @click="promptDelete(cat)"
                class="p-1.5 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-lg transition-colors"
                title="安全删除分类"
              >
                <Trash2 class="w-4 h-4" />
              </button>
            </div>
          </div>
        </div>

        <!-- 底部栏 -->
        <div class="mt-4 pt-3 border-t border-slate-100 flex justify-between items-center text-sm">
          <div class="flex items-center space-x-2 text-slate-500 font-medium">
            <span>共 <strong class="text-slate-800">{{ categories.length }}</strong> 个私有分类</span>
            <span class="text-slate-300">|</span>
            <span class="text-xs text-slate-400">💡 支持拖拽或点击上下箭头排序</span>
          </div>

          <button
            type="button"
            @click="emit('close')"
            class="px-4 py-1.5 text-sm font-bold text-slate-700 bg-slate-100 hover:bg-slate-200 rounded-xl transition-colors"
          >
            完成并关闭
          </button>
        </div>
      </div>
    </div>
  </Transition>

  <!-- 安全解绑删除确认弹窗 (统一温润大圆角规范，严禁原生 confirm) -->
  <ConfirmDialog
    :is-open="showDeleteConfirm"
    title="解绑并删除分类"
    :message="`确定要删除分类“${catToDelete?.name}”吗？若该分类下有关联物品，系统将自动将其解绑并设为未分类，绝不会删除任何物品！`"
    confirm-text="确认解绑并删除"
    :is-danger="true"
    @confirm="executeDelete"
    @cancel="showDeleteConfirm = false"
  />
</template>

<script setup lang="ts">
import { ref, watch } from "vue";
import type { Category } from "@/types";
import {
  getCategoriesApi,
  createCategoryApi,
  updateCategoryApi,
  toggleCategoryStatusApi,
  deleteCategoryApi,
  reorderUserCategoriesApi,
} from "@/api";
import { useToastStore } from "@/stores/toast";
import ConfirmDialog from "@/components/ui/ConfirmDialog.vue";
import EmojiPickerPopover from "@/components/ui/EmojiPickerPopover.vue";
import { FolderCog, X, Edit3, Trash2, Check, ArrowUp, ArrowDown, GripVertical } from "lucide-vue-next";

const props = defineProps<{
  isOpen: boolean;
}>();

const emit = defineEmits(["close", "updated"]);
const toastStore = useToastStore();

const categories = ref<Category[]>([]);
const submitting = ref(false);
const loading = ref(false);
const isReordering = ref(false);
const draggedIndex = ref<number | null>(null);

const newName = ref("");
const newIcon = ref("📦");
const showNewEmojiPopover = ref(false);
const showEditEmojiPopover = ref(false);

const editingId = ref<number | null>(null);
const editName = ref("");
const editIcon = ref("📦");

const showDeleteConfirm = ref(false);
const catToDelete = ref<Category | null>(null);

async function loadAllCategories() {
  loading.value = true;
  try {
    categories.value = await getCategoriesApi(true);
  } catch (err: any) {
    toastStore.error("加载分类失败", err.message);
  } finally {
    loading.value = false;
  }
}

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
  const item = categories.value.splice(draggedIndex.value, 1)[0];
  categories.value.splice(targetIndex, 0, item);
  draggedIndex.value = null;
  await persistReorder();
}

function onDragEnd() {
  draggedIndex.value = null;
}

async function moveItem(index: number, delta: number) {
  const newIndex = index + delta;
  if (newIndex < 0 || newIndex >= categories.value.length) return;
  const item = categories.value.splice(index, 1)[0];
  categories.value.splice(newIndex, 0, item);
  await persistReorder();
}

async function persistReorder() {
  isReordering.value = true;
  try {
    const orderedIds = categories.value.map((c) => c.id);
    const updated = await reorderUserCategoriesApi(orderedIds);
    categories.value = updated;
    toastStore.success("分类排序已更新");
    emit("updated");
  } catch (err: any) {
    toastStore.error("保存排序失败", err.message);
    await loadAllCategories();
  } finally {
    isReordering.value = false;
  }
}

async function handleCreateCategory() {
  if (!newName.value.trim() || submitting.value) return;
  submitting.value = true;
  try {
    await createCategoryApi({
      name: newName.value.trim(),
      icon: newIcon.value,
      sort_order: categories.value.length + 1,
      is_active: true,
    });
    toastStore.success("分类创建成功", `已添加“${newName.value.trim()}”`);
    newName.value = "";
    newIcon.value = "📦";
    await loadAllCategories();
    emit("updated");
  } catch (err: any) {
    toastStore.error("创建失败", err.message);
  } finally {
    submitting.value = false;
  }
}

function startEdit(cat: Category) {
  editingId.value = cat.id;
  editName.value = cat.name;
  editIcon.value = cat.icon;
}

async function handleSaveEdit(id: number) {
  if (!editName.value.trim()) return;
  try {
    await updateCategoryApi(id, {
      name: editName.value.trim(),
      icon: editIcon.value.trim() || "📦",
    });
    toastStore.success("分类已修改", `更新为“${editName.value.trim()}”`);
    editingId.value = null;
    await loadAllCategories();
    emit("updated");
  } catch (err: any) {
    toastStore.error("修改失败", err.message);
  }
}

async function handleToggleStatus(cat: Category) {
  const nextStatus = cat.is_active === false;
  try {
    await toggleCategoryStatusApi(cat.id, nextStatus);
    toastStore.info(
      nextStatus ? "分类已启用" : "分类已停用",
      `分类“${cat.name}”已${nextStatus ? "恢复正常展示" : "设为停用状态"}`
    );
    await loadAllCategories();
    emit("updated");
  } catch (err: any) {
    toastStore.error("状态切换失败", err.message);
  }
}

function promptDelete(cat: Category) {
  catToDelete.value = cat;
  showDeleteConfirm.value = true;
}

async function executeDelete() {
  if (!catToDelete.value) return;
  try {
    await deleteCategoryApi(catToDelete.value.id);
    toastStore.success("分类已删除", `“${catToDelete.value.name}”已移除，关联物品已解绑`);
    showDeleteConfirm.value = false;
    catToDelete.value = null;
    await loadAllCategories();
    emit("updated");
  } catch (err: any) {
    toastStore.error("删除失败", err.message);
  }
}

watch(
  () => props.isOpen,
  (open) => {
    if (open) {
      loadAllCategories();
    }
  }
);
</script>

