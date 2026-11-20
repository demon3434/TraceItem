<template>
  <div class="space-y-6">
    <!-- 顶栏：灾备控制与操作卡片 -->
    <div class="bg-white p-5 rounded-3xl border border-slate-100 shadow-2xs flex flex-col md:flex-row md:items-center justify-between gap-4">
      <div class="flex items-center space-x-3">
        <div class="w-10 h-10 rounded-2xl bg-amber-100 text-amber-700 flex items-center justify-center font-bold">
          <Archive class="w-5 h-5" />
        </div>
        <div>
          <h3 class="text-lg font-black text-slate-800">数据备份与恢复</h3>
          <p class="text-xs text-slate-400 mt-0.5">支持快照恢复、本地上传恢复及服务器目录导入恢复</p>
        </div>
      </div>

      <div class="flex items-center space-x-2.5">
        <input
          ref="fileInputRef"
          type="file"
          accept=".tar"
          class="hidden"
          @change="handleFileSelected"
        />
        <button
          type="button"
          @click="triggerFileUpload"
          :disabled="isRestoring || isBackingUp"
          class="px-3.5 py-2 text-xs font-bold text-slate-700 bg-slate-100 hover:bg-slate-200 rounded-xl transition-colors flex items-center space-x-1.5"
        >
          <UploadCloud class="w-4 h-4 text-slate-500" />
          <span>上传 TAR 恢复</span>
        </button>

        <button
          type="button"
          @click="promptCreateBackup"
          :disabled="isBackingUp || isRestoring"
          class="px-4 py-2 text-xs font-bold text-white rounded-xl shadow-xs transition-all flex items-center space-x-1.5"
          :class="isBackingUp ? 'bg-slate-400 cursor-not-allowed' : 'bg-gradient-to-r from-amber-500 to-orange-500 hover:from-amber-600 hover:to-orange-600'"
        >
          <RefreshCw v-if="isBackingUp" class="w-4 h-4 animate-spin" />
          <Plus v-else class="w-4 h-4" />
          <span>{{ isBackingUp ? "正在打包生成备份中..." : "一键生成备份" }}</span>
        </button>
      </div>
    </div>

    <!-- 服务器目录 SCP 导入指引与外部归档扫描区 -->
    <div class="bg-gradient-to-r from-amber-50/70 via-orange-50/50 to-amber-50/40 p-5 rounded-3xl border border-amber-200/60 shadow-2xs space-y-3">
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
        <div class="flex items-center space-x-2 text-amber-900 font-bold text-sm">
          <Server class="w-4 h-4 text-amber-600" />
          <span>服务器导入目录 (/data/media/backups/import/)</span>
        </div>
        <button
          type="button"
          @click="scanImportDirectory(true)"
          :disabled="isScanningImport"
          class="self-start sm:self-auto px-3 py-1.5 text-xs font-bold text-amber-800 bg-white/80 hover:bg-white rounded-xl border border-amber-300 shadow-2xs transition-all flex items-center space-x-1"
        >
          <RefreshCw class="w-3.5 h-3.5" :class="{ 'animate-spin': isScanningImport }" />
          <span>扫描导入目录</span>
        </button>
      </div>
      <p class="text-xs text-amber-800/80 leading-relaxed">
        若备份包超过浏览器上传限制，可通过终端直接使用 SCP 上传至：
        <code class="px-1.5 py-0.5 bg-amber-200/60 rounded text-amber-950 font-mono">/data/media/backups/import/</code>。
        系统将校验其结构（确认含 items.db 数据库）并加载到下方可恢复列表中。
      </p>

      <!-- 扫描到的导入备份列表 -->
      <div v-if="importedBackups.length > 0" class="pt-2 space-y-2">
        <div
          v-for="imp in importedBackups"
          :key="imp.filename"
          class="p-3 bg-white/90 rounded-2xl border flex items-center justify-between text-xs"
          :class="imp.is_valid ? 'border-amber-200' : 'border-rose-200 bg-rose-50/50'"
        >
          <div class="min-w-0 pr-2">
            <div class="flex items-center space-x-2">
              <span class="font-bold text-slate-800 truncate">{{ imp.filename }}</span>
              <span class="px-2 py-0.5 rounded-full font-mono text-slate-500 bg-slate-100">
                {{ imp.file_size_display }}
              </span>
              <span
                v-if="imp.is_valid"
                class="px-2 py-0.5 rounded-full font-bold bg-emerald-50 text-emerald-700"
              >
                校验通过 (含 items.db)
              </span>
              <span
                v-else
                class="px-2 py-0.5 rounded-full font-bold bg-rose-50 text-rose-700"
              >
                非法归档: {{ imp.error_message }}
              </span>
            </div>
            <p v-if="imp.is_valid" class="text-slate-400 mt-1">
              备份于: {{ imp.backup_at ? new Date(imp.backup_at).toLocaleString() : '未知' }} · 物品: {{ imp.item_count ?? '-' }} · 附件: {{ imp.attachment_count ?? '-' }}
            </p>
          </div>

          <button
            v-if="imp.is_valid"
            type="button"
            @click="promptRestoreImport(imp.filename)"
            :disabled="isRestoring"
            class="px-3 py-1.5 text-xs font-bold text-amber-800 bg-amber-100 hover:bg-amber-200 rounded-xl transition-colors flex-shrink-0"
          >
            从该归档恢复
          </button>
        </div>
      </div>
    </div>

    <!-- 历史备份记录快照表格 -->
    <div class="bg-white rounded-3xl border border-slate-100 shadow-2xs overflow-hidden">
      <div class="px-5 py-3.5 border-b border-slate-100 flex flex-wrap items-center justify-between gap-2 text-xs font-bold text-slate-500">
        <span>历史备份记录 (共 {{ backups.length }} 份)</span>
        <div class="flex items-center space-x-2">
          <button
            v-if="backups.length > 3"
            type="button"
            @click="promptPruneBackups"
            class="px-2.5 py-1 text-xs font-bold text-amber-700 bg-amber-50 hover:bg-amber-100 rounded-xl border border-amber-200 transition-colors flex items-center space-x-1"
          >
            <Trash2 class="w-3.5 h-3.5" />
            <span>保留最新 3 份并清理</span>
          </button>
          <button
            @click="loadBackups"
            class="text-amber-600 hover:text-amber-700 flex items-center space-x-1"
          >
            <RefreshCw class="w-3.5 h-3.5" :class="{ 'animate-spin': loading }" />
            <span>刷新</span>
          </button>
        </div>
      </div>

      <div v-if="loading && backups.length === 0" class="text-center py-16 text-slate-400 text-sm">
        正在拉取备份记录...
      </div>

      <div v-else-if="backups.length === 0" class="text-center py-20">
        <div class="w-14 h-14 rounded-2xl bg-amber-50 text-amber-500 mx-auto flex items-center justify-center text-2xl mb-2">
          📦
        </div>
        <p class="text-sm font-bold text-slate-700">暂无历史备份存档</p>
        <p class="text-xs text-slate-400 mt-1">点击右上角“一键生成备份”开始备份吧！</p>
      </div>

      <div v-else class="overflow-x-auto">
        <table class="w-full text-left text-sm border-collapse">
          <thead>
            <tr class="bg-slate-50/70 text-slate-500 text-xs font-bold border-b border-slate-100">
              <th class="py-3 px-4">备份文件名</th>
              <th class="py-3 px-4">包体积</th>
              <th class="py-3 px-4">物品 / 附件</th>
              <th class="py-3 px-4">打包时间</th>
              <th class="py-3 px-4 text-right">管理操作</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="b in paginatedBackups" :key="b.id" class="hover:bg-slate-50/60 transition-colors">
              <td class="py-3.5 px-4 font-mono font-bold text-slate-800 text-xs">
                {{ b.filename }}
              </td>
              <td class="py-3.5 px-4 text-xs font-bold text-slate-600">
                {{ b.file_size_display }}
              </td>
              <td class="py-3.5 px-4 text-xs text-slate-600">
                📦 {{ b.item_count }} 件 · 📷 {{ b.attachment_count }} 份
              </td>
              <td class="py-3.5 px-4 text-xs text-slate-400">
                {{ formatDate(b.created_at) }}
              </td>
              <td class="py-3.5 px-4 text-right space-x-2">
                <button
                  type="button"
                  @click="handleDownload(b)"
                  class="px-2.5 py-1.5 text-xs font-semibold text-slate-600 hover:text-slate-900 bg-slate-100 hover:bg-slate-200 rounded-xl transition-colors"
                  title="下载至本地"
                >
                  下载
                </button>
                <button
                  type="button"
                  @click="promptRestoreSnapshot(b)"
                  :disabled="isRestoring"
                  class="px-2.5 py-1.5 text-xs font-bold text-amber-700 bg-amber-100 hover:bg-amber-200 rounded-xl transition-colors"
                >
                  恢复
                </button>
                <button
                  type="button"
                  @click="promptDeleteBackup(b)"
                  class="px-2.5 py-1.5 text-xs font-semibold text-rose-600 bg-rose-50 hover:bg-rose-100 rounded-xl transition-colors"
                >
                  删除
                </button>
              </td>
            </tr>
          </tbody>
        </table>

        <!-- 分页栏 (默认每页 10 条) -->
        <div v-if="totalPages > 1" class="px-5 py-3 border-t border-slate-100 flex items-center justify-between text-xs text-slate-500">
          <span>共 {{ backups.length }} 条记录，第 {{ currentPage }} / {{ totalPages }} 页</span>
          <div class="flex items-center space-x-2">
            <button
              type="button"
              @click="currentPage--"
              :disabled="currentPage <= 1"
              class="px-3 py-1 rounded-xl border border-slate-200 bg-white hover:bg-slate-50 disabled:opacity-40 disabled:cursor-not-allowed font-medium transition-colors"
            >
              上一页
            </button>
            <span class="px-2 font-mono font-bold text-slate-700">{{ currentPage }}</span>
            <button
              type="button"
              @click="currentPage++"
              :disabled="currentPage >= totalPages"
              class="px-3 py-1 rounded-xl border border-slate-200 bg-white hover:bg-slate-50 disabled:opacity-40 disabled:cursor-not-allowed font-medium transition-colors"
            >
              下一页
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 确认操作对话框 (统一温润大圆角，严禁原生 alert/confirm) -->
    <ConfirmDialog
      :is-open="confirmState.isOpen"
      :title="confirmState.title"
      :message="confirmState.message"
      :confirm-text="confirmState.confirmText"
      :is-danger="confirmState.isDanger"
      @confirm="executeConfirmAction"
      @cancel="confirmState.isOpen = false"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from "vue";
