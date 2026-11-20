<template>
  <div class="space-y-6">
    <!-- 顶栏：多媒体存储与孤儿附件清理工作台 -->
    <div class="bg-white p-5 rounded-3xl border border-slate-100 shadow-2xs flex flex-col md:flex-row md:items-center justify-between gap-4">
      <div class="flex items-center space-x-3">
        <div class="w-10 h-10 rounded-2xl bg-amber-100 text-amber-700 flex items-center justify-center font-bold">
          <Trash2 class="w-5 h-5" />
        </div>
        <div>
          <h3 class="text-lg font-black text-slate-800">存储清理</h3>
          <p class="text-xs text-slate-400 mt-0.5">扫描对比数据库有效附件与磁盘物理文件，一键清理无引用的孤儿文件</p>
        </div>
      </div>

      <div class="flex items-center space-x-2.5">
        <button
          type="button"
          @click="scanOrphans(true)"
          :disabled="scanning || cleaning"
          class="px-4 py-2 text-xs font-bold text-slate-700 bg-slate-100 hover:bg-slate-200 rounded-xl transition-colors flex items-center space-x-1.5"
        >
          <RefreshCw class="w-3.5 h-3.5" :class="{ 'animate-spin': scanning }" />
          <span>{{ scanning ? "正在扫描磁盘..." : "扫描孤儿文件" }}</span>
        </button>

        <button
          v-if="orphanStats && orphanStats.orphan_count > 0"
          type="button"
          @click="promptCleanOrphans"
          :disabled="cleaning || scanning"
          class="px-4 py-2 text-xs font-bold text-white bg-gradient-to-r from-rose-500 to-red-500 hover:from-rose-600 hover:to-red-600 rounded-xl shadow-xs transition-all flex items-center space-x-1.5"
        >
          <Trash2 class="w-3.5 h-3.5" />
          <span>{{ cleaning ? "正在清理释放..." : "一键清理孤儿文件" }}</span>
        </button>
      </div>
    </div>

    <!-- 存储指标卡片 -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
      <div class="p-5 bg-white rounded-3xl border border-slate-100 shadow-2xs">
        <div class="flex items-center justify-between text-xs text-slate-400 font-bold">
          <span>总多媒体物理存储</span>
          <span>💾</span>
        </div>
        <p class="text-2xl font-black text-slate-800 mt-2">
          {{ systemStats?.media_storage_display || "0 KB" }}
        </p>
        <p class="text-xs text-slate-400 mt-1">含图片、音频、短视频与缩略图</p>
      </div>

      <div class="p-5 bg-white rounded-3xl border border-slate-100 shadow-2xs">
        <div class="flex items-center justify-between text-xs text-slate-400 font-bold">
          <span>孤儿文件总数</span>
          <span>🧹</span>
        </div>
        <p class="text-2xl font-black mt-2" :class="orphanStats?.orphan_count ? 'text-rose-600' : 'text-emerald-600'">
          {{ orphanStats ? orphanStats.orphan_count : '-' }} <span class="text-sm font-normal text-slate-400">份</span>
        </p>
        <p class="text-xs text-slate-400 mt-1">未被任何有效物品关联引用的文件</p>
      </div>

      <div class="p-5 bg-white rounded-3xl border border-slate-100 shadow-2xs">
        <div class="flex items-center justify-between text-xs text-slate-400 font-bold">
          <span>可释放磁盘空间</span>
          <span>✨</span>
        </div>
        <p class="text-2xl font-black mt-2" :class="orphanStats?.orphan_size_bytes ? 'text-amber-600' : 'text-slate-700'">
          {{ orphanStats ? orphanStats.orphan_size_display : '-' }}
        </p>
        <p class="text-xs text-slate-400 mt-1">清理后可完全归还宿主机磁盘</p>
      </div>
    </div>

    <!-- 孤儿文件审计清单 -->
    <div class="bg-white rounded-3xl border border-slate-100 shadow-2xs overflow-hidden">
      <div class="px-5 py-3.5 border-b border-slate-100 flex items-center justify-between text-xs font-bold text-slate-500">
        <span>磁盘孤儿文件列表预览</span>
        <span v-if="orphanStats">已列出前 {{ orphanStats.orphan_files.length }} 份</span>
      </div>

      <div v-if="scanning" class="text-center py-20 text-slate-400 text-sm">
        正在逐层递归扫描 /data/media/ 目录与核对数据表...
      </div>

      <div v-else-if="!orphanStats" class="text-center py-20 text-slate-400 text-sm">
        点击上方“扫描孤儿文件”开始审计
      </div>

      <div v-else-if="orphanStats.orphan_count === 0" class="text-center py-20">
        <div class="w-14 h-14 rounded-2xl bg-emerald-50 text-emerald-600 mx-auto flex items-center justify-center text-2xl mb-2">
          ✓
        </div>
        <p class="text-sm font-bold text-slate-700">磁盘整洁，未发现任何孤儿文件！</p>
        <p class="text-xs text-slate-400 mt-1">所有物理文件均与物品附件一一对应有效引用</p>
      </div>

      <div v-else class="divide-y divide-slate-100">
        <div
          v-for="f in orphanStats.orphan_files"
          :key="f"
          class="px-5 py-3 flex items-center justify-between text-xs font-mono text-slate-700 hover:bg-slate-50/60"
        >
          <div class="flex items-center space-x-2 truncate pr-4">
            <span class="w-1.5 h-1.5 rounded-full bg-rose-400 flex-shrink-0"></span>
            <span class="truncate">{{ f }}</span>
          </div>
          <span class="px-2 py-0.5 rounded text-rose-600 bg-rose-50 flex-shrink-0">
            无数据库引用
          </span>
        </div>
      </div>
    </div>

    <!-- 统一二次确认弹窗 -->
    <ConfirmDialog
      :is-open="confirmOpen"
      title="确认物理清理孤儿文件？"
      :message="`系统将从磁盘永久删除 ${orphanStats?.orphan_count} 份无引用孤儿附件，释放约 ${orphanStats?.orphan_size_display} 存储空间。此操作不可逆，是否继续？`"
      confirm-text="确认物理清除"
      :is-danger="true"
      @confirm="executeClean"
      @cancel="confirmOpen = false"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from "vue";
