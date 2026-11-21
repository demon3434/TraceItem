import { defineStore } from "pinia";
import { ref, computed } from "vue";
import type { User } from "../types";
import { getMeApi } from "../api";

const SERVER_INSTANCE_KEY = "traceitem_server_instance_id";

export const useAuthStore = defineStore("auth", () => {
  const token = ref<string>(localStorage.getItem("traceitem_token") || "");
  const user = ref<User | null>(
    localStorage.getItem("traceitem_user")
      ? JSON.parse(localStorage.getItem("traceitem_user")!)
      : null
  );

  const isAuthenticated = computed(() => !!token.value);
  const isAdmin = computed(() => user.value?.role === "admin");

  function setAuth(accessToken: string, userData: User) {
    token.value = accessToken;
    user.value = userData;
    localStorage.setItem("traceitem_token", accessToken);
    localStorage.setItem("traceitem_user", JSON.stringify(userData));
  }

  function updateUser(userData: User) {
    user.value = userData;
    localStorage.setItem("traceitem_user", JSON.stringify(userData));
  }

  async function fetchCurrentUser() {
    if (!token.value) return null;
    try {
      const u = await getMeApi();
      user.value = u;
      localStorage.setItem("traceitem_user", JSON.stringify(u));
      return u;
    } catch {
      logout();
      return null;
    }
  }

  function logout() {
    token.value = "";
    user.value = null;
    localStorage.removeItem("traceitem_token");
    localStorage.removeItem("traceitem_user");
    if (window.location.pathname !== "/login") {
      window.location.href = "/login";
    }
  }

  function checkServerInstance(serverInstanceId?: string): boolean {
    if (!serverInstanceId || !serverInstanceId.trim()) return false;
    const cleanId = serverInstanceId.trim();
    const lastId = localStorage.getItem(SERVER_INSTANCE_KEY);
    const isLegacySessionWithoutFingerprint = !lastId && !!token.value;

    if ((lastId && lastId !== cleanId) || isLegacySessionWithoutFingerprint) {
      localStorage.setItem(SERVER_INSTANCE_KEY, cleanId);
      logout();
      return true;
    }

    if (lastId !== cleanId) {
      localStorage.setItem(SERVER_INSTANCE_KEY, cleanId);
    }
    return false;
  }

  return {
    token,
    user,
    isAuthenticated,
    isAdmin,
    setAuth,
    updateUser,
    fetchCurrentUser,
    checkServerInstance,
    logout,
  };
});

