<template>
  <div class="relative" ref="containerRef">
    <!-- 一级设置触发按钮 -->
    <button
      type="button"
      @click="toggleMenu"
      class="relative flex items-center justify-center w-10 h-10 rounded-xl bg-white hover:bg-slate-50 text-slate-700 shadow-2xs border border-slate-200/90 transition-all hover:scale-105 active:scale-95"
      title="系统设置与账号"
      aria-label="打开设置菜单"
    >
      <Settings class="w-5 h-5" :style="{ color: 'var(--theme-primary)' }" />
    </button>

    <!-- 下拉设置菜单 -->
    <Transition
      enter-active-class="ease-out duration-150 transition"
      enter-from-class="opacity-0 translate-y-2 scale-95"
      enter-to-class="opacity-100 translate-y-0 scale-100"
      leave-active-class="ease-in duration-100 transition"
      leave-from-class="opacity-100 translate-y-0 scale-100"
      leave-to-class="opacity-0 translate-y-2 scale-95"
    >
      <div
        v-if="isOpen"
        class="fixed sm:absolute right-4 sm:right-0 mt-2 rounded-2xl shadow-2xl border border-slate-200 z-50 overflow-hidden transition-all"
        :class="activeView === 'theme' ? 'w-80' : 'w-64'"
        style="background-color: #ffffff;"
      >
        <!-- 主菜单视图 -->
        <div v-show="activeView === 'main'" class="p-2.5 space-y-1">
          <!-- 当前账号信息摘要 -->
          <div class="px-3 py-2.5 mb-1 rounded-xl bg-slate-50 border border-slate-100 flex items-center justify-between gap-2">
            <div class="min-w-0">
              <p class="text-sm font-bold text-slate-800 truncate">
                {{ authStore.user?.nickname || authStore.user?.username || "当前用户" }}
              </p>
              <p class="text-xs text-slate-500 truncate mt-0.5">
                @{{ authStore.user?.username || "-" }}
              </p>
            </div>
            <span
              v-if="authStore.isAdmin"
              class="text-xs px-2 py-0.5 rounded-full font-semibold flex-shrink-0"
              :style="{ backgroundColor: 'var(--theme-primary-light)', color: 'var(--theme-primary-text)' }"
            >
              管理员
            </span>
          </div>

          <!-- 切换主题 -->
          <button
            type="button"
            @click.stop="activeView = 'theme'"
            class="w-full flex items-center justify-between px-3 py-2.5 rounded-xl text-sm font-semibold text-slate-700 hover:bg-slate-50 transition-colors"
          >
            <div class="flex items-center space-x-2.5 min-w-0">
              <Palette class="w-4 h-4 flex-shrink-0" :style="{ color: 'var(--theme-primary)' }" />
              <span>切换主题</span>
            </div>
            <div class="flex items-center space-x-1.5 text-xs text-slate-500 flex-shrink-0">
              <span class="truncate max-w-[88px]">{{ themeStore.currentTheme.name }}</span>
              <ChevronRight class="w-4 h-4 text-slate-400" />
            </div>
          </button>

          <!-- 修改昵称 -->
          <button
            type="button"
            @click="handleAction('openEditNickname')"
            class="w-full flex items-center space-x-2.5 px-3 py-2.5 rounded-xl text-sm font-semibold text-slate-700 hover:bg-slate-50 transition-colors"
          >
            <Pencil class="w-4 h-4 flex-shrink-0 text-sky-500" />
            <span>修改昵称</span>
          </button>

          <!-- 修改密码 -->
          <button
            type="button"
            @click="handleAction('openChangePassword')"
            class="w-full flex items-center space-x-2.5 px-3 py-2.5 rounded-xl text-sm font-semibold text-slate-700 hover:bg-slate-50 transition-colors"
          >
            <KeyRound class="w-4 h-4 flex-shrink-0 text-amber-500" />
            <span>修改密码</span>
          </button>

          <div class="my-1 border-t border-slate-100" />

          <!-- 退出登录 -->
          <button
            type="button"
            @click="handleAction('logoutConfirm')"
            class="w-full flex items-center space-x-2.5 px-3 py-2.5 rounded-xl text-sm font-semibold text-rose-600 hover:bg-rose-50 transition-colors"
          >
            <LogOut class="w-4 h-4 flex-shrink-0" />
            <span>退出登录</span>
          </button>
        </div>

        <!-- 主题选择子视图 -->
        <div v-show="activeView === 'theme'" class="p-3.5 max-h-[460px] overflow-y-auto space-y-3">
          <div class="flex items-center justify-between pb-2.5 border-b border-slate-100">
            <button
              type="button"
              @click.stop="activeView = 'main'"
              class="flex items-center space-x-1.5 text-sm font-bold text-slate-700 hover:text-slate-900 rounded-lg px-1.5 py-1 hover:bg-slate-100 transition-colors"
            >
              <ArrowLeft class="w-4 h-4" />
              <span>返回设置</span>
            </button>
            <span class="text-xs px-2.5 py-0.5 rounded-full bg-orange-100 text-orange-700 font-bold">
              {{ themeStore.currentTheme.name }}
            </span>
          </div>

          <div>
            <div class="px-2 py-1 text-xs font-bold text-orange-600 tracking-wider">
              🌟 活力多巴胺色板
            </div>
            <div class="grid grid-cols-1 gap-1 mt-1">
              <button
                v-for="t in dopamineThemes"
                :key="t.id"
                type="button"
                @click="selectTheme(t.id)"
                class="w-full flex items-center justify-between px-3 py-2 rounded-xl text-sm font-semibold transition-all text-left"
                :class="
                  themeStore.currentThemeId === t.id
                    ? 'bg-orange-50 text-orange-900 border border-orange-200 shadow-xs'
                    : 'text-slate-700 hover:bg-slate-50'
                "
              >
                <div class="flex items-center space-x-2.5 min-w-0">
                  <span class="text-base">{{ t.icon }}</span>
                  <span class="truncate">{{ t.name }}</span>
                </div>
                <div class="flex items-center space-x-2 flex-shrink-0 ml-2">
                  <Check v-if="themeStore.currentThemeId === t.id" class="w-4 h-4 text-orange-600" />
                  <span
                    class="w-4 h-4 rounded-full border-2 border-white shadow-xs"
                    :style="{ backgroundColor: t.primaryColor }"
                  />
                </div>
              </button>
            </div>
          </div>

          <div class="pt-2 border-t border-slate-100">
            <div class="px-2 py-1 text-xs font-bold text-slate-600 tracking-wider">
              🏛️ shadcn 官方经典色系
            </div>
            <div class="grid grid-cols-1 gap-1 mt-1">
              <button
                v-for="t in shadcnThemes"
                :key="t.id"
                type="button"
                @click="selectTheme(t.id)"
                class="w-full flex items-center justify-between px-3 py-2 rounded-xl text-sm font-medium transition-all text-left"
                :class="
                  themeStore.currentThemeId === t.id
                    ? 'bg-slate-100 text-slate-900 font-bold border border-slate-300 shadow-xs'
                    : 'text-slate-600 hover:bg-slate-50'
                "
              >
                <div class="flex items-center space-x-2 min-w-0">
                  <span class="text-base">{{ t.icon }}</span>
                  <span class="truncate">{{ t.name }}</span>
                </div>
                <div class="flex items-center space-x-2 flex-shrink-0 ml-2">
                  <Check v-if="themeStore.currentThemeId === t.id" class="w-4 h-4 text-slate-700" />
                  <span
                    class="w-3.5 h-3.5 rounded-full border-2 border-white shadow-xs"
                    :style="{ backgroundColor: t.primaryColor }"
                  />
                </div>
              </button>
            </div>
          </div>
        </div>
      </div>
    </Transition>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from "vue";
