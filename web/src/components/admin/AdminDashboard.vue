<template>
  <div class="flex-1 overflow-y-auto p-6 md:p-8">
    <!-- 专属 100% 独立管理面板切换 (无冗余 Banner，无重复 Tab 栏) -->
    <UserManagementPanel v-if="activeTab === 'users'" />

    <CategoryTemplatePanel v-else-if="activeTab === 'categories'" />

    <MultiDimensionalSearchPanel
      v-else-if="activeTab === 'search' || activeTab === 'inspection'"
      @inspect-item="(it) => emit('inspectItem', it)"
    />

    <BackupRestorePanel v-else-if="activeTab === 'backup'" />

    <MediaCleanupPanel v-else-if="activeTab === 'cleanup'" />

    <div v-else class="text-center py-20 text-slate-400 text-sm">
      请在左侧选择要进入的管理工作区
    </div>
  </div>
</template>

<script setup lang="ts">
import UserManagementPanel from "./UserManagementPanel.vue";
import CategoryTemplatePanel from "./CategoryTemplatePanel.vue";
import MultiDimensionalSearchPanel from "./MultiDimensionalSearchPanel.vue";
import BackupRestorePanel from "./BackupRestorePanel.vue";
import MediaCleanupPanel from "./MediaCleanupPanel.vue";
import type { AdminSystemStats } from "@/types";

defineProps<{
  activeTab: string;
  stats?: AdminSystemStats | null;
}>();

const emit = defineEmits(["updateTab", "openBackupPanel", "inspectItem"]);
</script>