import { Archive, Plus, UploadCloud, Server, RefreshCw, Trash2 } from "lucide-vue-next";
import ConfirmDialog from "@/components/ui/ConfirmDialog.vue";
import {
  getBackupsApi,
  createBackupApi,
  deleteBackupApi,
  downloadBackupApi,
  pruneBackupsApi,
  restoreBackupApi,
  restoreFromUploadApi,
  scanImportBackupsApi,
  restoreFromImportApi,
} from "@/api";
import { useToastStore } from "@/stores/toast";
import type { BackupRecord, ImportedBackupRecord } from "@/types";

const toastStore = useToastStore();

const loading = ref(false);
const isBackingUp = ref(false);
const isRestoring = ref(false);
const isScanningImport = ref(false);
const backups = ref<BackupRecord[]>([]);
const importedBackups = ref<ImportedBackupRecord[]>([]);
const fileInputRef = ref<HTMLInputElement | null>(null);

const currentPage = ref(1);
const pageSize = ref(10);
const sortedBackups = computed(() => {
  return [...backups.value].sort((a, b) => {
    const timeA = new Date(a.created_at).getTime() || 0;
    const timeB = new Date(b.created_at).getTime() || 0;
    return timeB - timeA;
  });
});
const totalPages = computed(() => Math.ceil(sortedBackups.value.length / pageSize.value) || 1);
const paginatedBackups = computed(() => {
  const start = (currentPage.value - 1) * pageSize.value;
  return sortedBackups.value.slice(start, start + pageSize.value);
});