import { Trash2, RefreshCw } from "lucide-vue-next";
import ConfirmDialog from "@/components/ui/ConfirmDialog.vue";
import { getAdminStatsApi, scanOrphanMediaApi, cleanOrphanMediaApi } from "@/api";
import { useToastStore } from "@/stores/toast";
import type { AdminSystemStats, OrphanMediaStats } from "@/types";

const toastStore = useToastStore();

const scanning = ref(false);
const cleaning = ref(false);
const confirmOpen = ref(false);
const systemStats = ref<AdminSystemStats | null>(null);
const orphanStats = ref<OrphanMediaStats | null>(null);

async function loadStats() {
  try {
    systemStats.value = await getAdminStatsApi();
  } catch (err) {
    console.error("加载系统指标失败", err);
  }
}

async function scanOrphans(isManual = false) {
  scanning.value = true;
  try {
    orphanStats.value = await scanOrphanMediaApi();
    if (isManual) {
      if (orphanStats.value.orphan_count === 0) {
        toastStore.success("扫描完成：未发现任何孤儿文件");
      } else {
        toastStore.info(
          `扫描到 ${orphanStats.value.orphan_count} 份孤儿附件`,
          `占用空间: ${orphanStats.value.orphan_size_display}`
        );
      }
    }
    await loadStats();
  } catch (err: any) {
    if (isManual) {
      toastStore.error("扫描孤儿文件失败", err.message);
    }
  } finally {
    scanning.value = false;
  }
}

function promptCleanOrphans() {
  confirmOpen.value = true;
}

async function executeClean() {
  confirmOpen.value = false;
  cleaning.value = true;
  try {
    const res = await cleanOrphanMediaApi();
    toastStore.success(`成功物理清理 ${res.cleaned_count} 份孤儿附件！`);
    await scanOrphans();
  } catch (err: any) {
    toastStore.error("清理孤儿文件失败", err.message);
  } finally {
    cleaning.value = false;
  }
}

onMounted(async () => {
  await loadStats();
  await scanOrphans();
});
</script>

