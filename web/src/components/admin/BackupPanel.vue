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
        <!-- 头部标题与立即备份动作 -->
        <div class="flex items-center justify-between pb-4 border-b border-slate-100">
          <div class="flex items-center space-x-2.5">
            <div class="w-9 h-9 rounded-xl bg-orange-100 text-orange-600 flex items-center justify-center">
              <Archive class="w-5 h-5" />
            </div>
            <div>
              <h2 class="text-lg font-bold text-slate-800">TAR 纯归档流备份中枢</h2>
              <p class="text-xs text-slate-400">免定时器、零算力损耗纯打包，防止磁盘膨胀</p>
            </div>
          </div>
          <button @click="emit('close')" class="text-slate-400 hover:text-slate-600 p-1 rounded-lg">
            <X class="w-5 h-5" />
          </button>
        </div>

        <!-- 操作栏 -->
        <div class="mt-4 flex items-center justify-between bg-orange-50/60 p-3.5 rounded-2xl border border-orange-100/60">
          <div class="text-xs text-orange-950 font-medium">
            💡 包含 SQLite 一致性镜像快照与工业化多媒体分片目录
          </div>
          <div class="flex items-center space-x-2">
            <button
              @click="handlePrune"
              :disabled="loading"
              class="px-3 py-1.5 text-xs font-semibold text-slate-600 hover:text-rose-600 bg-white hover:bg-rose-50 rounded-xl border border-slate-200 transition-colors"
            >
              一键清理保留前5份
            </button>
            <button
              @click="handleCreateBackup"
              :disabled="loading"
              class="px-4 py-1.5 text-xs font-bold text-white bg-orange-500 hover:bg-orange-600 rounded-xl shadow-sm transition-all"
            >
              {{ loading ? "生成中..." : "+ 立即生成纯 TAR 备份" }}
            </button>
          </div>
        </div>

        <!-- 历史备份记录列表 -->
        <div class="mt-4 max-h-[360px] overflow-y-auto space-y-2">
          <div v-if="backups.length === 0" class="text-center py-12 text-xs text-slate-400">
            暂无历史备份记录，请点击上方按钮立即生成
          </div>

          <div
            v-for="b in backups"
            :key="b.id"
            class="p-3 bg-slate-50 rounded-xl border border-slate-100 flex items-center justify-between text-xs"
          >
            <div class="min-w-0 pr-3">
              <p class="font-bold text-slate-800 truncate">{{ b.filename }}</p>
              <p class="text-xs text-slate-400 mt-0.5">
                {{ b.created_at ? new Date(b.created_at).toLocaleString() : '' }} · 体积: {{ b.file_size_display }} · 物品: {{ b.item_count }}
              </p>
            </div>
            <div class="flex items-center space-x-2 flex-shrink-0">
              <button
                type="button"
                @click="handleDownload(b)"
                :disabled="downloadingId === b.id"
                class="px-2.5 py-1 text-slate-700 bg-white hover:bg-slate-100 rounded-lg border border-slate-200 transition-colors flex items-center space-x-1 font-semibold"
                title="通过 Bearer 鉴权安全下载 TAR 归档包"
              >
                <Download class="w-3.5 h-3.5" />
                <span>{{ downloadingId === b.id ? "下载中..." : "下载" }}</span>
              </button>
              <button
                @click="confirmDeleteBackup(b)"
                class="p-1 text-slate-400 hover:text-rose-600 rounded-lg transition-colors"
                title="删除此备份"
              >
                <Trash2 class="w-3.5 h-3.5" />
              </button>
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

  <!-- 备份删除危险确认遮罩 (无原生 confirm) -->
  <ConfirmDialog
    :is-open="showDeleteConfirm"
    title="确认删除该 TAR 备份？"
    :message="`将永久从磁盘删除归档文件【${deletingBackup?.filename}】，此操作不可逆！`"
    :is-danger="true"
    confirm-text="彻底删除"
    @confirm="executeDelete"
    @cancel="showDeleteConfirm = false"
  />
</template>

<script setup lang="ts">
import { ref, watch } from "vue";
import type { BackupRecord } from "@/types";
import {
  getBackupsApi,
  createBackupApi,
  deleteBackupApi,
  pruneBackupsApi,
  downloadBackupApi,
} from "@/api";
import { useToastStore } from "@/stores/toast";
import ConfirmDialog from "@/components/ui/ConfirmDialog.vue";
import { Archive, X, Download, Trash2 } from "lucide-vue-next";

const props = defineProps<{
  isOpen: boolean;
}>();

const emit = defineEmits(["close"]);
const toastStore = useToastStore();

const backups = ref<BackupRecord[]>([]);
const loading = ref(false);
const downloadingId = ref<number | null>(null);
const showDeleteConfirm = ref(false);
const deletingBackup = ref<BackupRecord | null>(null);

watch(
  () => props.isOpen,
  (open) => {
    if (open) {
      loadBackups();
    }
  }
);

async function loadBackups() {
  try {
    backups.value = await getBackupsApi();
  } catch (err: any) {
    toastStore.error("加载备份列表失败", err.message);
  }
}

async function handleCreateBackup() {
  loading.value = true;
  try {
    const rec = await createBackupApi();
    toastStore.success("TAR 纯打包备份已生成！", `文件名: ${rec.filename} (${rec.file_size_display})`);
    await loadBackups();
  } catch (err: any) {
    toastStore.error("备份生成失败", err.message);
  } finally {
    loading.value = false;
  }
}

async function handlePrune() {
  try {
    const cnt = await pruneBackupsApi(5);
    toastStore.info(`已成功清理 ${cnt} 份陈旧备份`);
    await loadBackups();
  } catch (err: any) {
    toastStore.error("清理历史备份失败", err.message);
  }
}

async function handleDownload(b: BackupRecord) {
  downloadingId.value = b.id;
  try {
    await downloadBackupApi(b.id, b.filename);
    toastStore.success("TAR 备份下载完成", b.filename);
  } catch (err: any) {
    toastStore.error("备份下载失败", err.message);
  } finally {
    downloadingId.value = null;
  }
}

function confirmDeleteBackup(b: BackupRecord) {
  deletingBackup.value = b;
  showDeleteConfirm.value = true;
}

async function executeDelete() {
  if (!deletingBackup.value) return;
  try {
    await deleteBackupApi(deletingBackup.value.id);
    toastStore.success("已彻底删除此备份文件");
    showDeleteConfirm.value = false;
    await loadBackups();
  } catch (err: any) {
    toastStore.error("删除备份失败", err.message);
  }
}
</script>