const confirmState = ref<{
  isOpen: boolean;
  title: string;
  message: string;
  confirmText: string;
  isDanger: boolean;
  action: () => Promise<void>;
}>({
  isOpen: false,
  title: "",
  message: "",
  confirmText: "确认",
  isDanger: false,
  action: async () => {},
});

async function loadBackups() {
  loading.value = true;
  try {
    backups.value = await getBackupsApi();
    if (currentPage.value > totalPages.value) currentPage.value = totalPages.value || 1;
  } catch (err) {
    toastStore.error("加载备份记录失败");
  } finally {
    loading.value = false;
  }
}

async function scanImportDirectory(isManual = false) {
  isScanningImport.value = true;
  try {
    importedBackups.value = await scanImportBackupsApi();
    if (isManual) {
      if (importedBackups.value.length === 0) {
        toastStore.info("导入目录中暂未扫描到 .tar 归档文件");
      } else {
        toastStore.success(`扫描到 ${importedBackups.value.length} 个导入归档文件`);
      }
    }
  } catch (err) {
    if (isManual) toastStore.error("扫描导入目录失败");
  } finally {
    isScanningImport.value = false;
  }
}

function promptCreateBackup() {
  confirmState.value = {
    isOpen: true,
    title: "确认生成数据备份？",
    message: "系统将生成包含 SQLite 数据库与多媒体文件的 TAR 归档包。备份期间服务正常运行。",
    confirmText: "开始备份",
    isDanger: false,
    action: handleCreateBackup,
  };
}

