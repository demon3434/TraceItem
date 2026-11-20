<template>
  <div id="app" class="font-sans antialiased text-slate-800">
    <router-view />
    <ToastContainer />
  </div>
</template>

<script setup lang="ts">
import { onMounted } from "vue";
import { useAuthStore } from "@/stores/auth";
import ToastContainer from "@/components/ui/ToastContainer.vue";

const authStore = useAuthStore();

onMounted(async () => {
  if (authStore.isAuthenticated) {
    // 每次应用启动或刷新，自动向后端同步最新的用户资料与昵称，杜绝浏览器 LocalStorage 历史缓存残留
    await authStore.fetchCurrentUser();
  }
});
</script>