import { useAuthStore } from "@/stores/auth";
import { useThemeStore } from "@/stores/theme";
import {
  Settings,
  Palette,
  Pencil,
  KeyRound,
  LogOut,
  ChevronRight,
  ArrowLeft,
  Check,
} from "lucide-vue-next";

const emit = defineEmits<{
  openEditNickname: [];
  openChangePassword: [];
  logoutConfirm: [];
}>();

const authStore = useAuthStore();
const themeStore = useThemeStore();

const isOpen = ref(false);
const activeView = ref<"main" | "theme">("main");
const containerRef = ref<HTMLElement | null>(null);

const dopamineThemes = computed(() =>
  themeStore.themes.filter((t) => t.category === "dopamine")
);

const shadcnThemes = computed(() =>
  themeStore.themes.filter((t) => t.category === "shadcn")
);

function toggleMenu() {
  isOpen.value = !isOpen.value;
  if (isOpen.value) {
    activeView.value = "main";
  }
}

function closeMenu() {
  isOpen.value = false;
  activeView.value = "main";
}

function handleAction(eventName: "openEditNickname" | "openChangePassword" | "logoutConfirm") {
  closeMenu();
  if (eventName === "openEditNickname") emit("openEditNickname");
  else if (eventName === "openChangePassword") emit("openChangePassword");
  else emit("logoutConfirm");
}

function selectTheme(themeId: string) {
  themeStore.applyTheme(themeId);
}

function handleClickOutside(e: MouseEvent) {
  if (containerRef.value && !containerRef.value.contains(e.target as Node)) {
    closeMenu();
  }
}

onMounted(() => {
  document.addEventListener("click", handleClickOutside);
});

onUnmounted(() => {
  document.removeEventListener("click", handleClickOutside);
});
</script>
