<template>
  <aside class="w-72 lg:w-80 bg-white/90 backdrop-blur-md border-r border-slate-100 flex flex-col h-full select-none">
    <!-- 头部品牌标志 -->
    <div class="p-6 pb-4 flex items-center space-x-3.5">
      <img
        src="/logo.png"
        alt="图觅"
        class="w-11 h-11 rounded-2xl object-cover shadow-sm flex-shrink-0"
      />
      <div>
        <h1 class="text-xl font-black text-slate-800 tracking-tight leading-none">图觅</h1>
      </div>
    </div>

    <!-- 空间导航树 (普通成员) / 系统管理导航 (系统管理员) -->
    <div class="flex-1 overflow-y-auto px-4 py-3 space-y-3">
      <!-- 1. 管理员专享管理面板导航 (4大独立单选路由工作台) -->
      <template v-if="authStore.isAdmin">
        <div class="space-y-2 pt-1">
          <div class="px-2 pb-1">
            <span class="text-xs font-bold text-slate-400 uppercase tracking-wider">系统管理</span>
          </div>

          <!-- 菜单 1: 用户账号管理 -->
          <button
            @click="emit('selectAdminTab', 'users')"
            class="w-full flex items-center justify-between px-3.5 py-3 rounded-2xl text-sm font-bold transition-all border text-left"
            :class="
              currentAdminTab === 'users'
                ? 'bg-amber-500 text-white shadow-sm border-amber-500'
                : 'bg-white hover:bg-slate-50 border-slate-200/80 text-slate-800'
            "
          >
            <div class="flex items-center space-x-2.5">
              <span class="text-base">👥</span>
              <div>
                <p class="text-sm font-bold leading-tight">用户账号管理</p>
                <p class="text-xs font-normal opacity-80 mt-0.5">用户账号与状态管理</p>
              </div>
            </div>
            <ChevronRight class="w-4 h-4 opacity-70" />
          </button>

          <!-- 菜单 2: 物品分类管理 -->
          <button
            @click="emit('selectAdminTab', 'categories')"
            class="w-full flex items-center justify-between px-3.5 py-3 rounded-2xl text-sm font-bold transition-all border text-left"
            :class="
              currentAdminTab === 'categories'
                ? 'bg-amber-500 text-white shadow-sm border-amber-500'
                : 'bg-white hover:bg-slate-50 border-slate-200/80 text-slate-800'
            "
          >
            <div class="flex items-center space-x-2.5">
              <span class="text-base">🏷️</span>
              <div>
                <p class="text-sm font-bold leading-tight">物品分类管理</p>
                <p class="text-xs font-normal opacity-80 mt-0.5">预设模板增删改停</p>
              </div>
            </div>
            <ChevronRight class="w-4 h-4 opacity-70" />
          </button>

          <!-- 菜单 3: 多维托底寻物 -->
          <button
            @click="emit('selectAdminTab', 'search')"
            class="w-full flex items-center justify-between px-3.5 py-3 rounded-2xl text-sm font-bold transition-all border text-left"
            :class="
              currentAdminTab === 'search' || currentAdminTab === 'inspection'
                ? 'bg-amber-500 text-white shadow-sm border-amber-500'
                : 'bg-white hover:bg-slate-50 border-slate-200/80 text-slate-800'
            "
          >
            <div class="flex items-center space-x-2.5">
              <span class="text-base">🔍</span>
              <div>
                <p class="text-sm font-bold leading-tight">多维托底寻物</p>
                <p class="text-xs font-normal opacity-80 mt-0.5">多维条件与级联检索</p>
              </div>
            </div>
            <ChevronRight class="w-4 h-4 opacity-70" />
          </button>

          <!-- 菜单 3: 数据备份与恢复 -->
          <button
            @click="emit('selectAdminTab', 'backup')"
            class="w-full flex items-center justify-between px-3.5 py-3 rounded-2xl text-sm font-bold transition-all border text-left"
            :class="
              currentAdminTab === 'backup'
                ? 'bg-amber-500 text-white shadow-sm border-amber-500'
                : 'bg-white hover:bg-slate-50 border-slate-200/80 text-slate-800'
            "
          >
            <div class="flex items-center space-x-2.5">
              <span class="text-base">📦</span>
              <div>
                <p class="text-sm font-bold leading-tight">数据备份与恢复</p>
                <p class="text-xs font-normal opacity-80 mt-0.5">TAR 归档与备份恢复</p>
              </div>
            </div>
            <ChevronRight class="w-4 h-4 opacity-70" />
          </button>

          <!-- 菜单 4: 存储清理 -->
          <button
            @click="emit('selectAdminTab', 'cleanup')"
            class="w-full flex items-center justify-between px-3.5 py-3 rounded-2xl text-sm font-bold transition-all border text-left"
            :class="
              currentAdminTab === 'cleanup'
                ? 'bg-amber-500 text-white shadow-sm border-amber-500'
                : 'bg-white hover:bg-slate-50 border-slate-200/80 text-slate-800'
            "
          >
            <div class="flex items-center space-x-2.5">
              <span class="text-base">🧹</span>
              <div>
                <p class="text-sm font-bold leading-tight">存储清理</p>
                <p class="text-xs font-normal opacity-80 mt-0.5">孤儿文件检查与清理</p>
              </div>
            </div>
            <ChevronRight class="w-4 h-4 opacity-70" />
          </button>
        </div>
      </template>

      <!-- 2. 普通家庭成员空间树 -->
      <SpaceTreeNav
        v-else
        @openCreateHouse="emit('openCreateHouse')"
        @openEditHouse="emit('openEditHouse', $event)"
        @deleteHouseConfirm="emit('deleteHouseConfirm', $event)"
        @openCreateRoom="emit('openCreateRoom', $event)"
        @openEditRoom="emit('openEditRoom', $event)"
        @deleteRoomConfirm="emit('deleteRoomConfirm', $event)"
      />
    </div>

    <!-- 底部管理员空间说明 -->
    <div v-if="authStore.isAdmin" class="p-4 border-t border-slate-100 text-center">
      <span class="text-xs text-slate-400 font-semibold">物迹 · 系统管理中枢</span>
    </div>
  </aside>
</template>

<script setup lang="ts">
import { useAuthStore } from "@/stores/auth";
import SpaceTreeNav from "@/components/space/SpaceTreeNav.vue";
import { ChevronRight } from "lucide-vue-next";

defineProps<{
  currentAdminTab?: "users" | "categories" | "search" | "inspection" | "backup" | "cleanup";
}>();

const authStore = useAuthStore();

const emit = defineEmits([
  "openAdminGodView",
  "openCreateHouse",
  "openEditHouse",
  "deleteHouseConfirm",
  "openCreateRoom",
  "openEditRoom",
  "deleteRoomConfirm",
  "openBackupPanel",
  "selectAdminTab",
]);
</script>