async function handleCreateBackup() {
  isBackingUp.value = true;
  try {
    const res = await createBackupApi();
    toastStore.success("TAR 备份归档打包完成！", `归档文件: ${res.filename}`);
    currentPage.value = 1;
    await loadBackups();
  } catch (err: any) {
    toastStore.error("创建备份失败", err.message);
  } finally {
    isBackingUp.value = false;
  }
}

function promptPruneBackups() {
  confirmState.value = {
    isOpen: true,
    title: "确认保留最近 3 份并清理过期备份？",
    message: "系统将仅保留最新的 3 份备份归档，其余历史备份及物理 TAR 文件将被彻底清理以释放磁盘空间。是否继续？",
    confirmText: "清理过期备份",
    isDanger: true,
    action: async () => {
      try {
        const count = await pruneBackupsApi(3);
        toastStore.success(`已成功清理 ${count} 份过期备份文件`);
        await loadBackups();
      } catch (err: any) {
        toastStore.error("清理备份失败", err.message);
      }
    },
  };
}

const handleDownload = (rec: BackupRecord) => downloadBackupApi(rec.id, rec.filename);
const triggerFileUpload = () => fileInputRef.value?.click();

async function handleFileSelected(e: Event) {
  const file = (e.target as HTMLInputElement).files?.[0];
  if (!file) return;
  (e.target as HTMLInputElement).value = "";

  confirmState.value = {
    isOpen: true,
    title: "确认上传并恢复备份？",
    message: `您将上传文件【${file.name}】并恢复系统。当前数据库将被热替换，请确保文件来自受信任的备份。系统会自动生成前置安全快照。`,
    confirmText: "确认恢复",
    isDanger: true,
    action: async () => {
      isRestoring.value = true;
      try {
        await restoreFromUploadApi(file);
        toastStore.success("上传恢复成功！系统全文索引已自动重建。");
        await loadBackups();
      } catch (err: any) {
        toastStore.error("上传恢复失败", err.message);
      } finally {
        isRestoring.value = false;
      }
    },
  };
}

function promptRestoreSnapshot(b: BackupRecord) {
  confirmState.value = {
    isOpen: true,
    title: "确认恢复该历史备份？",
    message: `系统将热替换回档至【${b.filename}】（${b.created_at}）。系统会自动在恢复前生成一份瞬时安全保护快照。是否继续？`,
    confirmText: "立即恢复",
    isDanger: true,
    action: async () => {
      isRestoring.value = true;
      try {
        await restoreBackupApi(b.id);
        toastStore.success("系统恢复完成！已回档至指定快照。");
        await loadBackups();
      } catch (err: any) {
        toastStore.error("恢复快照失败", err.message);
      } finally {
        isRestoring.value = false;
      }
    },
  };
}

function promptRestoreImport(filename: string) {
  confirmState.value = {
    isOpen: true,
    title: "确认从服务器导入目录恢复？",
    message: `系统将加载 /data/media/backups/import/${filename} 并执行热替换恢复。是否确认执行？`,
    confirmText: "确认恢复",
    isDanger: true,
    action: async () => {
      isRestoring.value = true;
      try {
        await restoreFromImportApi(filename);
        toastStore.success("服务器导入恢复成功！全文索引已刷新。");
        await loadBackups();
      } catch (err: any) {
        toastStore.error("恢复失败", err.message);
      } finally {
        isRestoring.value = false;
      }
    },
  };
}

function promptDeleteBackup(b: BackupRecord) {
  confirmState.value = {
    isOpen: true,
    title: "确认删除该备份归档？",
    message: `确定要删除备份记录【${b.filename}】吗？磁盘上的物理 .tar 文件也将被彻底清理。`,
    confirmText: "确认删除",
    isDanger: true,
    action: async () => {
      try {
        await deleteBackupApi(b.id);
        toastStore.success("备份记录已删除");
        await loadBackups();
      } catch (err: any) {
        toastStore.error("删除备份失败", err.message);
      }
    },
  };
}

async function executeConfirmAction() {
  confirmState.value.isOpen = false;
  await confirmState.value.action();
}

function formatDate(iso: string) {
  if (!iso) return "-";
  return new Date(iso).toLocaleString("zh-CN", {
    year: "numeric",
    month: "numeric",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

onMounted(async () => {
  await loadBackups();
  await scanImportDirectory();
});
</script>

