<template>
  <div class="relative z-40 px-6 lg:px-8 py-3 bg-white/80 backdrop-blur-md border-b border-slate-100 flex items-center justify-between gap-4">
    <!-- 空间定位轨迹面包屑 (普通成员) / 当前管理工作区名称 (管理员) -->
    <div class="flex items-center space-x-2.5 text-base text-slate-700 min-w-0">
      <template v-if="authStore.isAdmin">
        <Sparkles class="w-5 h-5 flex-shrink-0 text-amber-500" />
        <span class="font-bold text-slate-900 text-base truncate">{{ adminModuleTitle }}</span>
      </template>
      <template v-else>
        <MapPin class="w-5 h-5 flex-shrink-0" :style="{ color: 'var(--theme-primary)' }" />
        <template v-if="!spaceStore.activeHouseId">
          <span class="font-bold text-slate-900 text-base">🌟 全部空间物品</span>
        </template>
        <template v-else>
          <span class="font-bold text-slate-900 text-base">{{ spaceStore.activeHouse?.icon }} {{ spaceStore.activeHouse?.name }}</span>
          <ChevronRight class="w-4 h-4 text-slate-400" />
          <span class="text-slate-700 font-semibold text-base">{{ spaceStore.activeRoom?.icon || "📦" }} {{ cleanName(spaceStore.activeRoom?.name, spaceStore.activeRoom?.icon) || "全部房间" }}</span>
        </template>
      </template>
    </div>

    <!-- 右侧操作区：空间锚定 (普通家庭成员) / 改密与快捷操作 (系统管理员) -->
    <div class="flex items-center space-x-3 flex-shrink-0">
      <!-- 普通成员空间锚定控制胶囊 -->
      <template v-if="!authStore.isAdmin">
        <div
          v-if="spaceStore.isAnchorLocked"
          class="flex items-center space-x-2 px-3.5 py-1.5 rounded-full text-sm font-semibold animate-pulse"
          :style="{ backgroundColor: 'var(--theme-primary-light)', color: 'var(--theme-primary-text)' }"
        >
          <Anchor class="w-4 h-4" />
          <span>已锁定: {{ spaceStore.anchorRoom?.name }}</span>
        </div>

        <button
          v-if="spaceStore.activeRoomId"
          @click="toggleAnchor"
          class="flex items-center space-x-1.5 px-3.5 py-2 rounded-xl text-sm font-semibold transition-all"
          :style="
            spaceStore.isAnchorLocked
              ? { backgroundColor: 'var(--theme-primary)', color: '#ffffff' }
              : { backgroundColor: 'var(--theme-primary-light)', color: 'var(--theme-primary-text)' }
          "
        >
          <Anchor class="w-4 h-4" />
          <span>{{ spaceStore.isAnchorLocked ? "解除锚定" : "锁定空间" }}</span>
        </button>

        <!-- 登记新物品大按钮 -->
        <button
          @click="emit('openCreateItem')"
          class="btn-theme-primary flex items-center space-x-2 px-4 py-2 rounded-xl text-sm font-bold transition-all hover:scale-[1.02]"
        >
          <Plus class="w-4 h-4" />
          <span>登记新物品</span>
        </button>
      </template>

      <!-- 统一设置一级入口（整合切换主题、修改密码、修改昵称、退出登录） -->
      <SettingsMenu
        @open-edit-nickname="emit('openEditNickname')"
        @open-change-password="emit('openChangePassword')"
        @logout-confirm="emit('logoutConfirm')"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from "vue";
import { useAuthStore } from "@/stores/auth";
import { useSpaceStore } from "@/stores/space";
import { useToastStore } from "@/stores/toast";
import SettingsMenu from "@/components/ui/SettingsMenu.vue";
import { MapPin, ChevronRight, Anchor, Plus, Sparkles } from "lucide-vue-next";
import type { AdminSystemStats } from "@/types";

const props = defineProps<{
  currentAdminTab?: string;
  stats?: AdminSystemStats | null;
}>();

const authStore = useAuthStore();
const spaceStore = useSpaceStore();
const toastStore = useToastStore();

const emit = defineEmits([
  "openCreateItem",
  "logoutConfirm",
  "openEditNickname",
  "openChangePassword",
]);

const adminModuleTitle = computed(() => {
  switch (props.currentAdminTab) {
    case "users":
      return "👥 用户账号管理";
    case "categories":
      return "🏷️ 物品分类管理";
    case "search":
    case "inspection":
      return "🔍 多维托底寻物";
    case "backup":
      return "📦 数据备份与恢复";
    case "cleanup":
      return "🧹 存储清理";
    default:
      return "👑 系统管理";
  }
});

function formatBackupTime(iso: string) {
  if (!iso) return "无备份";
  const d = new Date(iso);
  return `${d.getMonth() + 1}/${d.getDate()} ${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
}

function cleanName(name?: string, icon?: string): string {
  if (!name) return "";
  let res = name.trim();
  if (icon && res.startsWith(icon)) {
    res = res.slice(icon.length).trim();
  }
  return res || name;
}

function toggleAnchor() {
  if (spaceStore.isAnchorLocked) {
    spaceStore.releaseAnchor();
    toastStore.info("已解除空间锚定");
  } else {
    if (spaceStore.activeHouseId && spaceStore.activeRoomId) {
      spaceStore.setAnchor(spaceStore.activeHouseId, spaceStore.activeRoomId);
      toastStore.success(
        "空间已成功锚定！",
        `后续录入将自动归档到: ${spaceStore.anchorRoom?.name}`
      );
    }
  }
}
</script>
